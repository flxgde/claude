# Security/Keycloak — adds security-engineer when a Keycloak/OAuth2/Spring Security signal is found.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_security_label() { echo "Security / Keycloak"; }
_security_group() { echo "DevOps"; }

_security_apply() {
  DETECTED_AGENTS+=(security-engineer)
}

detect_security() {
  if _grep_project_files 'keycloak|spring-boot-starter-oauth2|spring-boot-starter-security' \
       PROJECT_BUILD_FILES PROJECT_COMPOSE_FILES PROJECT_CONFIG_FILES; then
    _security_apply
    DETECTED_NOTES+=("Security/Keycloak — dependency / application config")
  fi
  return 0
}
