# PostgreSQL — adds postgres-engineer when a Postgres signal is found.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_postgres_label() { echo "PostgreSQL"; }
_postgres_group() { echo "Database"; }

_postgres_apply() {
  DETECTED_AGENTS+=(postgres-engineer)
}

detect_postgres() {
  if _grep_project_files 'postgresql' PROJECT_BUILD_FILES PROJECT_COMPOSE_FILES PROJECT_CONFIG_FILES; then
    _postgres_apply
    DETECTED_NOTES+=("PostgreSQL — dependency / compose file / application config")
  fi
  return 0
}
