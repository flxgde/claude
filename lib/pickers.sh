# Generic single/multi-choice prompt helpers, fzf-backed with a plain numbered-prompt fallback.
# Domain-specific prompting (agent/skill selection, the git-workflow wizard) lives in
# selection.sh / git_workflow.sh and is built on top of these.
#
# None of these pickers return their answer via stdout/echo + $(...) — they set the globals
# PICK_RESULT (the answer) and WIZARD_BACK (true if the user asked to go back instead of
# answering), and every call site invokes them as a bare statement, never wrapped in $(...). This
# is deliberate, not a style choice: $(...) forks a SUBSHELL, and a subshell's variable
# assignments — PICK_RESULT and WIZARD_BACK included — vanish the instant it exits instead of
# reaching the caller. An earlier version of this file returned the answer via `echo` with callers
# doing `result=$(pick ...)`, which silently discarded every WIZARD_BACK/PICK_RESULT assignment
# made anywhere inside that call tree; the whole back-navigation feature was a no-op until this was
# caught by an end-to-end scripted-stdin test (see the manual test recipe in CLAUDE.md) showing
# every wizard step firing exactly once no matter what the fake input said. Keep every call site as
# `pick ...; x="$PICK_RESULT"`, never `x=$(pick ...)`.
#
# Esc is distinguished from Ctrl-C via fzf's `--expect=esc`: with that key registered, pressing Esc
# no longer exits 130 (fzf's default cancel code, still used by Ctrl-C) — instead fzf exits 0 and
# prints the triggering key's name as its own first output line, ahead of the normal result.
# check_fzf_cancelled() still only fires (and still aborts the whole install) on a genuine 130,
# i.e. Ctrl-C — Esc is a first-class "go back," not a cancellation.
#
# bash dynamic-scoping gotcha (found live while building back-navigation): run_wizard_from()
# (lib/ui.sh) declares `local i` and `local direction` that stay live for its entire loop — which
# runs every resolve_*() step function and, transitively, every picker in this file. Bash's `local`
# is dynamically scoped: a descendant function that assigns a BARE (non-local) `i` doesn't get its
# own variable, it silently overwrites the nearest ancestor frame's `local i` still on the call
# stack. pick_with_prompt()/pick_deselect_with_prompt() print their numbered item list via
# `for i in "${!items[@]}"` without declaring `i` local — while these are called (indirectly)
# from inside run_wizard_from()'s loop, that bare loop clobbered run_wizard_from's own `i` with
# whatever index the list-printing loop last reached (e.g. a 12-item Agents list left it at 11),
# corrupting the step index the very first time the wizard revisited an earlier step. Every loop
# variable used anywhere in this file (or in auto.sh/selection.sh/practices.sh/git_workflow.sh,
# all of which run inside that same window) must be `local` for exactly this reason — it's not
# just style here, an unlocalized loop var is a latent step-index corruption bug.
PICK_RESULT=""

# Sentinel item pick() offers so the user can submit an explicit "zero selected" answer. Plain
# multi-select otherwise can't distinguish "deliberately picked nothing" from "didn't bother
# picking anything" — blank Enter has always defaulted to "select everything" (the `-z
# "$PICK_RESULT"` branches below), which is a fine convenience default but leaves no way to
# actually choose none, e.g. Guided mode's per-group screens (lib/auto.sh) when you want zero items
# from a group (say, no frontend at all). Selecting this item always wins outright over any other
# item also toggled — picking "none" and something else at the same time is a mis-click, not a
# request to include that item, so its presence short-circuits the whole result to "none"
# regardless of what else got toggled. That's the same literal string resolve() (lib/selection.sh)
# already treats as "install zero for this category," so resolve_agent_selection/
# resolve_skill_selection need no extra handling; for Guided's per-group screens, which match
# picked labels directly against category labels rather than going through resolve(), "none" simply
# fails to match any real label, so nothing gets applied for that group either way.
PICK_NONE_LABEL="(none of these)"

# Splits fzf --expect output into the triggering key (its first line) and the actual result (the
# rest). Sets WIZARD_BACK and PICK_RESULT.
_pick_split_expect() {
  local raw="$1" key
  key=$(printf '%s\n' "$raw" | head -n1)
  if [[ "$key" == "esc" ]]; then
    WIZARD_BACK=true
    PICK_RESULT=""
    return 0
  fi
  WIZARD_BACK=false
  PICK_RESULT=$(printf '%s\n' "$raw" | tail -n +2)
}

pick_with_fzf() {
  local label="$1"; shift
  local raw rc=0
  raw=$(printf '%s\n' "$@" "$PICK_NONE_LABEL" \
    | fzf --multi --height=50% --border --reverse \
          --bind "space:toggle+down,ctrl-a:select-all" \
          --expect=esc \
          --prompt="$label > " \
          --header="SPACE = select/deselect  |  ENTER = confirm  |  ESC = back  |  CTRL-A = select all") || rc=$?
  check_fzf_cancelled "$rc"
  _pick_split_expect "$raw"
  $WIZARD_BACK && return 0
  if printf '%s\n' "$PICK_RESULT" | grep -qxF "$PICK_NONE_LABEL"; then
    PICK_RESULT="none"
  elif [[ -z "$PICK_RESULT" ]]; then
    PICK_RESULT=$(printf '%s,' "$@" | sed 's/,$//')
  else
    PICK_RESULT=$(printf '%s\n' "$PICK_RESULT" | tr '\n' ',' | sed 's/,$//')
  fi
  return 0
}

pick_with_prompt() {
  local label="$1"; shift
  local items=("$@")
  local i
  {
    echo ""
    echo -e "${BOLD}Available $label:${RESET}"
    for i in "${!items[@]}"; do
      printf "  %2d) %s\n" "$((i+1))" "${items[$i]}"
    done
    echo ""
  } >&2
  local selection
  prompt_read -r -p "Numbers (space-separated), 'all', 'none', or 'b' to go back [all]: " selection
  if [[ "$selection" =~ ^[Bb]([Aa][Cc][Kk])?$ ]]; then
    WIZARD_BACK=true
    return 0
  fi
  WIZARD_BACK=false
  if [[ "$selection" == "none" ]]; then
    PICK_RESULT="none"
  elif [[ -z "$selection" || "$selection" == "all" ]]; then
    PICK_RESULT=$(printf '%s,' "${items[@]}" | sed 's/,$//')
  else
    local result="" n idx
    for n in $selection; do
      # Validate before arithmetic: `idx=$((n-1))` on a non-numeric token (a typo, a stray word)
      # isn't just "wrong index," it's a crash — bash arithmetic resolves a non-numeric operand as
      # another variable NAME to look up, and under `set -u` an unset one throws "unbound
      # variable" and kills the whole install script, not just this picker. This was found live:
      # typing "none" here (meant for the OTHER picker, pick_with_prompt, where it's a real
      # keyword) took the whole wizard down instead of printing "Invalid number."
      if [[ ! "$n" =~ ^[0-9]+$ ]]; then
        warn "Invalid number $n — skipped"
        continue
      fi
      idx=$((n-1))
      if [[ $idx -ge 0 && $idx -lt ${#items[@]} ]]; then
        result+="${items[$idx]},"
      else
        warn "Invalid number $n — skipped"
      fi
    done
    PICK_RESULT="${result%,}"
  fi
  return 0
}

pick() {
  local label="$1"; shift
  if command -v fzf &>/dev/null; then
    pick_with_fzf "$label" "$@"
  else
    warn "fzf not found — using numbered prompt (brew install fzf for a better experience)"
    pick_with_prompt "$label" "$@"
  fi
}

# ── Opt-out multi-select (best-practices picker) ──────────────────────────────
# Same idea as pick(), inverted: every item starts INCLUDED, and the user removes the ones they
# don't want instead of building the list up from nothing. Used where "everything" is the
# recommended default and deselecting an exception is the common interaction, not selecting from
# scratch.
pick_deselect_with_fzf() {
  local label="$1"; shift
  local raw rc=0
  # --sync + the "start" event is fzf's own documented way to pre-select everything before the
  # first render (see `fzf`'s man page KEY/EVENT BINDING examples) — without --sync there's a race
  # where the first frame can paint before the selection is applied.
  raw=$(printf '%s\n' "$@" \
    | fzf --multi --height=50% --border --reverse --sync \
          --bind "start:select-all,space:toggle+down,ctrl-a:select-all,ctrl-d:deselect-all" \
          --expect=esc \
          --prompt="$label > " \
          --header="All included by default — SPACE = toggle  |  ENTER = confirm  |  ESC = back  |  CTRL-D = deselect all") || rc=$?
  check_fzf_cancelled "$rc"
  _pick_split_expect "$raw"
  $WIZARD_BACK && return 0
  # Unlike pick_with_fzf, an empty result here is NOT ambiguous: everything starts selected, so an
  # empty result at a normal (non-cancelled) exit means the user deliberately deselected
  # everything and confirmed — that's a real "include nothing" answer, not "didn't bother."
  PICK_RESULT=$(printf '%s\n' "$PICK_RESULT" | tr '\n' ',' | sed 's/,$//')
  return 0
}

pick_deselect_with_prompt() {
  local label="$1"; shift
  local items=("$@")
  local i
  {
    echo ""
    echo -e "${BOLD}Available $label${RESET} ${DIM}(all included by default)${RESET}:"
    for i in "${!items[@]}"; do
      printf "  %2d) %s\n" "$((i+1))" "${items[$i]}"
    done
    echo ""
  } >&2
  local selection
  prompt_read -r -p "Numbers to EXCLUDE (space-separated), Enter to include all, or 'b' to go back: " selection
  if [[ "$selection" =~ ^[Bb]([Aa][Cc][Kk])?$ ]]; then
    WIZARD_BACK=true
    return 0
  fi
  WIZARD_BACK=false
  if [[ -z "$selection" ]]; then
    PICK_RESULT=$(printf '%s,' "${items[@]}" | sed 's/,$//')
    return 0
  fi
  local exclude=() n idx
  for n in $selection; do
    # See the matching check in pick_with_prompt() (same file) — a non-numeric token here would
    # otherwise reach `idx=$((n-1))` and crash the whole install ("unbound variable" under
    # `set -u`), not just fail to parse as an index.
    if [[ ! "$n" =~ ^[0-9]+$ ]]; then
      warn "Invalid number $n — skipped"
      continue
    fi
    idx=$((n-1))
    if [[ $idx -ge 0 && $idx -lt ${#items[@]} ]]; then
      exclude+=("${items[$idx]}")
    else
      warn "Invalid number $n — skipped"
    fi
  done
  local result="" item is_excluded e
  for item in "${items[@]}"; do
    is_excluded=false
    if [[ ${#exclude[@]} -gt 0 ]]; then
      for e in "${exclude[@]}"; do
        [[ "$item" == "$e" ]] && is_excluded=true
      done
    fi
    $is_excluded || result+="$item,"
  done
  PICK_RESULT="${result%,}"
  return 0
}

pick_deselect() {
  local label="$1"; shift
  if command -v fzf &>/dev/null; then
    pick_deselect_with_fzf "$label" "$@"
  else
    warn "fzf not found — using numbered prompt (brew install fzf for a better experience)"
    pick_deselect_with_prompt "$label" "$@"
  fi
}

# ── Single-choice picker (git workflow wizard) ────────────────────────────────
ask_choice() {
  local question="$1"; shift
  local options=("$@")
  local result

  if command -v fzf &>/dev/null; then
    local raw rc=0
    raw=$(printf '%s\n' "${options[@]}" \
      | fzf --height=40% --border --reverse \
            --expect=esc \
            --prompt="$question > " \
            --header="ENTER = confirm  |  ESC = back") || rc=$?
    check_fzf_cancelled "$rc"
    _pick_split_expect "$raw"
    $WIZARD_BACK && return 0
    result="$PICK_RESULT"
  else
    {
      echo ""
      echo -e "${BOLD}$question${RESET}"
      local i
      for i in "${!options[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${options[$i]}"
      done
    } >&2
    local sel
    prompt_read -r -p "Choice [1) ${options[0]}], or 'b' to go back: " sel
    if [[ "$sel" =~ ^[Bb]([Aa][Cc][Kk])?$ ]]; then
      WIZARD_BACK=true
      return 0
    fi
    WIZARD_BACK=false
    if [[ -z "$sel" ]]; then
      result="${options[0]}"
    elif [[ "$sel" =~ ^[0-9]+$ && $((sel-1)) -ge 0 && $((sel-1)) -lt ${#options[@]} ]]; then
      result="${options[$((sel-1))]}"
    else
      warn "Invalid choice — defaulting to '${options[0]}'"
      result="${options[0]}"
    fi
  fi

  [[ -z "$result" ]] && result="${options[0]}"
  PICK_RESULT="$result"
  return 0
}
