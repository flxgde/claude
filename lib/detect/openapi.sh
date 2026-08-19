# OpenAPI contract — an openapi.yml/yaml or swagger.yml/yaml file anywhere shallow.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_openapi_label() { echo "OpenAPI / API contract"; }
_openapi_group() { echo "DevOps"; }

_openapi_apply() {
  DETECTED_AGENTS+=(api-designer)
}

detect_openapi() {
  if [[ ${#PROJECT_OPENAPI_FILES[@]} -gt 0 ]]; then
    _openapi_apply
    DETECTED_NOTES+=("OpenAPI spec file found")
  fi
  return 0
}
