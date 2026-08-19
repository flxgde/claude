---
name: ansible-automation
description: Ansible playbook, role, and inventory patterns for infrastructure automation and configuration management — idempotency, handlers, templates, blocks/rescue error handling, vault-encrypted secrets, and rolling deployments. Use when writing or reviewing Ansible playbooks/roles, provisioning or patching servers, or automating multi-host deployments.
---

# Ansible Automation

## Playbook Structure

Keep the top-level playbook thin — orchestration only, real work lives in roles.

```yaml
# site.yml
---
- name: Deploy application stack
  hosts: webservers
  gather_facts: yes
  serial: "30%"          # rolling deployment — see "Rolling Deployments" below
  become: yes            # scope privilege escalation here, not per-task (see "Privilege Escalation")

  pre_tasks:
    - name: Verify connectivity
      ping:
      tags: [always]

  roles:
    - common
    - docker
    - application

  post_tasks:
    - name: Verify health endpoint
      uri:
        url: "http://{{ inventory_hostname }}:8080/health"
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 3
      delay: 10
```

✅ `hosts:` targets a group, not `all` — a bad inventory edit can't touch prod and staging in one run.
❌ Don't put real configuration tasks directly in the playbook — every non-trivial responsibility
belongs in a role, so it can be reused, tested, and versioned on its own.

---

## Role Layout

`ansible-galaxy init roles/application` scaffolds this — don't hand-roll the directory tree:

```
roles/application/
├── defaults/main.yml     # lowest-precedence vars — safe defaults, always overridable
├── vars/main.yml         # higher-precedence vars — role-internal constants
├── tasks/main.yml        # the actual work
├── handlers/main.yml     # notify targets (see "Handlers")
├── templates/*.j2        # Jinja2 templates (see "Templates")
├── files/                # static files copied verbatim
└── meta/main.yml         # role dependencies, galaxy metadata
```

Role dependencies (auto-run before this role, in order, deduped across the whole play):

```yaml
# roles/application/meta/main.yml
---
dependencies:
  - role: common
  - role: docker
```

---

## Inventory and Variable Precedence

```ini
# inventory/hosts.ini
[webservers]
web1 ansible_host=10.0.1.10
web2 ansible_host=10.0.1.11

[databases]
db1 ansible_host=10.0.2.10 db_role=primary

[webservers:vars]
http_port=8080
```

```yaml
# inventory/group_vars/webservers.yml — applies to the whole group
---
app_version: "1.2.3"
environment: production
```

```yaml
# inventory/host_vars/web1.yml — overrides for this one host only
---
max_connections: 500
```

**Precedence (low → high, the ones that matter day to day):** role `defaults/` → inventory
`group_vars/all` → inventory `group_vars/<group>` → inventory `host_vars/<host>` → role `vars/` →
`-e` on the command line (always wins). When a variable "isn't taking effect," check this order
before anything else — it's almost always a more-specific scope overriding what you just changed.

✅ Commit inventory + `group_vars`/`host_vars` to version control (a separate repo from application
code is common, so infra changes get their own review/audit trail).
❌ Don't hardcode IPs or environment-specific values inside playbooks/roles — they belong in
inventory, where switching environments is a `-i` flag, not a code change.

---

## Idempotency — Modules Over shell/command

A playbook should be safe to re-run; re-running against an already-converged system should report
zero changes.

```yaml
# ❌ Not idempotent — reports "changed" every single run, gives no real signal
- name: Add config line
  shell: echo "PARAM=value" >> /etc/app.conf

# ✅ Idempotent module — reports changed only the first time
- name: Ensure config line present
  lineinfile:
    path: /etc/app.conf
    line: "PARAM=value"
    create: yes
```

When there's truly no module for what you need, keep `shell`/`command` idempotent explicitly:

```yaml
- name: Run migration once
  command: /opt/app/migrate.sh
  args:
    creates: /opt/app/.migrated   # skip the whole task if this file already exists
  register: migration
  changed_when: "'Applied' in migration.stdout"
```

Prefer a real module (`package`, `service`, `template`, `lineinfile`, `copy`, `user`, ...) over
`shell`/`command` whenever one exists — modules check current state before acting and are
idempotent by construction; `shell`/`command` are not, by default.

---

## Handlers — Restart Only When Something Actually Changed

Handlers run at most once per play, after all tasks, and only if notified — this is what keeps a
service restart from happening on every single run regardless of whether anything changed.

```yaml
# roles/application/tasks/main.yml
- name: Deploy application config
  template:
    src: app.conf.j2
    dest: /etc/app/app.conf
  notify: restart application

- name: Deploy nginx config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: reload nginx
```

```yaml
# roles/application/handlers/main.yml
---
- name: restart application
  systemd:
    name: application
    state: restarted

- name: reload nginx
  systemd:
    name: nginx
    state: reloaded          # reload, not restart — no dropped connections
```

Multiple tasks can `notify` the same handler; it still only fires once, at the end of the play (or
immediately if you insert `meta: flush_handlers`, useful mid-play right before a task that depends
on the just-restarted service already being back up).

---

## Templates (Jinja2) — Not `copy`, When Values Differ Per Host

```jinja2
{# roles/application/templates/app.conf.j2 #}
environment={{ environment }}
port={{ app_port | default(8080) }}
workers={{ ansible_processor_vcpus }}
database_url=postgresql://{{ db_user }}:{{ db_password }}@{{ db_host }}:5432/{{ db_name }}
{% if sentry_dsn is defined %}
sentry_dsn={{ sentry_dsn }}
{% endif %}
```

```yaml
- name: Deploy config from template
  template:
    src: app.conf.j2
    dest: /etc/app/app.conf
    owner: appuser
    mode: "0600"          # secrets in this file — not world-readable
  notify: restart application
```

✅ `template` for anything containing a variable, a conditional, or a per-host value — the `.j2`
extension is convention, not a requirement, but keep it for anything that isn't purely static.
❌ `copy` for a file that actually needs `{{ inventory_hostname }}`-style substitution — `copy`
transfers the file byte-for-byte, no Jinja2 rendering happens.

---

## Error Handling — block / rescue / always

```yaml
- name: Deploy with rollback on failure
  block:
    - name: Pull new image
      docker_image:
        name: "myapp:{{ app_version }}"
        source: pull

    - name: Start new container
      docker_container:
        name: myapp
        image: "myapp:{{ app_version }}"
        state: started

    - name: Verify health
      uri:
        url: "http://localhost:8080/health"
        status_code: 200
      retries: 5
      delay: 5

  rescue:
    - name: Roll back to previous image
      docker_container:
        name: myapp
        image: "myapp:{{ previous_app_version }}"
        state: started

    - name: Fail the play so CI/CD reports red
      fail:
        msg: "Deployment of {{ app_version }} failed health check — rolled back to {{ previous_app_version }}"

  always:
    - name: Clean up dangling images
      docker_prune:
        images: yes
```

`rescue` runs only if a task in `block` fails; `always` runs regardless — the same shape as
try/catch/finally. Prefer this over scattering `ignore_errors: yes` through a task list, which
silences failures instead of handling them.

`failed_when`/`changed_when` override what counts as failure/change for a single task — useful when
a command's exit code or output doesn't mean what Ansible assumes:

```yaml
- name: Check disk usage (informational — a non-zero exit here isn't a real failure)
  command: df -h /
  register: disk_check
  failed_when: false
  changed_when: false
```

---

## Privilege Escalation (`become`)

```yaml
# ✅ Scope become to the play, override per-task only when a DIFFERENT user is needed
- hosts: webservers
  become: yes
  tasks:
    - name: Install system package
      package:
        name: nginx
        state: present

    - name: Run as the app user, not root, even though the play defaults to become
      command: /opt/app/healthcheck.sh
      become: yes
      become_user: appuser
```

Don't set `become_user: root` explicitly — `become: yes` alone already defaults to root; only set
`become_user` when you need a user that *isn't* root.

---

## Ansible Vault — Secrets

Never commit plaintext secrets in `group_vars`/`host_vars`. Encrypt the value (or the whole file)
with Vault:

```bash
# Encrypt a single value, paste the result straight into group_vars/all.yml
ansible-vault encrypt_string 'S3cr3tP@ss' --name 'vault_db_password'

# Or encrypt an entire vars file in place
ansible-vault encrypt group_vars/production/vault.yml
ansible-vault edit group_vars/production/vault.yml   # decrypts, opens $EDITOR, re-encrypts on save
```

```yaml
# group_vars/production/vars.yml — plaintext, safe to commit — references the vaulted variable
db_password: "{{ vault_db_password }}"

# group_vars/production/vault.yml — fully encrypted file; the vault_ prefix marks "secret only"
vault_db_password: S3cr3tP@ss
```

Run with `--vault-password-file ~/.vault_pass` (keep that file out of version control, `chmod 600`)
or `--ask-vault-pass` — never pass the vault password on the command line, where it lands in shell
history.

---

## Rolling Deployments & Health Checks

```yaml
- hosts: webservers
  serial: 1                    # one host at a time — or "30%" for a percentage of the group
  max_fail_percentage: 0       # abort the whole run the moment one host fails

  tasks:
    - name: Remove from load balancer
      # ...

    - name: Deploy new version
      # ...

    - name: Wait for health check before moving to the next host
      uri:
        url: "http://{{ inventory_hostname }}:8080/health"
        status_code: 200
      register: health
      until: health.status == 200
      retries: 10
      delay: 5

    - name: Re-add to load balancer
      # ...
```

`serial` controls the batch size; `max_fail_percentage` (or the default of aborting on any failure)
decides whether one bad host halts the whole rollout — for production, `0` so a single failing
host stops everything rather than degrading service across the fleet one node at a time.

---

## Test Before You Run

```bash
ansible-playbook --syntax-check -i inventory/hosts.ini site.yml   # catches YAML/syntax errors only
ansible-playbook --check --diff -i inventory/hosts.ini site.yml   # dry run — shows what WOULD change
ansible-lint site.yml                                             # style / best-practice linter
```

`--check` mode isn't a full guarantee — a task built on `shell`/`command` doesn't actually run under
check mode (there's no "what would this shell out to" simulation), so it may report nothing or
something misleading. Treat a clean `--check --diff` as a strong signal for module-based tasks, and
with more caution for anything using `shell`/`command`.

---

## Common Quick Reference

| Problem | Symptom | Solution |
|---|---|---|
| Playbook not idempotent | `changed` every run | Real module instead of `shell`/`command`; `creates`/`changed_when` if unavoidable |
| Service restarts on every run | Handler fires unconditionally | Only `notify` from tasks that actually change config |
| Variable "isn't applying" | Wrong value used despite editing group_vars | Check precedence — host_vars/`-e` beats group_vars/defaults |
| Templated file has literal `{{ var }}` in it | Used `copy` instead of `template` | Switch to `template` — `copy` never renders Jinja2 |
| Deployment fails halfway, left inconsistent | No rollback path | `block`/`rescue`/`always` |
| Secret visible in git history | Plaintext value in group_vars | `ansible-vault encrypt_string` / encrypt the whole file |
| One bad host takes down the whole fleet | No rolling strategy | `serial` + `max_fail_percentage: 0` + health-check `until` |
| `--check` run says "no changes" but the real run isn't | Task uses `shell`/`command`, no check-mode support | Prefer real modules; treat `--check` as advisory for shell-based tasks |
