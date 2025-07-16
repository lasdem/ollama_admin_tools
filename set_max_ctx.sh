#!/bin/bash

# ==============================================================================
# set_max_ctx.sh
#
# A powerful utility to manage the 'num_ctx' parameter for Ollama models.
# It can overwrite existing models or create new, correctly-sized ones.
#
# ==============================================================================

# --- Default values ---
CONFIRM_ALL=false
FORCE_UPDATE=false
GLOBAL_MAX_CTX=""
SPECIFIC_CTX=""
TARGET_MODEL=""
AUTO_NAME=false
OUTPUT_NAME=""

# --- Helper function for usage instructions ---
usage() {
    echo "ℹ️  Usage: $0 [-y] [-f] [-a | -o <new_name>] [-m <size> | -s <size>] [model_name]"
    echo
    echo "Modes:"
    echo "  Batch Mode:   If [model_name] is omitted, the script checks all models."
    echo "  Single Mode:  If [model_name] is provided, only that model is processed."
    echo
    echo "Naming Options:"
    echo "  (default)          Overwrite the existing model tag."
    echo "  -a, --auto-name    Create a new model with an auto-generated tag (e.g., model:128k_num_ctx)."
    echo "  -o, --output-name  Create a new model with a specific custom name (single mode only)."
    echo "                     (Options -a and -o are mutually exclusive)"
    echo
    echo "Context Options:"
    echo "  -m, --max-ctx      (Optional) Set a MAXIMUM context size to act as a cap."
    echo "  -s, --set-ctx      (Optional) Set a SPECIFIC context size."
    echo "                     (Options -m and -s are mutually exclusive)"
    echo
    echo "Other Options:"
    echo "  -y, --yes          Automatically confirm all changes without prompting."
    echo "  -f, --force        Force update even if a 'num_ctx' is already set."
    echo "  -h, --help         Display this help message and exit."
    echo
    echo "Size Formats: Numbers (e.g., 8192), k/K (e.g., 8k), M/M (e.g., 1M) are supported."
    exit 1
}

# --- Helper function to parse human-readable sizes like "128k" or "1M" ---
parse_size() {
    local input_size cleaned_size num suffix
    input_size=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    cleaned_size=$(echo "$input_size" | tr -d '.,')
    
    num=$(echo "$cleaned_size" | sed -E 's/([km])$//')
    suffix=$(echo "$cleaned_size" | sed -E 's/^([0-9]+)//')

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi
    
    case "$suffix" in
        k) echo $((num * 1024)) ;;
        m) echo $((num * 1024 * 1024)) ;;
        *) echo "$num" ;;
    esac
}

# --- Helper function to format a number into a human-readable size tag ---
format_size_tag() {
    local num=$1
    if (( num % (1024*1024) == 0 )); then
        echo "$((num / 1024 / 1024))m"
    elif (( num % 1024 == 0 )); then
        echo "$((num / 1024))k"
    else
        echo "$num"
    fi
}


# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -y|--yes) CONFIRM_ALL=true; shift ;;
        -f|--force) FORCE_UPDATE=true; shift ;;
        -a|--auto-name) AUTO_NAME=true; shift ;;
        -o|--output-name)
            if [[ -n "$2" ]]; then OUTPUT_NAME="$2"; shift 2; else echo "❌ Error: --output-name requires an argument." >&2; usage; fi ;;
        -m|--max-ctx)
            if [[ -n "$2" ]]; then GLOBAL_MAX_CTX=$(parse_size "$2"); if [[ "$GLOBAL_MAX_CTX" == "0" ]]; then echo "❌ Error: Invalid numeric value for --max-ctx." >&2; exit 1; fi; shift 2; else echo "❌ Error: --max-ctx requires an argument." >&2; usage; fi ;;
        -s|--set-ctx)
            if [[ -n "$2" ]]; then SPECIFIC_CTX=$(parse_size "$2"); if [[ "$SPECIFIC_CTX" == "0" ]]; then echo "❌ Error: Invalid numeric value for --set-ctx." >&2; exit 1; fi; shift 2; else echo "❌ Error: --set-ctx requires an argument." >&2; usage; fi ;;
        -*) echo "❌ Error: Unknown option '$1'" >&2; usage ;;
        *) if [[ -z "$TARGET_MODEL" ]]; then TARGET_MODEL="$1"; shift; else echo "❌ Error: Only one model name can be specified." >&2; usage; fi ;;
    esac
done

# --- Validate mutually exclusive options ---
if [[ -n "$GLOBAL_MAX_CTX" && -n "$SPECIFIC_CTX" ]]; then echo "❌ Error: --max-ctx (-m) and --set-ctx (-s) are mutually exclusive." >&2; usage; fi
if [[ "$AUTO_NAME" = true && -n "$OUTPUT_NAME" ]]; then echo "❌ Error: --auto-name (-a) and --output-name (-o) are mutually exclusive." >&2; usage; fi
if [[ -z "$TARGET_MODEL" && -n "$OUTPUT_NAME" ]]; then echo "❌ Error: --output-name (-o) can only be used in single model mode." >&2; usage; fi


# --- Core logic in a function ---
update_model() {
    local source_model="$1"
    local dest_model="$2"
    local ctx_to_set="$3"
    local temp_modelfile="./temp_model_override.Modelfile"

    echo "ℹ️  Creating temporary Modelfile FROM '$source_model' with context $ctx_to_set..."
    cat > "$temp_modelfile" <<EOL
FROM $source_model
PARAMETER num_ctx $ctx_to_set
EOL

    echo "⚙️  Applying configuration to create '$dest_model'..."
    ollama create "$dest_model" -f "$temp_modelfile"

    if [ $? -eq 0 ]; then
        echo "✅  Successfully created/updated '$dest_model'."
        echo "ℹ️  Verifying new parameters:"
        ollama show "$dest_model" | grep -A 10 "Parameters"
    else
        echo "❌  An error occurred."
    fi

    rm "$temp_modelfile"
}

# --- Main processing logic for a single model ---
process_model() {
    local model_name="$1"
    
    echo "----------------------------------------"
    echo "🔎  Processing source model: $model_name"

    MODEL_INFO=$(ollama show "$model_name" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌  Error: Could not get information for '$model_name'. Does the model exist?"
        return 1
    fi

    # The overwrite check is only relevant if we are not creating a new model
    if [[ "$AUTO_NAME" = false && -z "$OUTPUT_NAME" ]]; then
      if echo "$MODEL_INFO" | grep -A 10 "Parameters" | grep -q -w "num_ctx"; then
          EXISTING_CTX=$(echo "$MODEL_INFO" | grep -w "num_ctx" | awk '{print $NF}')
          if [ "$FORCE_UPDATE" = false ]; then
              echo "ℹ️  Model already has 'num_ctx' set to $EXISTING_CTX. Skipping (use -f to override)."
              return 0
          else
              echo "⚠️  Model has 'num_ctx' set to $EXISTING_CTX. --force is active, proceeding to overwrite."
          fi
      fi
    fi

    MODEL_NATIVE_CTX=$(echo "$MODEL_INFO" | grep "context length" | awk '{print $NF}')
    if [ -z "$MODEL_NATIVE_CTX" ] || ! [[ "$MODEL_NATIVE_CTX" =~ ^[0-9]+$ ]]; then
        echo "ℹ️  Could not determine a valid 'context length' for $model_name. Skipping."
        return 0
    fi
    echo "ℹ️  Discovered model's native context length: $MODEL_NATIVE_CTX"

    local FINAL_CTX=""
    if [[ -n "$SPECIFIC_CTX" ]]; then
        FINAL_CTX=$SPECIFIC_CTX
        echo "ℹ️  Action: SET specific context to $FINAL_CTX as requested by --set-ctx."
    elif [[ -n "$GLOBAL_MAX_CTX" && "$MODEL_NATIVE_CTX" -gt "$GLOBAL_MAX_CTX" ]]; then
        FINAL_CTX=$GLOBAL_MAX_CTX
        echo "⚠️  Action: CAP native context at $FINAL_CTX as requested by --max-ctx."
    else
        FINAL_CTX=$MODEL_NATIVE_CTX
        echo "ℹ️  Action: USE native context length of $FINAL_CTX."
    fi

    local DEST_MODEL_NAME="$model_name"
    if [[ "$AUTO_NAME" = true ]]; then
        BASE_NAME=$(echo "$model_name" | cut -d: -f1)
        SIZE_TAG=$(format_size_tag "$FINAL_CTX")
        DEST_MODEL_NAME="${BASE_NAME}:${SIZE_TAG}_num_ctx"
        echo "ℹ️  New model name will be auto-generated: $DEST_MODEL_NAME"
    elif [[ -n "$OUTPUT_NAME" ]]; then
        DEST_MODEL_NAME="$OUTPUT_NAME"
        echo "ℹ️  New model name will be set to custom name: $DEST_MODEL_NAME"
    else
        echo "ℹ️  Action: OVERWRITE existing model tag: $model_name"
    fi

    if [ "$CONFIRM_ALL" = false ]; then
        read -p "❓  Proceed with this action? [y/N/all] " -n 1 -r
        echo
        if [[ "$REPLY" =~ ^[Aa]$ ]]; then
            echo "❗  Confirming for this and all subsequent models."
            CONFIRM_ALL=true
        elif [[ ! "$REPLY" =~ ^[Yy]$ ]];then
            echo "ℹ️  Skipping action for $model_name."
            return 0
        fi
    fi

    update_model "$model_name" "$DEST_MODEL_NAME" "$FINAL_CTX"
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
    if [ -z "$MODEL_LIST" ]; then echo "❌ No Ollama models found. Exiting."; exit 1; fi
    for model_name_in_loop in $MODEL_LIST; do process_model "$model_name_in_loop"; done
fi

echo "----------------------------------------"
echo
echo "--- Operation Complete ---"