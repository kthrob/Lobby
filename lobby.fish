# ~/.config/fish/functions/lobby.fish
#
# Usage:
#   lobby                        # run claude code with saved default local model
#   lobby --anthropic            # run claude code against Anthropic's API
#   lobby --set                  # toggle which models are enabled for lobby
#   lobby --list                 # list models currently enabled for lobby
#   lobby --set-default          # pick a default from locally installed Ollama models
#   lobby --set-anthropic-model  # pick a default Anthropic model
#   lobby --help / -h            # show this help

function lobby --description "Run Claude Code against local Ollama or Anthropic"

    set CONFIG_DIR           "$HOME/.config/lobby"
    set LOCAL_DEFAULT_FILE   "$CONFIG_DIR/default_local_model"
    set ENABLED_FILE         "$CONFIG_DIR/enabled_models"
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
    function _lobby_warn
        echo (set_color yellow)"[lobby]"(set_color normal) $argv
    end

    function _lobby_saved_default --argument-names default_file builtin_default
        if test -n "$default_file"; and test -f "$default_file"
            set saved_model (string trim -- (cat "$default_file" 2>/dev/null))
            if test -n "$saved_model"
                echo $saved_model
            else
                echo $builtin_default
            end
        else
            echo $builtin_default
        end
    end

    function _lobby_enabled_models --argument-names enabled_file
        if test -f "$enabled_file"
            for model in (cat "$enabled_file" 2>/dev/null | string trim | string match -rv '^$')
                echo $model
            end
        end
    end

    function _lobby_local_models
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _lobby_info "Starting Ollama server briefly to list models..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_ollama_pid $last_pid
            set _started_ollama 1
            sleep 2
        end

        set models (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

        if test $_started_ollama -eq 1
            kill $_tmp_ollama_pid 2>/dev/null
        end

        for model in $models
            echo $model
        end
    end

    function _lobby_pull_model --argument-names model_name
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _lobby_info "Starting Ollama server briefly to pull '$model_name'..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_ollama_pid $last_pid
            set _started_ollama 1
            sleep 2
        end

        ollama pull $model_name
        set pull_status $status

        if test $_started_ollama -eq 1
            kill $_tmp_ollama_pid 2>/dev/null
        end

        return $pull_status
    end

    # ── --help ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--help" -o "$argv[1]" = "-h"
        set current (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)
        echo ""
        echo (set_color --bold)"lobby"(set_color normal)" — Claude Code launcher (local Ollama or Anthropic)"
        echo ""
        echo (set_color --bold)"USAGE"(set_color normal)
        echo "  lobby [claude args...]          Run Claude Code via local Ollama"
        echo "  lobby --anthropic [claude args] Run Claude Code via Anthropic API"
        echo ""
        echo (set_color --bold)"OPTIONS"(set_color normal)
        printf "  %-28s %s\n" "--set"                 "Interactively toggle which local models are enabled for lobby"
        printf "  %-28s %s\n" "--list"                "Show currently enabled models"
        printf "  %-28s %s\n" "--set-default"         "Pick a default from locally installed Ollama models"
        printf "  %-28s %s\n" "--set-anthropic-model" "Pick a default Anthropic model"
        printf "  %-28s %s\n" "--anthropic"           "Use Anthropic's API instead of local Ollama"
        printf "  %-28s %s\n" "--help, -h"            "Show this help message"
        echo ""
        echo (set_color --bold)"CURRENT DEFAULTS"(set_color normal)
        echo "  Local model:     $current"
        echo ""
        echo (set_color --bold)"EXAMPLES"(set_color normal)
        echo "  lobby                          # start Claude Code with $current"
        echo "  lobby --set                    # choose which models lobby is allowed to use"
        echo "  lobby --list                   # list currently enabled models"
        echo "  lobby --set-default            # choose default local model"
        echo "  lobby --set-anthropic-model    # choose default Anthropic model"
        echo "  lobby --anthropic              # start Claude Code via Anthropic API"
        echo "  lobby 'fix the linting errors' # pass a prompt directly to Claude Code"
        echo ""
        echo (set_color --bold)"ENVIRONMENT (Ollama mode)"(set_color normal)
        echo "  ANTHROPIC_BASE_URL   $OLLAMA_URL"
        echo "  ANTHROPIC_AUTH_TOKEN ollama"
        echo "  ANTHROPIC_API_KEY    (empty)"
        echo ""
        echo (set_color --bold)"NOTES"(set_color normal)
        echo "  If '$ENABLED_FILE' exists, only listed models can be launched with lobby."
        echo "  Ollama v0.14+ speaks the Anthropic Messages API natively — no proxy needed."
        echo "  In Anthropic mode, your ANTHROPIC_API_KEY from the environment is used."
        echo "  Models with at least 64k context are recommended for Claude Code."
        echo ""
        return 0
    end

    # ── --list ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--list"
        set current (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)

        if not test -f "$ENABLED_FILE"
            _lobby_info "No explicit enabled list set. All installed models are allowed."
            return 0
        end

        set enabled_models (_lobby_enabled_models $ENABLED_FILE)
        if test (count $enabled_models) -eq 0
            _lobby_warn "No models are currently enabled."
            return 0
        end

        echo ""
        echo (set_color --bold)"Enabled models for lobby:"(set_color normal)
        for model in $enabled_models
            if test "$model" = "$current"
                echo (set_color yellow)"  • $model  ✓ current default"(set_color normal)
            else
                echo "  • $model"
            end
        end
        echo ""
        return 0
    end

    # ── --set ──────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--set"
        mkdir -p $CONFIG_DIR

        set models (_lobby_local_models)
        if test -f "$ENABLED_FILE"
            set enabled_models (_lobby_enabled_models $ENABLED_FILE)
        else
            set enabled_models $models
        end

        while true
            set current (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)

            echo ""
            echo (set_color --bold)"lobby model selector"(set_color normal)
            if test (count $models) -eq 0
                _lobby_warn "No local models found yet. Use 'pull <model>' to add one."
            else
                for i in (seq (count $models))
                    set model $models[$i]
                    set marker " "
                    if contains -- $model $enabled_models
                        set marker "x"
                    end

                    if test "$model" = "$current"
                        echo (set_color yellow)"  $i) [$marker] $model  ✓ current default"(set_color normal)
                    else
                        echo "  $i) [$marker] $model"
                    end
                end
            end

            echo ""
            echo "  number      toggle model"
            echo "  pull <name> pull model from Ollama and enable it"
            echo "  all         enable all listed models"
            echo "  none        disable all listed models"
            echo "  save        save and exit"
            echo "  q           cancel"

            read --prompt-str (set_color cyan)"[lobby]"(set_color normal)" set> " choice
            set choice (string trim -- "$choice")
            if test -z "$choice"
                continue
            end

            if string match -qri '^(q|quit)$' -- $choice
                _lobby_info "No changes saved."
                return 0
            else if string match -qri '^(save|s)$' -- $choice
                set normalized_enabled
                for model in $models
                    if contains -- $model $enabled_models
                        set -a normalized_enabled $model
                    end
                end
                set enabled_models $normalized_enabled

                if test (count $enabled_models) -gt 0
                    printf "%s\n" $enabled_models > $ENABLED_FILE
                else
                    cat /dev/null > $ENABLED_FILE
                end

                _lobby_ok "Saved "(count $enabled_models)" enabled model(s)."
                return 0
            else if string match -qri '^(all|a)$' -- $choice
                set enabled_models $models
                _lobby_ok "Enabled all listed models."
            else if string match -qri '^(none|n)$' -- $choice
                set enabled_models
                _lobby_ok "Disabled all listed models."
            else if string match -qri '^pull\s+\S+$' -- $choice
                set model_to_pull (string replace -r '^[Pp][Uu][Ll][Ll]\s+' '' -- $choice)
                _lobby_info "Pulling model '$model_to_pull'..."
                if _lobby_pull_model $model_to_pull
                    set models (_lobby_local_models)
                    if not contains -- $model_to_pull $enabled_models
                        set -a enabled_models $model_to_pull
                    end

                    set normalized_enabled
                    for model in $models
                        if contains -- $model $enabled_models
                            set -a normalized_enabled $model
                        end
                    end
                    set enabled_models $normalized_enabled

                    _lobby_ok "Pulled and enabled: $model_to_pull"
                else
                    _lobby_err "Failed to pull model: $model_to_pull"
                end
            else if string match -qr '^\d+$' -- $choice
                if test (count $models) -eq 0
                    _lobby_err "No models to toggle yet. Use: pull <model>"
                    continue
                end

                if test $choice -ge 1; and test $choice -le (count $models)
                    set selected $models[$choice]
                    if contains -- $selected $enabled_models
                        set idx (contains -i -- $selected $enabled_models)
                        set -e enabled_models[$idx]
                        _lobby_info "Disabled: $selected"
                    else
                        set -a enabled_models $selected
                        _lobby_info "Enabled: $selected"
                    end
                else
                    _lobby_err "Please enter a number between 1 and "(count $models)"."
                end
            else
                _lobby_err "Unknown input. Use a number, pull <name>, all, none, save, or q."
            end
        end
    end

    # ── --set-default (local Ollama model) ────────────────────────────────

    if test "$argv[1]" = "--set-default"
        set models (_lobby_local_models)
        set enabled_file_exists 0

        if test -f "$ENABLED_FILE"
            set enabled_file_exists 1
            set enabled_models (_lobby_enabled_models $ENABLED_FILE)

            if test (count $enabled_models) -eq 0
                _lobby_err "No models are enabled for lobby. Run: lobby --set"
                return 1
            end

            set filtered_models
            for model in $models
                if contains -- $model $enabled_models
                    set -a filtered_models $model
                end
            end
            set models $filtered_models
        end

        if test (count $models) -eq 0
            if test $enabled_file_exists -eq 1
                _lobby_err "No enabled models are installed. Run: lobby --set (and use pull <model> if needed)."
            else
                _lobby_err "No models found. Pull one first with: ollama pull <model>"
            end
            return 1
        end

        # Print numbered list
        echo ""
        echo (set_color --bold)"Available models:"(set_color normal)
        set current (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)
        for i in (seq (count $models))
            if test "$models[$i]" = "$current"
                echo (set_color yellow)"  $i) $models[$i]  ✓ current default"(set_color normal)
            else
                echo "  $i) $models[$i]"
            end
        end
        echo ""

        # Prompt for selection
        while true
            read --prompt-str (set_color cyan)"[lobby]"(set_color normal)" Select a number (1-"(count $models)"): " choice
            if string match -qr '^\d+$' -- $choice
                and test $choice -ge 1
                and test $choice -le (count $models)
                break
            end
            _lobby_err "Please enter a number between 1 and "(count $models)"."
        end

        set selected $models[$choice]
        mkdir -p $CONFIG_DIR
        echo $selected > $LOCAL_DEFAULT_FILE
        _lobby_ok "Default model set to: $selected"
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
        set current (_lobby_saved_default $ANTHROPIC_DEFAULT_FILE $BUILTIN_ANTHROPIC)
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
        set model (_lobby_saved_default $ANTHROPIC_DEFAULT_FILE $BUILTIN_ANTHROPIC)
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

        claude --model $model $passthrough_args
        return
    end

    # ── Ollama (local) mode — default ────────────────────────────────────

    set enabled_file_exists 0
    set enabled_models
    if test -f "$ENABLED_FILE"
        set enabled_file_exists 1
        set enabled_models (_lobby_enabled_models $ENABLED_FILE)
    end

    # Use passed model, or fall back to saved/builtin default
    if test (count $argv) -gt 0
        set MODEL $argv[1]

        if test $enabled_file_exists -eq 1
            if test (count $enabled_models) -eq 0
                _lobby_err "No models are enabled. Run: lobby --set"
                return 1
            end

            if not contains -- $MODEL $enabled_models
                _lobby_err "Model '$MODEL' is not enabled for lobby. Run: lobby --set"
                return 1
            end
        end
    else
        set MODEL (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)

        if test $enabled_file_exists -eq 1
            if test (count $enabled_models) -eq 0
                _lobby_err "No models are enabled. Run: lobby --set"
                return 1
            end

            if not contains -- $MODEL $enabled_models
                set MODEL $enabled_models[1]
                _lobby_warn "Saved default is not enabled; using first enabled model: $MODEL"
            else
                _lobby_info "Using default model: $MODEL"
            end
        else
            _lobby_info "Using default model: $MODEL"
        end
    end

    # Ensure Ollama is running
    if not pgrep -x ollama > /dev/null
        _lobby_info "Starting Ollama server..."
        ollama serve > /dev/null 2>&1 &
        sleep 2
    end

    # Pull model if not already cached
    _lobby_info "Ensuring model '$MODEL' is available..."
    ollama pull $MODEL

    _lobby_info "Mode: local Ollama ($OLLAMA_URL)"
    _lobby_info "Model: $MODEL"

    ANTHROPIC_BASE_URL=$OLLAMA_URL \
    ANTHROPIC_AUTH_TOKEN=ollama \
    ANTHROPIC_API_KEY="" \
        claude --model $MODEL $passthrough_args

end
