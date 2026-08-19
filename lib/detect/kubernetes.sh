# Kubernetes/Helm — a helm/charts/k8s/kubernetes directory, or a Chart.yaml anywhere shallow.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label() shape every category file
# follows.
_kubernetes_label() { echo "Kubernetes / Helm"; }
_kubernetes_group() { echo "DevOps"; }

_kubernetes_apply() {
  DETECTED_AGENTS+=(kubernetes-engineer)
}

detect_kubernetes() {
  if $PROJECT_HAS_K8S_DIR || [[ ${#PROJECT_CHART_FILES[@]} -gt 0 ]]; then
    _kubernetes_apply
    DETECTED_NOTES+=("Kubernetes — helm/charts/k8s directory or Chart.yaml")
  fi
  return 0
}
