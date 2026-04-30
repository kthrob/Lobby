# Lobby

## Purpose

This repository provides `lobby` — a fish shell function for macOS (Apple Silicon) that wraps the Claude Code CLI and lets you switch between running it against a **local Ollama model** or **Anthropic's API** with a single flag.

Default behaviour is local-first: `lobby` runs Claude Code pointed at your Ollama instance (`http://127.0.0.1:11434`) using the Anthropic-compatible API that Ollama v0.14+ exposes natively. No proxy required. Pass `--anthropic` to route through Anthropic's API instead.

The `lobby` function includes an optional model allowlist system (`enabled_models` file) that lets you control which local models can be launched — useful for managing multiple models and preventing accidental use of unintended models.

---

## Repo structure

| File | Description |
|---|---|
| `lobby.fish` | The fish function — the main deliverable |
| `setup.fish` | Installer: checks/installs dependencies, installs `lobby.fish` |
| `CLAUDE.md` | This file — context for Claude Code |
| `README.md` | Human-facing documentation |

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

### Anthropic mode (`--anthropic`)

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

## Installation

```fish
fish setup.fish
```

The setup script installs, in order: Homebrew → Python 3 → Node.js → Claude Code CLI → Ollama, then copies `lobby.fish` into `~/.config/fish/functions/` and optionally pulls a starter model.

---

## Notes for Claude Code

- `lobby.fish` is self-contained — all config paths are defined at the top of the function body.
- `setup.fish` is idempotent — safe to re-run at any time to update dependencies.
- The `_lobby_*` helper functions are nested inside the outer `lobby` function to avoid polluting the global fish namespace.
- Do not modify `CLAUDE.md` without also updating `setup.fish` and `lobby.fish` if the change affects installation or env var behaviour.
- The Ollama URL is hardcoded to `http://127.0.0.1:11434` — change the `OLLAMA_URL` variable at the top of `lobby.fish` if your setup differs.
- In Anthropic mode, `lobby` uses `exec claude` so the lobby function is replaced by the claude process — no wrapper overhead.
- The model allowlist feature mirrors the implementation in `llamy` — if modifying one, consider syncing changes to the other.
