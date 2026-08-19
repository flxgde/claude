# Angular frontend — angular.json present, or package.json depends on @angular/core.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_angular_label() { echo "Angular frontend"; }
_angular_group() { echo "Frontend"; }

_angular_apply() {
  DETECTED_AGENTS+=(angular-engineer angular-reviewer)
  # clean-code is language-agnostic (see dist/skills/clean-code/SKILL.md) and listed in both
  # angular-engineer's and angular-reviewer's own `skills:` frontmatter — it belongs wherever
  # those agents do, not behind its own detection signal.
  DETECTED_SKILLS+=(angular-patterns clean-code)
}

detect_angular() {
  local is_angular=false
  if [[ ${#PROJECT_ANGULAR_JSON_FILES[@]} -gt 0 ]]; then
    is_angular=true
  elif [[ ${#PROJECT_PACKAGE_JSON_FILES[@]} -gt 0 ]] \
       && _detect_grep_any '"@angular/core"' "${PROJECT_PACKAGE_JSON_FILES[@]}"; then
    is_angular=true
  fi
  if $is_angular; then
    _angular_apply
    DETECTED_NOTES+=("Angular frontend — angular.json / package.json")
  fi
  return 0
}
