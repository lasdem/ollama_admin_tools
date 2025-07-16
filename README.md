# Ollama Admin Tools

A collection of utility scripts for managing Ollama models on Linux systems. These tools help simplify common administration tasks for your Ollama server.

## What is Ollama?

Ollama is a framework that allows you to run large language models locally. These utilities help you manage your Ollama installation more efficiently.

## Tools Included

### 1. Update All Models (update_all_models.sh)

Automatically checks for and pulls the latest versions of all installed Ollama models.

**Features:**
- Updates all models in sequence
- Provides clear feedback during the update process

### 2. Context Size Manager (set_max_ctx.sh)

A powerful utility to optimize and manage the context window size for your Ollama models.
Ollama per default limits context size for models and with this utility you can set it to the models trained context size. 

**Features:**
- Interactive per-model confirmation [y/N/all]
- Non-interactive mode with `-y` for batch processing
- Global context size cap with `-m <value>`
- Force mode to overwrite existing context settings
- Single model or batch mode operation
- Support for international number formats

## Requirements
- Linux operating system
- Ollama installed and configured
- Bash shell

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/ollama-admin-tools.git
   cd ollama-admin-tools
   ```

2. Make the scripts executable:
   ```bash
   chmod +x *.sh
   ```

## Usage

### Managing a Remote Ollama Server

By default, these tools connect to your local Ollama instance. To manage a remote Ollama server:

```bash
export OLLAMA_HOST="http://your-remote-server:11434"
```

### Updating All Models

To check and update all your installed models to their latest versions:

```bash
./update_all_models.sh
```

### Managing Context Window Sizes

#### Usage Examples

```bash
# Display help information:
./set_max_ctx.sh --help

# Single Model Operations:
./set_max_ctx.sh llama3.3:latest                              # Update using native context
./set_max_ctx.sh -y llama3.3:latest                           # Update without confirmation prompt
./set_max_ctx.sh -f llama3.3:latest                           # Force update even if context already set
./set_max_ctx.sh -s 4096 llama3.3:latest                      # Set specific context size (4096)
./set_max_ctx.sh -s 32k llama3.3:latest                       # Set specific context size (32k)
./set_max_ctx.sh -m 8192 llama3.3:latest                      # Cap context at 8192
./set_max_ctx.sh -m 8k llama3.3:latest                        # Cap context at 8K (equivalent to 8192)

# New Model Operations:
./set_max_ctx.sh -a llama3.3:latest                           # Auto-named model with native context (e.g., 'llama3.3:128k_num_ctx')
./set_max_ctx.sh -a -m 16k llama3.3:latest                    # Auto-named model with capped context (e.g., 'llama3.3:16k_num_ctx')
./set_max_ctx.sh -a -s 4096 llama3.3:latest                   # Auto-named model with specific context (e.g., 'llama3.3:4k_num_ctx')
./set_max_ctx.sh -o llama3.3:full_context llama3.3:latest     # Custom-named model with native context
./set_max_ctx.sh -o llama3.3:large -m 32k llama3.3:latest     # Custom-named model with capped context
./set_max_ctx.sh -o llama3.3:4k -s 4096 llama3.3:latest       # Custom-named model with specific context

# Batch Operations (All Installed Models):
./set_max_ctx.sh                                              # Interactive update of all models (native context)
./set_max_ctx.sh -y                                           # Non-interactive update of all models (native context)
./set_max_ctx.sh -y -f                                        # Force update all models, no confirmations
./set_max_ctx.sh -y -m 8k                                     # Update all models, cap at 8K
./set_max_ctx.sh -y -s 4096                                   # Update all models to exactly 4096 context
./set_max_ctx.sh -a                                           # Create auto-named copies of all models with their native max context
./set_max_ctx.sh -a -m 16k                                    # Create auto-named copies capped at 16K

# Combined Options:
./set_max_ctx.sh -y -f -m 32k llama3.3:latest                 # Force update with no confirmation, cap at 32K
./set_max_ctx.sh -y -f -a -m 16k llama3.3:latest              # Create auto-named model, force, no confirmation, cap at 16K
```

## Examples

### Scenario: Optimizing Context Sizes on Memory-Constrained System

If you have a system with limited RAM but want to use the maximum practical context size:

```bash
# Set all models to use at most 8k context but keeping their original names.
./set_max_ctx.sh -y -m 8k
```

Or create copies with new auto named models

```bash
# create new models to use at most 8k context with auto generated names.
./set_max_ctx.sh -y -m 8k -a
```

### Scenario: Regular Model Updates

Add to your crontab for weekly updates:

```bash
0 2 * * 0 /path/to/update_all_models.sh > /path/to/update_log.txt 2>&1 && /path/to/set_max_ctx.sh -y -m 32k -a >> /path/to/update_log.txt 2>&1
```

## Contributing

Contributions are welcome! Feel free to submit pull requests or create issues for bugs and feature requests.

## License

MIT License
