# Ansible — ansible.cfg, a top-level ansible/ directory, or an inventory file (hosts.ini/
# inventory.ini), existence-only. Deliberately conservative: a bare "roles/" directory isn't used
# as a signal on its own (too many other tools use that name) — ansible.cfg and inventory files are
# specific enough that false positives are effectively impossible.
# See kotlin.sh for the detect_<name>()/_<name>_apply()/_<name>_label()/_<name>_group() shape every
# category file follows.
_ansible_label() { echo "Ansible (server provisioning / config management)"; }
_ansible_group() { echo "DevOps"; }

_ansible_apply() {
  DETECTED_AGENTS+=(ansible-engineer)
  DETECTED_SKILLS+=(ansible-automation)
}

detect_ansible() {
  if [[ ${#PROJECT_ANSIBLE_CFG_FILES[@]} -gt 0 || ${#PROJECT_ANSIBLE_INVENTORY_FILES[@]} -gt 0 ]] \
     || $PROJECT_HAS_ANSIBLE_DIR; then
    _ansible_apply
    DETECTED_NOTES+=("Ansible — ansible.cfg / ansible/ directory / inventory file")
  fi
  return 0
}
