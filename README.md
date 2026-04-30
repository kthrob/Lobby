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
lobby --anthropic  # Anthropic API, full Claude power
```

No proxy. No config files to hand-edit. Ollama v0.14+ speaks the Anthropic Messages API natively — `lobby` just sets the right environment variables and gets out of your way.

---

## Install

```fish
git clone https://github.com/yourusername/lobby.git
cd lobby
fish setup.fish
```

The setup script handles everything in order:

1. **Homebrew** — install or update
2. **Python 3** — needed for tooling
3. **Node.js** — required by Claude Code CLI
4. **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
5. **Ollama** — local model server
6. Copies `lobby.fish` → `~/.config/fish/functions/` and makes it executable
7. Optionally pulls a starter model (`qwen2.5-coder:latest`)

Open a new terminal when done.

---

## Usage

```fish
lobby                         # run Claude Code with your default local model
lobby --anthropic             # run Claude Code via Anthropic API
lobby --set                   # toggle which local models are enabled for lobby
lobby --list                  # list currently enabled models
lobby --set-default           # pick a default from locally installed Ollama models
lobby --set-anthropic-model   # pick a default Anthropic model
lobby --help                  # show all commands
```

Any extra arguments are passed straight through to `claude`:

```fish
lobby 'fix the failing tests'
lobby --anthropic --print 'review this PR'
```

### Model management

`lobby` supports an optional allowlist system to control which models can be used:

```fish
lobby --set       # interactively toggle which models are enabled
lobby --list      # see which models are currently enabled
```

When no allowlist exists, all installed models are available. Once you create an allowlist with `--set`, only those models can be launched.

### Switching default local model

```
$ lobby --set-default

Available models:
  1) qwen2.5-coder:latest  ✓ current default
  2) mistral:latest
  3) llama3.1:8b

[lobby] Select a number (1-3): 2
[lobby] ✓ Local default model set to: mistral:latest
```

---

## How it works

In **local mode**, `lobby` sets three env vars before calling `claude`:

```
ANTHROPIC_BASE_URL=http://127.0.0.1:11434
ANTHROPIC_AUTH_TOKEN=ollama
ANTHROPIC_API_KEY=""
```

Ollama v0.14+ exposes an Anthropic Messages API-compatible endpoint natively at `/v1/messages` — no translation proxy needed. Claude Code talks to it like it's Anthropic.

In **Anthropic mode**, those overrides are cleared and your real `ANTHROPIC_API_KEY` is used.

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon) | M1 / M2 / M3 |
| [Fish shell](https://fishshell.com/) | `lobby` is a native fish function |
| [Homebrew](https://brew.sh) | All deps installed through it |
| [Node.js](https://nodejs.org) | Installed by `setup.fish` |
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | Installed by `setup.fish` |
| [Ollama](https://ollama.com) v0.14+ | Installed by `setup.fish` |
| `ANTHROPIC_API_KEY` | Only needed for `--anthropic` mode |

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
├── lobby.fish     # the fish function
├── setup.fish     # dependency installer
├── CLAUDE.md      # context file for Claude Code
└── README.md      # you are here
```
