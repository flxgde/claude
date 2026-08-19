# The dist/AGENTS.md sections that can be toggled independently of Auto/Guided/Manual setup mode
# or which agents/skills got installed — general working-style practices (plan mode, verification,
# etc.), not stack-specific. Each is wrapped in dist/AGENTS.md as
# <!-- IF_PRACTICE:id --> ... <!-- END_IF --> (see render_agents_md() in lib/actions.sh).
#
# Kept as a plain (id, label) list here rather than one-file-per-practice like agents/detection
# categories: these aren't independently detectable or file-backed, just a handful of fixed
# toggles within a single document — splitting them into files would be ceremony without payoff.
# Git Workflow and Core Principles are NOT in this list: Git Workflow already has its own dedicated
# wizard question (and can't be "on/off", only reconfigured), and Core Principles is treated as
# foundational/non-optional rather than a togglable practice.
PRACTICE_IDS=(plan-mode self-improvement verification demand-elegance skills sub-agents)
PRACTICE_LABELS=(
  "Plan Mode Default — plan before non-trivial work"
  "Self-Improvement Loop — log corrections to tasks/lessons.md"
  "Verification Before Done — never claim done without proof"
  "Demand Elegance — pause and ask for a more elegant solution on non-trivial changes"
  "Skills — use packaged skills for matching capabilities"
  "Sub-agents — prefer delegating to specialist agents over main-context work"
)

# No-op for --uninstall (it deletes AGENTS.md outright, doesn't care about its content) — also
# what STEP_IDX_PRACTICES=-1 there guards against, but this is the belt to that suspenders.
# PRACTICES_FLAG_PRESET (captured once in install.sh from --practices right after argument parsing)
# or --no-confirm: skip the picker, default to "all" if still unset. Checking PRACTICES_FLAG_PRESET
# rather than `[[ -n "$SELECTED_PRACTICES" ]]` matters once "back" navigation exists: this step's own
# picker sets SELECTED_PRACTICES too, and testing the live value would turn a revisit (go back, then
# forward again) into a silent skip instead of a re-prompt — see the same reasoning in
# resolve_agent_selection()/resolve_skill_selection() (lib/selection.sh).
resolve_best_practices() {
  if $UNINSTALL; then
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi
  if $PRACTICES_FLAG_PRESET || $NO_CONFIRM; then
    [[ -z "$SELECTED_PRACTICES" ]] && SELECTED_PRACTICES="all"
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi

  step "$STEP_IDX_PRACTICES" "${WIZARD_STEPS[$STEP_IDX_PRACTICES]}"

  local selection
  pick_deselect "Best practices" "${PRACTICE_LABELS[@]}"
  WIZARD_SKIPPED=false
  $WIZARD_BACK && return 0
  selection="$PICK_RESULT"

  if [[ -z "$selection" ]]; then
    SELECTED_PRACTICES="none"
  else
    local chosen=() label i ids=""
    IFS=',' read -ra chosen <<< "$selection"
    for label in "${chosen[@]}"; do
      for i in "${!PRACTICE_LABELS[@]}"; do
        [[ "${PRACTICE_LABELS[$i]}" == "$label" ]] && ids+="${PRACTICE_IDS[$i]},"
      done
    done
    SELECTED_PRACTICES="${ids%,}"
  fi
  return 0
}

# Expands SELECTED_PRACTICES ("all"/"none"/comma-list — same resolve() used for -a/-s) into
# EFFECTIVE_PRACTICES, the array render_agents_md()'s IF_PRACTICE blocks check membership against.
build_effective_practices() {
  EFFECTIVE_PRACTICES=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && EFFECTIVE_PRACTICES+=("$p")
  done < <(resolve "$SELECTED_PRACTICES" "${PRACTICE_IDS[@]}")
  return 0
}

_practice_selected() {
  [[ ${#EFFECTIVE_PRACTICES[@]} -eq 0 ]] && return 1
  local name p
  for name in "$@"; do
    for p in "${EFFECTIVE_PRACTICES[@]}"; do
      [[ "$p" == "$name" ]] && return 0
    done
  done
  return 1
}
