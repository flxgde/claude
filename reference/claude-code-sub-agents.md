# Claude Code — Custom Sub-Agents Reference

Source: https://code.claude.com/docs/en/sub-agents
Fetched: 2026-03-25

## File location

| Scope | Path | Priority |
|---|---|---|
| Session only | `--agents` CLI flag (JSON) | 1 (highest) |
| Project | `.claude/agents/` | 2 |
| User (global) | `~/.claude/agents/` | 3 |
| Plugin | plugin's `agents/` dir | 4 (lowest) |

## File format

```markdown
---
name: agent-name           # required, lowercase + hyphens
description: When Claude should delegate to this agent  # required
tools: Read, Glob, Grep, Bash, Write, Edit   # optional allowlist
disallowedTools: Write, Edit                  # optional denylist
model: haiku | sonnet | opus | inherit | <full-model-id>  # default: inherit
permissionMode: default | acceptEdits | dontAsk | bypassPermissions | plan
maxTurns: 20               # optional
memory: user | project | local  # enables persistent memory directory
background: true           # always run as background task
effort: low | medium | high | max  # overrides session effort
isolation: worktree        # run in isolated git worktree
skills:
  - skill-name             # preloaded skill content
mcpServers:
  - server-name            # reference or inline definition
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---

System prompt goes here in Markdown.
```

## Invocation

- **Automatic**: Claude delegates based on the `description` field
- **@-mention**: `@"agent-name (agent)"` — guarantees the agent runs
- **Natural language**: "Use the spring-boot-engineer agent to..."
- **Session-wide**: `claude --agent agent-name`

## Memory scopes

| Scope | Location |
|---|---|
| `user` | `~/.claude/agent-memory/<name>/` |
| `project` | `.claude/agent-memory/<name>/` |
| `local` | `.claude/agent-memory-local/<name>/` |

When `memory` is set, the agent gets Read/Write/Edit automatically and a MEMORY.md is loaded into context.

## Key constraints

- Subagents **cannot spawn other subagents**
- Background subagents cannot ask clarifying questions (AskUserQuestion fails silently)
- Agents are loaded at **session start** — restart or use `/agents` to load new files
- `bypassPermissions` parent mode overrides subagent permissionMode

## Model aliases

- `haiku` → claude-haiku-4-5-20251001 (fast, cheap)
- `sonnet` → claude-sonnet-4-6
- `opus` → claude-opus-4-6
- `inherit` → same model as main session (default)
