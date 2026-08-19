# claude

Personal AI coding assistant configuration — agents, skills, and reference material for
**Claude Code** and **OpenCode**. Versioned here, installed project-locally via `install.sh`.

## Install

Always installs into the current directory — there's no global install option; agents, skills, and
rules are meant to be project-local. By default installs for both tools; pass `--tool claude` or
`--tool opencode` to install for just one.

```bash
# One-shot from the web — run from the target project's directory, no clone needed
cd ~/projects/myapp
curl -fsSL https://raw.githubusercontent.com/flxgde/claude/main/install.sh | bash
```

Or from a local checkout of this repo — same flags either way, just invoke `install.sh` by path instead
of piping it through `bash`:

```bash
# Run from the target project's directory
cd ~/projects/myapp

# Install everything for both Claude Code and OpenCode
/path/to/claude/install.sh

# Just one tool
/path/to/claude/install.sh --tool opencode

# Preview without making changes
/path/to/claude/install.sh --dry-run

# Install specific agents and skills
/path/to/claude/install.sh --agents spring-boot-engineer,angular-engineer \
                            --skills kotlin-patterns,angular-patterns

# Detect this project's stack and install exactly what applies
/path/to/claude/install.sh --auto

# Uninstall
/path/to/claude/install.sh --uninstall
```

Run `./install.sh --help` for full usage.

### Setup modes: Auto / Guided / Manual

Interactively (and whenever you haven't already passed `-a`/`-s`), the wizard leads with how to
pick agents and skills:

- **Auto** — scans the target project for concrete signals: a `build.gradle.kts`/`pom.xml` with a
  Spring Boot dependency, `angular.json`, `Dockerfile`/`docker-compose.yml`, a Helm chart, an
  OpenAPI spec, database driver dependencies, and so on — and installs exactly what matches,
  explaining what it found before doing so. Conservative by design: only agents/skills tied to an
  actual file-level signal get selected; generic ones (`architect`, `doc-writer`) are never
  auto-added. Only offered when something was actually detected — on an empty/unrecognizable
  directory it's simply not a choice (or, with `--auto` the flag, fails with a clear message
  instead of installing nothing useful).
- **Guided** — pick your tech stack (Kotlin, Java, Angular, PostgreSQL, MongoDB, Docker,
  Kubernetes, Security/Keycloak, OpenAPI, ...) from one multi-select list, and the matching
  agents/skills are installed for you — no file scanning involved, so it works in an empty
  directory too (e.g. before writing any code).
- **Manual** — pick agents and skills directly, the original picker flow.

`--auto` on the command line skips straight to Auto (or fails clearly if nothing's detected and
neither `-a` nor `-s` was given); there's no flag equivalent for Guided, since it's inherently an
interactive Q&A.

The git-workflow question (below) is always asked afterward, regardless of which of the three you
picked — it configures AGENTS.md's content, a separate concern from which agents/skills get
installed.

### Best practices

Also asked afterward, regardless of setup mode: a multi-select of six `AGENTS.md` working-style
sections — Plan Mode Default, Self-Improvement Loop, Verification Before Done, Demand Elegance,
Skills, Sub-agents — everything included by default, so you deselect the ones you don't want
instead of picking from scratch. `--practices <ids>` sets it non-interactively
(comma-separated, `all`, or `none`); `--no-confirm` defaults to `all`.

### What gets installed where

| File | Tool | Notes |
|---|---|---|
| `./AGENTS.md` | Both | Canonical shared rules payload; OpenCode reads this natively. Tailored to your selection — the agent-dispatch table and stack-specific conventions only mention agents you actually installed |
| `./.claude/CLAUDE.md` | Claude Code | `@AGENTS.md` import — Claude Code only ever reads `CLAUDE.md`. Appended to existing content rather than overwritten if the file already has some. |
| `./.claude/agents/*.md` | Claude Code | Subagent definitions |
| `./.claude/skills/<name>/` | Both | Skills — OpenCode reads this exact path directly, so there's no separate copy |
| `./.opencode/agents/*.md` | OpenCode | Rendered from the same `dist/agents/` source, translated to OpenCode's frontmatter schema |

Agents are authored once, in Claude Code's frontmatter dialect (`dist/agents/*.md`), and the
OpenCode version is generated at install time — `model:`, `skills:`, and `memory:` have no OpenCode
equivalent and are dropped; `permissions.allow` Bash patterns become `permission.bash` entries; the
`model:` field is deliberately left unset in the OpenCode output so the agent inherits whichever
provider/model you've configured there instead of assuming Anthropic.

### Git workflow

`AGENTS.md`'s "Git Workflow" section is generated at install time, not static. It's always asked
interactively, regardless of which setup mode (Auto/Guided/Manual) you picked above — it's a
separate concern from which agents/skills get installed. One leading question — **no git**
(recommended default), **commit locally**, or **Custom** — rather than five questions up front;
Custom opens the full breakdown (does it use git, auto-commit, work via feature branch + MR, open
that MR itself, push directly to main — each independently).

Under `--no-confirm`, or if you pass any of the flags below, no question is asked at all: flags win
outright, and anything left unset takes the "no git" default for that one dimension.
`--use-git` (default `no`), `--auto-commit` (default `no`), `--use-mrs` (default `no`),
`--create-mrs` (default `no`), `--push-direct` (default `no`). `--git-wizard` skips straight to the
full breakdown, bypassing the leading question.

```bash
# Silent: no git at all (the default)
./install.sh --no-confirm

# Silent, but with local auto-commit turned on
./install.sh --no-confirm --use-git yes --auto-commit yes

# Skip the leading question, go straight to the full breakdown
./install.sh --git-wizard
```

## Agents

| Agent | Model | Description |
|---|---|---|
| `architect` | opus | Project structure, technology choices, ADRs |
| `api-designer` | sonnet | OpenAPI spec design and validation |
| `spring-boot-engineer` | inherit | Kotlin/Spring Boot feature implementation |
| `spring-boot-reviewer` | haiku | Kotlin/Spring Boot code review |
| `angular-engineer` | inherit | Angular frontend implementation |
| `angular-reviewer` | haiku | Angular code review |
| `security-engineer` | sonnet | Security review (OWASP, Spring Security, K8s) |
| `docker-engineer` | sonnet | Dockerfiles, Docker Compose, multi-stage builds |
| `kubernetes-engineer` | sonnet | Helm charts, K8s manifests, GitHub Actions CI/CD |
| `ansible-engineer` | sonnet | Ansible playbooks, roles, server provisioning/config management |
| `postgres-engineer` | sonnet | Schema design, Flyway migrations, query optimization |
| `mongodb-engineer` | sonnet | Document modeling, aggregation pipelines, indexes |
| `doc-writer` | haiku | README, ADR, API documentation |

## Skills

| Skill | Used by |
|---|---|
| `kotlin-patterns` | spring-boot-engineer, spring-boot-reviewer |
| `jpa-patterns` | spring-boot-engineer, spring-boot-reviewer |
| `logging-patterns` | spring-boot-engineer |
| `design-patterns` | spring-boot-engineer |
| `angular-patterns` | angular-engineer, angular-reviewer |
| `clean-code` | spring-boot-engineer, spring-boot-reviewer, angular-engineer, angular-reviewer |
| `ansible-automation` | ansible-engineer |

## Structure

```
dist/agents/       Agent source files (*.md, Claude Code frontmatter dialect)
dist/skills/       Skill directories (each contains SKILL.md)
dist/AGENTS.md     Distributable rules payload — the canonical, tool-agnostic source
reference/         Fetched reference documentation (repo-dev-time only, not installed)
install.sh         Install/uninstall script (project-local only, always copies)
```

## Tech defaults

These are preferences, not hard rules — alternatives are suggested when clearly better.

| Concern | Default |
|---|---|
| Backend | Kotlin + Spring Boot |
| Build | Gradle (Kotlin DSL) + `libs.versions.toml` |
| Frontend | Angular (TypeScript, zoneless, signals) |
| Relational DB | PostgreSQL |
| Document DB | MongoDB |
| Messaging | RabbitMQ |
| Auth/SSO | Keycloak |
| Containers | Docker Compose (local), Kubernetes + Helm (prod) |
| CI/CD | GitHub Actions |
