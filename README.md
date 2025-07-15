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

```bash
# Update a single model to its native max context:
./set_max_ctx.sh llama3.3:latest

# Update a single model, capping its context at 16k:
./set_max_ctx.sh -m 16384 llama3.3:latest

# Update ALL models (interactively), capping at 128k:
./set_max_ctx.sh -m 131072
```

## Examples

### Scenario: Optimizing Context Sizes on Memory-Constrained System

If you have a system with limited RAM but want to use the maximum practical context size:

```bash
# Set all models to use at most 8k context
./set_max_ctx.sh -y -m 8192
```

### Scenario: Regular Model Updates

Add to your crontab for weekly updates:

```bash
0 2 * * 0 /path/to/update_all_models.sh > /path/to/update_log.txt 2>&1
```

## Contributing

Contributions are welcome! Feel free to submit pull requests or create issues for bugs and feature requests.

## License

MIT License
