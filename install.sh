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
warn() { echo -e "${YELLOW}[warn]${RESET}  $*"; }
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
      --no-confirm        Silent install — no pickers, no plan, no prompts
      --no-backup         Skip backup of existing files before overwriting
  -n, --dry-run           Show the plan without making any changes
  -u, --uninstall         Remove installed agents/skills/rules from the project
  -h, --help              Show this help

${BOLD}What goes where:${RESET}
  ./AGENTS.md              Shared rules payload — read natively by OpenCode
  ./.claude/CLAUDE.md       One-line "@AGENTS.md" import — Claude Code only reads CLAUDE.md
  ./.claude/agents/*.md     Claude Code subagents
  ./.claude/skills/<name>/  Skills — also read directly by OpenCode from this same path
  ./.opencode/agents/*.md   OpenCode subagents, rendered from the same dist/agents/ source

  --tool scopes agents and the CLAUDE.md import wrapper. AGENTS.md and skills are shared by
  both tools and are always installed/removed together regardless of --tool.

${BOLD}Examples:${RESET}
  # Interactive — pick, review plan, ENTER to confirm (default, both tools)
  ./install.sh

  # Silent install of everything, OpenCode only
  ./install.sh --tool opencode --no-confirm

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
  echo ""
  echo -e "${BOLD}Available $label:${RESET}"
  for i in "${!items[@]}"; do
    printf "  %2d) %s\n" "$((i+1))" "${items[$i]}"
  done
  echo ""
  echo -n "Numbers (space-separated) or 'all' [all]: "
  read -r selection
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

# --no-confirm: skip pickers and default to everything
if $NO_CONFIRM; then
  [[ -z "$SELECTED_AGENTS" ]] && SELECTED_AGENTS="all"
  [[ -z "$SELECTED_SKILLS" ]] && SELECTED_SKILLS="all"
else
  [[ -z "$SELECTED_AGENTS" ]] && SELECTED_AGENTS=$(pick "Agents" "${ALL_AGENTS[@]}")
  [[ -z "$SELECTED_SKILLS" ]] && SELECTED_SKILLS=$(pick "Skills" "${ALL_SKILLS[@]}")
fi

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
run "cp '$AGENTS_MD_SRC' '$AGENTS_MD_DEST'"
ok "Config: AGENTS.md"

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
