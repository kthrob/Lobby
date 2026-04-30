# ~/.config/fish/functions/lobby.fish
#
# Usage:
#   lobby                        # run claude code with saved default local model
#   lobby --anthropic            # run claude code against Anthropic's API
#   lobby --set-default          # pick a default from locally installed Ollama models
#   lobby --set-anthropic-model  # pick a default Anthropic model
#   lobby --help / -h            # show this help

function lobby --description "Run Claude Code against local Ollama or Anthropic"

    set CONFIG_DIR           "$HOME/.config/lobby"
    set LOCAL_DEFAULT_FILE   "$CONFIG_DIR/default_local_model"
    set ANTHROPIC_DEFAULT_FILE "$CONFIG_DIR/default_anthropic_model"
    set BUILTIN_LOCAL        "qwen2.5-coder:latest"
    set BUILTIN_ANTHROPIC    "claude-sonnet-4-5"
    set OLLAMA_URL           "http://127.0.0.1:11434"

    # ── helpers ────────────────────────────────────────────────────────────

    function _lobby_info
        echo (set_color cyan)"[lobby]"(set_color normal) $argv
    end
    function _lobby_ok
        echo (set_color green)"[lobby] ✓"(set_color normal) $argv
    end
    function _lobby_err
        echo (set_color red)"[lobby] ✗"(set_color normal) $argv >&2
    end

    function _lobby_local_default
        if test -f $LOCAL_DEFAULT_FILE
            cat $LOCAL_DEFAULT_FILE
        else
            echo $BUILTIN_LOCAL
        end
    end

    function _lobby_anthropic_default
        if test -f $ANTHROPIC_DEFAULT_FILE
            cat $ANTHROPIC_DEFAULT_FILE
        else
            echo $BUILTIN_ANTHROPIC
        end
    end

    # ── --help ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--help" -o "$argv[1]" = "-h"
        set local_def (_lobby_local_default)
        set anth_def  (_lobby_anthropic_default)
        echo ""
        echo (set_color --bold)"lobby"(set_color normal)" — Claude Code launcher (local Ollama or Anthropic)"
        echo ""
        echo (set_color --bold)"USAGE"(set_color normal)
        echo "  lobby [claude args...]          Run Claude Code via local Ollama"
        echo "  lobby --anthropic [claude args] Run Claude Code via Anthropic API"
        echo ""
        echo (set_color --bold)"OPTIONS"(set_color normal)
        printf "  %-28s %s\n" "--anthropic"            "Use Anthropic's API instead of local Ollama"
        printf "  %-28s %s\n" "--set-default"          "Pick a default local Ollama model interactively"
        printf "  %-28s %s\n" "--set-anthropic-model"  "Pick a default Anthropic model interactively"
        printf "  %-28s %s\n" "--help, -h"             "Show this help message"
        echo ""
        echo (set_color --bold)"CURRENT DEFAULTS"(set_color normal)
        echo "  Local model:     $local_def"
        echo "  Anthropic model: $anth_def"
        echo ""
        echo (set_color --bold)"EXAMPLES"(set_color normal)
        echo "  lobby                          # start Claude Code with $local_def"
        echo "  lobby --anthropic              # start Claude Code with $anth_def via Anthropic API"
        echo "  lobby --set-default            # choose default local model"
        echo "  lobby --set-anthropic-model    # choose default Anthropic model"
        echo "  lobby 'fix the linting errors' # pass a prompt directly to Claude Code"
        echo ""
        echo (set_color --bold)"ENVIRONMENT (Ollama mode)"(set_color normal)
        echo "  ANTHROPIC_BASE_URL   $OLLAMA_URL"
        echo "  ANTHROPIC_AUTH_TOKEN ollama"
        echo "  ANTHROPIC_API_KEY    (empty)"
        echo ""
        echo (set_color --bold)"NOTES"(set_color normal)
        echo "  Ollama v0.14+ speaks the Anthropic Messages API natively — no proxy needed."
        echo "  In Anthropic mode, your ANTHROPIC_API_KEY from the environment is used."
        echo "  Models with at least 64k context are recommended for Claude Code."
        echo ""
        return 0
    end

    # ── --set-default (local Ollama model) ────────────────────────────────

    if test "$argv[1]" = "--set-default"
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _lobby_info "Starting Ollama briefly to list models..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_pid $last_pid
            set _started_ollama 1
            sleep 2
        end

        set models (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

        if test $_started_ollama -eq 1
            kill $_tmp_pid 2>/dev/null
        end

        if test (count $models) -eq 0
            _lobby_err "No local models found. Pull one first: ollama pull <model>"
            return 1
        end

        echo ""
        echo (set_color --bold)"Available local models:"(set_color normal)
        set current (_lobby_local_default)
        for i in (seq (count $models))
            if test "$models[$i]" = "$current"
                echo (set_color yellow)"  $i) $models[$i]  ✓ current default"(set_color normal)
            else
                echo "  $i) $models[$i]"
            end
        end
        echo ""

        while true
            read --prompt-str (set_color cyan)"[lobby]"(set_color normal)" Select a number (1-"(count $models)"): " choice
            if string match -qr '^\d+$' -- $choice
                and test $choice -ge 1
                and test $choice -le (count $models)
                break
            end
            _lobby_err "Please enter a number between 1 and "(count $models)"."
        end

        mkdir -p $CONFIG_DIR
        echo $models[$choice] > $LOCAL_DEFAULT_FILE
        _lobby_ok "Local default model set to: $models[$choice]"
        return 0
    end

    # ── --set-anthropic-model ─────────────────────────────────────────────

    if test "$argv[1]" = "--set-anthropic-model"
        # Curated list of current Claude Code-capable models
        set models \
            "claude-opus-4-5" \
            "claude-sonnet-4-5" \
            "claude-haiku-4-5"

        echo ""
        echo (set_color --bold)"Available Anthropic models:"(set_color normal)
        set current (_lobby_anthropic_default)
        for i in (seq (count $models))
            if test "$models[$i]" = "$current"
                echo (set_color yellow)"  $i) $models[$i]  ✓ current default"(set_color normal)
            else
                echo "  $i) $models[$i]"
            end
        end
        echo ""

        while true
            read --prompt-str (set_color cyan)"[lobby]"(set_color normal)" Select a number (1-"(count $models)"): " choice
            if string match -qr '^\d+$' -- $choice
                and test $choice -ge 1
                and test $choice -le (count $models)
                break
            end
            _lobby_err "Please enter a number between 1 and "(count $models)"."
        end

        mkdir -p $CONFIG_DIR
        echo $models[$choice] > $ANTHROPIC_DEFAULT_FILE
        _lobby_ok "Anthropic default model set to: $models[$choice]"
        return 0
    end

    # ── --anthropic mode ──────────────────────────────────────────────────

    if test "$argv[1]" = "--anthropic"
        set model (_lobby_anthropic_default)
        set passthrough_args $argv[2..]

        if not set -q ANTHROPIC_API_KEY; or test -z "$ANTHROPIC_API_KEY"
            _lobby_err "ANTHROPIC_API_KEY is not set. Add it to your fish config:"
            _lobby_err "  set -Ux ANTHROPIC_API_KEY sk-ant-..."
            return 1
        end

        _lobby_info "Mode: Anthropic API"
        _lobby_info "Model: $model"

        # Unset any Ollama overrides that might be lingering in the environment
        set -e ANTHROPIC_BASE_URL 2>/dev/null
        set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null

        exec claude --model $model $passthrough_args
        return
    end

    # ── Ollama (local) mode — default ────────────────────────────────────

    set model (_lobby_local_default)
    set passthrough_args $argv

    # Ensure Ollama is running
    if not pgrep -x ollama > /dev/null
        _lobby_info "Starting Ollama server..."
        ollama serve > /dev/null 2>&1 &
        sleep 2
    end

    # Pull model if not already cached
    _lobby_info "Ensuring model '$model' is available..."
    ollama pull $model

    _lobby_info "Mode: local Ollama ($OLLAMA_URL)"
    _lobby_info "Model: $model"

    ANTHROPIC_BASE_URL=$OLLAMA_URL \
    ANTHROPIC_AUTH_TOKEN=ollama \
    ANTHROPIC_API_KEY="" \
        exec claude --model $model $passthrough_args

end
