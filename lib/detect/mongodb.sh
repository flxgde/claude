# MongoDB — adds mongodb-engineer when a MongoDB signal is found.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_mongodb_label() { echo "MongoDB"; }
_mongodb_group() { echo "Database"; }

_mongodb_apply() {
  DETECTED_AGENTS+=(mongodb-engineer)
}

detect_mongodb() {
  if _grep_project_files 'spring-boot-starter-data-mongodb|mongodb-driver|mongodb://|mongo:' \
       PROJECT_BUILD_FILES PROJECT_COMPOSE_FILES PROJECT_CONFIG_FILES; then
    _mongodb_apply
    DETECTED_NOTES+=("MongoDB — dependency / compose file / application config")
  fi
  return 0
}
