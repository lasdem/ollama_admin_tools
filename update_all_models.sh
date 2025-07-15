#!/bin/bash

# ==============================================================================
# A utility to update all installed models on Ollama models. 
#
# --- USAGE ---
#   ./update_all_models.sh
# ==============================================================================

ollama list | awk 'NR>1 {print $1}' | while read -r model_name; do                                                                                                                                                                                          echo "--- Pulling latest for $model_name ---"
  ollama pull "$model_name"
  echo "" # Add a newline for better readability
done

echo "--- All models checked/updated. ---"
