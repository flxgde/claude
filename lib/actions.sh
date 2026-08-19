# The actual file-writing/removal phases, run once all wizard questions are resolved and the
# plan has been confirmed. Each of run_install/run_uninstall exits the process itself.

# Union of "agents being installed this run" and "agent files already present in the destination
# directories from a prior install" — the set AGENTS.md's dynamic content (dispatch table, Project
# Defaults) is rendered against. This union matters because a plain re-install with a narrower
# -a/-s selection never deletes agents from a prior run (only --uninstall does): without it, an
# additive install (e.g. adding Angular to an already-installed Spring Boot project) would make
# AGENTS.md silently drop the Spring Boot dispatch row even though spring-boot-engineer.md is still
# sitting in .claude/agents/. Scans both tool dest dirs regardless of --tool, since AGENTS.md is a
# shared, tool-agnostic description of "agents available in this project."
compute_effective_agents() {
  EFFECTIVE_AGENTS=()
  if [[ ${#AGENTS_TO_INSTALL[@]} -gt 0 ]]; then
    EFFECTIVE_AGENTS=("${AGENTS_TO_INSTALL[@]}")
  fi
  local dest f
  for dest in "$CLAUDE_AGENTS_DEST" "$OPENCODE_AGENTS_DEST"; do
    [[ -d "$dest" ]] || continue
    while IFS= read -r f; do
      EFFECTIVE_AGENTS+=("$(basename "$f" .md)")
    done < <(find "$dest" -maxdepth 1 -name "*.md" 2>/dev/null)
  done
  EFFECTIVE_AGENTS=($(printf '%s\n' "${EFFECTIVE_AGENTS[@]-}" | awk 'NF && !seen[$0]++'))
  return 0
}

_agent_in_effective_set() {
  [[ ${#EFFECTIVE_AGENTS[@]} -eq 0 ]] && return 1
  local name a
  for name in "$@"; do
    for a in "${EFFECTIVE_AGENTS[@]}"; do
      [[ "$a" == "$name" ]] && return 0
    done
  done
  return 1
}

# Renders dist/AGENTS.md against EFFECTIVE_AGENTS/EFFECTIVE_PRACTICES. Two independent marker
# conventions coexist:
#   <!-- GIT_WORKFLOW_POLICY -->                          — single-line marker, replaced wholesale
#                                                            by render_git_workflow_policy()'s
#                                                            output (this content is *generated*
#                                                            from five settings, not simply
#                                                            included/excluded).
#   <!-- IF_AGENT:a,b / IF_PRACTICE:a,b --> ... <!-- END_IF -->
#                                                          — a block of already-written markdown
#                                                            that survives only if at least one of
#                                                            the named agents/practices is
#                                                            selected; marker lines are always
#                                                            stripped. Blocks DO nest (e.g. the
#                                                            per-agent dispatch-table rows sit
#                                                            inside the whole "Sub-agents" section,
#                                                            which is itself an IF_PRACTICE block) —
#                                                            tracked with a plain string stack (one
#                                                            "0"/"1" character per open block, most
#                                                            recent on the right) rather than an
#                                                            array, sidestepping bash 3.2's
#                                                            empty-named-array crash entirely for
#                                                            this piece of state. A line is skipped
#                                                            if ANY enclosing block is skipping,
#                                                            i.e. the stack contains a "1" anywhere.
# This is why AGENTS.md never references an agent (or describes stack-specific conventions for
# one) that isn't actually part of the project, and never includes a practice section the install
# deselected.
render_agents_md() {
  local skip_stack="" line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "<!-- GIT_WORKFLOW_POLICY -->" ]]; then
      [[ "$skip_stack" == *1* ]] || render_git_workflow_policy
      continue
    fi
    if [[ "$line" =~ ^\<!--\ IF_(AGENT|PRACTICE):([a-zA-Z0-9_,-]+)\ --\>$ ]]; then
      local kind="${BASH_REMATCH[1]}" names_arr satisfied=false
      IFS=',' read -ra names_arr <<< "${BASH_REMATCH[2]}"
      if [[ "$kind" == "AGENT" ]]; then
        _agent_in_effective_set "${names_arr[@]}" && satisfied=true
      else
        _practice_selected "${names_arr[@]}" && satisfied=true
      fi
      if $satisfied; then skip_stack="${skip_stack}0"; else skip_stack="${skip_stack}1"; fi
      continue
    fi
    if [[ "$line" == "<!-- END_IF -->" ]]; then
      skip_stack="${skip_stack%?}"
      continue
    fi
    [[ "$skip_stack" == *1* ]] || printf '%s\n' "$line"
  done < "$AGENTS_MD_SRC"
  return 0
}

write_agents_md() {
  local dest="$1"
  compute_effective_agents
  build_effective_practices
  if $DRY_RUN; then
    echo -e "${YELLOW}[dry]${RESET}   render AGENTS.md (git workflow: $(git_workflow_summary), agents: ${#EFFECTIVE_AGENTS[@]}, practices: ${#EFFECTIVE_PRACTICES[@]}) -> '$dest'"
    return
  fi
  render_agents_md > "$dest"
}

# .claude/CLAUDE.md must never clobber pre-existing project content that predates this installer
# (e.g. a hand-written root CLAUDE.md's sibling, or a .claude/CLAUDE.md someone already authored by
# hand) — only a genuinely empty/missing file gets the plain one-line "@AGENTS.md" import. A
# non-empty file that doesn't already import AGENTS.md gets the import line appended, preserving
# everything already there; a file that already imports it is left alone entirely (re-running the
# installer must not append a second copy of the same import line).
write_claude_md_import() {
  local dest="$1"
  if [[ -s "$dest" ]]; then
    if grep -qF '@AGENTS.md' "$dest"; then
      ok "Config: .claude/CLAUDE.md (already imports AGENTS.md — left untouched)"
    else
      run "printf '\n@AGENTS.md\n' >> '$dest'"
      ok "Config: .claude/CLAUDE.md (existing content preserved, appended @AGENTS.md import)"
    fi
  else
    run "printf '@AGENTS.md\n' > '$dest'"
    ok "Config: .claude/CLAUDE.md (imports AGENTS.md)"
  fi
  return 0
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
run_uninstall() {
  if ! $NO_CONFIRM; then
    while true; do
      step "$STEP_IDX_REVIEW" "${WIZARD_STEPS[$STEP_IDX_REVIEW]}"
      print_plan "Uninstall"
      confirm
      if $WIZARD_BACK; then
        rerun_wizard_from_git
        build_install_arrays
        compute_total_ops
        continue
      fi
      break
    done
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
    if [[ ${#AGENTS_TO_INSTALL[@]} -gt 0 ]]; then
      for agent in "${AGENTS_TO_INSTALL[@]}"; do
        local_target="$CLAUDE_AGENTS_DEST/${agent}.md"
        if [[ -e "$local_target" || -L "$local_target" ]]; then
          run "rm -f '$local_target'"; ok "Removed Claude Code agent: $agent"
        else
          warn "Not found — skipped: .claude/agents/$agent.md"
        fi
      done
    fi
  fi

  if tool_active opencode && [[ ${#AGENTS_TO_INSTALL[@]} -gt 0 ]]; then
    for agent in "${AGENTS_TO_INSTALL[@]}"; do
      local_target="$OPENCODE_AGENTS_DEST/${agent}.md"
      if [[ -e "$local_target" || -L "$local_target" ]]; then
        run "rm -f '$local_target'"; ok "Removed OpenCode agent: $agent"
      else
        warn "Not found — skipped: .opencode/agents/$agent.md"
      fi
    done
  fi

  if [[ ${#SKILLS_TO_INSTALL[@]} -gt 0 ]]; then
    for skill in "${SKILLS_TO_INSTALL[@]}"; do
      local_target="$CLAUDE_SKILLS_DEST/$skill"
      if [[ -e "$local_target" || -L "$local_target" ]]; then
        run "rm -rf '$local_target'"; ok "Removed skill: $skill"
      else
        warn "Not found — skipped: $skill"
      fi
    done
  fi
  echo ""; info "Done."
  exit 0
}

# ── Install ───────────────────────────────────────────────────────────────────
run_install() {
  if ! $NO_CONFIRM; then
    while true; do
      step "$STEP_IDX_REVIEW" "${WIZARD_STEPS[$STEP_IDX_REVIEW]}"
      print_plan "Install"
      $DRY_RUN && warn "Dry-run — no changes will be made."
      confirm
      if $WIZARD_BACK; then
        rerun_wizard_from_git
        build_install_arrays
        compute_total_ops
        continue
      fi
      break
    done
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
    write_claude_md_import "$CLAUDE_MD_DEST"
  fi

  if [[ ${#AGENTS_TO_INSTALL[@]} -gt 0 ]]; then
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
  fi

  if [[ ${#SKILLS_TO_INSTALL[@]} -gt 0 ]]; then
    for skill in "${SKILLS_TO_INSTALL[@]}"; do
      src="$SKILLS_SRC/$skill"; dest="$CLAUDE_SKILLS_DEST/$skill"
      [[ -d "$src" ]] || { warn "Source not found — skipped: $src"; continue; }
      backup_item "$dest"
      run "cp -r '$src' '$dest'"
      ok "Skill: $skill"
    done
  fi

  echo ""
  info "Done. AGENTS.md + ${#AGENTS_TO_INSTALL[@]} agent(s) + ${#SKILLS_TO_INSTALL[@]} skill(s) installed into $PWD (tool: $TOOL)"
  $BACKUP_USED && info "Backup saved to $BACKUP_DIR"
  exit 0
}
