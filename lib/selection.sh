# Discovering installable items and turning the user's -a/-s selections (or a picker's output)
# into the concrete AGENTS_TO_INSTALL / SKILLS_TO_INSTALL arrays used by the rest of the script.

discover_items() {
  ALL_AGENTS=()
  while IFS= read -r f; do
    ALL_AGENTS+=("$(basename "$f" .md)")
  done < <(find "$AGENTS_SRC" -maxdepth 1 -name "*.md" | sort)

  ALL_SKILLS=()
  while IFS= read -r d; do
    ALL_SKILLS+=("$(basename "$d")")
  done < <(find "$SKILLS_SRC" -maxdepth 1 -mindepth 1 -type d | sort)

  [[ ${#ALL_AGENTS[@]} -gt 0 ]] || die "No agents found in $AGENTS_SRC"
  [[ ${#ALL_SKILLS[@]} -gt 0 ]] || die "No skills found in $SKILLS_SRC"
  return 0
}

# One step function per WIZARD_STEPS entry (see run_wizard_from() in lib/ui.sh) — kept as two
# separate functions, not one combined "agents+skills" function, specifically so Esc during the
# Skills picker can go back to the Agents picker (the previous wizard step) via the generic driver,
# instead of needing its own bespoke two-question back-loop the way git_workflow.sh's five-question
# breakdown does.
#
# --auto/Guided mode already applied their selection (see apply_detected_selection in auto.sh) —
# nothing to prompt for, ever, while that mode holds (going back to Mode and picking a different one
# resets AUTO_MODE/GUIDED_MODE — see resolve_setup_mode()). AGENTS_FLAG_PRESET/SKILLS_FLAG_PRESET
# (captured once in install.sh from -a/-s right after argument parsing, before any wizard step can
# mutate SELECTED_AGENTS/SELECTED_SKILLS) is what "permanently preset via the CLI" means here —
# checking `[[ -n "$SELECTED_AGENTS" ]]` instead would also be true after this step's own picker ran
# once, which would wrongly turn a revisit (after going back and forward again) into a silent skip
# instead of re-prompting.
resolve_agent_selection() {
  if $AUTO_MODE || $GUIDED_MODE; then
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi
  if $AGENTS_FLAG_PRESET || $NO_CONFIRM; then
    [[ -z "$SELECTED_AGENTS" ]] && SELECTED_AGENTS="all"
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi

  step "$STEP_IDX_AGENTS" "${WIZARD_STEPS[$STEP_IDX_AGENTS]}"
  pick "Agents" "${ALL_AGENTS[@]}"
  WIZARD_SKIPPED=false
  $WIZARD_BACK || SELECTED_AGENTS="$PICK_RESULT"
  return 0
}

resolve_skill_selection() {
  if $AUTO_MODE || $GUIDED_MODE; then
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi
  if $SKILLS_FLAG_PRESET || $NO_CONFIRM; then
    [[ -z "$SELECTED_SKILLS" ]] && SELECTED_SKILLS="all"
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi

  step "$STEP_IDX_SKILLS" "${WIZARD_STEPS[$STEP_IDX_SKILLS]}"
  pick "Skills" "${ALL_SKILLS[@]}"
  WIZARD_SKIPPED=false
  $WIZARD_BACK || SELECTED_SKILLS="$PICK_RESULT"
  return 0
}

# Expands a "-a"/"-s" selection string (comma-separated names, "all", "none", or empty) against
# the full list, warning on and dropping unknown names. "none" is an explicit "install zero" —
# distinct from "" (unset, defaults to "all") — used by --auto when a category detects nothing.
resolve() {
  local selection="$1"; shift
  local all=("$@")

  [[ "$selection" == "none" ]] && return

  if [[ -z "$selection" || "$selection" == "all" ]]; then
    printf '%s\n' "${all[@]}"
    return
  fi

  while IFS=',' read -ra names; do
    for name in "${names[@]}"; do
      name="${name#"${name%%[![:space:]]*}"}"
      name="${name%"${name##*[![:space:]]}"}"
      [[ -z "$name" ]] && continue
      local found=false
      for item in "${all[@]}"; do
        [[ "$item" == "$name" ]] && { found=true; break; }
      done
      if $found; then echo "$name"
      else warn "Unknown item '$name' — skipped"
      fi
    done
  done <<< "$selection"
}

build_install_arrays() {
  AGENTS_TO_INSTALL=()
  while IFS= read -r a; do [[ -n "$a" ]] && AGENTS_TO_INSTALL+=("$a"); done \
    < <(resolve "$SELECTED_AGENTS" "${ALL_AGENTS[@]}")

  SKILLS_TO_INSTALL=()
  while IFS= read -r s; do [[ -n "$s" ]] && SKILLS_TO_INSTALL+=("$s"); done \
    < <(resolve "$SELECTED_SKILLS" "${ALL_SKILLS[@]}")

  [[ ${#AGENTS_TO_INSTALL[@]} -gt 0 || ${#SKILLS_TO_INSTALL[@]} -gt 0 ]] \
    || die "Nothing selected — exiting"
  return 0
}

# Gives every ok() line during the copy/remove phase a running "[n/total]" counter instead of a
# static "[ ok]" tag, so file-writing progress is visible, not just the wizard prompts before it.
compute_total_ops() {
  TOTAL_OPS=1  # AGENTS.md
  tool_active claude && TOTAL_OPS=$((TOTAL_OPS+1))  # .claude/CLAUDE.md
  local per_agent_ops=0
  tool_active claude   && per_agent_ops=$((per_agent_ops+1))
  tool_active opencode && per_agent_ops=$((per_agent_ops+1))
  TOTAL_OPS=$((TOTAL_OPS + per_agent_ops * ${#AGENTS_TO_INSTALL[@]} + ${#SKILLS_TO_INSTALL[@]}))
  DONE_OPS=0
  return 0
}
