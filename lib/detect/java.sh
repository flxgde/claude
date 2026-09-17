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
  # clean-code, testing-patterns, and security-review are language-agnostic (see their SKILL.md
  # files) and listed in both spring-boot-engineer's and spring-boot-reviewer's own `skills:`
  # frontmatter — they belong wherever those agents do, not behind their own detection signal.
  DETECTED_SKILLS+=(java-patterns spring-boot-patterns logging-patterns clean-code testing-patterns security-review)
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
