# Java backend (Spring Boot) — fires on the same evidence the old combined check used (a
# spring-boot/springframework dependency in a build file, OR a src/main/java directory), but only
# when there's no Kotlin evidence (see kotlin.sh). Before that split, the combined check added
# kotlin-patterns unconditionally to every Spring Boot project, including pure-Java ones with zero
# Kotlin evidence — that was a bug, not a feature; the split fixed it.
#
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_java_label() { echo "Java backend (Spring Boot)"; }
_java_group() { echo "Backend"; }

_java_apply() {
  DETECTED_AGENTS+=(spring-boot-engineer spring-boot-reviewer)
  # clean-code is language-agnostic (see dist/skills/clean-code/SKILL.md) and listed in both
  # spring-boot-engineer's and spring-boot-reviewer's own `skills:` frontmatter — it belongs
  # wherever those agents do, not behind its own detection signal.
  DETECTED_SKILLS+=(logging-patterns clean-code)
}

detect_java() {
  $PROJECT_HAS_KOTLIN_SRC && return 0

  local has_spring=false
  _grep_project_files 'spring-boot|springframework' \
    PROJECT_BUILD_FILES PROJECT_COMPOSE_FILES PROJECT_CONFIG_FILES && has_spring=true

  if $has_spring || $PROJECT_HAS_JAVA_SRC; then
    _java_apply
    DETECTED_NOTES+=("Spring Boot backend (Java) — build file dependency / src/main/java")
  fi
  return 0
}
