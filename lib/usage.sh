# --help text. Kept in its own file since it's a large static block, separate from the
# runtime UI helpers in ui.sh.
usage() {
  cat <<EOF
${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]

Install agents, skills, and rules into the current project for Claude Code and/or OpenCode.
Always project-local — there is no option to target a global directory.

${BOLD}Options:${RESET}
  -t, --tool <tool>       claude, opencode, or both (default: both)
  -a, --agents <names>    Comma-separated names, "all", or "none" (skips the picker)
  -s, --skills <names>    Comma-separated names, "all", or "none" (skips the picker)
      --practices <ids>   Comma-separated best-practice IDs, "all", or "none" (skips the picker;
                          see "Best practices" below for the list)
  -A, --auto              Detect this project's stack (build files, angular.json, Dockerfile,
                          docker-compose, Helm charts, OpenAPI spec, ...) and install exactly the
                          agents/skills that apply — install-only, ignored with --uninstall. Fills
                          in whichever of -a/-s wasn't already given; explicit flags still win.
                          Interactively, offered as the wizard's leading "Auto" choice whenever
                          something is detected and neither -a nor -s was already passed — that
                          same leading question also offers "Guided" (pick your tech stack from a
                          list, agents/skills are chosen for you) and "Manual" (pick agents/skills
                          directly, today's picker flow).
      --no-confirm        Silent install — no pickers, no wizard, no plan, no prompts
      --no-backup         Skip backup of existing files before overwriting
  -n, --dry-run           Show the plan without making any changes
  -u, --uninstall         Remove installed agents/skills/rules from the project
  -h, --help              Show this help

${BOLD}Best practices:${RESET}
  A single multi-select, everything included by default — SPACE deselects an item instead of
  having to opt into each one (opposite of the agents/skills picker). Six togglable AGENTS.md
  sections: plan-mode, self-improvement, verification, demand-elegance, skills, sub-agents. Always
  offered interactively regardless of Auto/Guided/Manual setup mode; --no-confirm or an explicit
  --practices value skips the prompt.

${BOLD}Git workflow:${RESET}
  Always asked interactively — regardless of Auto/Guided/Manual setup mode, since it configures
  AGENTS.md's content, a separate concern from which agents/skills get installed. One leading
  question: no git / commit locally / Custom. "No git" (the recommended default) never touches
  git at all. "Commit locally" auto-commits with no branch/MR workflow and no direct push.
  "Custom" opens the full five-question breakdown. Under --no-confirm, or if any flag below is
  passed, no question is asked at all — flags win outright, and any flag left unset takes the
  "no git" default for its dimension.
      --use-git <yes|no>       Does the agent use git in this project at all? (default: no)
      --auto-commit <yes|no>   Commit its own completed work without asking? (default: no)
      --use-mrs <yes|no>       Work via feature branch + merge/pull request? (default: no)
      --create-mrs <yes|no>    Open the MR/PR itself (e.g. gh/glab), not just push? (default: no)
      --push-direct <yes|no>   Allow direct pushes to the main/trunk branch? (default: no)
      --git-wizard             Jump straight to the five-question breakdown, skipping the leading
                                question (ignored under --no-confirm)

${BOLD}What goes where:${RESET}
  ./AGENTS.md              Shared rules payload — read natively by OpenCode. Its "Git Workflow"
                            section is generated from the settings above.
  ./.claude/CLAUDE.md       "@AGENTS.md" import — Claude Code only reads CLAUDE.md. Appended to
                            existing content rather than overwritten if the file isn't empty.
  ./.claude/agents/*.md     Claude Code subagents
  ./.claude/skills/<name>/  Skills — also read directly by OpenCode from this same path
  ./.opencode/agents/*.md   OpenCode subagents, rendered from the same dist/agents/ source

  --tool scopes agents and the CLAUDE.md import wrapper. AGENTS.md and skills are shared by
  both tools and are always installed/removed together regardless of --tool.

${BOLD}Examples:${RESET}
  # Interactive — choose Auto/Guided/Manual, the git-workflow question, review plan, ENTER to
  # confirm (both tools)
  ./install.sh

  # Silent install of everything, OpenCode only
  ./install.sh --tool opencode --no-confirm

  # Detect the stack and install exactly what applies, no prompts
  ./install.sh --auto --no-confirm

  # Skip straight to the full git-workflow breakdown instead of the one leading question
  ./install.sh --git-wizard

  # Silent install with an explicit git workflow: auto-commit, MR-based, agent opens its own MRs
  ./install.sh --no-confirm --use-mrs yes --create-mrs yes

  # One-shot from web (run from the target project's directory)
  bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh)
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | bash
EOF
}
