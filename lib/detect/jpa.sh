# JPA/Hibernate — adds jpa-patterns.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_jpa_label() { echo "JPA / Hibernate"; }
_jpa_group() { echo "Backend"; }

_jpa_apply() {
  DETECTED_SKILLS+=(jpa-patterns)
}

detect_jpa() {
  if _grep_project_files 'spring-boot-starter-data-jpa|hibernate' \
       PROJECT_BUILD_FILES PROJECT_COMPOSE_FILES PROJECT_CONFIG_FILES; then
    _jpa_apply
    DETECTED_NOTES+=("JPA/Hibernate — dependency / compose file / application config")
  fi
  return 0
}
