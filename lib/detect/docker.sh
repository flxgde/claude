# Docker — any compose file or Dockerfile, existence-only (no content grep needed).
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_docker_label() { echo "Docker"; }
_docker_group() { echo "DevOps"; }

_docker_apply() {
  DETECTED_AGENTS+=(docker-engineer)
}

detect_docker() {
  if [[ ${#PROJECT_COMPOSE_FILES[@]} -gt 0 || ${#PROJECT_DOCKERFILES[@]} -gt 0 ]]; then
    _docker_apply
    DETECTED_NOTES+=("Docker — Dockerfile / compose file")
  fi
  return 0
}
