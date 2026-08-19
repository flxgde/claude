#!/usr/bin/env bash
# Install Claude Code and/or OpenCode agents, skills, and rules into the current project.
# Always project-local — installing globally into ~/.claude or ~/.config/opencode is not supported.
#
# Source of truth lives in dist/ (agents, skills, AGENTS.md) and is authored once, in Claude
# Code's frontmatter dialect. --tool opencode renders OpenCode-format agent files on the fly;
# skills need no translation — OpenCode reads .claude/skills/ directly, same spec Claude Code uses.
#
# This file is just the entrypoint: argument parsing and the top-level install/uninstall flow.
# The implementation is split across lib/*.sh (sourced below) — pickers, the git-workflow wizard,
# the OpenCode frontmatter transform, plan/backup rendering, and the install/uninstall actions
# each get their own file. Keep this file to orchestration only; put real logic in lib/.
#
# Run from the repo:
#   ./install.sh
#
# One-shot from the web:
#   bash <(curl -fsSL https://raw.githubusercontent.com/flxgde/claude/main/install.sh)
#   curl -fsSL https://raw.githubusercontent.com/flxgde/claude/main/install.sh | bash
# Both of these fetch this file only; it then downloads and extracts the whole repo (including
# lib/) into a tempdir before sourcing anything, so the lib/ split works the same way whether
# run from a checkout or standalone — see "Locate assets" below.
#
# All three are interactive. Use --no-confirm to skip all prompts and install silently.
set -euo pipefail

GITHUB_REPO="flxgde/claude"
GITHUB_BRANCH="main"
GITHUB_ARCHIVE="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"

# ── Locate assets ─────────────────────────────────────────────────────────────
# BASH_SOURCE is empty (zero elements, not just an empty string) when this script arrives via a
# pipe rather than a real file — exactly the `curl -fsSL ... | bash` invocation form documented
# above. Bare-expanding BASH_SOURCE[0] in that case is the same bash-3.2-style "unbound variable
# under set -u" trap as the empty-named-array gotcha elsewhere in this codebase (see CLAUDE.md):
# it doesn't stop the script (the fallback below still ends up correct by the time it's done), but
# it does leak a scary "unbound variable" error to the terminal on every piped run. Check the
# array length first, same fix pattern as everywhere else this gotcha shows up.
if [[ ${#BASH_SOURCE[@]} -gt 0 ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
else
  SCRIPT_DIR=""
fi
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

# ── Load library modules ──────────────────────────────────────────────────────
# ui.sh first — it defines die()/warn(), used by the sanity check for the rest.
LIB_DIR="$REPO_ROOT/lib"
[[ -f "$LIB_DIR/ui.sh" ]] || { echo "[error] Missing $LIB_DIR/ui.sh — corrupted install/download?" >&2; exit 1; }
source "$LIB_DIR/ui.sh"
for lib in usage pickers selection git_workflow auto practices opencode plan actions; do
  [[ -f "$LIB_DIR/$lib.sh" ]] || die "Missing library file: $LIB_DIR/$lib.sh (corrupted install/download?)"
  source "$LIB_DIR/$lib.sh"
done

# lib/detect/*.sh — one file per detection category, discovered the same "glob it, don't register
# it" way as dist/agents/*.md / dist/skills/*/ (see discover_items() in lib/selection.sh). Sourcing
# only defines detect_<name>() functions; nothing scans the filesystem until run_detection()
# (lib/auto.sh) actually calls them.
DETECT_LIB_FILES=()
while IFS= read -r f; do DETECT_LIB_FILES+=("$f"); done \
  < <(find "$LIB_DIR/detect" -maxdepth 1 -name "*.sh" | sort)
[[ ${#DETECT_LIB_FILES[@]} -gt 0 ]] \
  || die "No detection modules found in $LIB_DIR/detect (corrupted install/download?)"
for f in "${DETECT_LIB_FILES[@]}"; do source "$f"; done

# ── Defaults ──────────────────────────────────────────────────────────────────
readonly CLAUDE_DIR="$PWD/.claude"
readonly OPENCODE_DIR="$PWD/.opencode"
TOOL="both"
SELECTED_AGENTS=""
SELECTED_SKILLS=""
SELECTED_PRACTICES=""
GIT_USE=""
GIT_AUTOCOMMIT=""
GIT_USE_MRS=""
GIT_CREATE_MRS=""
GIT_PUSH_DIRECT=""
GIT_WIZARD=false
AUTO_MODE=false
GUIDED_MODE=false
NO_CONFIRM=false
NO_BACKUP=false
DRY_RUN=false
UNINSTALL=false
TOTAL_OPS=0
DONE_OPS=0
# Snapshot of run_detection()'s file-based results, taken once below (install path only) and
# restored by resolve_setup_mode() whenever "Auto" is (re-)picked — see lib/auto.sh. Declared here,
# always as an array (even if never filled, e.g. on the --uninstall path), to avoid the bash 3.2
# "unbound variable on bare-expanding an empty named array" gotcha (see CLAUDE.md).
ORIG_DETECTED_AGENTS=()
ORIG_DETECTED_SKILLS=()
ORIG_DETECTED_NOTES=()

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tool)       TOOL="$2"; shift 2 ;;
    -a|--agents)     SELECTED_AGENTS="$2"; shift 2 ;;
    -s|--skills)     SELECTED_SKILLS="$2"; shift 2 ;;
       --practices)  SELECTED_PRACTICES="$2"; shift 2 ;;
    -A|--auto)       AUTO_MODE=true; shift ;;
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

# Captured once, right after argument parsing, before any wizard step (or a "back" revisit of one)
# can mutate SELECTED_AGENTS/SELECTED_SKILLS/SELECTED_PRACTICES/GIT_*. Every resolve_*() step checks
# these — not the live variables, which its own picker also writes to — to tell "the CLI pinned
# this permanently" apart from "this step already answered it once earlier in this same run."
AGENTS_FLAG_PRESET=false;    [[ -n "$SELECTED_AGENTS" ]]    && AGENTS_FLAG_PRESET=true
SKILLS_FLAG_PRESET=false;    [[ -n "$SELECTED_SKILLS" ]]    && SKILLS_FLAG_PRESET=true
PRACTICES_FLAG_PRESET=false; [[ -n "$SELECTED_PRACTICES" ]] && PRACTICES_FLAG_PRESET=true
GIT_USE_PRESET=false;         [[ -n "$GIT_USE" ]]          && GIT_USE_PRESET=true
GIT_AUTOCOMMIT_PRESET=false;  [[ -n "$GIT_AUTOCOMMIT" ]]   && GIT_AUTOCOMMIT_PRESET=true
GIT_USE_MRS_PRESET=false;     [[ -n "$GIT_USE_MRS" ]]      && GIT_USE_MRS_PRESET=true
GIT_CREATE_MRS_PRESET=false;  [[ -n "$GIT_CREATE_MRS" ]]   && GIT_CREATE_MRS_PRESET=true
GIT_PUSH_DIRECT_PRESET=false; [[ -n "$GIT_PUSH_DIRECT" ]]  && GIT_PUSH_DIRECT_PRESET=true
GIT_ANY_FLAG_PRESET=false
if $GIT_USE_PRESET || $GIT_AUTOCOMMIT_PRESET || $GIT_USE_MRS_PRESET \
   || $GIT_CREATE_MRS_PRESET || $GIT_PUSH_DIRECT_PRESET; then
  GIT_ANY_FLAG_PRESET=true
fi

CLAUDE_AGENTS_DEST="$CLAUDE_DIR/agents"
CLAUDE_SKILLS_DEST="$CLAUDE_DIR/skills"
CLAUDE_MD_DEST="$CLAUDE_DIR/CLAUDE.md"
OPENCODE_AGENTS_DEST="$OPENCODE_DIR/agents"
AGENTS_MD_DEST="$PWD/AGENTS.md"
BACKUP_DIR="$CLAUDE_DIR/.backup/$(date +%Y%m%d_%H%M%S)"
BACKUP_USED=false

discover_items

$UNINSTALL && $AUTO_MODE && die "--auto only applies to install, not --uninstall"

# ── Wizard framing ────────────────────────────────────────────────────────────
# STEP_IDX_* index into WIZARD_STEPS for each stage's step() call — computed once here rather
# than hardcoded per-file, since whether the leading "setup mode" step (and, within it, the
# "choose your tech stack" Guided sub-step) exists at all depends on OFFER_SETUP_MODE below, which
# shifts every index after it.
if $UNINSTALL; then
  WIZARD_STEPS=("Choose which agents to remove" "Choose which skills to remove" \
                "Review the plan and confirm")
  STEP_IDX_MODE=-1; STEP_IDX_GUIDED=-1; STEP_IDX_AGENTS=0; STEP_IDX_SKILLS=1; STEP_IDX_PRACTICES=-1
  STEP_IDX_GIT=-1; STEP_IDX_REVIEW=2
  OFFER_SETUP_MODE=false
else
  run_detection
  [[ ${#DETECTED_AGENTS[@]} -gt 0 ]] && ORIG_DETECTED_AGENTS=("${DETECTED_AGENTS[@]}")
  [[ ${#DETECTED_SKILLS[@]} -gt 0 ]] && ORIG_DETECTED_SKILLS=("${DETECTED_SKILLS[@]}")
  [[ ${#DETECTED_NOTES[@]}  -gt 0 ]] && ORIG_DETECTED_NOTES=("${DETECTED_NOTES[@]}")

  if $AUTO_MODE; then
    if [[ -z "$SELECTED_AGENTS" && -z "$SELECTED_SKILLS" \
          && ${#DETECTED_AGENTS[@]} -eq 0 && ${#DETECTED_SKILLS[@]} -eq 0 ]]; then
      die "--auto found nothing recognizable in $PWD to install (no build file, angular.json, Dockerfile, ...) — run without --auto, or pass -a/-s explicitly."
    fi
    apply_detected_selection
    info "Auto-detected setup:"
    print_detected_notes
  fi

  # Offered whenever neither -a nor -s was already given and this isn't --no-confirm/--auto —
  # "Auto" itself only appears as one of the choices inside resolve_setup_mode() when something
  # was actually detected; Guided and Manual are always available regardless of detection.
  OFFER_SETUP_MODE=false
  if ! $NO_CONFIRM && ! $AUTO_MODE && [[ -z "$SELECTED_AGENTS" && -z "$SELECTED_SKILLS" ]]; then
    OFFER_SETUP_MODE=true
  fi

  if $OFFER_SETUP_MODE; then
    WIZARD_STEPS=("Choose a setup mode" "Choose your tech stack" "Choose which agents to install" \
                  "Choose which skills to install" "Choose which best practices to include" \
                  "Decide how the agent should use git in this project" "Review the plan and confirm")
    STEP_IDX_MODE=0; STEP_IDX_GUIDED=1; STEP_IDX_AGENTS=2; STEP_IDX_SKILLS=3; STEP_IDX_PRACTICES=4
    STEP_IDX_GIT=5; STEP_IDX_REVIEW=6
  else
    WIZARD_STEPS=("Choose which agents to install" "Choose which skills to install" \
                  "Choose which best practices to include" \
                  "Decide how the agent should use git in this project" "Review the plan and confirm")
    STEP_IDX_MODE=-1; STEP_IDX_GUIDED=-1; STEP_IDX_AGENTS=0; STEP_IDX_SKILLS=1; STEP_IDX_PRACTICES=2
    STEP_IDX_GIT=3; STEP_IDX_REVIEW=4
  fi
fi
STEP_TOTAL=${#WIZARD_STEPS[@]}

if ! $NO_CONFIRM; then
  print_intro "$($UNINSTALL && echo Uninstall || echo Install)"
fi

run_wizard_steps
build_install_arrays
compute_total_ops

if $UNINSTALL; then
  run_uninstall
else
  run_install
fi
