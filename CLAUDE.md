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
  renders it (not a verbatim copy — see below) to a target project's root `AGENTS.md` (OpenCode reads
  this natively) and ensures `./.claude/CLAUDE.md` imports it via `@AGENTS.md` (Claude Code only ever
  reads `CLAUDE.md`, never `AGENTS.md` — see
  [Anthropic's docs](https://code.claude.com/docs/en/memory#agentsmd)). This never clobbers pre-existing
  content: a missing/empty `.claude/CLAUDE.md` gets the plain one-line `@AGENTS.md` file as before, but
  a `.claude/CLAUDE.md` that already has real content (hand-authored, from a prior tool, whatever) gets
  the import line *appended* instead — and left alone entirely if it already imports `AGENTS.md`
  (`write_claude_md_import()` in `lib/actions.sh`). Note this is a separate file from a project's root
  `CLAUDE.md` (if one exists) — Claude Code loads both when present, concatenated, so installing into a
  repo that already has its own root `CLAUDE.md` never touches that file at all; `AGENTS.md`'s content
  just arrives as an addition via `.claude/CLAUDE.md`. `dist/AGENTS.md` contains the agent-dispatch
  rules, plan-mode policy, and Kotlin/Spring/Angular tech defaults that apply to *downstream* projects
  — not to work done in this repo. Edit it when changing what gets shipped to consumers; edit this file
  when changing how Claude Code should behave while working on the bundle itself.

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

# --auto: run against a scratch dir seeded with recognizable files (a build.gradle.kts with a
# spring-boot dependency, an angular.json, a docker-compose.yml, ...) and confirm both paths:
/path/to/repo/install.sh --auto --no-confirm --dry-run   # flag-forced, prints "Auto-detected setup:"
/path/to/repo/install.sh --dry-run                        # interactive — wizard should offer "Auto"
# ...and against an empty scratch dir: --auto must die with a clear message, and the interactive
# wizard must NOT offer "Auto" as one of the three options (Guided/Manual are still always offered).

# Esc goes back a step: interactively (fzf installed), press Esc on any picker/ask_choice screen —
# Ctrl-C must still abort the whole install (check_fzf_cancelled()'s 130 path is unchanged; only Esc
# is registered via --expect=esc). Confirm Esc steps back exactly one wizard step (e.g. from Skills
# back to Agents), that a step with nothing to show (Agents/Skills while Auto/Guided already filled
# them) is skipped over transparently while backing up — landing on Mode, not stalling on a blank
# screen — and that going back and picking a different setup mode (Auto -> Manual, say) actually
# re-prompts Agents/Skills instead of silently keeping the old selection. At the final review
# screen, confirm typing 'b' at "Proceed? [Y/n/b=back]" re-opens the git-workflow question
# (rerun_wizard_from_git() in lib/actions.sh) and that changing the answer there is reflected in the
# re-displayed plan and the eventually-installed AGENTS.md. Without fzf installed (rename/hide it
# from PATH for the test), confirm the numbered-prompt fallback accepts typing 'b'/'back' the same
# way. This is hard to script end-to-end (real terminal-only Esc handling for the fzf path), but the
# non-fzf path IS scriptable via piped stdin — worth doing after any change here, since this exact
# feature had a bug (a bash dynamic-scoping clobber of the wizard's step-index variable — see the
# comment atop lib/pickers.sh) that only surfaced under a scripted multi-step back-and-forth
# sequence, not a quick single-step check.

# Guided mode: choose it at the leading question, confirm it now shows FOUR separate per-group
# screens in order — Frontend, Backend, Database, DevOps (GROUP_ORDER in resolve_guided_stack(),
# lib/auto.sh) — each listing only that group's category labels, rather than one flat multi-select
# of everything. Confirm picking two categories that share an agent (e.g. Kotlin + Java, both add
# spring-boot-engineer) dedupes to one copy, and that the git-workflow question still gets asked
# afterward (it's no longer skippable via any setup mode — only --no-confirm/explicit flags skip
# it). Also confirm Guided reflects ONLY what was picked, not a mix with whatever Auto's file-based
# detection separately found (resolve_guided_stack() must reset DETECTED_* before applying picks —
# this was a real bug caught by testing: a Dockerfile in the scratch dir silently leaked
# docker-engineer into a Guided selection that never asked about Docker).
#
# Guided's per-group screens support the same Esc-goes-back navigation as the rest of the wizard
# (see the "Esc goes back a step" section below): confirm going back from the Database screen lands
# on Backend (not all the way to Frontend — it's one screen back, same as everywhere else), and
# that Esc on the very first screen shown (Frontend, unless it's ever empty) propagates out to
# re-ask the Auto/Guided/Manual question rather than exiting the wizard. Also confirm a category
# file with no _<name>_group() function still appears, grouped under its own trailing "Other"
# screen, instead of silently vanishing from Guided mode — this is the fallback GROUP_ORDER's
# unknown-group-name branch exists to guarantee, and is easy to break by hardcoding an exhaustive
# group list instead of appending unknowns.

# When touching lib/detect/*.sh specifically: pure-Java-no-Kotlin must get spring-boot-engineer/
# reviewer + logging-patterns + clean-code but NOT kotlin-patterns; a mixed project with both
# src/main/kotlin and src/main/java must get exactly one backend note (kotlin.sh wins) and DOES get
# kotlin-patterns (also with clean-code, from _kotlin_apply() this time, not _java_apply()).
mkdir -p pure-java-spring/src/main/java && cd pure-java-spring
printf "implementation 'org.springframework.boot:spring-boot-starter-web'\n" > build.gradle
/path/to/repo/install.sh --auto --no-confirm --dry-run   # must show logging-patterns + clean-code, no kotlin-patterns

# When touching dist/AGENTS.md's IF_AGENT blocks or lib/actions.sh's render_agents_md()/
# compute_effective_agents(): a narrow selection's installed AGENTS.md must not mention any agent
# not in that selection (grep for other agents' backtick-quoted names, expect zero), a full/--auto
# install of everything must reproduce today's static content exactly (diff against dist/AGENTS.md
# with markers stripped), and an ADDITIVE re-install (install backend, then re-run with only
# -a angular-engineer) must still mention the first run's agent — this is what
# compute_effective_agents' union-with-what's-already-on-disk exists to guarantee. Also re-check a
# zero-agent selection (-a none, skills only) renders without crashing — this is the same
# empty-array bash 3.2 class of bug caught once already this session, and it recurred once in
# compute_effective_agents() itself before being caught by exactly this test.

# Best practices (lib/practices.sh, dist/AGENTS.md's IF_PRACTICE blocks): --practices none must
# drop all six togglable sections (Plan Mode Default, Self-Improvement Loop, Verification Before
# Done, Demand Elegance, Skills, Sub-agents) while Git Workflow and Core Principles stay; a partial
# --practices list must drop only the deselected ones (check no numbering gaps remain — headings
# are unnumbered on purpose, see the dist/AGENTS.md section above); the dispatch-table rows nested
# inside "Sub-agents" must vanish along with it even for agents that ARE installed (nesting: an
# outer skip wins over an inner keep) — deselecting sub-agents entirely must leave zero
# `IF_AGENT`-gated rows behind, not just the section heading. Interactively, confirm pick_deselect
# actually starts with everything pre-checked (fzf's `start:select-all`) rather than requiring the
# user to opt into all six by hand.
```

Run this after any change to `install.sh` or `lib/*.sh`/`lib/detect/*.sh`, or after adding/renaming
an agent or skill, to confirm discovery, copying, and the OpenCode frontmatter transform still work.
There's no CI — this manual dry-run is the whole safety net (`bash -n install.sh lib/*.sh
lib/detect/*.sh` at least catches syntax errors before that — but note it only catches parse errors,
not the empty-array/`bash 3.2` class of bug below, which only surfaces at runtime with a specific
empty selection). When touching the OpenCode render logic specifically, `cat` a couple
of the rendered `.opencode/agents/*.md` files — especially one with a `permissions.allow` Bash list
(e.g. `spring-boot-engineer`) and one reviewer with no `Write`/`Edit` (e.g. `spring-boot-reviewer`) —
to confirm the `permission:` block came out right. When touching the git-workflow policy, `sed -n
'/## Git Workflow/,/^## /p' AGENTS.md` (the end anchor is deliberately "any next `##` heading," not
a specific one — which heading follows Git Workflow now depends on which best-practice sections got
selected) after an install with a few different
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
`dist/AGENTS.md`, wrapped in `<!-- IF_AGENT:new-agent-name --> ... <!-- END_IF -->` (see the
`dist/AGENTS.md` section below) so it only shows up in projects that actually installed it. If the
agent implies new stack-specific conventions, add them to `## Project Defaults` under the same
convention.

**OpenCode rendering** (`render_opencode_agent()` in `lib/opencode.sh`): translates this frontmatter into
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

Installed to a target project's root `AGENTS.md` (OpenCode reads this directly) and imported by
`.claude/CLAUDE.md` via `@AGENTS.md` (Claude Code's documented pattern for sharing rules with
AGENTS.md-based tools; Claude Code never reads `AGENTS.md` on its own) — see `write_claude_md_import()`
in `lib/actions.sh` for why that import is appended rather than overwriting when `.claude/CLAUDE.md`
already has content. Because both tools read this same file, keep it tool-agnostic where practical —
avoid hardcoding one tool's paths or mechanisms (e.g. the agent-directory line spells out both
`.claude/agents/` and `.opencode/agents/` rather than assuming one).

Not installed verbatim — `render_agents_md()` (in `lib/actions.sh`) reads `dist/AGENTS.md` line by
line and applies two independent, coexisting marker conventions:

- **`<!-- GIT_WORKFLOW_POLICY -->`** — a single-line marker under `## Git Workflow`, replaced
  wholesale by `render_git_workflow_policy()`'s output (`lib/git_workflow.sh`). Use this shape —
  one marker, one dedicated function — when the replacement content is *generated* from multiple
  settings and doesn't exist as static text anywhere (git workflow is built from five
  yes/no-ish settings, not a fixed block of prose).
- **`<!-- IF_AGENT:name,name --> ... <!-- END_IF -->`** / **`<!-- IF_PRACTICE:id,id --> ... <!-- END_IF -->`**
  — a block of *already-written* markdown (a table row, a whole `##`/`###` section) that survives
  in the installed file only if at least one of the comma-separated agent names is installed
  (`IF_AGENT`) or best-practice IDs is selected (`IF_PRACTICE` — see `lib/practices.sh`). Used
  throughout the "Available agents" dispatch table (one row per agent), `## Project Defaults`
  (Kotlin/Spring/Angular/Postgres/Mongo/Keycloak/Kubernetes/Docker Compose content, each gated on
  the agent whose domain it is), and the six togglable top-level sections (Plan Mode Default,
  Self-Improvement Loop, Verification Before Done, Demand Elegance, Skills, Sub-agents) — so a
  project that only installs `docker-engineer`, say, doesn't get an `AGENTS.md` that still tells
  Claude to dispatch backend work to `spring-boot-engineer`, and a user who deselected
  "Self-Improvement Loop" doesn't get that section at all. Use this shape when content already
  exists as plain markdown and just needs to be conditionally included, rather than generated —
  keeps it readable/editable as markdown instead of turning prose into bash `echo` string
  literals. **Blocks DO nest** (e.g. the per-agent dispatch-table rows sit inside the whole
  "Sub-agents" section, itself an `IF_PRACTICE` block) — `render_agents_md()` tracks this with a
  plain string stack (one `"0"`/`"1"` character per open block) rather than an array, specifically
  to sidestep the bash 3.2 empty-array gotcha below for this piece of state; a line is skipped if
  the stack contains a `"1"` anywhere, so an outer skip always wins over an inner "keep." One
  accepted consequence of keeping this otherwise simple: "Preferred Technology Defaults" can render
  as a table header with zero rows if literally none of the relevant agents are installed.

The agent set gating `IF_AGENT` blocks is not just this run's `-a`/`--auto`/Guided selection —
`compute_effective_agents()` unions `AGENTS_TO_INSTALL` with whatever agent `.md` files are
*already* present in `.claude/agents/`/`.opencode/agents/` from a prior install (scanning both
regardless of `--tool`, since `AGENTS.md` is a shared, tool-agnostic description of "agents
available in this project"). Without this union, an additive re-install (e.g. add Angular to an
already-installed Spring Boot project via `-a angular-engineer` alone) would make `AGENTS.md`
silently drop the Spring Boot dispatch row even though `spring-boot-engineer.md` is still on disk —
only `--uninstall` actually removes agent files, so a narrower `-a`/`-s` on a later run must never
be read as "these are the only agents that exist now."

The `dist/AGENTS.md` section headings for the six togglable practices (and Git Workflow) are
deliberately *not* numbered ("Plan Mode Default", not "1. Plan Mode Default") — they used to be,
but once any of them can be independently dropped, sequential numbers would show gaps (e.g. "1."
then "3." with no "2." if the second section got deselected), which reads as broken rather than
intentional. Don't reintroduce numbering here unless it's made robust to arbitrary subsets being
present.

Interactively (and not `--no-confirm`, and no flag already set), the git-workflow question leads
with one question via `ask_choice`: "commit locally" (the non-invasive default — never touches the
remote), "no git", or "Custom...". Only "Custom" drops into `ask_git_workflow_details()`, the full
five-question breakdown (same function `--git-wizard` calls directly, skipping the leading
question; both live in `lib/git_workflow.sh`). Passing any one of the five flags skips the leading
question entirely — the CLI is already "custom" at that point — and fills whichever dimensions are
still unset with the "commit locally" default. This two-tier shape (one low-friction question by
default, full control one level down) is deliberate: asking all five questions unconditionally was
tried first and was more setup than wanted for the common case. This question is always asked
regardless of Auto/Guided/Manual setup mode — see the git-workflow bullet below.

### `reference/*.md` — fetched external docs

Local copies of upstream documentation (Kotlin coding conventions, Angular signals/zoneless/style-guide
docs) that skills point to instead of re-fetching a URL each time. Repo-dev-time only — not part of
`dist/`, never installed into a consumer project. This mirrors the "Reference Material" rule in
`dist/AGENTS.md`: fetch once, save locally, cite the local file afterward.

### `install.sh` + `lib/*.sh` — the installer

`install.sh` is a thin entrypoint, not a monolith: locate/download assets, source `lib/*.sh`, parse
arguments, run `discover_items`/`run_detection`, decide the wizard shape (`WIZARD_STEPS`,
`STEP_TOTAL`, the `STEP_IDX_*` constants, `OFFER_SETUP_MODE`), then call into library functions for the
rest of the flow (`resolve_setup_mode` → `resolve_agent_skill_selection` → `resolve_git_workflow` →
`build_install_arrays` → `compute_total_ops` → `run_install`/`run_uninstall`). Keep new logic in
`lib/`; `install.sh` itself should stay orchestration-only. The split:

- `lib/ui.sh` — colours, `info`/`ok`/`warn`/`die`, `run()`, `tool_active()`, the fzf-cancel guard
  (`check_fzf_cancelled`), `confirm()`, and the wizard chrome (`step()`, `print_intro()` — the intro
  banner and running "Step X/N" headers shown on any run short of `--no-confirm`). `step()` takes
  the step's fixed `STEP_IDX_*` value, not an auto-incrementing counter — see the gotcha below.
- `lib/usage.sh` — the `--help` text.
- `lib/pickers.sh` — generic fzf-backed / numbered-prompt choice helpers, with no domain knowledge
  of agents/skills/git/practices — that lives one layer up. Two shapes: `pick`/`ask_choice`
  (opt-in — nothing selected until the user picks it, empty submission defaults to "all") and
  `pick_deselect` (opt-out — everything starts selected, the user removes what they don't want;
  uses fzf's documented `start:select-all` binding to pre-check every item, `--sync` to avoid a
  first-frame race). Use opt-in when building a list from nothing is the common case (agents,
  skills); opt-out when "everything" is the recommended default and carving out an exception is
  the common case (best practices).
- `lib/selection.sh` — discovering installable agents/skills (`discover_items`) and resolving
  `-a`/`-s`/picker/`--auto` output into the `AGENTS_TO_INSTALL`/`SKILLS_TO_INSTALL` arrays
  (`resolve_agent_skill_selection`, `resolve()`, `build_install_arrays`); also `compute_total_ops()`,
  which sizes the `[n/total]` progress counter `ok()` (in `lib/ui.sh`) prints during the copy/remove
  phase. `resolve()` treats the literal string `"none"` as an explicit "install zero for this
  category" — distinct from `""` (unset, defaults to "all") — which is how `--auto` represents "I
  detected nothing here" without falling back to installing everything.
- `lib/git_workflow.sh` — the git-workflow wizard (leading question + five-question "Custom"
  breakdown, `resolve_git_workflow`/`ask_git_workflow_details`) and rendering it into AGENTS.md's
  `## Git Workflow` section (`render_git_workflow_policy`, `git_workflow_summary`). **Always
  asked interactively**, regardless of which of Auto/Guided/Manual was picked for agents/skills —
  it configures AGENTS.md's content, a separate concern from agent/skill selection. Only
  `--no-confirm` or explicit `--use-git`/etc. flags skip it.
- `lib/practices.sh` — `--practices` / the "choose which best practices to include" wizard step:
  `PRACTICE_IDS`/`PRACTICE_LABELS` are the one hand-maintained list of (id, label) pairs for the
  six togglable `dist/AGENTS.md` sections (Plan Mode Default, Self-Improvement Loop, Verification
  Before Done, Demand Elegance, Skills, Sub-agents) — not one-file-per-practice like agents/
  detection categories, since these aren't independently file-backed, just fixed toggles within
  one document. `resolve_best_practices()` shows the `pick_deselect` multi-select (all six
  pre-checked; --no-confirm or an explicit `--practices` value skips it, defaulting to "all"), and
  `build_effective_practices()`/`_practice_selected()` feed `render_agents_md()`
  (`lib/actions.sh`) the same way `compute_effective_agents()`/`_agent_in_effective_set()` do for
  agents — reuses `resolve()` (`lib/selection.sh`) for the "all"/"none"/comma-list semantics, same
  as `-a`/`-s`. Like Git Workflow, this step is always offered regardless of Auto/Guided/Manual and
  is install-only (no-op under `--uninstall`).
- `lib/auto.sh` — the setup-mode engine + wizard glue: `--auto`, and the wizard's leading
  Auto/Guided/Manual question. Two file-scanning phases power Auto: `_project_scan()` scans the
  target project *once* for generic, concrete file-level facts (build files,
  `angular.json`/`package.json`, `Dockerfile`/compose, Helm charts, an OpenAPI spec,
  `src/main/kotlin`/`src/main/java` — even nested one level, e.g. `backend/src/main/kotlin`, via
  `_detect_path_dir`) into `PROJECT_*` globals; `run_detection()` then discovers and calls every
  `detect_*` category function defined in `lib/detect/*.sh` **by reflection** (`declare -F | grep
  '^detect_'` — no hardcoded category list anywhere, same "glob it, don't register it" philosophy
  as `dist/agents/*.md`/`dist/skills/*/`), each of which reads the `PROJECT_*` facts and
  independently fills `DETECTED_AGENTS`/`DETECTED_SKILLS`/`DETECTED_NOTES`. Guided mode
  (`resolve_guided_stack()`) fills the *same* three arrays a different way: it resets them, shows a
  multi-select of every category's `_<name>_label()` (also reflection-discovered, off the `_apply`
  suffix this time), and calls `_<name>_apply()` directly for whatever the user picks — the exact
  same contribution code Auto's `detect_<name>()` calls, just triggered by a choice instead of a
  file signal. Also defines the shared helpers every category uses: `_detect_grep_any`/
  `_detect_find`/`_detect_any_dir`/`_detect_path_dir` (filesystem probes) and `_grep_project_files`
  (greps a pattern across one or more named `PROJECT_*_FILES` arrays, safe with any mix of empty
  ones — uses `eval` for name-indirection since bash 3.2 has neither namerefs nor associative
  arrays; see the gotcha below). `apply_detected_selection()` turns `DETECTED_*` into
  `SELECTED_AGENTS`/`SELECTED_SKILLS` (without overriding either that `-a`/`-s` already pinned);
  `resolve_setup_mode()` is the wizard's leading question, a no-op unless the entrypoint set
  `OFFER_SETUP_MODE=true` — "Auto" only appears as one of its options when something was actually
  detected, "Guided"/"Manual" are always offered.
- `lib/detect/*.sh` — one file per detection category (`kotlin.sh`, `java.sh`, `angular.sh`,
  `jpa.sh`, `postgres.sh`, `mongodb.sh`, `docker.sh`, `kubernetes.sh`, `security.sh`, `openapi.sh`,
  `ansible.sh`),
  each defining **three** functions (see the comment at the top of `kotlin.sh` for the full
  rationale):
  - `detect_<name>()` — Auto's entry point. Reads `PROJECT_*` facts; on a hit, calls
    `_<name>_apply()` and adds its own evidence-specific `DETECTED_NOTES` line
    ("... — src/main/kotlin", "... — dependency / compose file / application config", etc.).
  - `_<name>_apply()` — the pure contribution: appends to `DETECTED_AGENTS`/`DETECTED_SKILLS`
    only, no notes. Shared between Auto and Guided, which is exactly why it can't hardcode an
    evidence-based note itself.
  - `_<name>_label()` — the human-readable stack-option text Guided mode's multi-select shows, and
    reused verbatim as the `DETECTED_NOTES` line when the user picks it there.

  No category calls `find`/`grep` against the filesystem itself — only `lib/auto.sh`'s
  `_project_scan()` does that. Sourced dynamically from `install.sh` the same way
  `dist/agents`/`dist/skills` are discovered — no registry; adding a category means adding a new
  file here, nothing else to wire up. **Naming conventions are load-bearing, in two directions**:
  any function starting with `detect_` gets invoked directly with no arguments by
  `run_detection()`'s reflection loop, and any function ending in `_apply` gets invoked the same
  way by `resolve_guided_stack()`'s — a private helper a category needs (that isn't itself an entry
  point) must avoid both patterns (e.g. `_kotlin_gradle_plugin_present`), or it'll be wrongly swept
  up and run as its own category. Detection stays deliberately conservative — only agents/skills
  tied to a real signal (Auto) or an explicit user pick (Guided) get selected; agents with no
  file-level signature (`architect`, `doc-writer`) and the on-demand `design-patterns` skill are
  never auto-selected — and every category must add a `DETECTED_NOTES` line explaining itself, no
  silent additions. `clean-code` is the deliberate exception: it's language-agnostic and listed in
  every language-writing agent's own `skills:` frontmatter (`spring-boot-engineer`/`-reviewer`,
  `angular-engineer`/`-reviewer`), so `kotlin.sh`/`java.sh`/`angular.sh`'s `_apply()` functions each
  add it directly — whichever language category gets selected (Auto or Guided) brings it along,
  rather than requiring a separate pick. Kotlin and Java are deliberately separate files, not one
  combined "backend"
  check: `kotlin.sh` fires only on actual Kotlin evidence and adds `kotlin-patterns`; `java.sh`
  fires on the same Spring Boot evidence but *only* when there's no Kotlin evidence, and never adds
  `kotlin-patterns` — before this split, a pure-Java Spring Boot project got `kotlin-patterns`
  unconditionally, which was a bug, not a feature.
- `lib/opencode.sh` — `render_opencode_agent()`/`write_opencode_agent()` (see the frontmatter-transform
  mapping above).
- `lib/plan.sh` — backup-before-overwrite (`backup_item`) and the install/uninstall plan preview
  (`print_plan`).
- `lib/actions.sh` — `write_agents_md()` (now just `compute_effective_agents()` +
  `build_effective_practices()` (`lib/practices.sh`) + `render_agents_md()` — see the
  `dist/AGENTS.md` section above for what these do and why) and the actual
  `run_install()`/`run_uninstall()` phases that do the real file writes/removals.

No dependencies beyond bash/curl/tar/sed/awk (fzf optional, for the interactive picker). Key behaviors:
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
  from inside the repo, and installs into the caller's cwd). This is *why* `lib/*.sh` is sourced from
  `$REPO_ROOT/lib`, not `$SCRIPT_DIR/lib`: the "Locate assets" step at the top of `install.sh` already
  resolves `REPO_ROOT` to a freshly-downloaded tempdir containing the *whole* repo — `lib/` included —
  whenever the script isn't sitting inside a checkout, so the same source-from-`REPO_ROOT` line works
  identically in both cases without any extra fetch logic. If you ever add a runtime dependency beyond
  `dist/` and `lib/`, route it through this same `REPO_ROOT`-relative pattern rather than assuming a
  local checkout.
- Both the install and uninstall paths (`run_install`/`run_uninstall` in `lib/actions.sh`) end with an
  explicit `exit 0`. Without it, the exit code is whatever the last statement happened to return — the
  install path's last statement used to be `$BACKUP_USED && info "..."`, which is `false && ...`
  (exit 1) on the common case of a fresh install needing no backup, so
  `install.sh --no-confirm && next_step` silently treated a successful install as a failure. If you add
  statements after the final `info`/`ok` call, keep (or move) the `exit 0` last.
- **`set -e` gotcha from the `lib/` split**: a guard like `[[ -z "$X" ]] && X="default"` is harmless as
  a bare top-level script statement — its failure when `$X` is already set is exempt from `set -e`,
  since it's the non-final member of its own `&&` list. But move that same line to be the *last*
  statement of a function, and it stops being harmless: the guard's non-firing exit status (1) becomes
  the function's own return status, and a bare (unwrapped in `if`/`&&`/`||`) call to that function *is*
  subject to `set -e` — so the whole script dies right after the call, with no error message. This
  actually happened once while splitting the monolith (`resolve_git_workflow`'s trailing
  `[[ -z ... ]] && ...` defaults-fill block). Every `lib/*.sh` function that's invoked as a bare
  statement now ends with an explicit `return 0` for this reason — keep that pattern for any new
  orchestration function, especially one whose last lines are `&&`/`||` guards.
- **bash 3.2 gotcha — empty named arrays under `set -u`**: macOS's default `/bin/bash` is 3.2.57
  (Apple never shipped a GPLv3-licensed bash), and in that version, bare-expanding an empty *named*
  array — `for x in "${arr[@]}"`, or passing `"${arr[@]}"` as a function argument, with `arr=()` —
  throws `unbound variable` under `set -u`, even though `${#arr[@]}` (length) is fine and looping
  over `"$@"` (positional params) is never affected regardless of count. This was a real, live bug:
  `run_install`/`run_uninstall` looped over `"${AGENTS_TO_INSTALL[@]}"`/`"${SKILLS_TO_INSTALL[@]}"`
  unguarded, and selecting zero skills (or zero agents) crashed the whole install with no useful
  error. `--auto` made this reachable in practice (a Docker-only project detects zero skills), which
  is how it was found. Fix (already applied): guard every such loop with
  `if [[ ${#arr[@]} -gt 0 ]]; then ... fi` first — `lib/auto.sh`'s top comment has the same guard
  pattern applied to its own array expansions. Never bare-expand a `DETECTED_*`/`*_TO_INSTALL`/any
  other array that can legitimately be empty; always check its length first. A second technique was
  needed for `lib/auto.sh`'s `_grep_project_files`: greping across one of several `PROJECT_*_FILES`
  arrays *chosen by name* at the call site, which bash 3.2 can only do via `eval`-based
  name-indirection (no `local -n`/namerefs before 4.3, no associative arrays before 4.0) — verified
  against a real 3.2.57 shell, including filenames containing spaces and a literal `$`. The exact
  same class of bug recurred a third time in `compute_effective_agents()`
  (`EFFECTIVE_AGENTS=("${AGENTS_TO_INSTALL[@]}")` as its first line) despite all this — a reminder
  that this gotcha has to be re-checked on every new array expansion, not just remembered once.
- **Step numbering is index-based, not a counter**: `step()` originally auto-incremented a counter
  each call, which looked right until `--auto`'s wizard choice started skipping 3 of 5 steps in one
  go — the final "review" step displayed as "Step 2/5" instead of "Step 5/5" because only 2 `step()`
  calls had actually happened. Fixed by having every call site pass its own fixed `STEP_IDX_*`
  (`step "$STEP_IDX_REVIEW" "${WIZARD_STEPS[$STEP_IDX_REVIEW]}"`) so the displayed number reflects
  the step's real position regardless of what got skipped before it. If you add a new wizard stage,
  give it a `STEP_IDX_*` constant in `install.sh` rather than reintroducing a counter.

## Conventions when adding or editing an agent/skill

- Agent `description` should read as a dispatch trigger ("Use when... / Use proactively when...") since
  that's the field the orchestrator matches against, for both tools.
- Reviewer agents (`*-reviewer`) get read-mostly tool sets (`Read, Grep, Glob, Bash`, no `Write`/`Edit`)
  and `model: haiku` — cheap, fast, high-volume checks. Implementer agents get the full
  `Read, Write, Edit, Bash, Glob, Grep` set and `model: sonnet` (or `opus` for `architect`, which does
  the highest-stakes reasoning). The `Write`/`Edit` distinction is load-bearing for the OpenCode
  render, too — it's what decides `permission.edit: deny` there.
- Keep `dist/AGENTS.md`'s agent-dispatch table, `README.md`'s agent/skill tables, and the actual
  frontmatter (`model:`, `tools:`) in sync by hand — the *row text* (trigger phrase, tech-default
  bullets) is still hand-authored, not generated, and they have drifted before (README currently
  lists `spring-boot-engineer`/`angular-engineer` as `model: inherit`; the frontmatter says
  `sonnet` — check the `.md` file itself, not the README table, when it matters). What *is*
  automatic at install time is which rows survive — see the `dist/AGENTS.md` section above.
- Keep frontmatter in the plain, single-line-value shape the OpenCode transform expects (see the
  `dist/agents/*.md` section above) — a multi-line `description:` or reformatted `permissions.allow`
  block will parse fine for Claude Code but silently produce an incomplete OpenCode file.
