# Console output helpers, the fzf-cancel guard, and the "wizard" framing (intro banner + running
# step counter) shared by every interactive stage of install.sh.

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; DIM=''; RESET=''
fi

info() { echo -e "${BLUE}[info]${RESET}  $*"; }
ok()   { DONE_OPS=$((DONE_OPS+1)); echo -e "${GREEN}[$DONE_OPS/$TOTAL_OPS]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[warn]${RESET}  $*" >&2; }
die()  { echo "[error] $*" >&2; exit 1; }

run() {
  if $DRY_RUN; then echo -e "${YELLOW}[dry]${RESET}   $*"
  else eval "$@"
  fi
}

tool_active() { [[ "$TOOL" == "both" || "$TOOL" == "$1" ]]; }

# Wraps `read` for every interactive prompt that isn't fzf-backed (fzf talks to /dev/tty on its
# own regardless of fd 0, so it's unaffected). Needed for `curl -fsSL ... | bash`: bash's own stdin
# in that invocation IS the piped script text, already at EOF by the time an interactive prompt
# runs — a bare `read` there returns instantly (empty, non-zero) instead of waiting on the user,
# and under this script's `set -e` that silently kills the whole install right after printing the
# prompt, before the user can type anything. Falls back to plain `read` (unchanged behavior) when
# fd 0 is already a terminal, or when /dev/tty isn't available at all (e.g. truly non-interactive —
# in which case NO_CONFIRM should have been used and this was already going to fail either way).
prompt_read() {
  if [[ -t 0 || ! -r /dev/tty ]]; then
    read "$@"
  else
    read "$@" < /dev/tty
  fi
}

# fzf catches Ctrl-C/Esc itself and exits 130 as a *normal* exit (not killed-by-signal), so bash
# never sees the interrupt propagate — without this check a cancelled picker would silently fall
# through to its "empty result" default (select everything / first option) instead of aborting.
check_fzf_cancelled() {
  [[ $1 -eq 130 ]] && { echo "" >&2; die "Cancelled."; }
  return 0
}

# ── Confirm prompt ────────────────────────────────────────────────────────────
# Sets WIZARD_BACK the same way the pickers do (see pickers.sh's top comment for why a global
# instead of an exit code) — 'b' at the review screen re-enters the wizard from the git-workflow
# step backward, instead of the plain "proceed/abort" choice run_install()/run_uninstall() used to
# offer. Callers must check WIZARD_BACK before treating a return as "proceed."
confirm() {
  $DRY_RUN && return 0
  echo -n "Proceed? [Y/n/b=back] "
  prompt_read -r answer
  if [[ "$answer" =~ ^[Bb]([Aa][Cc][Kk])?$ ]]; then
    WIZARD_BACK=true
    return 0
  fi
  WIZARD_BACK=false
  [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  echo ""
}

# ── Wizard framing ────────────────────────────────────────────────────────────
# Any interactive run (anything short of --no-confirm) is framed as a short wizard: an intro
# banner up front explaining what's about to happen, and a running "Step X of N" header before
# each stage so it's always clear how far through the install/uninstall the user is. WIZARD_STEPS,
# STEP_TOTAL, and the STEP_IDX_* constants are populated by the entrypoint once it knows whether
# this is an install or an uninstall (and, for install, whether --auto is being offered) — these
# are just the zero-value defaults until then.
STEP_TOTAL=0
WIZARD_STEPS=()

# WIZARD_BACK/WIZARD_SKIPPED are the two-flag protocol every resolve_*() step function and every
# picker (pickers.sh) uses to talk to run_wizard_from() below: WIZARD_SKIPPED=true means the step
# did nothing interactive (pre-filled via a flag, --no-confirm, --auto, or --uninstall not needing
# it) and should just be passed through in whatever direction the wizard is already travelling;
# WIZARD_SKIPPED=false + WIZARD_BACK=true means the step DID prompt and the user asked to go back;
# WIZARD_SKIPPED=false + WIZARD_BACK=false means the step prompted and the user answered forward.
# Both are reset to false at the top of every run_wizard_from() iteration so a stale value from an
# unrelated earlier call can never leak into the next step's decision.
WIZARD_BACK=false
WIZARD_SKIPPED=false
WIZARD_FUNCS=()

# Runs WIZARD_FUNCS[start_idx..] in the given direction (1 = forward, -1 = backward), letting each
# step's WIZARD_BACK flip the direction and step back one, and letting a skipped step pass through
# in whatever direction was already in effect (see the comment above) — this is what makes "Esc"
# during Auto/Guided mode correctly jump straight back to the mode question instead of stopping on
# the no-op Agents/Skills steps that Auto/Guided fill in without prompting. Used both for the
# initial forward pass through the wizard (run_wizard_steps(), start_idx=0, direction=1) and to
# re-enter it from the install/uninstall review screen when the user answers 'b' to confirm()
# (rerun_wizard_from_git() in actions.sh, start_idx=last, direction=-1) — same traversal logic,
# just a different entry point.
run_wizard_from() {
  local i="$1" direction="$2"
  while [[ $i -ge 0 && $i -lt ${#WIZARD_FUNCS[@]} ]]; do
    WIZARD_BACK=false; WIZARD_SKIPPED=false
    "${WIZARD_FUNCS[$i]}"
    if $WIZARD_SKIPPED; then
      i=$((i + direction))
    elif $WIZARD_BACK; then
      direction=-1
      i=$((i - 1))
    else
      direction=1
      i=$((i + 1))
    fi
    [[ $i -lt 0 ]] && { i=0; direction=1; }
  done
  return 0
}

# The wizard's one and only forward pass, called once from install.sh after the step list is known.
run_wizard_steps() {
  WIZARD_FUNCS=(resolve_setup_mode resolve_agent_selection resolve_skill_selection \
                resolve_best_practices resolve_git_workflow)
  run_wizard_from 0 1
  return 0
}

# Re-entry point for confirm()'s 'b' answer at the review screen (run_install()/run_uninstall() in
# lib/actions.sh) — starts at the last wizard step (git workflow) moving backward, so it cascades
# through Practices/Skills/Agents/Mode exactly the same way Esc does mid-wizard, just entered from
# the far end instead of stopped there already.
rerun_wizard_from_git() {
  run_wizard_from $((${#WIZARD_FUNCS[@]} - 1)) -1
  return 0
}

# step() takes the step's fixed index (one of the STEP_IDX_* constants the entrypoint computed),
# not an auto-incrementing counter: some steps get skipped (pre-filled via -a/-s/git flags/--auto),
# and a counter would then under-report — e.g. the final "review" step showing "2/5" instead of
# "5/5" because 3 steps in between never ran. Indexing off the step's real position means the last
# step displayed is always "N/N" regardless of which earlier ones were skipped.
step() {
  local idx="$1"; shift
  echo ""
  echo -e "${BOLD}${BLUE}Step $((idx+1))/$STEP_TOTAL${RESET} ${BOLD}$*${RESET}"
  echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"
}

print_intro() {
  local verb="$1"
  echo ""
  echo -e "${BOLD}Claude Code / OpenCode installer${RESET}"
  echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"
  if [[ "$verb" == "Uninstall" ]]; then
    echo "This removes the agents, skills, and shared AGENTS.md rules that were installed"
    echo "into this project — nothing outside it is touched:"
  else
    echo "This installs agent configs, skills, and a shared AGENTS.md rules file for"
    echo "Claude Code and/or OpenCode into this project — nothing outside it is touched:"
  fi
  echo ""
  echo -e "  ${BOLD}$PWD${RESET}  ${DIM}(tool: $TOOL)${RESET}"
  echo ""
  echo "You'll walk through:"
  local i=1 label
  for label in "${WIZARD_STEPS[@]}"; do
    echo "  $i. $label"
    i=$((i+1))
  done
  echo ""
  echo -e "${DIM}Esc goes back a step, Ctrl-C cancels — nothing is written until you confirm the plan.${RESET}"
}
