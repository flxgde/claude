# TaigaUI — adds taigaui-patterns when a @taiga-ui/* dependency is found.
# Skill-only category (no agent of its own — see jpa.sh for the same shape): taigaui-patterns rides
# along on whichever frontend agent is already selected (angular-engineer/-reviewer today).
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_taigaui_label() { echo "TaigaUI"; }
_taigaui_group() { echo "Frontend"; }

_taigaui_apply() {
  DETECTED_SKILLS+=(taigaui-patterns)
}

detect_taigaui() {
  if _grep_project_files '"@taiga-ui/' PROJECT_PACKAGE_JSON_FILES; then
    _taigaui_apply
    DETECTED_NOTES+=("TaigaUI — package.json dependency")
  fi
  return 0
}
