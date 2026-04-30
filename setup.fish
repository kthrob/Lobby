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
    if test -f /opt/homebrew/bin/brew
        eval (/opt/homebrew/bin/brew shellenv)
    end
    if not command -q brew
        die "Homebrew installation failed. Install manually: https://brew.sh"
    end
    ok "Homebrew installed"
else
    info "Homebrew found — updating..."
    brew update --quiet
    ok "Homebrew up to date ("(brew --version | head -1)")"
end

# ── 2. Node.js (required by Claude Code CLI) ──────────────────────────────────

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

# ── 3. Claude Code CLI ────────────────────────────────────────────────────────

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

# ── 4. Ollama ─────────────────────────────────────────────────────────────────

header "Ollama"

if not command -q ollama
    info "Ollama not found — installing via Homebrew..."
    brew install ollama
    if not command -q ollama
        die "Ollama installation failed."
    end
    ok "Ollama installed ("(ollama --version 2>&1 | head -1)")"
else
    info "Ollama found — checking for upgrade..."
    brew upgrade ollama --quiet 2>/dev/null
    ok "Ollama up to date ("(ollama --version 2>&1 | head -1)")"
end

# ── 5. ANTHROPIC_API_KEY check ────────────────────────────────────────────────

header "Anthropic API key"

if set -q ANTHROPIC_API_KEY; and test -n "$ANTHROPIC_API_KEY"
    ok "ANTHROPIC_API_KEY is set (needed for --anthropic mode)"
else
    warn "ANTHROPIC_API_KEY is not set."
    warn "You can still use lobby in local Ollama mode without it."
    warn "To enable Anthropic mode, add this to ~/.config/fish/config.fish:"
    warn "  set -Ux ANTHROPIC_API_KEY sk-ant-..."
end

# ── 6. Install lobby.fish ─────────────────────────────────────────────────────

header "Installing lobby"

set FISH_FUNCTIONS "$HOME/.config/fish/functions"
mkdir -p $FISH_FUNCTIONS

set DEST "$FISH_FUNCTIONS/lobby.fish"
cp ./lobby.fish $DEST
or die "Failed to copy lobby.fish to $DEST"

chmod +x $DEST
or die "Failed to chmod $DEST"

ok "lobby.fish installed → $DEST"

# ── 7. Pull a starter model ───────────────────────────────────────────────────

header "Starter model"

info "Starting Ollama server to pull a starter model..."
if not pgrep -x ollama > /dev/null
    ollama serve > /dev/null 2>&1 &
    set _ollama_pid $last_pid
    sleep 2
    set _started_here 1
end

info "Pulling qwen2.5-coder:latest (recommended for Claude Code, ~4 GB)..."
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

if set -q _started_here
    kill $_ollama_pid 2>/dev/null
end

# ── done ──────────────────────────────────────────────────────────────────────

echo ""
echo (set_color --bold)(set_color green)"  All done!"(set_color normal)
echo ""
echo "  Open a new terminal (or run "(set_color cyan)"source ~/.config/fish/config.fish"(set_color normal)") and:"
echo ""
echo "    "(set_color --bold)"lobby --help"(set_color normal)"                   see all commands"
echo "    "(set_color --bold)"lobby --set-default"(set_color normal)"            choose your local model"
echo "    "(set_color --bold)"lobby"(set_color normal)"                          launch Claude Code (local)"
echo "    "(set_color --bold)"lobby --anthropic"(set_color normal)"              launch Claude Code (Anthropic API)"
echo ""
