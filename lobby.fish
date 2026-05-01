# ~/.config/fish/functions/lobby.fish
#
# Usage:
#   lobby                        # run claude code with saved default local model
#   lobby --model                # pick a model interactively, then run
#   lobby --model <name>         # run with a specific model (validated)
#   lobby --claude               # run claude code with your Claude.ai subscription (no API key needed)
#   lobby --claude --model       # pick model interactively for subscription mode
#   lobby --anthropic            # run claude code against Anthropic's API key
#   lobby --anthropic --model    # pick Anthropic model interactively, then run
#   lobby --set                  # toggle which models are enabled for lobby
#   lobby --list                 # list models currently enabled for lobby
#   lobby --set-default          # pick a default from locally installed Ollama models
#   lobby --set-anthropic-model  # pick a default Anthropic model
#   lobby --help / -h            # show this help

function lobby --description "Run Claude Code against local Ollama, Anthropic API, or Claude.ai subscription"

    set CONFIG_DIR           "$HOME/.config/lobby"
    set LOCAL_DEFAULT_FILE   "$CONFIG_DIR/default_local_model"
    set ENABLED_FILE         "$CONFIG_DIR/enabled_models"
    set ANTHROPIC_DEFAULT_FILE "$CONFIG_DIR/default_anthropic_model"
    set BUILTIN_LOCAL        "qwen2.5-coder:latest"
    set BUILTIN_ANTHROPIC    "claude-sonnet-4-6"
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

    function _lobby_wait_for_ollama
        set _attempts 0
        while test $_attempts -lt 10
            if curl -sf "$OLLAMA_URL" > /dev/null 2>&1
                return 0
            end
            sleep 1
            set _attempts (math $_attempts + 1)
        end
        return 1
    end

    function _lobby_local_models
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _lobby_info "Starting Ollama server briefly to list models..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_ollama_pid $last_pid
            set _started_ollama 1
            if not _lobby_wait_for_ollama
                _lobby_err "Ollama did not respond in time."
                kill $_tmp_ollama_pid 2>/dev/null
                return 1
            end
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
            if not _lobby_wait_for_ollama
                _lobby_err "Ollama did not respond in time."
                kill $_tmp_ollama_pid 2>/dev/null
                return 1
            end
        end

        ollama pull $model_name
        set pull_status $status

        if test $_started_ollama -eq 1
            kill $_tmp_ollama_pid 2>/dev/null
        end

        return $pull_status
    end

    # Print a numbered model list and prompt the user to pick one.
    # Prints the chosen model name to stdout; returns 1 on empty list.
    # --argument-names: models_var (name of list variable), default_model
    function _lobby_pick_model_interactive --argument-names default_model
        # Caller passes models as remaining argv after default_model
        set available_models $argv[2..]

        if test (count $available_models) -eq 0
            _lobby_err "No models available to pick from."
            return 1
        end

        echo ""
        echo (set_color --bold)"Available models:"(set_color normal)
        for i in (seq (count $available_models))
            if test "$available_models[$i]" = "$default_model"
                echo (set_color yellow)"  $i) $available_models[$i]  ✓ current default"(set_color normal)
            else
                echo "  $i) $available_models[$i]"
            end
        end
        echo ""

        while true
            read --prompt-str (set_color cyan)"[lobby]"(set_color normal)" Select a number (1-"(count $available_models)"): " choice
            if string match -qr '^\d+$' -- $choice
                and test $choice -ge 1
                and test $choice -le (count $available_models)
                echo $available_models[$choice]
                return 0
            end
            _lobby_err "Please enter a number between 1 and "(count $available_models)"."
        end
    end

    # ── unknown flag guard ─────────────────────────────────────────────────
    # All lobby flags start with --. Any unrecognised --word is a likely typo.
    # Catch it here before it silently becomes a model name or claude arg.

    set _known_flags --help -h --list --set --set-default --set-anthropic-model --anthropic --claude --model --memory

    if test (count $argv) -gt 0
        if string match -qr '^-' -- $argv[1]
            if not contains -- $argv[1] $_known_flags
                _lobby_err "Unknown option: $argv[1]"

                # Simple did-you-mean: find the known flag sharing the longest common prefix
                set _input $argv[1]
                set _best ""
                set _best_len 0
                for flag in $_known_flags
                    set _min_len (math "min("(string length -- $_input)", "(string length -- $flag)")")
                    set _shared 0
                    for j in (seq $_min_len)
                        if test (string sub -s $j -l 1 -- $_input) = (string sub -s $j -l 1 -- $flag)
                            set _shared (math $_shared + 1)
                        else
                            break
                        end
                    end
                    if test $_shared -gt $_best_len
                        set _best_len $_shared
                        set _best $flag
                    end
                end

                if test -n "$_best"; and test $_best_len -ge 3
                    _lobby_err "  Did you mean: $_best?"
                end
                echo ""
                echo "  Run "(set_color --bold)"lobby --help"(set_color normal)" for usage."
                echo ""
                return 1
            end
        end
    end

    # ── --help ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--help" -o "$argv[1]" = "-h"
        set current (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)
        echo ""
        echo (set_color --bold)"lobby"(set_color normal)" — Claude Code launcher (local Ollama or Anthropic)"
        echo ""
        echo (set_color --bold)"USAGE"(set_color normal)
        echo "  lobby                           Run Claude Code with your saved default local model"
        echo "  lobby --model                   Pick a local model interactively, then run"
        echo "  lobby --model <name>            Run with a specific local model (validated)"
        echo "  lobby --claude                  Run Claude Code with your Claude.ai subscription"
        echo "  lobby --claude --model          Pick model interactively for subscription mode"
        echo "  lobby --anthropic               Run Claude Code via Anthropic API key"
        echo "  lobby --anthropic --model       Pick Anthropic model interactively, then run"
        echo ""
        echo (set_color --bold)"OPTIONS"(set_color normal)
        printf "  %-28s %s\n" "--model [name]"        "Override the model; omit name to pick interactively"
        printf "  %-28s %s\n" "--claude"              "Use your Claude.ai subscription (Pro/Max/Team/Enterprise)"
        printf "  %-28s %s\n" "--memory"              "Show mem0 memory status (Qdrant, MCP registration)"
        printf "  %-28s %s\n" "--set"                 "Interactively toggle which local models are enabled for lobby"
        printf "  %-28s %s\n" "--list"                "Show currently enabled models"
        printf "  %-28s %s\n" "--set-default"         "Pick a default from locally installed Ollama models"
        printf "  %-28s %s\n" "--set-anthropic-model" "Pick a default Anthropic model"
        printf "  %-28s %s\n" "--anthropic"           "Use Anthropic's API key instead of local Ollama"
        printf "  %-28s %s\n" "--help, -h"            "Show this help message"
        echo ""
        echo (set_color --bold)"CURRENT DEFAULTS"(set_color normal)
        echo "  Local model:     $current"
        echo ""
        echo (set_color --bold)"EXAMPLES"(set_color normal)
        echo "  lobby                          # start Claude Code with $current (local)"
        echo "  lobby --model                  # pick a local model from a list, then launch"
        echo "  lobby --model mistral          # launch with mistral (validated)"
        echo "  lobby --claude                 # start Claude Code via Claude.ai subscription"
        echo "  lobby --claude --model         # pick a Claude model, then launch via subscription"
        echo "  lobby --set                    # choose which models lobby is allowed to use"
        echo "  lobby --list                   # list currently enabled models"
        echo "  lobby --set-default            # choose default local model"
        echo "  lobby --set-anthropic-model    # choose default Anthropic API model"
        echo "  lobby --anthropic              # start Claude Code via Anthropic API key"
        echo ""
        echo (set_color --bold)"ENVIRONMENT (Ollama mode)"(set_color normal)
        echo "  ANTHROPIC_BASE_URL   $OLLAMA_URL"
        echo "  ANTHROPIC_AUTH_TOKEN ollama"
        echo "  ANTHROPIC_API_KEY    (empty)"
        echo ""
        echo (set_color --bold)"NOTES"(set_color normal)
        echo "  --claude uses your logged-in Claude.ai session (run 'claude /login' first)."
        echo "  --anthropic uses your ANTHROPIC_API_KEY environment variable."
        echo "  If '$ENABLED_FILE' exists, only listed models can be launched with lobby."
        echo "  Ollama v0.14+ speaks the Anthropic Messages API natively — no proxy needed."
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

    # ── --memory ───────────────────────────────────────────────────────────

    if test "$argv[1]" = "--memory"
        echo ""
        echo (set_color --bold)"lobby memory (mem0)"(set_color normal)
        echo ""

        # Qdrant health
        if curl -sf "http://localhost:6333/healthz" > /dev/null 2>&1
            echo "  Qdrant:      "(set_color green)"running"(set_color normal)" — http://localhost:6333"

            # Try to get vector count from mem0 collection
            set _col_info (curl -s "http://localhost:6333/collections/mem0_mcp_selfhosted" 2>/dev/null)
            set _vec_count (echo $_col_info | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('vectors_count','?'))" 2>/dev/null)
            if test -n "$_vec_count"
                echo "  Memories:    $_vec_count stored vectors"
            else
                echo "  Memories:    (collection not yet initialised — run a lobby session first)"
            end
        else
            echo "  Qdrant:      "(set_color red)"not running"(set_color normal)
            echo ""
            echo "  Start it with:"
            echo "    "(set_color cyan)"docker compose up -d"(set_color normal)"   (from the lobby repo root)"
            echo ""
            echo "  Or start automatically by re-running:"
            echo "    "(set_color cyan)"fish setup.fish"(set_color normal)
        end

        # MCP registration status
        echo ""
        set _mcp_registered (claude mcp list 2>/dev/null | grep -c "mem0")
        if test "$_mcp_registered" -gt 0
            echo "  MCP server:  "(set_color green)"registered"(set_color normal)" (mem0 tools load in every claude session)"
        else
            echo "  MCP server:  "(set_color red)"not registered"(set_color normal)
            echo "  Register with: fish setup.fish   (from the lobby repo root)"
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
        set _sd_models (_lobby_local_models)
        set _sd_enabled_file_exists 0

        if test -f "$ENABLED_FILE"
            set _sd_enabled_file_exists 1
            set _sd_enabled (_lobby_enabled_models $ENABLED_FILE)

            if test (count $_sd_enabled) -eq 0
                _lobby_err "No models are enabled for lobby. Run: lobby --set"
                return 1
            end

            set _sd_filtered
            for m in $_sd_models
                if contains -- $m $_sd_enabled
                    set -a _sd_filtered $m
                end
            end
            set _sd_models $_sd_filtered
        end

        if test (count $_sd_models) -eq 0
            if test $_sd_enabled_file_exists -eq 1
                _lobby_err "No enabled models are installed. Run: lobby --set (and use pull <model> if needed)."
            else
                _lobby_err "No models found. Pull one first with: ollama pull <model>"
            end
            return 1
        end

        set _sd_current (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)
        set selected (_lobby_pick_model_interactive $_sd_current $_sd_models)
        or return 1

        mkdir -p $CONFIG_DIR
        echo $selected > $LOCAL_DEFAULT_FILE
        _lobby_ok "Default model set to: $selected"
        return 0
    end

    # ── --set-anthropic-model ─────────────────────────────────────────────

    if test "$argv[1]" = "--set-anthropic-model"
        # Curated list of current Claude Code-capable models.
        # Update this list when Anthropic releases new model generations.
        set _ant_models \
            "claude-opus-4-6" \
            "claude-sonnet-4-6" \
            "claude-haiku-4-5-20251001"

        set _ant_current (_lobby_saved_default $ANTHROPIC_DEFAULT_FILE $BUILTIN_ANTHROPIC)
        set selected (_lobby_pick_model_interactive $_ant_current $_ant_models)
        or return 1

        mkdir -p $CONFIG_DIR
        echo $selected > $ANTHROPIC_DEFAULT_FILE
        _lobby_ok "Anthropic default model set to: $selected"
        return 0
    end

    # ── --claude mode (Claude.ai subscription) ───────────────────────────
    # Uses the OAuth session from 'claude /login' — no API key required.
    # Clears all Ollama/gateway overrides so Claude Code uses its own auth.

    if test "$argv[1]" = "--claude"
        # Curated list of current Claude Code-capable models.
        # Update this list when Anthropic releases new model generations.
        set _claude_models \
            "claude-opus-4-6" \
            "claude-sonnet-4-6" \
            "claude-haiku-4-5-20251001"

        set _claude_default (_lobby_saved_default $ANTHROPIC_DEFAULT_FILE $BUILTIN_ANTHROPIC)

        # Check for --model as next arg
        if test "$argv[2]" = "--model"
            if test (count $argv) -ge 3
                # --model <name> supplied — validate against known list
                set _override $argv[3]
                if not contains -- $_override $_claude_models
                    _lobby_err "'$_override' is not a recognised Claude model."
                    _lobby_err "Known models: "(string join ", " $_claude_models)
                    return 1
                end
                set _claude_model $_override
                set passthrough_args $argv[4..]
            else
                # --model with no value — show picker
                set _claude_model (_lobby_pick_model_interactive $_claude_default $_claude_models)
                or return 1
                set passthrough_args $argv[3..]
            end
        else
            set _claude_model $_claude_default
            set passthrough_args $argv[2..]
        end

        _lobby_info "Mode: Claude.ai subscription"
        _lobby_info "Model: $_claude_model"
        _lobby_info "(Using your logged-in Claude.ai account — run 'claude /login' if not authenticated)"

        # Clear all Ollama/gateway overrides so Claude Code uses its own OAuth session
        set -e ANTHROPIC_BASE_URL 2>/dev/null
        set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null
        set -e ANTHROPIC_API_KEY 2>/dev/null

        claude --model $_claude_model $passthrough_args
        return
    end

    # ── --anthropic mode ──────────────────────────────────────────────────

    if test "$argv[1]" = "--anthropic"
        if not set -q ANTHROPIC_API_KEY; or test -z "$ANTHROPIC_API_KEY"
            _lobby_err "ANTHROPIC_API_KEY is not set. Add it to your fish config:"
            _lobby_err "  set -Ux ANTHROPIC_API_KEY sk-ant-..."
            return 1
        end

        # Curated list of current Claude Code-capable models.
        # Update this list when Anthropic releases new model generations.
        set _anthropic_models \
            "claude-opus-4-6" \
            "claude-sonnet-4-6" \
            "claude-haiku-4-5-20251001"

        set _anthropic_default (_lobby_saved_default $ANTHROPIC_DEFAULT_FILE $BUILTIN_ANTHROPIC)

        # Check for --model as next arg
        if test "$argv[2]" = "--model"
            if test (count $argv) -ge 3
                # --model <name> supplied — validate against known list
                set _override $argv[3]
                if not contains -- $_override $_anthropic_models
                    _lobby_err "'$_override' is not a recognised Anthropic model."
                    _lobby_err "Known models: "(string join ", " $_anthropic_models)
                    return 1
                end
                set model $_override
                set passthrough_args $argv[4..]
            else
                # --model with no value — show picker
                set model (_lobby_pick_model_interactive $_anthropic_default $_anthropic_models)
                or return 1
                set passthrough_args $argv[3..]
            end
        else
            set model $_anthropic_default
            set passthrough_args $argv[2..]
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

    # Build the candidate model list (all installed, filtered by allowlist if set)
    set _local_default (_lobby_saved_default $LOCAL_DEFAULT_FILE $BUILTIN_LOCAL)

    if test "$argv[1]" = "--model"
        # Need the model list for both picker and validation
        set _all_local (_lobby_local_models)
        if test $enabled_file_exists -eq 1
            set _candidate_models
            for m in $_all_local
                if contains -- $m $enabled_models
                    set -a _candidate_models $m
                end
            end
        else
            set _candidate_models $_all_local
        end

        if test (count $_candidate_models) -eq 0
            if test $enabled_file_exists -eq 1
                _lobby_err "No enabled models are installed. Run: lobby --set"
            else
                _lobby_err "No models found. Pull one with: ollama pull <model>"
            end
            return 1
        end

        if test (count $argv) -ge 2
            # --model <name> supplied — validate against installed/enabled models
            set _override $argv[2]
            if not contains -- $_override $_candidate_models
                if test $enabled_file_exists -eq 1
                    _lobby_err "'$_override' not found in your enabled models."
                else
                    _lobby_err "'$_override' not found in your installed models."
                end
                _lobby_err "Available: "(string join ", " $_candidate_models)
                _lobby_err "Run 'lobby --model' (no value) to pick interactively."
                return 1
            end
            set MODEL $_override
            set passthrough_args $argv[3..]
        else
            # --model with no value — interactive picker
            set MODEL (_lobby_pick_model_interactive $_local_default $_candidate_models)
            or return 1
            set passthrough_args $argv[2..]
        end
    else
        # No --model flag — use saved/builtin default
        set passthrough_args $argv[1..]
        set MODEL $_local_default

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
        if not _lobby_wait_for_ollama
            _lobby_err "Ollama did not respond after 10 s — check your Ollama installation."
            return 1
        end
    end

    # Pull model if not already cached
    _lobby_info "Ensuring model '$MODEL' is available..."
    ollama pull $MODEL

    _lobby_info "Mode: local Ollama ($OLLAMA_URL)"
    _lobby_info "Model: $MODEL"

    # Warn if Qdrant is down — memory won't persist, but Claude Code still works
    if not curl -sf "http://localhost:6333/healthz" > /dev/null 2>&1
        _lobby_warn "Qdrant not running — mem0 memory will be unavailable this session."
        _lobby_warn "Start it with: docker compose up -d  (from the lobby repo root)"
    end

    ANTHROPIC_BASE_URL=$OLLAMA_URL \
    ANTHROPIC_AUTH_TOKEN=ollama \
    ANTHROPIC_API_KEY="" \
        claude --model $MODEL $passthrough_args

end
