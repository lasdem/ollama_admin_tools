#!/bin/bash

# ==============================================================================
# set_max_ctx.sh
#
# A utility to manage the 'num_ctx' parameter for Ollama models. It provides
# rich, informative output about the state before and after changes.
#
# --- USAGE ---
#
# Update a SINGLE model to its native max context:
#   ./set_max_ctx.sh llama3.3:latest
#
# Update a SINGLE model, CAPPING its context at 16k:
#   ./set_max_ctx.sh -m 16384 llama3.3:latest
#
# Update a SINGLE model, SETTING its context to exactly 8k:
#   ./set_max_ctx.sh -s 8192 llama3.3:
#
# Update ALL models (interactively), capping at 128k:
#   ./set_max_ctx.sh -m 131072
# ==============================================================================

# --- Default values ---
CONFIRM_ALL=false
FORCE_UPDATE=false
GLOBAL_MAX_CTX=""
SPECIFIC_CTX=""
TARGET_MODEL=""

# --- Helper function for usage instructions ---
usage() {
    echo "ℹ️  Usage: $0 [-y] [-f] [-m <value> | -s <value>] [model_name]"
    echo
    echo "Modes:"
    echo "  Batch Mode:   If [model_name] is omitted, the script checks all models."
    echo "  Single Mode:  If [model_name] is provided, only that model is updated."
    echo
    echo "Options:"
    echo "  -y, --yes          Automatically confirm all changes without prompting."
    echo "  -f, --force        Force update even if a 'num_ctx' is already set."
    echo "  -m, --max-ctx    (Optional) Set a MAXIMUM context size to act as a cap."
    echo "  -s, --set-ctx    (Optional) Set a SPECIFIC context size, ignoring the model's native value."
    echo "                   (Options -m and -s cannot be used together)"
    echo "                   (Thousand separators '.' and ',' are supported for values)"
    exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            CONFIRM_ALL=true
            shift
            ;;
        -f|--force)
            FORCE_UPDATE=true
            shift
            ;;
        -m|--max-ctx)
            if [[ -n "$2" ]]; then
                GLOBAL_MAX_CTX=$(echo "$2" | tr -d '.,')
                if ! [[ "$GLOBAL_MAX_CTX" =~ ^[0-9]+$ ]]; then
                    echo "❌  Error: --max-ctx requires a valid numeric argument." >&2; exit 1
                fi
                shift 2
            else
                echo "❌  Error: --max-ctx requires an argument." >&2; usage
            fi
            ;;
        -s|--set-ctx)
            if [[ -n "$2" ]]; then
                SPECIFIC_CTX=$(echo "$2" | tr -d '.,')
                if ! [[ "$SPECIFIC_CTX" =~ ^[0-9]+$ ]]; then
                    echo "❌  Error: --set-ctx requires a valid numeric argument." >&2; exit 1
                fi
                shift 2
            else
                echo "❌  Error: --set-ctx requires an argument." >&2; usage
            fi
            ;;
        -*)
            echo "❌  Error: Unknown option '$1'" >&2; usage
            ;;
        *)
            if [[ -z "$TARGET_MODEL" ]]; then
                TARGET_MODEL="$1"
                shift
            else
                echo "❌  Error: Only one model name can be specified." >&2; usage
            fi
            ;;
    esac
done

# --- Validate that -m and -s are not used together ---
if [[ -n "$GLOBAL_MAX_CTX" && -n "$SPECIFIC_CTX" ]]; then
    echo "❌  Error: The --max-ctx (-m) and --set-ctx (-s) options are mutually exclusive." >&2
    usage
fi

# --- Core logic in a function ---
update_model() {
    local model_name_to_update="$1"
    local ctx_to_set="$2"
    local temp_modelfile="./temp_model_override.Modelfile"

    echo "ℹ️  Creating temporary Modelfile for '$model_name_to_update' with context $ctx_to_set..."
    cat > "$temp_modelfile" <<EOL
FROM $model_name_to_update
PARAMETER num_ctx $ctx_to_set
EOL

    echo "⚙️  Applying new configuration..."
    ollama create "$model_name_to_update" -f "$temp_modelfile"

    if [ $? -eq 0 ]; then
        echo "✅  Successfully updated '$model_name_to_update'."
        echo "ℹ️  Verifying new parameters:"
        ollama show "$model_name_to_update" | grep -A 10 "Parameters"
    else
        echo "❌  An error occurred while updating '$model_name_to_update'."
    fi

    rm "$temp_modelfile"
}

# --- Main processing logic for a single model ---
process_model() {
    local model_name="$1"
    
    echo "----------------------------------------"
    echo "🔎  Processing model: $model_name"

    MODEL_INFO=$(ollama show "$model_name" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌  Error: Could not get information for '$model_name'. Does the model exist?"
        return 1
    fi

    if echo "$MODEL_INFO" | grep -A 10 "Parameters" | grep -q -w "num_ctx"; then
        EXISTING_CTX=$(echo "$MODEL_INFO" | grep -w "num_ctx" | awk '{print $NF}')
        if [ "$FORCE_UPDATE" = false ]; then
            echo "ℹ️  Model already has 'num_ctx' set to $EXISTING_CTX. Skipping (use -f to override)."
            return 0
        else
            echo "⚠️  Model has 'num_ctx' set to $EXISTING_CTX. --force is active, proceeding to overwrite."
        fi
    fi

    MODEL_NATIVE_CTX=$(echo "$MODEL_INFO" | grep "context length" | awk '{print $NF}')
    if [ -z "$MODEL_NATIVE_CTX" ] || ! [[ "$MODEL_NATIVE_CTX" =~ ^[0-9]+$ ]]; then
        echo "ℹ️  Could not determine a valid 'context length' for $model_name. Skipping."
        return 0
    fi
    
    # Always display the discovered native context
    echo "ℹ️  Discovered model's native context length: $MODEL_NATIVE_CTX"

    local FINAL_CTX=""

    if [[ -n "$SPECIFIC_CTX" ]]; then
        # If -s is used, it takes highest priority.
        FINAL_CTX=$SPECIFIC_CTX
        echo "ℹ️  Setting specific context size to $FINAL_CTX as requested by --set-ctx."
    elif [[ -n "$GLOBAL_MAX_CTX" && "$MODEL_NATIVE_CTX" -gt "$GLOBAL_MAX_CTX" ]]; then
        # If -m is used and native context is larger, apply the cap.
        FINAL_CTX=$GLOBAL_MAX_CTX
        echo "⚠️  Capping at $GLOBAL_MAX_CTX as requested by --max-ctx."
    else
        # Otherwise, use the model's native context length.
        FINAL_CTX=$MODEL_NATIVE_CTX
        echo "ℹ️  Using native context length of $FINAL_CTX."
    fi

    if [ "$CONFIRM_ALL" = false ]; then
        read -p "❓  Update $model_name to use context size $FINAL_CTX? [y/N/all] " -n 1 -r
        echo
        if [[ "$REPLY" =~ ^[Aa]$ ]]; then
            echo "‼️  Confirming for this and all subsequent models."
            CONFIRM_ALL=true
        elif [[ ! "$REPLY" =~ ^[Yy]$ ]];then
            echo "ℹ️  Skipping update for $model_name."
            return 0
        fi
    fi

    update_model "$model_name" "$FINAL_CTX"
}


# ==============================================================================
# --- SCRIPT ENTRYPOINT ---
# ==============================================================================

if [[ -n "$TARGET_MODEL" ]]; then
    echo "--- Single Model Mode ---"
    process_model "$TARGET_MODEL"
else
    echo "--- Batch Mode: Checking all installed models ---"

    MODEL_LIST=$(ollama list | awk 'NR>1 {print $1}')
    if [ -z "$MODEL_LIST" ]; then
        echo "❌  No Ollama models found. Exiting."
        exit 1
    fi

    for model_name_in_loop in $MODEL_LIST; do
        process_model "$model_name_in_loop"
    done
fi

echo "----------------------------------------"
echo
echo "--- Operation Complete ---"