# claude

Agent, skill, and rules bundle for **Claude Code** and **OpenCode**, installed project-locally via
`install.sh`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/flxgde/claude/main/install.sh | bash
```

Run from the target project's directory. From a local checkout, invoke `install.sh` by path instead
of piping through `bash` — same flags either way.

### Common flags

| Flag | Effect |
|---|---|
| `--dry-run` | Preview without writing anything |
| `--auto` | Detect the project's stack and install exactly what applies |
| `--tool claude\|opencode\|both` | Which tool(s) to install for (default `both`) |
| `--agents <names>` / `--skills <names>` | Install specific agents/skills (comma-separated, or `none`) |
| `--practices <ids>` | Which `AGENTS.md` working-style sections to include (comma-separated, `all`, `none`) |
| `--no-confirm` | Non-interactive; everything unset falls back to sane defaults |
| `--uninstall` | Remove everything a previous install added |
| `--help` | Full usage |

Without `--auto`/`--agents`/`--skills`/`--no-confirm`, an interactive wizard walks through setup
(see below).

### Setup modes

- **Auto** — scans the project for concrete signals (build files, `angular.json`, `Dockerfile`,
  Helm charts, an OpenAPI spec, DB dependencies, ...) and installs exactly what matches. Only
  offered when something is actually detected.
- **Guided** — pick your stack from a multi-select list; no file scanning, works in an empty
  project.
- **Manual** — pick agents and skills directly.

The git-workflow question and the best-practices multi-select are always asked afterward,
regardless of setup mode — they configure `AGENTS.md`'s content, independent of which agents/skills
get installed.

### Git workflow

One leading question — **no git** (default), **commit locally**, or **Custom** (the full
breakdown: git usage, auto-commit, feature-branch + MR flow, who opens the MR, direct push). Skip
straight to the full breakdown with `--git-wizard`, or set it non-interactively with
`--use-git`/`--auto-commit`/`--use-mrs`/`--create-mrs`/`--push-direct` (all default `no`).

### What gets installed where

| File | Tool | Notes |
|---|---|---|
| `./AGENTS.md` | Both | Shared rules payload; OpenCode reads it natively. Tailored to your selection |
| `./.claude/CLAUDE.md` | Claude Code | `@AGENTS.md` import, appended to existing content if any |
| `./.claude/agents/*.md` | Claude Code | Subagent definitions |
| `./.claude/skills/<name>/` | Both | OpenCode reads this same path directly |
| `./.opencode/agents/*.md` | OpenCode | Rendered from `dist/agents/` at install time |

## Agents

| Agent | Model | Description |
|---|---|---|
| `architect` | opus | Project structure, technology choices, ADRs |
| `api-contract-engineer` | sonnet | OpenAPI spec design and validation |
| `spring-boot-engineer` | sonnet | Spring Boot feature implementation (Kotlin or Java) |
| `spring-boot-reviewer` | haiku | Spring Boot code review (Kotlin or Java) |
| `angular-engineer` | sonnet | Angular frontend implementation |
| `angular-reviewer` | haiku | Angular code review |
| `security-engineer` | sonnet | Security review (OWASP, Spring Security, Keycloak, K8s) |
| `docker-engineer` | sonnet | Dockerfiles, Docker Compose, multi-stage builds |
| `kubernetes-engineer` | sonnet | Helm charts, K8s manifests, GitHub Actions CI/CD |
| `ansible-engineer` | sonnet | Ansible playbooks, roles, server provisioning/config management |
| `postgres-engineer` | sonnet | Schema design, Flyway migrations, query optimization |
| `mongodb-engineer` | sonnet | Document modeling, aggregation pipelines, indexes |
| `doc-writer` | haiku | README, ADR, API documentation |

## Skills

| Skill | Used by |
|---|---|
| `kotlin-patterns` / `java-patterns` | spring-boot-engineer, spring-boot-reviewer |
| `spring-boot-patterns` | spring-boot-engineer, spring-boot-reviewer |
| `jpa-patterns` | spring-boot-engineer, spring-boot-reviewer |
| `logging-patterns` | spring-boot-engineer |
| `design-patterns` | spring-boot-engineer |
| `angular-patterns` | angular-engineer, angular-reviewer |
| `tailwind-patterns` / `taigaui-patterns` | angular-engineer, angular-reviewer |
| `clean-code` / `testing-patterns` / `security-review` | spring-boot-engineer/-reviewer, angular-engineer/-reviewer, security-engineer |
| `api-design-review` | api-contract-engineer, spring-boot-engineer/-reviewer, angular-engineer/-reviewer |
| `openapi-generator-patterns` | api-contract-engineer, spring-boot-engineer, angular-engineer |
| `mongodb-patterns` | mongodb-engineer |
| `docker-patterns` | docker-engineer |
| `kubernetes-patterns` | kubernetes-engineer |
| `keycloak-patterns` | security-engineer |
| `ansible-automation` | ansible-engineer |

## Tech defaults

Preferences, not hard rules — alternatives suggested when clearly better.

| Concern | Default |
|---|---|
| Backend | Spring Boot (Kotlin preferred, Java fully supported) |
| Build | Gradle (Kotlin DSL) + `libs.versions.toml` |
| Frontend | Angular (TypeScript, zoneless, signals) |
| Relational DB | PostgreSQL |
| Document DB | MongoDB |
| Messaging | RabbitMQ |
| Auth/SSO | Keycloak |
| Containers | Docker Compose (local), Kubernetes + Helm (prod) |
| CI/CD | GitHub Actions |

## Structure

```
dist/agents/       Agent source files (*.md, Claude Code frontmatter dialect)
dist/skills/       Skill directories (each contains SKILL.md)
dist/AGENTS.md     Distributable rules payload — the canonical, tool-agnostic source
reference/         Fetched reference documentation (repo-dev-time only, not installed)
install.sh         Install/uninstall script
```
