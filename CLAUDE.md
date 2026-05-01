# Lobby

## Purpose

This repository provides `lobby` — a fish shell function for macOS (Apple Silicon) that wraps the Claude Code CLI and lets you switch between running it against a **local Ollama model** or **Anthropic's API** with a single flag.

Default behaviour is local-first: `lobby` runs Claude Code pointed at your Ollama instance (`http://127.0.0.1:11434`) using the Anthropic-compatible API that Ollama v0.14+ exposes natively. No proxy required. Pass `--anthropic` to route through Anthropic's API instead.

The model is selected via `--model [name]`: omit the name to pick interactively from a numbered list of installed models, or supply a name to validate and use it directly. Plain `lobby` with no args uses the saved default silently. Unknown flags (e.g. `--helk`) are caught immediately with a did-you-mean suggestion rather than being silently treated as model names.

The `lobby` function includes an optional model allowlist system (`enabled_models` file) that lets you control which local models can be launched — useful for managing multiple models and preventing accidental use of unintended models.

---

## Repo structure

| File | Description |
|---|---|
| `lobby.fish` | The fish function — the main deliverable |
| `setup.fish` | Installer: checks/installs dependencies, installs `lobby.fish`, sets up mem0 |
| `docker-compose.yml` | Starts Qdrant (vector store for mem0) via OrbStack Docker |
| `CLAUDE.md` | This file — context for agents |
| `README.md` | Human-facing documentation |
| `BACKLOG.md` | Planned features, improvements, and bug fixes (see below) |

---

## How it works

### Ollama mode (default)

Sets three environment variables before calling `claude`:

```
ANTHROPIC_BASE_URL=http://127.0.0.1:11434
ANTHROPIC_AUTH_TOKEN=ollama
ANTHROPIC_API_KEY=""
```

Ollama v0.14+ exposes an Anthropic Messages API-compatible endpoint at `/v1/messages`, so Claude Code speaks to it natively without any translation proxy.

### Subscription mode (`--claude`)

Unsets all three env var overrides (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`) so Claude Code falls back to its own OAuth session — the one established by `claude /login`. Requires a Claude.ai Pro, Max, Team, or Enterprise subscription. No API key needed.

### Anthropic API mode (`--anthropic`)

Unsets the Ollama overrides and passes through the real `ANTHROPIC_API_KEY` from the environment. The default Anthropic model is saved to `~/.config/lobby/default_anthropic_model`.

### Model allowlist

If `~/.config/lobby/enabled_models` exists, only models listed in that file can be launched with `lobby`. This is managed via `lobby --set`. If the file doesn't exist, all installed models are allowed.

---

## Configuration files

| Path | Purpose |
|---|---|
| `~/.config/fish/functions/lobby.fish` | Installed fish function |
| `~/.config/lobby/default_local_model` | Saved default local Ollama model |
| `~/.config/lobby/default_anthropic_model` | Saved default Anthropic model |
| `~/.config/lobby/enabled_models` | Optional allowlist of enabled models |

---

## mem0 persistent memory

`lobby` integrates [mem0-mcp-selfhosted](https://github.com/elvismdev/mem0-mcp-selfhosted) to give every Claude Code session persistent memory across terminals and days. The memory layer is fully local — no cloud API keys required.

### Architecture

```
lobby → claude (CLI) → MCP (stdio) → mem0-mcp-selfhosted (uvx) → Qdrant (OrbStack Docker)
                                             ↓
                                      Ollama (LLM + bge-m3 embeddings)
```

- **Qdrant** stores memory vectors in an OrbStack Docker container (`docker-compose.yml` in repo root)
- **mem0-mcp-selfhosted** is launched as a stdio subprocess by Claude Code at session start — no separate daemon
- **bge-m3** is the local embedding model (pulled via `ollama pull bge-m3`)
- **MCP registration** lives in `~/.claude.json` (scope: user) — applies to all projects

### Repo files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Starts Qdrant via OrbStack Docker |

### Setup

`fish setup.fish` handles everything: starts Qdrant, pulls `bge-m3`, and registers the MCP server with Claude Code. To verify:

```fish
lobby --memory      # shows Qdrant status and MCP registration
```

### Starting Qdrant

Qdrant is configured with `restart: unless-stopped`, so it persists across OrbStack restarts. If it's ever down:

```fish
docker compose up -d    # from the lobby repo root
```

### MCP tools available in every session

| Tool | Purpose |
|---|---|
| `add_memory` | Store a fact or conversation summary |
| `search_memories` | Semantic search over stored memories |
| `get_memories` | List all stored memories |
| `update_memory` | Edit an existing memory |
| `delete_memory` | Remove a specific memory |

### Notes for agents

- `MEM0_LLM_MODEL` in the MCP registration defaults to the lobby builtin (`qwen2.5-coder:latest`) but is set to the user's saved default at `setup.fish` run time
- The collection name used by mem0-mcp-selfhosted is `mem0_mcp_selfhosted` — use this when querying Qdrant directly
- If MCP registration needs updating (e.g. model changed): `claude mcp remove mem0` then re-run `fish setup.fish`
- The correct `claude mcp add` syntax puts the server name BEFORE `-e` flags: `claude mcp add -s user mem0 -e KEY=val ... -- uvx ...` — putting `-e` before the name causes the parser to consume the name as an env var value
- Qdrant data volume is named `lobby_qdrant_storage` — do not delete it

---

## Installation

```fish
fish setup.fish
```

The setup script installs, in order: Homebrew → Python 3 → Node.js → Claude Code CLI → Ollama → mem0 (Qdrant + bge-m3 + MCP registration), then copies `lobby.fish` into `~/.config/fish/functions/` and optionally pulls a starter model.

---

## Notes for agents

- `lobby.fish` is self-contained — all config paths are defined at the top of the function body.
- `setup.fish` is idempotent — safe to re-run at any time to update dependencies.
- The `_lobby_*` helper functions are nested inside the outer `lobby` function to avoid polluting the global fish namespace.
- Do not modify `CLAUDE.md` without also updating `setup.fish` and `lobby.fish` if the change affects installation or env var behaviour.
- The Ollama URL is hardcoded to `http://127.0.0.1:11434` — change the `OLLAMA_URL` variable at the top of `lobby.fish` if your setup differs.
- All lobby flags start with `-`. Any unrecognised `-` prefixed argument is caught by the unknown flag guard (before the `--help` handler) and returns an error with a did-you-mean suggestion. This prevents typos from silently launching with the wrong model.
- `--model` is parsed in the Ollama path, `--claude` path, and `--anthropic` path. In Ollama mode, model names are validated against installed/enabled models. In `--claude` and `--anthropic` modes, they are validated against the hardcoded `_claude_models` / `_anthropic_models` lists (same content, defined locally in each branch).
- `--claude` and `--anthropic` share the same model list and the same `default_anthropic_model` config file — the distinction is only in how the `claude` process authenticates.
- The `_lobby_pick_model_interactive` helper is used by `--model` (picker), `--set-default`, and `--set-anthropic-model` — all three share the same numbered list UI.
- The model allowlist feature mirrors the implementation in `llamy` — if modifying one, consider syncing changes to the other.

---

## Backlog

Planned work lives in [`BACKLOG.md`](./BACKLOG.md). It is the authoritative source for what needs doing in this repo — bugs, features, and improvements.

### How the backlog works

Each task in `BACKLOG.md` has a status, a unique ID (`LOBBY-N`), metadata, a full description, implementation notes, and acceptance criteria. The format is designed so an agent can open the file, pick up a task, implement it, and mark it done — without needing additional context from a human.

### Agent workflow for backlog tasks

1. **Read `BACKLOG.md` first.** Before starting any work session, scan for `[PLANNED]` or `[IN PROGRESS]` tasks relevant to the work being requested.
2. **Claim the task.** Change its status from `[PLANNED]` to `[IN PROGRESS]` and update the `Updated` date before touching any code.
3. **Follow the implementation notes.** Each task includes specific file locations, known edge cases, and decisions already made — use them.
4. **Mark done and move.** When complete, change status to `[DONE]` and move the task block to the `## Completed` section at the bottom of `BACKLOG.md`.
5. **Add new tasks as discovered.** If work reveals a new bug or improvement, add it to `BACKLOG.md` with the next sequential ID rather than silently fixing or ignoring it.

### Adding a task

Use this minimal template and append it to the `## Planned` section, maintaining priority order (high → medium → low):

```markdown
### [PLANNED] Short imperative title (#LOBBY-N)

- **ID**: LOBBY-N
- **Type**: bug | feature | improvement | refactor
- **Priority**: high | medium | low
- **Effort**: small | medium | large
- **Added**: YYYY-MM-DD
- **Updated**: YYYY-MM-DD
- **Author**: name or "agent"

#### Problem / Motivation
...

#### Proposed Solution
...

#### Implementation Notes
...

#### Acceptance Criteria
- [ ] ...
```
