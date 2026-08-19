# Backup-before-overwrite and the "here's what will happen" plan rendered before confirm().

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
