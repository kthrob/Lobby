#!/usr/bin/env fish
# setup.fish — install lobby and its dependencies
#
# Run from the repository root:
#   fish setup.fish

# ── helpers ───────────────────────────────────────────────────────────────────

function info
    echo (set_color cyan)"[setup]"(set_color normal) $argv
end
function ok
    echo (set_color green)"[setup] ✓"(set_color normal) $argv
end
function warn
    echo (set_color yellow)"[setup] !"(set_color normal) $argv
end
function err
    echo (set_color red)"[setup] ✗"(set_color normal) $argv >&2
end
function header
    echo ""
    echo (set_color --bold)"── $argv"(set_color normal)
end
function die
    err $argv
    exit 1
end

# ── 0. sanity: must be run from repo root ────────────────────────────────────

header "Checking repo"

if not test -f ./lobby.fish
    die "lobby.fish not found in current directory. Run setup.fish from the repo root."
end
ok "lobby.fish found"

# ── 1. Homebrew ───────────────────────────────────────────────────────────────

header "Homebrew"

if not command -q brew
    info "Homebrew not found — installing..."
    /bin/bash -c (curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
    # Add brew to PATH for Apple Silicon if needed
    if test -f /opt/homebrew/bin/brew
        eval (/opt/homebrew/bin/brew shellenv)
    end
    if not command -q brew
        die "Homebrew installation failed. Please install manually: https://brew.sh"
    end
    ok "Homebrew installed"
else
    info "Homebrew found — checking for updates..."
    brew update --quiet
    ok "Homebrew up to date ("(brew --version | head -1)")"
end

# ── 2. Python 3 ───────────────────────────────────────────────────────────────

header "Python 3"

# Claude Code and related tooling may need a system python3
if not command -q python3
    info "python3 not found — installing via Homebrew..."
    brew install python
    if not command -q python3
        die "python3 installation failed."
    end
    ok "python3 installed ("(python3 --version)")"
else
    set pyver (python3 --version 2>&1)
    ok "python3 already installed ($pyver)"
    # Upgrade if installed via brew
    if brew list python &>/dev/null
        info "Upgrading python via Homebrew..."
        brew upgrade python --quiet
        ok "python3 up to date"
    end
end

# ── 3. Node.js (required by Claude Code CLI) ──────────────────────────────────

header "Node.js"

if not command -q node
    info "Node.js not found — installing via Homebrew..."
    brew install node
    if not command -q node
        die "Node.js installation failed."
    end
    ok "Node.js installed ("(node --version)")"
else
    info "Node.js found ("(node --version)") — checking for upgrade..."
    brew upgrade node --quiet 2>/dev/null
    ok "Node.js up to date ("(node --version)")"
end

# ── 4. Claude Code CLI ────────────────────────────────────────────────────────

header "Claude Code CLI"

if not command -q claude
    info "Claude Code not found — installing via npm..."
    npm install -g @anthropic-ai/claude-code
    if not command -q claude
        die "Claude Code installation failed. Try: npm install -g @anthropic-ai/claude-code"
    end
    ok "Claude Code installed ("(claude --version 2>&1 | head -1)")"
else
    info "Claude Code found — checking for upgrade..."
    npm update -g @anthropic-ai/claude-code --quiet 2>/dev/null
    ok "Claude Code up to date ("(claude --version 2>&1 | head -1)")"
end

# ── 5. Ollama ─────────────────────────────────────────────────────────────────

header "Ollama"

if not command -q ollama
    info "Ollama not found — installing via Homebrew..."
    brew install ollama
    if not command -q ollama
        die "Ollama installation failed."
    end
    ok "Ollama installed ("(ollama --version 2>&1 | head -1)")"
else
    set ol_current (ollama --version 2>&1 | head -1)
    info "Ollama already installed ($ol_current) — checking for upgrade..."
    brew upgrade ollama --quiet 2>/dev/null
    ok "Ollama up to date ("(ollama --version 2>&1 | head -1)")"
end

# ── 6. Install lobby.fish ─────────────────────────────────────────────────────

header "Installing lobby"

if test -n "$__fish_config_dir"
    set FISH_FUNCTIONS "$__fish_config_dir/functions"
else
    set FISH_FUNCTIONS "$HOME/.config/fish/functions"
end
mkdir -p $FISH_FUNCTIONS

set DEST "$FISH_FUNCTIONS/lobby.fish"

cp ./lobby.fish $DEST
or die "Failed to copy lobby.fish to $DEST"

chmod +x $DEST
or die "Failed to chmod $DEST"

ok "lobby.fish installed → $DEST"

if fish -c "type -q lobby"
    ok "lobby command is available in Fish"
else
    die "lobby is not discoverable in Fish after install. Check your fish function path and rerun setup."
end

# ── 7. ANTHROPIC_API_KEY check ────────────────────────────────────────────────

header "Anthropic API key"

if set -q ANTHROPIC_API_KEY; and test -n "$ANTHROPIC_API_KEY"
    ok "ANTHROPIC_API_KEY is set (needed for --anthropic mode)"
else
    warn "ANTHROPIC_API_KEY is not set."
    warn "You can still use lobby in local Ollama mode without it."
    warn "To enable Anthropic mode, add this to ~/.config/fish/config.fish:"
    warn "  set -Ux ANTHROPIC_API_KEY sk-ant-..."
end

# ── 8. Pull a starter model ───────────────────────────────────────────────────

header "Starter model"

info "Starting Ollama server to check available models..."
if not pgrep -x ollama > /dev/null
    ollama serve > /dev/null 2>&1 &
    set _ollama_pid $last_pid
    sleep 2
    set _started_here 1
end

set existing_models (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

if set -q _started_here
    kill $_ollama_pid 2>/dev/null
end

if test (count $existing_models) -eq 0
    info "No models found. Pulling qwen2.5-coder:latest (recommended for Claude Code, ~4 GB)..."
    info "You can skip this and pull a different model later with: ollama pull <model>"
    echo ""
    read --prompt-str (set_color cyan)"[setup]"(set_color normal)" Pull starter model now? [Y/n]: " pull_answer

    if test "$pull_answer" != "n" -a "$pull_answer" != "N"
        ollama pull qwen2.5-coder:latest
        ok "Starter model ready"
    else
        info "Skipped. Pull a model later with: ollama pull <model>"
        info "Then set it as default with: lobby --set-default"
    end
else
    ok "Models already present — lobby can use any installed model"
    info "Use "(set_color cyan)"lobby --set"(set_color normal)" to choose which models are enabled"
    info "Use "(set_color cyan)"lobby --set-default"(set_color normal)" to pick the default"
end

# ── done ──────────────────────────────────────────────────────────────────────

echo ""
echo (set_color --bold)(set_color green)"  All done!"(set_color normal)
echo ""
echo "  Open a new terminal (or run "(set_color cyan)"source ~/.config/fish/config.fish"(set_color normal)") and:"
echo ""
echo "    "(set_color --bold)"lobby --help"(set_color normal)"                   see all commands"
echo "    "(set_color --bold)"lobby --set"(set_color normal)"                    choose which models to enable"
echo "    "(set_color --bold)"lobby --list"(set_color normal)"                    list enabled models"
echo "    "(set_color --bold)"lobby --set-default"(set_color normal)"            choose your default model"
echo "    "(set_color --bold)"lobby"(set_color normal)"                          launch Claude Code (local)"
echo "    "(set_color --bold)"lobby --anthropic"(set_color normal)"              launch Claude Code (Anthropic API)"
echo ""
