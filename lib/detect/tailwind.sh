# Tailwind CSS — adds tailwind-patterns when a Tailwind dependency or v4 CSS-first config is found.
# Skill-only category (no agent of its own — see jpa.sh for the same shape): tailwind-patterns rides
# along on whichever frontend agent is already selected (angular-engineer/-reviewer today).
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_tailwind_label() { echo "Tailwind CSS"; }
_tailwind_group() { echo "Frontend"; }

_tailwind_apply() {
  DETECTED_SKILLS+=(tailwind-patterns)
}

detect_tailwind() {
  if _grep_project_files '"tailwindcss"|"@tailwindcss/' PROJECT_PACKAGE_JSON_FILES; then
    _tailwind_apply
    DETECTED_NOTES+=("Tailwind CSS — package.json dependency")
  fi
  return 0
}
