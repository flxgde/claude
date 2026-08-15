#!/usr/bin/env bash
# Install Claude Code and/or OpenCode agents, skills, and rules into the current project.
# Always project-local — installing globally into ~/.claude or ~/.config/opencode is not supported.
#
# Source of truth lives in dist/ (agents, skills, AGENTS.md) and is authored once, in Claude
# Code's frontmatter dialect. --tool opencode renders OpenCode-format agent files on the fly;
# skills need no translation — OpenCode reads .claude/skills/ directly, same spec Claude Code uses.
#
# Run from the repo:
#   ./install.sh
#
# One-shot from the web:
#   bash <(curl -fsSL https://raw.githubusercontent.com/flxgde/claude/main/install.sh)
#   curl -fsSL https://raw.githubusercontent.com/flxgde/claude/main/install.sh | bash
#
# All three are interactive. Use --no-confirm to skip all prompts and install silently.
set -euo pipefail

GITHUB_REPO="flxgde/claude"
GITHUB_BRANCH="main"
GITHUB_ARCHIVE="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"

# ── Locate assets ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
_TMPDIR=""

if [[ -d "$SCRIPT_DIR/dist/agents" && -d "$SCRIPT_DIR/dist/skills" ]]; then
  REPO_ROOT="$SCRIPT_DIR"
else
  echo "[info]  Assets not found locally — downloading from GitHub..."
  _TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$_TMPDIR"' EXIT
  curl -fsSL "$GITHUB_ARCHIVE" | tar -xz --strip-components=1 -C "$_TMPDIR"
  REPO_ROOT="$_TMPDIR"
fi

AGENTS_SRC="$REPO_ROOT/dist/agents"
SKILLS_SRC="$REPO_ROOT/dist/skills"
AGENTS_MD_SRC="$REPO_ROOT/dist/AGENTS.md"

# ── Defaults ──────────────────────────────────────────────────────────────────
readonly CLAUDE_DIR="$PWD/.claude"
readonly OPENCODE_DIR="$PWD/.opencode"
TOOL="both"
SELECTED_AGENTS=""
SELECTED_SKILLS=""
GIT_USE=""
GIT_AUTOCOMMIT=""
GIT_USE_MRS=""
GIT_CREATE_MRS=""
GIT_PUSH_DIRECT=""
GIT_WIZARD=false
NO_CONFIRM=false
NO_BACKUP=false
DRY_RUN=false
UNINSTALL=false

# ── Colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; DIM=''; RESET=''
fi

info() { echo -e "${BLUE}[info]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[ ok]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[warn]${RESET}  $*" >&2; }
die()  { echo "[error] $*" >&2; exit 1; }

run() {
  if $DRY_RUN; then echo -e "${YELLOW}[dry]${RESET}   $*"
  else eval "$@"
  fi
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]

Install agents, skills, and rules into the current project for Claude Code and/or OpenCode.
Always project-local — there is no option to target a global directory.

${BOLD}Options:${RESET}
  -t, --tool <tool>       claude, opencode, or both (default: both)
  -a, --agents <names>    Comma-separated names, or "all" (skips the picker)
  -s, --skills <names>    Comma-separated names, or "all" (skips the picker)
      --no-confirm        Silent install — no pickers, no wizard, no plan, no prompts
      --no-backup         Skip backup of existing files before overwriting
  -n, --dry-run           Show the plan without making any changes
  -u, --uninstall         Remove installed agents/skills/rules from the project
  -h, --help              Show this help

${BOLD}Git workflow:${RESET}
  Interactively, one leading question: commit locally / no git / Custom. "Commit locally" (the
  recommended default) never touches the remote — no branch/MR workflow, no direct push. "Custom"
  opens the full five-question breakdown. Under --no-confirm, or if any flag below is passed, no
  question is asked at all — flags win outright, and any flag left unset takes the "commit locally"
  default for its dimension.
      --use-git <yes|no>       Does the agent use git in this project at all? (default: yes)
      --auto-commit <yes|no>   Commit its own completed work without asking? (default: yes)
      --use-mrs <yes|no>       Work via feature branch + merge/pull request? (default: no)
      --create-mrs <yes|no>    Open the MR/PR itself (e.g. gh/glab), not just push? (default: no)
      --push-direct <yes|no>   Allow direct pushes to the main/trunk branch? (default: no)
      --git-wizard             Jump straight to the five-question breakdown, skipping the leading
                                question (ignored under --no-confirm)

${BOLD}What goes where:${RESET}
  ./AGENTS.md              Shared rules payload — read natively by OpenCode. Its "Git Workflow"
                            section is generated from the settings above.
  ./.claude/CLAUDE.md       One-line "@AGENTS.md" import — Claude Code only reads CLAUDE.md
  ./.claude/agents/*.md     Claude Code subagents
  ./.claude/skills/<name>/  Skills — also read directly by OpenCode from this same path
  ./.opencode/agents/*.md   OpenCode subagents, rendered from the same dist/agents/ source

  --tool scopes agents and the CLAUDE.md import wrapper. AGENTS.md and skills are shared by
  both tools and are always installed/removed together regardless of --tool.

${BOLD}Examples:${RESET}
  # Interactive — pick, one git-workflow question (commit locally / no git / Custom), review
  # plan, ENTER to confirm (both tools)
  ./install.sh

  # Silent install of everything, OpenCode only
  ./install.sh --tool opencode --no-confirm

  # Skip straight to the full git-workflow breakdown instead of the one leading question
  ./install.sh --git-wizard

  # Silent install with an explicit git workflow: auto-commit, MR-based, agent opens its own MRs
  ./install.sh --no-confirm --use-mrs yes --create-mrs yes

  # One-shot from web (run from the target project's directory)
  bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh)
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | bash
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tool)       TOOL="$2"; shift 2 ;;
    -a|--agents)     SELECTED_AGENTS="$2"; shift 2 ;;
    -s|--skills)     SELECTED_SKILLS="$2"; shift 2 ;;
       --use-git)     GIT_USE="$2"; shift 2 ;;
       --auto-commit) GIT_AUTOCOMMIT="$2"; shift 2 ;;
       --use-mrs)     GIT_USE_MRS="$2"; shift 2 ;;
       --create-mrs)  GIT_CREATE_MRS="$2"; shift 2 ;;
       --push-direct) GIT_PUSH_DIRECT="$2"; shift 2 ;;
       --git-wizard) GIT_WIZARD=true; shift ;;
       --no-confirm) NO_CONFIRM=true; shift ;;
       --no-backup)  NO_BACKUP=true; shift ;;
    -n|--dry-run)    DRY_RUN=true; shift ;;
    -u|--uninstall)  UNINSTALL=true; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               die "Unknown option: $1. Run with --help for usage." ;;
  esac
done

[[ "$TOOL" == "claude" || "$TOOL" == "opencode" || "$TOOL" == "both" ]] \
  || die "Tool must be 'claude', 'opencode', or 'both'"

for pair in "--use-git:$GIT_USE" "--auto-commit:$GIT_AUTOCOMMIT" "--use-mrs:$GIT_USE_MRS" \
            "--create-mrs:$GIT_CREATE_MRS" "--push-direct:$GIT_PUSH_DIRECT"; do
  flag="${pair%%:*}"; val="${pair#*:}"
  [[ -z "$val" || "$val" == "yes" || "$val" == "no" ]] || die "$flag must be 'yes' or 'no'"
done

tool_active() { [[ "$TOOL" == "both" || "$TOOL" == "$1" ]]; }

CLAUDE_AGENTS_DEST="$CLAUDE_DIR/agents"
CLAUDE_SKILLS_DEST="$CLAUDE_DIR/skills"
CLAUDE_MD_DEST="$CLAUDE_DIR/CLAUDE.md"
OPENCODE_AGENTS_DEST="$OPENCODE_DIR/agents"
AGENTS_MD_DEST="$PWD/AGENTS.md"
BACKUP_DIR="$CLAUDE_DIR/.backup/$(date +%Y%m%d_%H%M%S)"
BACKUP_USED=false

# ── Discover available items ──────────────────────────────────────────────────
ALL_AGENTS=()
while IFS= read -r f; do
  ALL_AGENTS+=("$(basename "$f" .md)")
done < <(find "$AGENTS_SRC" -maxdepth 1 -name "*.md" | sort)

ALL_SKILLS=()
while IFS= read -r d; do
  ALL_SKILLS+=("$(basename "$d")")
done < <(find "$SKILLS_SRC" -maxdepth 1 -mindepth 1 -type d | sort)

[[ ${#ALL_AGENTS[@]} -gt 0 ]] || die "No agents found in $AGENTS_SRC"
[[ ${#ALL_SKILLS[@]} -gt 0 ]] || die "No skills found in $SKILLS_SRC"

# ── Interactive pickers ───────────────────────────────────────────────────────
pick_with_fzf() {
  local label="$1"; shift
  local result
  result=$(printf '%s\n' "$@" \
    | fzf --multi --height=50% --border --reverse \
          --bind "space:toggle+down,ctrl-a:select-all" \
          --prompt="$label > " \
          --header="SPACE = select/deselect  |  ENTER = confirm  |  CTRL-A = select all") || true
  if [[ -z "$result" ]]; then
    printf '%s,' "$@" | sed 's/,$//'
  else
    echo "$result" | tr '\n' ',' | sed 's/,$//'
  fi
}

pick_with_prompt() {
  local label="$1"; shift
  local items=("$@")
  {
    echo ""
    echo -e "${BOLD}Available $label:${RESET}"
    for i in "${!items[@]}"; do
      printf "  %2d) %s\n" "$((i+1))" "${items[$i]}"
    done
    echo ""
  } >&2
  local selection
  read -r -p "Numbers (space-separated) or 'all' [all]: " selection
  if [[ -z "$selection" || "$selection" == "all" ]]; then
    printf '%s,' "${items[@]}" | sed 's/,$//'
  else
    local result=""
    for n in $selection; do
      local idx=$((n-1))
      if [[ $idx -ge 0 && $idx -lt ${#items[@]} ]]; then
        result+="${items[$idx]},"
      else
        warn "Invalid number $n — skipped"
      fi
    done
    echo "${result%,}"
  fi
}

pick() {
  local label="$1"; shift
  if command -v fzf &>/dev/null; then
    pick_with_fzf "$label" "$@"
  else
    warn "fzf not found — using numbered prompt (brew install fzf for a better experience)"
    pick_with_prompt "$label" "$@"
  fi
}

# ── Single-choice picker (git workflow wizard) ────────────────────────────────
ask_choice() {
  local question="$1"; shift
  local options=("$@")
  local result

  if command -v fzf &>/dev/null; then
    result=$(printf '%s\n' "${options[@]}" \
      | fzf --height=40% --border --reverse \
            --prompt="$question > " \
            --header="ENTER = confirm") || true
  else
    {
      echo ""
      echo -e "${BOLD}$question${RESET}"
      local i
      for i in "${!options[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${options[$i]}"
      done
    } >&2
    local sel
    read -r -p "Choice [1) ${options[0]}]: " sel
    if [[ -z "$sel" ]]; then
      result="${options[0]}"
    elif [[ "$sel" =~ ^[0-9]+$ && $((sel-1)) -ge 0 && $((sel-1)) -lt ${#options[@]} ]]; then
      result="${options[$((sel-1))]}"
    else
      warn "Invalid choice — defaulting to '${options[0]}'"
      result="${options[0]}"
    fi
  fi

  [[ -z "$result" ]] && result="${options[0]}"
  echo "$result"
}

# --no-confirm: skip pickers and default to everything
if $NO_CONFIRM; then
  [[ -z "$SELECTED_AGENTS" ]] && SELECTED_AGENTS="all"
  [[ -z "$SELECTED_SKILLS" ]] && SELECTED_SKILLS="all"
else
  [[ -z "$SELECTED_AGENTS" ]] && SELECTED_AGENTS=$(pick "Agents" "${ALL_AGENTS[@]}")
  [[ -z "$SELECTED_SKILLS" ]] && SELECTED_SKILLS=$(pick "Skills" "${ALL_SKILLS[@]}")
fi

# ── Git workflow ───────────────────────────────────────────────────────────────
# Answers become the "## 4. Git Workflow" section of AGENTS.md — see render_git_workflow_policy().
# Meaningless for --uninstall (it deletes AGENTS.md outright, doesn't care about its content).
#
# Interactively, this always leads with one question offering the non-invasive default as a single
# named choice, "no git" as another, and "Custom..." to drop into the full five-question breakdown —
# rather than asking five separate questions up front. Explicit --use-git/--auto-commit/--use-mrs/
# --create-mrs/--push-direct flags always win and skip whichever question they answer;
# passing any of them skips the leading question entirely (the CLI is itself "custom" already).
# --git-wizard jumps straight to the five-question breakdown, skipping the leading question.
ask_git_workflow_details() {
  [[ -z "$GIT_USE" ]] && GIT_USE=$(ask_choice \
    "Does the agent work with git in this project?" "yes" "no")

  if [[ "$GIT_USE" == "yes" ]]; then
    [[ -z "$GIT_AUTOCOMMIT" ]] && GIT_AUTOCOMMIT=$(ask_choice \
      "Commit its own completed work automatically, without asking?" "yes" "no")
    [[ -z "$GIT_USE_MRS" ]] && GIT_USE_MRS=$(ask_choice \
      "Work via feature branch + merge/pull request, instead of the current branch directly?" "no" "yes")
    if [[ "$GIT_USE_MRS" == "yes" ]]; then
      [[ -z "$GIT_CREATE_MRS" ]] && GIT_CREATE_MRS=$(ask_choice \
        "Open the merge/pull request itself (e.g. gh/glab), not just push the branch?" "no" "yes")
    else
      GIT_CREATE_MRS="no"
    fi
    [[ -z "$GIT_PUSH_DIRECT" ]] && GIT_PUSH_DIRECT=$(ask_choice \
      "Allow direct pushes to the main/trunk branch?" "no" "yes")
  else
    GIT_AUTOCOMMIT="no"; GIT_USE_MRS="no"; GIT_CREATE_MRS="no"; GIT_PUSH_DIRECT="no"
  fi
}

if ! $UNINSTALL; then
  flags_preset=false
  [[ -n "$GIT_USE$GIT_AUTOCOMMIT$GIT_USE_MRS$GIT_CREATE_MRS$GIT_PUSH_DIRECT" ]] && flags_preset=true

  if $NO_CONFIRM || $flags_preset; then
    : # no prompting — fall through to the defaults below for whatever's still unset
  elif $GIT_WIZARD; then
    ask_git_workflow_details
  else
    OPT_DEFAULT="Commit automatically, no push or MRs (recommended)"
    OPT_NOGIT="No git"
    OPT_CUSTOM="Custom..."
    workflow_choice=$(ask_choice "How should the agent handle git in this project?" \
      "$OPT_DEFAULT" "$OPT_NOGIT" "$OPT_CUSTOM")
    case "$workflow_choice" in
      "$OPT_NOGIT")
        GIT_USE="no"; GIT_AUTOCOMMIT="no"; GIT_USE_MRS="no"; GIT_CREATE_MRS="no"; GIT_PUSH_DIRECT="no" ;;
      "$OPT_CUSTOM")
        ask_git_workflow_details ;;
      *)
        GIT_USE="yes"; GIT_AUTOCOMMIT="yes"; GIT_USE_MRS="no"; GIT_CREATE_MRS="no"; GIT_PUSH_DIRECT="no" ;;
    esac
  fi

  [[ -z "$GIT_USE" ]]          && GIT_USE="yes"
  [[ -z "$GIT_AUTOCOMMIT" ]]   && GIT_AUTOCOMMIT="yes"
  [[ -z "$GIT_USE_MRS" ]]      && GIT_USE_MRS="no"
  [[ -z "$GIT_CREATE_MRS" ]]   && GIT_CREATE_MRS="no"
  [[ -z "$GIT_PUSH_DIRECT" ]]  && GIT_PUSH_DIRECT="no"
fi

# Renders the "## 4. Git Workflow" bullet list from the wizard answers above.
render_git_workflow_policy() {
  if [[ "$GIT_USE" != "yes" ]]; then
    echo "- This project's workflow does not involve git — do not run git commands or create commits."
    return
  fi

  if [[ "$GIT_AUTOCOMMIT" == "yes" ]]; then
    echo "- After a full implementation cycle (feature code + passing tests), commit automatically — no need to ask."
    echo "- Only after tests pass — never commit a broken state."
    echo "- Write a meaningful commit message: imperative mood, concise subject line, body if the why needs explaining."
    echo "- Stage only the files relevant to the feature — never \`git add .\` blindly."
  else
    echo "- Always ask before committing — do not commit automatically, even after a completed feature cycle."
  fi

  if [[ "$GIT_USE_MRS" == "yes" ]]; then
    echo "- Work on a feature branch, not directly on the main/trunk branch."
    if [[ "$GIT_CREATE_MRS" == "yes" ]]; then
      echo "- Once the branch is pushed and ready for review, open the merge/pull request yourself (e.g. \`gh pr create\` / \`glab mr create\`)."
    else
      echo "- Push the feature branch, but leave opening the merge/pull request to the user."
    fi
  else
    echo "- Do not use a branch + merge/pull-request workflow — work directly on the current branch."
  fi

  if [[ "$GIT_PUSH_DIRECT" == "yes" ]]; then
    echo "- Direct pushes to the main/trunk branch are allowed when appropriate."
  else
    echo "- Never push directly to the main/trunk branch."
  fi
}

# One-line summary shown in the install plan.
git_workflow_summary() {
  if [[ "$GIT_USE" != "yes" ]]; then
    echo "no git"
    return
  fi
  local parts=()
  [[ "$GIT_AUTOCOMMIT" == "yes" ]] && parts+=("auto-commit") || parts+=("ask before commit")
  if [[ "$GIT_USE_MRS" == "yes" ]]; then
    [[ "$GIT_CREATE_MRS" == "yes" ]] && parts+=("opens MRs itself") || parts+=("pushes branch (no MR)")
  else
    parts+=("no branch/MR workflow")
  fi
  [[ "$GIT_PUSH_DIRECT" == "yes" ]] && parts+=("direct push to main allowed") || parts+=("no direct push to main")

  local out="" p
  for p in "${parts[@]}"; do
    [[ -z "$out" ]] && out="$p" || out="$out, $p"
  done
  echo "$out"
}

# ── Resolve selection strings to arrays ──────────────────────────────────────
resolve() {
  local selection="$1"; shift
  local all=("$@")

  if [[ -z "$selection" || "$selection" == "all" ]]; then
    printf '%s\n' "${all[@]}"
    return
  fi

  while IFS=',' read -ra names; do
    for name in "${names[@]}"; do
      name="${name#"${name%%[![:space:]]*}"}"
      name="${name%"${name##*[![:space:]]}"}"
      [[ -z "$name" ]] && continue
      local found=false
      for item in "${all[@]}"; do
        [[ "$item" == "$name" ]] && { found=true; break; }
      done
      if $found; then echo "$name"
      else warn "Unknown item '$name' — skipped"
      fi
    done
  done <<< "$selection"
}

AGENTS_TO_INSTALL=()
while IFS= read -r a; do [[ -n "$a" ]] && AGENTS_TO_INSTALL+=("$a"); done \
  < <(resolve "$SELECTED_AGENTS" "${ALL_AGENTS[@]}")

SKILLS_TO_INSTALL=()
while IFS= read -r s; do [[ -n "$s" ]] && SKILLS_TO_INSTALL+=("$s"); done \
  < <(resolve "$SELECTED_SKILLS" "${ALL_SKILLS[@]}")

[[ ${#AGENTS_TO_INSTALL[@]} -gt 0 || ${#SKILLS_TO_INSTALL[@]} -gt 0 ]] \
  || die "Nothing selected — exiting"

# ── OpenCode agent frontmatter transform ─────────────────────────────────────
# Renders an OpenCode-format agent file from a Claude Code source file. OpenCode's schema
# has no equivalent for name/model/memory/skills, so those are dropped: the filename is the
# agent identifier, and model is intentionally left unset so the agent inherits whatever
# provider/model is configured in OpenCode rather than assuming Anthropic. tools: Read/Write/
# Edit/etc maps to permission.edit (deny for reviewer agents with no Write/Edit). permissions.
# allow Bash(cmd:*) patterns map to permission.bash entries, with "*": ask as the catch-all —
# the same "only these are pre-approved" intent as the Claude Code source.
render_opencode_agent() {
  local src="$1"
  local desc tools body esc_desc

  desc=$(sed -n 's/^description: //p' "$src" | head -1)
  esc_desc=$(printf '%s' "$desc" | sed 's/"/\\"/g')
  tools=$(sed -n 's/^tools: //p' "$src" | head -1)
  body=$(awk '/^---$/{c++; next} c>=2' "$src")

  local can_edit=true
  [[ "$tools" == *Write* || "$tools" == *Edit* ]] || can_edit=false

  local -a bash_patterns=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && bash_patterns+=("$p")
  done < <(sed -n 's/^    - "Bash(\(.*\))"$/\1/p' "$src")

  echo "---"
  echo "description: \"$esc_desc\""
  echo "mode: subagent"
  if [[ ${#bash_patterns[@]} -gt 0 ]]; then
    echo "permission:"
    $can_edit || echo "  edit: deny"
    echo "  bash:"
    echo "    \"*\": ask"
    for p in "${bash_patterns[@]}"; do
      local ocp="$p"
      [[ "$p" == *:\* ]] && ocp="${p%:\*}*"
      echo "    \"$ocp\": allow"
    done
  elif ! $can_edit; then
    echo "permission:"
    echo "  edit: deny"
  fi
  echo "---"
  echo "$body"
}

write_opencode_agent() {
  local src="$1" dest="$2"
  if $DRY_RUN; then
    echo -e "${YELLOW}[dry]${RESET}   render OpenCode agent '$(basename "$dest")' -> '$dest'"
  else
    render_opencode_agent "$src" > "$dest"
  fi
}

# Writes AGENTS.md with the "<!-- GIT_WORKFLOW_POLICY -->" marker replaced by the wizard's answers.
write_agents_md() {
  local dest="$1"
  if $DRY_RUN; then
    echo -e "${YELLOW}[dry]${RESET}   render AGENTS.md (git workflow: $(git_workflow_summary)) -> '$dest'"
    return
  fi
  local marker_line
  marker_line=$(grep -n '<!-- GIT_WORKFLOW_POLICY -->' "$AGENTS_MD_SRC" | head -1 | cut -d: -f1)
  if [[ -z "$marker_line" ]]; then
    cp "$AGENTS_MD_SRC" "$dest"
    return
  fi
  {
    head -n $((marker_line - 1)) "$AGENTS_MD_SRC"
    render_git_workflow_policy
    tail -n +$((marker_line + 1)) "$AGENTS_MD_SRC"
  } > "$dest"
}

# ── Destination status check ──────────────────────────────────────────────────
dest_status() {
  if   [[ -L "$1" ]]; then echo "overwrite-symlink"
  elif [[ -d "$1" ]]; then echo "overwrite-dir"
  elif [[ -f "$1" ]]; then echo "overwrite-file"
  else                      echo "new"
  fi
}

# ── Backup ────────────────────────────────────────────────────────────────────
backup_item() {
  local dest="$1"
  $NO_BACKUP && return 0
  [[ -e "$dest" || -L "$dest" ]] || return 0   # nothing to back up

  if ! $BACKUP_USED; then
    run "mkdir -p '$BACKUP_DIR'"
    BACKUP_USED=true
  fi

  local name; name="$(basename "$dest")"
  if [[ -d "$dest" && ! -L "$dest" ]]; then
    run "cp -r '$dest' '$BACKUP_DIR/$name'"
  else
    run "cp -P '$dest' '$BACKUP_DIR/$name'"
  fi
}

# ── Plan display ──────────────────────────────────────────────────────────────
print_plan_row() {
  local verb="$1" name="$2" status="$3"
  local prefix note=""

  if [[ "$verb" == "Uninstall" ]]; then
    case "$status" in
      new) prefix="${DIM}-${RESET}"; note="${DIM}(not installed — will skip)${RESET}" ;;
      *)   prefix="${RED}-${RESET}" ;;
    esac
  else
    case "$status" in
      new)               prefix="${GREEN}+${RESET}"; note="${DIM}new${RESET}" ;;
      overwrite-symlink) prefix="${YELLOW}~${RESET}"; note="${YELLOW}overwrites symlink${RESET}" ;;
      overwrite-file)    prefix="${RED}~${RESET}";    note="${RED}overwrites file${RESET}" ;;
      overwrite-dir)     prefix="${RED}~${RESET}";    note="${RED}overwrites directory${RESET}" ;;
    esac
    # Annotate overwrites that will be backed up
    if [[ "$status" != "new" ]] && ! $NO_BACKUP; then
      note="$note ${DIM}→ backup${RESET}"
    fi
  fi

  printf "  %b  %-35s %b\n" "$prefix" "$name" "$note"
}

print_plan() {
  local verb="$1"

  echo ""
  echo -e "${BOLD}$verb plan${RESET}  →  $PWD  ${DIM}(tool: $TOOL)${RESET}"
  echo ""

  echo -e "  ${BOLD}Config${RESET}"
  echo    "  ──────────────────────────────────────────────────"
  print_plan_row "$verb" "AGENTS.md" "$(dest_status "$AGENTS_MD_DEST")"
  tool_active claude && print_plan_row "$verb" ".claude/CLAUDE.md" "$(dest_status "$CLAUDE_MD_DEST")"
  [[ "$verb" == "Install" ]] && echo -e "     ${DIM}Git workflow: $(git_workflow_summary)${RESET}"
  echo ""

  if [[ ${#AGENTS_TO_INSTALL[@]} -gt 0 ]]; then
    if tool_active claude; then
      echo -e "  ${BOLD}Agents — Claude Code${RESET}"
      echo    "  ──────────────────────────────────────────────────"
      for agent in "${AGENTS_TO_INSTALL[@]}"; do
        print_plan_row "$verb" "$agent" "$(dest_status "$CLAUDE_AGENTS_DEST/${agent}.md")"
      done
      echo ""
    fi
    if tool_active opencode; then
      echo -e "  ${BOLD}Agents — OpenCode${RESET}"
      echo    "  ──────────────────────────────────────────────────"
      for agent in "${AGENTS_TO_INSTALL[@]}"; do
        print_plan_row "$verb" "$agent" "$(dest_status "$OPENCODE_AGENTS_DEST/${agent}.md")"
      done
      echo ""
    fi
  fi

  if [[ ${#SKILLS_TO_INSTALL[@]} -gt 0 ]]; then
    echo -e "  ${BOLD}Skills${RESET} ${DIM}(.claude/skills/ — also read by OpenCode)${RESET}"
    echo    "  ──────────────────────────────────────────────────"
    for skill in "${SKILLS_TO_INSTALL[@]}"; do
      print_plan_row "$verb" "$skill" "$(dest_status "$CLAUDE_SKILLS_DEST/$skill")"
    done
    echo ""
  fi
}

# ── Confirm prompt ────────────────────────────────────────────────────────────
confirm() {
  $DRY_RUN && return 0
  echo -n "Proceed? [Y/n] "
  read -r answer
  [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  echo ""
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
if $UNINSTALL; then
  if ! $NO_CONFIRM; then
    print_plan "Uninstall"
    confirm
  fi

  if [[ -e "$AGENTS_MD_DEST" || -L "$AGENTS_MD_DEST" ]]; then
    run "rm -f '$AGENTS_MD_DEST'"; ok "Removed: AGENTS.md"
  else
    warn "Not found — skipped: AGENTS.md"
  fi

  if tool_active claude; then
    if [[ -e "$CLAUDE_MD_DEST" || -L "$CLAUDE_MD_DEST" ]]; then
      run "rm -f '$CLAUDE_MD_DEST'"; ok "Removed: .claude/CLAUDE.md"
    else
      warn "Not found — skipped: .claude/CLAUDE.md"
    fi
    for agent in "${AGENTS_TO_INSTALL[@]}"; do
      local_target="$CLAUDE_AGENTS_DEST/${agent}.md"
      if [[ -e "$local_target" || -L "$local_target" ]]; then
        run "rm -f '$local_target'"; ok "Removed Claude Code agent: $agent"
      else
        warn "Not found — skipped: .claude/agents/$agent.md"
      fi
    done
  fi

  if tool_active opencode; then
    for agent in "${AGENTS_TO_INSTALL[@]}"; do
      local_target="$OPENCODE_AGENTS_DEST/${agent}.md"
      if [[ -e "$local_target" || -L "$local_target" ]]; then
        run "rm -f '$local_target'"; ok "Removed OpenCode agent: $agent"
      else
        warn "Not found — skipped: .opencode/agents/$agent.md"
      fi
    done
  fi

  for skill in "${SKILLS_TO_INSTALL[@]}"; do
    local_target="$CLAUDE_SKILLS_DEST/$skill"
    if [[ -e "$local_target" || -L "$local_target" ]]; then
      run "rm -rf '$local_target'"; ok "Removed skill: $skill"
    else
      warn "Not found — skipped: $skill"
    fi
  done
  echo ""; info "Done."
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
if ! $NO_CONFIRM; then
  print_plan "Install"
  $DRY_RUN && warn "Dry-run — no changes will be made."
  confirm
fi

tool_active claude   && run "mkdir -p '$CLAUDE_AGENTS_DEST'"
tool_active opencode && run "mkdir -p '$OPENCODE_AGENTS_DEST'"
[[ ${#SKILLS_TO_INSTALL[@]} -gt 0 ]] && run "mkdir -p '$CLAUDE_SKILLS_DEST'"

[[ -f "$AGENTS_MD_SRC" ]] || die "AGENTS.md not found at $AGENTS_MD_SRC"
backup_item "$AGENTS_MD_DEST"
write_agents_md "$AGENTS_MD_DEST"
ok "Config: AGENTS.md (git workflow: $(git_workflow_summary))"

if tool_active claude; then
  backup_item "$CLAUDE_MD_DEST"
  run "printf '@AGENTS.md\n' > '$CLAUDE_MD_DEST'"
  ok "Config: .claude/CLAUDE.md (imports AGENTS.md)"
fi

for agent in "${AGENTS_TO_INSTALL[@]}"; do
  src="$AGENTS_SRC/${agent}.md"
  [[ -f "$src" ]] || { warn "Source not found — skipped: $src"; continue; }

  if tool_active claude; then
    dest="$CLAUDE_AGENTS_DEST/${agent}.md"
    backup_item "$dest"
    run "cp '$src' '$dest'"
    ok "Claude Code agent: $agent"
  fi

  if tool_active opencode; then
    dest="$OPENCODE_AGENTS_DEST/${agent}.md"
    backup_item "$dest"
    write_opencode_agent "$src" "$dest"
    ok "OpenCode agent: $agent"
  fi
done

for skill in "${SKILLS_TO_INSTALL[@]}"; do
  src="$SKILLS_SRC/$skill"; dest="$CLAUDE_SKILLS_DEST/$skill"
  [[ -d "$src" ]] || { warn "Source not found — skipped: $src"; continue; }
  backup_item "$dest"
  run "cp -r '$src' '$dest'"
  ok "Skill: $skill"
done

echo ""
info "Done. AGENTS.md + ${#AGENTS_TO_INSTALL[@]} agent(s) + ${#SKILLS_TO_INSTALL[@]} skill(s) installed into $PWD (tool: $TOOL)"
$BACKUP_USED && info "Backup saved to $BACKUP_DIR"
exit 0
