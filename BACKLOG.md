# lobby — Backlog

<!--
AGENT INSTRUCTIONS — READ THIS BEFORE MODIFYING THIS FILE
──────────────────────────────────────────────────────────
This file is the shared backlog for lobby. It is read and written by both
humans and humans and AI agents. Follow these rules exactly.

## Task format

Each task is a level-3 heading followed by a metadata block, a description,
and optional sections. The full schema:

```
### [STATUS] Short imperative title (#ID)

- **ID**: LOBBY-N          (increment from last used ID)
- **Type**: bug | feature | improvement | refactor
- **Priority**: high | medium | low
- **Effort**: small | medium | large
- **Added**: YYYY-MM-DD
- **Updated**: YYYY-MM-DD
- **Author**: name or "agent"

#### Problem / Motivation
Why this needs doing.

#### Proposed Solution
What to build and how.

#### Implementation Notes
Specific code locations, edge cases, decisions already made.

#### Acceptance Criteria
- [ ] Checkable outcomes that define "done"

#### Dependencies
Other tasks or external requirements this depends on.
```

## Status values

- `[PLANNED]`     — approved, not yet started
- `[IN PROGRESS]` — actively being worked on (update the file to reflect this)
- `[BLOCKED]`     — waiting on something external
- `[DONE]`        — completed (move to ## Completed section, keep for reference)
- `[REJECTED]`    — decided not to do; leave a brief reason

## Rules for agents

1. Before starting a task, change its status to `[IN PROGRESS]` and update
   the **Updated** date.
2. When complete, change status to `[DONE]`, fill in any relevant outcomes,
   and move the entire task block to the ## Completed section.
3. Never delete a task — use `[REJECTED]` with a reason instead.
4. When adding a new task, assign the next sequential ID (check the highest
   existing ID first).
5. Keep the Planned section sorted by Priority (high → medium → low), then
   by Added date within the same priority.
6. Update **Updated** date whenever you edit a task, even just to add a note.
-->

---

## Planned

*(no planned tasks)*

---

## Completed

<!-- Completed tasks are moved here. Keep them for reference. -->

### [DONE] Add mem0 persistent memory via MCP server (#LOBBY-1)

- **ID**: LOBBY-1
- **Type**: feature
- **Priority**: high
- **Effort**: medium
- **Added**: 2026-04-30
- **Updated**: 2026-04-30
- **Author**: agent
- **Completed**: 2026-04-30

#### Problem / Motivation
`lobby` sessions currently have no persistent memory between runs. Each time you call `lobby`, Claude Code starts with no context from previous sessions — no matter the terminal, time of day, or day of the week.

#### Proposed Solution
Integrate [mem0-mcp-selfhosted](https://github.com/elvismdev/mem0-mcp-selfhosted) as a persistent memory layer via Claude Code's MCP protocol. Claude Code natively loads MCP servers registered in `~/.claude/settings.json` at session start, so any `lobby` instance automatically inherits persistent memory tools.

Architecture:
```
lobby → claude (CLI) → MCP (stdio) → mem0-mcp-selfhosted (uvx) → Qdrant (OrbStack Docker)
                                            ↓
                                     Ollama (LLM + bge-m3 embeddings)
```

- **Qdrant** runs in OrbStack as a Docker container, data persisted to a named volume
- **mem0-mcp-selfhosted** is launched by Claude Code as a stdio subprocess each session (no daemon needed)
- **Ollama** provides the LLM for memory extraction and `bge-m3` for embeddings — fully local, no API keys
- `setup.fish` handles all one-time configuration

#### Implementation Notes
- MCP server: `uvx --from git+https://github.com/elvismdev/mem0-mcp-selfhosted.git mem0-mcp-selfhosted`
- Embeddings model: `bge-m3` (must be pulled via `ollama pull bge-m3`, ~670 MB)
- `MEM0_LLM_MODEL` defaults to `qwen2.5-coder:latest` (lobby builtin default)
- Qdrant docker-compose in repo root; started by `setup.fish` and documented in `--memory`
- `lobby.fish` warns (non-blocking) if Qdrant is not reachable when launching in Ollama mode
- `setup.fish` uses `claude mcp add --scope user` to register the MCP server
- Check `claude mcp list` before adding to avoid duplicates

#### Acceptance Criteria
- [x] `docker-compose.yml` in repo root starts Qdrant via OrbStack
- [x] `setup.fish` pulls `bge-m3`, starts Qdrant, and registers mem0 MCP in `~/.claude/settings.json`
- [x] mem0 MCP tools available automatically in every `lobby` session
- [x] `lobby --memory` shows memory status (Qdrant up/down, how to start)
- [x] Qdrant-down warning printed (non-blocking) when launching in Ollama mode
- [x] Memories persist across terminal restarts and different days
