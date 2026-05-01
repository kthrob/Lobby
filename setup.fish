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

# ── 6. mem0 persistent memory ────────────────────────────────────────────────
# Sets up Qdrant (vector store) via OrbStack Docker and registers the
# mem0-mcp-selfhosted MCP server with Claude Code CLI so every lobby
# session automatically has access to persistent memory tools.

header "mem0 persistent memory"

# Check Docker is available (OrbStack must be running)
if not command -q docker
    warn "Docker not found — skipping mem0 setup."
    warn "Install OrbStack (https://orbstack.dev) and re-run setup.fish to enable memory."
else if not docker info > /dev/null 2>&1
    warn "Docker daemon not running — skipping mem0 setup."
    warn "Start OrbStack and re-run setup.fish to enable memory."
else
    # Start Qdrant via docker compose
    if not test -f ./docker-compose.yml
        die "docker-compose.yml not found. Run setup.fish from the lobby repo root."
    end

    info "Starting Qdrant vector store..."
    docker compose up -d 2>/dev/null
    or die "docker compose up failed. Check OrbStack and try again."

    # Wait for Qdrant health (up to 15 s)
    set _q_attempts 0
    while test $_q_attempts -lt 15
        if curl -sf "http://localhost:6333/healthz" > /dev/null 2>&1
            break
        end
        sleep 1
        set _q_attempts (math $_q_attempts + 1)
    end

    if not curl -sf "http://localhost:6333/healthz" > /dev/null 2>&1
        warn "Qdrant did not respond in time — mem0 MCP may not work until it's healthy."
        warn "Check: docker compose ps"
    else
        ok "Qdrant is running at http://localhost:6333"
    end

    # Pull bge-m3 embedding model (needed by mem0 for local embeddings)
    info "Checking for bge-m3 embedding model (required by mem0, ~670 MB)..."
    set _has_bge (ollama list 2>/dev/null | grep -c "bge-m3")
    if test "$_has_bge" -eq 0
        echo ""
        read --prompt-str (set_color cyan)"[setup]"(set_color normal)" Pull bge-m3 embedding model now? [Y/n]: " bge_answer
        if test "$bge_answer" != "n" -a "$bge_answer" != "N"
            # Ensure Ollama is running to pull
            if not pgrep -x ollama > /dev/null
                info "Starting Ollama to pull bge-m3..."
                ollama serve > /dev/null 2>&1 &
                set _bge_ollama_pid $last_pid
                sleep 2
                set _started_for_bge 1
            end
            ollama pull bge-m3
            if set -q _started_for_bge
                kill $_bge_ollama_pid 2>/dev/null
            end
            ok "bge-m3 ready"
        else
            warn "Skipped. Pull it later with: ollama pull bge-m3"
            warn "mem0 will fail to start until bge-m3 is available."
        end
    else
        ok "bge-m3 already installed"
    end

    # Register mem0 MCP server with Claude Code (scope: user, applies to all projects)
    if not command -q claude
        warn "Claude Code CLI not found — skipping MCP registration."
        warn "Run setup.fish again after installing Claude Code."
    else
        # Check if already registered to avoid duplicates
        set _already_registered (claude mcp list 2>/dev/null | grep -c "mem0")
        if test "$_already_registered" -gt 0
            ok "mem0 MCP already registered with Claude Code"
        else
            info "Registering mem0 MCP server with Claude Code..."

            # Determine the default local model to use for memory extraction
            set _mem0_llm "qwen2.5-coder:latest"
            if test -f "$HOME/.config/lobby/default_local_model"
                set _saved (string trim -- (cat "$HOME/.config/lobby/default_local_model" 2>/dev/null))
                if test -n "$_saved"
                    set _mem0_llm $_saved
                end
            end

            if claude mcp add -s user mem0 \
                -e MEM0_USER_ID=lobby-user \
                -e MEM0_PROVIDER=ollama \
                -e MEM0_LLM_MODEL=$_mem0_llm \
                -e MEM0_OLLAMA_BASE_URL=http://127.0.0.1:11434 \
                -e MEM0_QDRANT_URL=http://localhost:6333 \
                -- uvx --from "git+https://github.com/elvismdev/mem0-mcp-selfhosted.git" mem0-mcp-selfhosted
                ok "mem0 MCP registered (scope: user)"
            else
                warn "MCP registration failed — run manually:"
                warn "  claude mcp add -s user mem0 -e MEM0_USER_ID=lobby-user -e MEM0_PROVIDER=ollama -e MEM0_LLM_MODEL=$_mem0_llm -e MEM0_OLLAMA_BASE_URL=http://127.0.0.1:11434 -e MEM0_QDRANT_URL=http://localhost:6333 -- uvx --from 'git+https://github.com/elvismdev/mem0-mcp-selfhosted.git' mem0-mcp-selfhosted"
            end
        end
    end
end

# ── 6b. Python venv for local mem0 scripts ────────────────────────────────────
# Creates .venv and installs mem0ai + qdrant-client so scripts/mem0_mcp_server.py
# and scripts/pre_tool_context.py can run without polluting the system Python.

header "Python venv (mem0 scripts)"

if not command -q python3
    warn "python3 not found — skipping venv setup."
    warn "Install Python 3 and re-run setup.fish."
else
    if test -f ./.venv/bin/python3
        ok "Python venv already exists"
    else
        info "Creating Python venv at .venv ..."
        if command -q uv
            uv venv .venv
        else
            python3 -m venv .venv
        end

        if test $status -ne 0
            warn "Failed to create venv. You can do it manually:"
            warn "  python3 -m venv .venv"
        else
            ok "Venv created"
        end
    end

    if test -f ./.venv/bin/python3
        info "Installing mem0ai and qdrant-client into venv..."
        if command -q uv
            uv pip install --python .venv/bin/python3 mem0ai qdrant-client
        else
            ./.venv/bin/pip install --quiet mem0ai qdrant-client
        end

        if test $status -eq 0
            ok "mem0ai and qdrant-client installed"
        else
            warn "Package install failed. Try manually:"
            warn "  .venv/bin/pip install mem0ai qdrant-client"
        end
    end
end

# ── 7. Install lobby.fish ─────────────────────────────────────────────────────

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

# ── 8. ANTHROPIC_API_KEY check ────────────────────────────────────────────────

header "Anthropic API key"

if set -q ANTHROPIC_API_KEY; and test -n "$ANTHROPIC_API_KEY"
    ok "ANTHROPIC_API_KEY is set (needed for --anthropic mode)"
else
    warn "ANTHROPIC_API_KEY is not set."
    warn "You can still use lobby in local Ollama mode without it."
    warn "To enable Anthropic mode, add this to ~/.config/fish/config.fish:"
    warn "  set -Ux ANTHROPIC_API_KEY sk-ant-..."
end

# ── 9. Pull a starter model ───────────────────────────────────────────────────

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

# ── test: verify mem0 integration ─────────────────────────────────────────────

header "Testing mem0 integration"

if test -f ./.venv/bin/python3
    info "Running mem0 integration test suite..."
    ./.venv/bin/python3 scripts/test_mem0_integration.py
    set test_exit_code $status

    if test $test_exit_code -eq 0
        ok "All mem0 tests passed!"
    else
        warn "Some mem0 tests failed — check output above"
        warn "You can re-run the test anytime with:"
        warn "  cd /Users/admin/Scripts/lobby && ./.venv/bin/python3 scripts/test_mem0_integration.py"
    end
else
    warn "Python venv not found — skipping mem0 tests"
    info "You can run tests later after re-running setup.fish"
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
