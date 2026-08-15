# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal, versioned bundle of AI coding assistant configuration — subagents, skills, and reference
docs for Kotlin/Spring Boot + Angular projects, targeting **both Claude Code and OpenCode**. It is not
an application; it has no build, no tests, and no runtime. The "product" is the config bundle itself,
distributed project-locally into other projects via `install.sh`.

**Two different rules files exist here, do not confuse them:**

- **This file** (repo root `CLAUDE.md`) — instructions for Claude Code while *developing this repo*.
  Repo-dev-only; never installed anywhere.
- **`dist/AGENTS.md`** — the distributable payload, authored once and shared by both tools. `install.sh`
  copies it verbatim to a target project's root `AGENTS.md` (OpenCode reads this natively) and writes a
  one-line `./.claude/CLAUDE.md` that does `@AGENTS.md` (Claude Code only ever reads `CLAUDE.md`, never
  `AGENTS.md` — see [Anthropic's docs](https://code.claude.com/docs/en/memory#agentsmd)). It contains
  the agent-dispatch rules, plan-mode policy, and Kotlin/Spring/Angular tech defaults that apply to
  *downstream* projects — not to work done in this repo. Edit it when changing what gets shipped to
  consumers; edit this file when changing how Claude Code should behave while working on the bundle
  itself.

## Commands

There is no build/lint/test toolchain (no package.json, no Gradle, no shellcheck installed). The only
way to verify a change is to run the installer against a scratch directory:

```bash
# Preview an install without touching anything (run from a scratch dir — always project-local)
mkdir -p /tmp/claude-install-test && cd /tmp/claude-install-test
/path/to/repo/install.sh --dry-run --no-confirm

# Full non-interactive install into that scratch dir, inspect the result (both tools)
/path/to/repo/install.sh --no-confirm
find . -maxdepth 3

# Check each tool's install path independently
/path/to/repo/install.sh --tool claude --no-confirm
/path/to/repo/install.sh --tool opencode --no-confirm

# Exercise the uninstall path too
/path/to/repo/install.sh --uninstall --no-confirm
```

Run this after any change to `install.sh`, or after adding/renaming an agent or skill, to confirm
discovery, copying, and the OpenCode frontmatter transform still work. There's no CI — this manual
dry-run is the whole safety net. When touching the OpenCode render logic specifically, `cat` a couple
of the rendered `.opencode/agents/*.md` files — especially one with a `permissions.allow` Bash list
(e.g. `spring-boot-engineer`) and one reviewer with no `Write`/`Edit` (e.g. `spring-boot-reviewer`) —
to confirm the `permission:` block came out right. When touching the git-workflow policy, `sed -n
'/## 4. Git Workflow/,/## 5/p' AGENTS.md` after an install with a few different
`--use-git`/`--auto-commit`/`--use-mrs`/`--create-mrs`/`--push-direct` combinations (including
`--use-git no` and the plain no-flags default) to confirm the rendered bullet list matches. Also check
the actual exit code
(`echo $?`, not just the printed output) after a plain `--no-confirm` run — see the `exit 0` note below
for why that's not automatically 0.

## Architecture

Everything under `dist/` is the *distributable payload* — authored once, installed for one or both
tools. `dist/agents/*.md` is authored in **Claude Code's** frontmatter dialect specifically, because
`install.sh` renders the OpenCode version from it at install time (see below) — there is no separate
hand-maintained OpenCode agent tree, and there shouldn't be; that's the drift problem this setup avoids.

### `dist/agents/*.md` — subagent definitions (source of truth for both tools)

One file per subagent. YAML frontmatter + a system-prompt body:

```yaml
---
name: spring-boot-engineer
description: <what it does and when to use it — this is what the dispatcher matches on>
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet          # opus for architect (heavy reasoning), sonnet for implementers, haiku for reviewers
memory: user
skills:                # skill names this agent should load — must exist under dist/skills/
  - kotlin-patterns
  - jpa-patterns
permissions:
  allow:
    - "Bash(gradle:*)"
    - "Bash(./gradlew:*)"
---
```

`install.sh` discovers agents by globbing `dist/agents/*.md` — no registry file to update. When adding
an agent, also add its row to the tables in `README.md` (agent list, model, description) and, if it's
meant to be dispatched from downstream projects, add a trigger row to the agent-dispatch table in
`dist/AGENTS.md`.

**OpenCode rendering** (`render_opencode_agent()` in `install.sh`): translates this frontmatter into
OpenCode's schema by simple `sed`/`awk` text extraction — it is *not* a general YAML parser, so keep
agent frontmatter within the shape shown above (single-line `description:`/`tools:`, and
`permissions.allow` entries exactly as `    - "Bash(<pattern>)"`) or the transform will silently drop
fields. Mapping:
- `name`, `model`, `memory`, `skills` — dropped. OpenCode uses the filename as the agent identifier,
  has no per-agent skill list (skills are discovered globally — see below), and `model` is left unset
  on purpose so the agent inherits whatever provider/model is configured in OpenCode rather than
  assuming Anthropic.
- `tools:` — if it lacks `Write`/`Edit` (i.e. a reviewer), emits `permission.edit: deny`.
- `permissions.allow` Bash patterns — become `permission.bash` entries, with `"*": ask` as the
  catch-all (same "only these are pre-approved" intent as the Claude Code source). `Bash(cmd:*)`
  becomes `"cmd*": allow`; an exact `Bash(cmd)` (no trailing `:*`) stays an exact-match key.
- The system-prompt body is copied through unchanged — both tools get the same instructions.

### `dist/skills/<name>/SKILL.md` — packaged domain knowledge (no OpenCode-specific copy needed)

Referenced by agents via the `skills:` frontmatter field (Claude Code only — see above). Each is a
self-contained knowledge doc (idioms, pitfalls, patterns) an agent loads for its domain — e.g.
`kotlin-patterns` and `jpa-patterns` back `spring-boot-engineer`/`spring-boot-reviewer`;
`angular-patterns` backs `angular-engineer`/`angular-reviewer`. Discovered the same way as agents
(directory glob), so no registry to maintain beyond `README.md`'s skills table.

Skills install to a single path, `.claude/skills/<name>/`, regardless of `--tool` — OpenCode's skill
discovery reads that exact Claude-compatible path natively, so there is nothing to render or duplicate
for it. Don't add a `.opencode/skills/` copy step; it would be redundant.

### `dist/AGENTS.md` — the shared rules payload

Installed to a target project's root `AGENTS.md` (OpenCode reads this directly) and imported by the
one-line `.claude/CLAUDE.md` install writes (`@AGENTS.md` — Claude Code's documented pattern for
sharing rules with AGENTS.md-based tools; Claude Code never reads `AGENTS.md` on its own). Because both
tools read this same file, keep it tool-agnostic where practical — avoid hardcoding one tool's paths or
mechanisms (e.g. the agent-directory line spells out both `.claude/agents/` and `.opencode/agents/`
rather than assuming one).

Not installed verbatim: the `## 4. Git Workflow` section is a single `<!-- GIT_WORKFLOW_POLICY -->`
marker line in the source, and `install.sh`'s `write_agents_md()` splices in a generated bullet list
(`render_git_workflow_policy()`) in its place at install time — content controlled by
`--use-git`/`--auto-commit`/`--use-mrs`/`--create-mrs`/`--push-direct`.

Interactively (and not `--no-confirm`, and no flag already set), the flow leads with one question via
`ask_choice`: "commit locally" (the non-invasive default — never touches the remote), "no git", or
"Custom...". Only "Custom" drops into `ask_git_workflow_details()`, the full five-question breakdown
(same function `--git-wizard` calls directly, skipping the leading question). Passing any one of the
five flags skips the leading question entirely — the CLI is already "custom" at that point — and fills
whichever dimensions are still unset with the "commit locally" default. This two-tier shape (one
low-friction question by default, full control one level down) is deliberate: asking all five questions
unconditionally was tried first and was more setup than wanted for the common case.

This is the one part of `dist/AGENTS.md` that's composed rather than static; if more sections become
user-configurable later, follow the same marker-plus-render-function pattern rather than templating the
whole file — and keep the same two-tier shape (one easy default-vs-custom question, not a list of
independent questions) as the bar for any new wizard, not just this one.

### `reference/*.md` — fetched external docs

Local copies of upstream documentation (Kotlin coding conventions, Angular signals/zoneless/style-guide
docs) that skills point to instead of re-fetching a URL each time. Repo-dev-time only — not part of
`dist/`, never installed into a consumer project. This mirrors the "Reference Material" rule in
`dist/AGENTS.md`: fetch once, save locally, cite the local file afterward.

### `install.sh` — the installer

Single script, no dependencies beyond bash/curl/tar/sed/awk (fzf optional, for the interactive
picker). Key behaviors:
- Discovers agents (`dist/agents/*.md`) and skills (`dist/skills/*/` directories) dynamically via
  `find`.
- `--tool claude|opencode|both` (default `both`) scopes agents and the `.claude/CLAUDE.md` import
  wrapper. `AGENTS.md` and skills are shared resources and are always installed/removed together
  regardless of `--tool` — don't make them independently scopable, there's no coherent per-tool
  meaning for "only OpenCode's copy of a file both tools read from the same path."
- **Project-local only**: destinations are hardcoded to `$PWD/.claude`, `$PWD/.opencode`, and
  `$PWD/AGENTS.md` — there is no `--target` flag and no global install path. Installing globally was
  deliberately removed; don't reintroduce a way to target an arbitrary/global directory.
- **Always copies** — no symlink mode. Every install lands independent files in the target project;
  there is no option to link back into this repo checkout. Don't reintroduce a `--mode`/symlink toggle.
- Backs up anything it would overwrite into `.claude/.backup/<timestamp>/` unless `--no-backup`.
- Also runnable standalone via `curl | bash` (downloads a tarball of `flxgde/claude`@main when not run
  from inside the repo, and installs into the caller's cwd) — keep the script self-contained (no
  sourcing other repo files at runtime beyond `dist/agents/`, `dist/skills/`, `dist/AGENTS.md`) so that
  path keeps working.
- Both the install and uninstall paths end with an explicit `exit 0`. Without it, the script's exit
  code is whatever its last statement happened to return — the install path's last statement used to be
  `$BACKUP_USED && info "..."`, which is `false && ...` (exit 1) on the common case of a fresh install
  needing no backup, so `install.sh --no-confirm && next_step` silently treated a successful install as
  a failure. If you add statements after the final `info`/`ok` call, keep (or move) the `exit 0` last.

## Conventions when adding or editing an agent/skill

- Agent `description` should read as a dispatch trigger ("Use when... / Use proactively when...") since
  that's the field the orchestrator matches against, for both tools.
- Reviewer agents (`*-reviewer`) get read-mostly tool sets (`Read, Grep, Glob, Bash`, no `Write`/`Edit`)
  and `model: haiku` — cheap, fast, high-volume checks. Implementer agents get the full
  `Read, Write, Edit, Bash, Glob, Grep` set and `model: sonnet` (or `opus` for `architect`, which does
  the highest-stakes reasoning). The `Write`/`Edit` distinction is load-bearing for the OpenCode
  render, too — it's what decides `permission.edit: deny` there.
- Keep `dist/AGENTS.md`'s agent-dispatch table, `README.md`'s agent/skill tables, and the actual
  frontmatter (`model:`, `tools:`) in sync by hand — none of this is generated, and they have drifted
  before (README currently lists `spring-boot-engineer`/`angular-engineer` as `model: inherit`; the
  frontmatter says `sonnet` — check the `.md` file itself, not the README table, when it matters).
- Keep frontmatter in the plain, single-line-value shape the OpenCode transform expects (see the
  `dist/agents/*.md` section above) — a multi-line `description:` or reformatted `permissions.allow`
  block will parse fine for Claude Code but silently produce an incomplete OpenCode file.
