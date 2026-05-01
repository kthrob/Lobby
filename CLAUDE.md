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
| `setup.fish` | Installer: checks/installs dependencies, installs `lobby.fish`, sets up mem0, graphify |
| `docker-compose.yml` | Starts Qdrant (vector store for mem0) via OrbStack Docker |
| `.mcp.json` | Registers graphify and mem0 MCP servers with Claude Code |
| `scripts/mem0_config.py` | mem0 configuration (Ollama + Qdrant backend) |
| `scripts/mem0_mcp_server.py` | MCP server implementation for mem0 |
| `scripts/sync_graph_to_mem0.py` | Syncs graphify god nodes into mem0 |
| `scripts/pre_tool_context.py` | PreToolUse hook for contextual memory injection |
| `graphify-out/` | Knowledge graph artifacts (committed to git, cache excluded) |
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

## Knowledge graph + persistent memory (graphify + mem0)

### Architecture

```
Claude Code CLI
    ├─ MCP: graphify         (query_graph, get_node, get_neighbors, shortest_path)
    │   └─ graphify-out/graph.json (codebase structure, entities, relationships)
    │
    └─ MCP: mem0             (add_memory, search_memory, get_all_memories, delete_memory)
        └─ Qdrant (vector store) ← Ollama (llama3 LLM + nomic-embed-text embeddings)
```

- **graphify** builds a structural knowledge graph of the codebase (entities, relationships, call graphs). Persists to `graphify-out/` in git. Compresses token cost by ~71x for architecture queries.
- **mem0** stores episodic and semantic memories across sessions (decisions, preferences, patterns). Backed by local Ollama models — no cloud calls.
- A **sync script** (`scripts/sync_graph_to_mem0.py`) promotes graphify's god nodes into mem0 so structural insights survive across graph rebuilds.

### Repo files

| File | Purpose |
|---|---|
| `.mcp.json` | Registers both MCP servers with Claude Code |
| `scripts/mem0_config.py` | mem0 configuration (Ollama + Qdrant) |
| `scripts/mem0_mcp_server.py` | MCP server exposing mem0 tools |
| `scripts/sync_graph_to_mem0.py` | Syncs graphify insights to mem0 |
| `scripts/pre_tool_context.py` | PreToolUse hook for contextual memory injection |
| `graphify-out/graph.json` | Knowledge graph (committed to git) |
| `graphify-out/GRAPH_REPORT.md` | Structural insights (committed to git) |
| `docker-compose.yml` | Starts Qdrant via OrbStack Docker |

### Session bootstrap (run at the start of every session)

1. Read `graphify-out/GRAPH_REPORT.md` for god nodes, community clusters, and surprising structural connections.
2. Call `search_memory` (MCP: mem0) with the query `"project decisions overview"` to surface the 5 most recent architectural decisions.
3. Briefly summarise what was in progress and what was decided before answering the user's first question.

### Before answering architecture or design questions

- Use `query_graph` (MCP: graphify) to look up the relevant component. Prefer graph traversal over Glob/Grep for structural questions.
- Use `search_memory` (MCP: mem0) with the component name as the query to check for past decisions related to it.
- Cite both sources when they are relevant.

### After making or discovering an architectural decision

- Call `add_memory` (MCP: mem0) immediately.
- Memory format: `"[Component]: [Decision]. Rationale: [why]."`
- Include metadata: `{"type": "decision", "component": "<name>"}`

### Storing developer preferences

- When the user states a preference (style, tooling, patterns), store it with `add_memory` and metadata `{"type": "preference"}`.
- These persist across sessions — do not ask the user to repeat preferences that are already in mem0.

### Graph maintenance

- After the user runs `/graphify .` or `/graphify --update`, immediately run: `.venv/bin/python3 scripts/sync_graph_to_mem0.py`
- This promotes new god nodes and insights into mem0.
- Do not re-run graphify on every session — only when files have changed.

### Starting Qdrant

Qdrant is configured with `restart: unless-stopped` in `docker-compose.yml`, so it persists across OrbStack restarts. If it's ever down:

```bash
docker compose up -d    # from the lobby repo root
```

### Notes for agents

- The MCP servers are discovered via `.mcp.json` at project root — no user-level registration needed.
- mem0 uses Qdrant for vector storage and Ollama (llama3 + nomic-embed-text) for embeddings — all local, no cloud API keys.
- The PreToolUse hook in `settings.json` injects graphify reminders and top mem0 hits before every Glob/Grep/Read call.
- If Qdrant is down, mem0 tools will fail with an error message — never silently skipped.
- The god-node sync script should be run after every graphify build to keep structural knowledge fresh in mem0.

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
