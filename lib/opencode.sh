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
