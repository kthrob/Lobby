```
    ██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗
    ██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
    ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝
    ██║     ██║   ██║██╔══██╗██╔══██╗  ╚██╔╝
    ███████╗╚██████╔╝██████╔╝██████╔╝   ██║
    ╚══════╝ ╚═════╝ ╚═════╝ ╚═════╝    ╚═╝


              '=.
          '=. ||
        _    _||
       [_]==[_]||=-.
       _||_||_||  =\\
      /         \   \\   Claude Code.
     |   LOCAL   |   ||  Your rules.
      \_  AI  __/  =//   Your machine.
       |=======| =-'
       |  | |  |
      /    '    \
```

---

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) against your local [Ollama](https://ollama.com) models — or switch to Anthropic's API when you need it. One command, zero friction.

```fish
lobby              # local model, private, offline-capable
lobby --model      # pick a model interactively, then launch
lobby --claude     # Claude.ai subscription — no API key needed
lobby --anthropic  # Anthropic API key
```

No proxy. No config files to hand-edit. Ollama v0.14+ speaks the Anthropic Messages API natively — `lobby` just sets the right environment variables and gets out of your way.

---

## Install

```fish
git clone https://github.com/kthrob/Lobby.git
cd lobby
fish setup.fish
```

The setup script handles everything in order:

1. **Homebrew** — install or update
2. **Python 3** — needed for tooling
3. **Node.js** — required by Claude Code CLI
4. **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
5. **Ollama** — local model server
6. **mem0 memory** — starts Qdrant (OrbStack Docker), pulls `bge-m3` embedding model, registers mem0 MCP server with Claude Code
7. Copies `lobby.fish` → `~/.config/fish/functions/` and makes it executable
8. Optionally pulls a starter model (`qwen2.5-coder:latest`)

Open a new terminal when done.

---

## Usage

```fish
lobby                         # run Claude Code with your default local model
lobby --model                 # pick a local model interactively, then run
lobby --model mistral         # run with a specific model (validated)
lobby --claude                # run Claude Code via your Claude.ai subscription
lobby --claude --model        # pick a Claude model interactively, then run
lobby --anthropic             # run Claude Code via Anthropic API key
lobby --anthropic --model     # pick Anthropic model interactively, then run
lobby --set                   # toggle which local models are enabled for lobby
lobby --list                  # list currently enabled models
lobby --set-default           # pick a default from locally installed Ollama models
lobby --set-anthropic-model   # pick a default Anthropic model
lobby --memory                # show mem0 memory status (Qdrant, MCP registration)
lobby --help                  # show all commands
```

Any extra arguments after model selection are passed straight through to `claude`:

```fish
lobby 'fix the failing tests'
lobby --model mistral 'fix the failing tests'
lobby --claude 'review this PR'
lobby --anthropic --print 'review this PR'
```

### Model management

`lobby` supports an optional allowlist system to control which models can be used:

```fish
lobby --set       # interactively toggle which models are enabled
lobby --list      # see which models are currently enabled
```

When no allowlist exists, all installed models are available. Once you create an allowlist with `--set`, only those models can be launched.

### Picking a model for a one-off run

```
$ lobby --model

Available models:
  1) qwen2.5-coder:latest  ✓ current default
  2) mistral:latest
  3) llama3.1:8b

[lobby] Select a number (1-3): 2
[lobby] ✓ Using mistral:latest
```

Or supply the name directly — lobby validates it against your installed models:

```fish
lobby --model mistral
```

### Switching the saved default local model

```
$ lobby --set-default

Available models:
  1) qwen2.5-coder:latest  ✓ current default
  2) mistral:latest
  3) llama3.1:8b

[lobby] Select a number (1-3): 2
[lobby] ✓ Default model set to: mistral:latest
```

---

## Persistent memory (mem0)

Every `lobby` session automatically has persistent memory via [mem0](https://github.com/elvismdev/mem0-mcp-selfhosted) — fully local, no cloud API keys.

```
lobby → claude (CLI) → MCP → mem0-mcp-selfhosted → Qdrant (OrbStack Docker)
                                       ↓
                               Ollama (bge-m3 embeddings)
```

Memory tools are available in every session without any extra steps:

| Tool | What it does |
|---|---|
| `add_memory` | Store a fact or conversation summary |
| `search_memories` | Semantic search over stored memories |
| `get_memories` | List everything stored |
| `update_memory` / `delete_memory` | Edit or remove entries |

`setup.fish` handles the one-time setup (Qdrant container, `bge-m3` model, MCP registration). Qdrant is configured with `restart: unless-stopped` so it survives OrbStack restarts. If it's ever down:

```fish
docker compose up -d    # from the lobby repo root
lobby --memory          # verify status
```

### Testing mem0 integration

After setup completes, `setup.fish` automatically runs an integration test that:

1. Seeds 4 test memories (decision, preference, insight, observation) into mem0
2. Verifies semantic search works
3. Validates metadata schema enforcement
4. Checks PreToolUse hook configuration
5. Tests contextual memory injection

If you need to re-run the test (from the lobby repo root):

```fish
cd ~/Scripts/lobby
./.venv/bin/python3 scripts/test_mem0_integration.py
```

This will show 7 test results with pass/fail status. All tests passing means mem0 is ready to use. If Qdrant is down, start it with `docker compose up -d`.

---

## How it works

lobby has three modes, selected by flag:

**Local mode** (`lobby` / `lobby --model`) sets three env vars before calling `claude`:

```
ANTHROPIC_BASE_URL=http://127.0.0.1:11434
ANTHROPIC_AUTH_TOKEN=ollama
ANTHROPIC_API_KEY=""
```

Ollama v0.14+ exposes an Anthropic Messages API-compatible endpoint natively at `/v1/messages` — no translation proxy needed. Claude Code talks to it like it's Anthropic.

**Subscription mode** (`lobby --claude`) clears all three overrides and lets Claude Code use its own OAuth session — the one from your Claude.ai account (Pro, Max, Team, or Enterprise). No API key is needed; just make sure you've logged in at least once with `claude /login` inside a normal terminal. The model is still selectable via `--model`.

**API key mode** (`lobby --anthropic`) clears the Ollama overrides and uses your `ANTHROPIC_API_KEY` environment variable directly.

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon) | M1 / M2 / M3 |
| [Fish shell](https://fishshell.com/) | `lobby` is a native fish function |
| [Homebrew](https://brew.sh) | All deps installed through it |
| [OrbStack](https://orbstack.dev) | Docker runtime for Qdrant (mem0 vector store) |
| [Node.js](https://nodejs.org) | Installed by `setup.fish` |
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | Installed by `setup.fish` |
| [Ollama](https://ollama.com) v0.14+ | Installed by `setup.fish` |
| `ANTHROPIC_API_KEY` | Only needed for `--anthropic` mode (not `--claude`) |

> **Recommended:** Use a model with at least 64k context for best results with Claude Code. `qwen2.5-coder` and `qwen3-coder` are good local choices.

---

## Anthropic API key

Only needed for `--anthropic` mode. Add it to your fish config once:

```fish
set -Ux ANTHROPIC_API_KEY sk-ant-...
```

---

## File locations

| Path | What it is |
|---|---|
| `~/.config/fish/functions/lobby.fish` | The installed function |
| `~/.config/lobby/default_local_model` | Saved default local Ollama model |
| `~/.config/lobby/default_anthropic_model` | Saved default Anthropic model |
| `~/.config/lobby/enabled_models` | Optional allowlist of enabled models |
| `~/.claude.json` | Claude Code user config — mem0 MCP server registered here |
| `lobby_qdrant_storage` (Docker volume) | Qdrant persistent vector storage — do not delete |

---

## Updating

Re-run the setup script at any time — it's idempotent:

```fish
fish setup.fish
```

---

## Repo structure

```
lobby/
├── lobby.fish          # the fish function
├── setup.fish          # dependency installer + mem0 setup
├── docker-compose.yml  # Qdrant vector store (for mem0 memory)
├── CLAUDE.md           # context for AI agents working in this repo
├── BACKLOG.md          # planned features, improvements, and bug fixes
└── README.md           # you are here
```

---

## Backlog

Planned work is tracked in [`BACKLOG.md`](./BACKLOG.md). Each entry is a self-contained task with a status, description, implementation notes, and acceptance criteria — written so an agent or a human can pick it up and execute it without needing additional context.

To see what's planned:

```fish
cat BACKLOG.md
```

To contribute a task, follow the template in `BACKLOG.md` and assign the next `LOBBY-N` ID.
