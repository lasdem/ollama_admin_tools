#!/bin/bash

# ==============================================================================
# A utility to manage the 'num_ctx' parameter for Ollama models. It provides
# rich, informative output about the state before and after changes.
#
# Features:
# - Interactive per-model confirmation [y/N/all].
# - Non-interactive mode with '-y' to confirm all changes.
# - Global context ceiling with '-m <value>' to cap memory usage.
# - Force mode with '-f' to overwrite models that already have a num_ctx set.
# - Single model or batch mode operation.
# - Handles international number formats for context size.
#
# --- USAGE ---
#
# Update a SINGLE model to its native max context:
#   ./set_max_ctx.sh llama3.3:latest
#
# Update a SINGLE model, capping its context at 16k:
#   ./set_max_ctx.sh -m 16384 llama3.3:latest
#
# Update ALL models (interactively), capping at 128k:
#   ./set_max_ctx.sh -m 131072
# ==============================================================================

# --- Default values ---
CONFIRM_ALL=false
FORCE_UPDATE=false
GLOBAL_MAX_CTX=""
TARGET_MODEL=""

# --- Helper function for usage instructions ---
usage() {
    echo "ℹ️  Usage: $0 [-y] [-f] [-m <value>] [model_name]"
    echo
    echo "Modes:"
    echo "  Batch Mode:   If [model_name] is omitted, the script checks all models."
    echo "  Single Mode:  If [model_name] is provided, only that model is updated."
    echo
    echo "Options:"
    echo "  -y, --yes          Automatically confirm all changes without prompting."
    echo "  -f, --force        Force update even if a 'num_ctx' is already set."
    echo "  -m, --max-ctx    (Optional) Set a maximum context size to act as a cap."
    echo "                   (Thousand separators '.' and ',' are supported)"
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
                    echo "❌  Error: --max-ctx requires a valid numeric argument." >&2
                    exit 1
                fi
                shift 2
            else
                echo "❌  Error: --max-ctx requires an argument." >&2
                usage
            fi
            ;;
        -*)
            echo "❌  Error: Unknown option '$1'" >&2
            usage
            ;;
        *)
            if [[ -z "$TARGET_MODEL" ]]; then
                TARGET_MODEL="$1"
                shift
            else
                echo "❌  Error: Only one model name can be specified." >&2
                usage
            fi
            ;;
    esac
done

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
        # Show just the parameters section for a clean verification
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

    echo "ℹ️  Discovered model's native context length: $MODEL_NATIVE_CTX"
    
    FINAL_CTX=$MODEL_NATIVE_CTX
    if [[ -n "$GLOBAL_MAX_CTX" && "$MODEL_NATIVE_CTX" -gt "$GLOBAL_MAX_CTX" ]]; then
        echo "⚠️  capping at $GLOBAL_MAX_CTX."
        FINAL_CTX=$GLOBAL_MAX_CTX
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