# Features & Roadmap

What this repo's installer should grow into, and in what order. The reference experience is
`oh-my-zsh`'s installer: one curl command, a short interactive setup, done.

## Now — multi-tool support (done)

Agents, skills, and rules are authored once and installed for **Claude Code and/or OpenCode**
(`--tool claude|opencode|both`, default both):

- Source of truth lives in `dist/` (`dist/agents/`, `dist/skills/`, `dist/AGENTS.md`), authored in
  Claude Code's frontmatter dialect.
- `install.sh` renders the OpenCode agent files at install time from that same source — no
  hand-maintained parallel tree, no drift between two copies.
- Skills need zero translation: OpenCode reads `.claude/skills/<name>/SKILL.md` directly (same spec
  Claude Code uses), so there's exactly one skills install, not two.
- The rules payload (`dist/AGENTS.md`) installs to root `AGENTS.md` (OpenCode reads it natively) plus
  a one-line `.claude/CLAUDE.md` that does `@AGENTS.md` — Claude Code's own documented pattern for
  sharing rules with AGENTS.md-based tools, since Claude Code never reads `AGENTS.md` on its own.
- One section of `AGENTS.md` is composed rather than static: whether the agent uses git at all,
  auto-commits, works via feature branch + MR, opens that MR itself, and pushes directly to main — each
  independently controllable via `--use-git`/`--auto-commit`/`--use-mrs`/`--create-mrs`/`--push-direct`
  — renders the "## 4. Git Workflow" section. Interactively it's a single leading question — commit
  locally (the non-invasive default), no git, or Custom (opens the full five-question breakdown) —
  rather than five questions up front; that was tried first and was more setup than wanted. Any of the
  five flags, or `--no-confirm`, skips the question(s) outright. First slice of the "composable
  AGENTS.md" item below; the rest of the file
  (tech defaults, agent-dispatch table) is still one static block regardless of what was selected.

Known gaps in the translation, deliberately deferred:
- OpenCode agent files ship with no `model:` set (inherits whatever provider/model you've configured
  in OpenCode) rather than mapping Claude Code's `sonnet`/`opus`/`haiku` to a specific
  `provider/model-id` — mapping that correctly requires knowing what provider you actually run in
  OpenCode, which this repo doesn't know yet.
- `dist/AGENTS.md`'s prose is still Claude-Code-flavored in a few spots (plan-mode framing, `/clear`
  vs `/compact`, the `Explore`/`general-purpose` built-in subagent names) — it degrades gracefully for
  an OpenCode reader rather than being wrong, but hasn't had a full tool-agnostic rewrite. Worth
  revisiting if OpenCode ends up being used as more than a secondary tool.

## Now — simple setup (mostly already built)

`install.sh` already gets most of the way there:

- One-liner from the web: `curl -fsSL .../install.sh | bash`. When not run from inside a checkout,
  it downloads a tarball of `main` into a temp dir and installs from there — no `git clone` step for
  the user.
- Interactive picker for agents and skills (fzf if available, numbered prompt otherwise), a plan
  preview showing what's new vs. what gets overwritten, and a confirm step.
- `--dry-run`, `--no-confirm` for silent/scripted installs, `--no-backup`, and `--uninstall`.
- Always project-local (`./.claude`) — no global install path.
- Always copies fresh files — no symlink-back-to-checkout mode. Every install is an independent
  snapshot; re-running the installer (or `--update`, once it exists — see below) is how you pick up
  upstream changes, not a live link.

What's still missing to call the "simple setup" complete:

- **Most of AGENTS.md is still one static block** (`dist/AGENTS.md`), not composed from what was
  actually selected — only the git-workflow section (see above) is dynamic so far. Someone who only
  installs `postgres-engineer` still gets Angular/Kotlin tech-default prose in their `AGENTS.md`. Fix:
  extend the marker-plus-render-function pattern the git-workflow section uses to the rest of the file
  (a small shared core + one fragment per stack/best-practice area), concatenating only what matches
  the agents/skills/best-practices selected.
- **"Best practices" beyond git workflow isn't a selectable category yet** — only agents, skills, and
  the git-workflow settings are configurable. Needs the same treatment for things like "plan-mode
  policy", "commit message conventions", "tech defaults table" as opt-in blocks, following the same
  marker-plus-flags-with-a-sane-default pattern the git-workflow section established (default silently,
  no wizard unless asked for) rather than inventing a new mechanism.
- **No presets.** A `--preset kotlin-spring` / `--preset angular` shortcut for "the usual combo for
  this kind of project" would cover the common case without opening the picker.
- **No manifest.** Nothing records what was installed (which agents/skills/version/hash) beyond the
  files themselves. Needed before an "update" flow can exist — right now `--uninstall` just deletes
  by name, and re-running install blindly overwrites (with a backup) rather than diffing.

## Next

- **Composable AGENTS.md, fully** (see above) — extend the git-workflow section's marker/render-function
  pattern to the rest of the file. The biggest remaining gap between "download some files" and "set up
  *my* AGENTS.md from what I chose."
- **Install manifest** (`.claude/.manifest.json`): records selected agents/skills/best-practices,
  source repo ref, and per-file hash. Enables:
  - `./install.sh --update` — re-sync already-installed items to the latest version of `main`
    without re-running the picker, showing a diff-style plan first.
  - Drift detection — warn if a locally installed file was hand-edited since install (hash mismatch)
    before silently overwriting it.
- **Version pinning** — install from a specific tag/release instead of always `main`, so a project
  can freeze its agent/skill versions independently of this repo's HEAD.
- **Shareable selection file** — a small `.claude-install.yml` (agents/skills/best-practices list +
  ref) that a team checks into their *own* project repo, replayable via
  `./install.sh --from-config .claude-install.yml` so teammates get an identical setup with one
  command instead of re-picking by hand.

## Later — auto-detection

`./install.sh --auto` (or auto-detect as the default when no flags are given and the picker would
otherwise run): scan the target project directory and pre-select agents/skills/best-practices from
what's actually there, then show the normal plan for confirmation (or skip confirmation under
`--no-confirm`).

Detection signals (start simple, extend over time):

| Found in project | Selects |
|---|---|
| `build.gradle.kts`, `pom.xml`, many `*.kt` files | `spring-boot-engineer`, `spring-boot-reviewer`, `kotlin-patterns`, `jpa-patterns` |
| `angular.json`, `package.json` with `@angular/core` | `angular-engineer`, `angular-reviewer`, `angular-patterns` |
| `Dockerfile`, `docker-compose*.yml` | `docker-engineer` |
| `**/templates/*.yaml` + `Chart.yaml`, or `k8s/`/`helm/` dirs | `kubernetes-engineer` |
| Flyway migrations, `spring-boot-starter-data-jpa` in build file | `postgres-engineer` |
| `spring-boot-starter-data-mongodb` in build file | `mongodb-engineer` |
| `openapi.yaml`/`openapi.yml` at repo root | `api-designer` |

Auto mode should always be overridable — show what it picked and why (one line per signal matched),
and let `--agents`/`--skills` flags or the interactive picker still take precedence when passed
explicitly.

## Explicitly out of scope

- Global (`~/.claude`) installs — removed on purpose; agents/skills stay project-local.
- Any dependency beyond bash/curl/tar for the core install path (fzf stays optional).
