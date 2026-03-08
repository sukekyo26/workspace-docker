# Reference

## Pre-installed Applications

### Development Tools

**Plugin Tools** (configured via `workspace.toml`, defined in `plugins/*.toml`):
- **Docker CLI** (`docker-cli`, default: on) — Container operations (using host Docker daemon via socket mount)
- **proto** (`proto`) — Unified multi-language version manager (Python, Node.js, Bun, Deno, Go, Rust, 100+ tools)
- **AWS CLI v2** (`aws-cli`) — AWS resource management
- **AWS SAM CLI** (`aws-sam-cli`) — Build, test and invoke serverless Lambda functions locally
- **GitHub CLI** (`github-cli`) — GitHub command-line interface for repository management and workflows
- **GitHub Copilot CLI** (`copilot-cli`) — AI-powered command-line assistant
- **Claude Code** (`claude-code`) — AI-powered coding assistant by Anthropic
- **uv** (`uv`) — Fast Python package and project manager by Astral
- **Go** (`go`) — Go programming language with checksum verification and GOPATH volume
- **Rust** (`rust`) — Rust toolchain via rustup (cargo, clippy, rustfmt) with persistent volumes
- **Zig** (`zig`) — Zig compiler for cargo-lambda cross-compilation (supports x86_64 and aarch64)
- **lazygit** (`lazygit`) — Terminal UI for git commands with checksum verification
- **Starship** (`starship`) — Cross-shell prompt with rich customization (conflicts with `custom-ps1`)
- **Custom PS1** (`custom-ps1`) — Lightweight bash prompt with container name, git status, and colors (conflicts with `starship`)

Each plugin is a self-contained TOML file in `plugins/` with metadata, Dockerfile instructions, and version info. To add a new tool, create a new `plugins/<name>.toml` file.

## Creating a Plugin

To add a new tool, create `plugins/<name>.toml` with the following structure:

### TOML Schema

```toml
[metadata]
name = "My Tool"                  # Display name
description = "What this tool does"
default = false                   # true = enabled by default
conflicts = ["other-plugin"]      # Optional: mutually exclusive plugins

[apt]
packages = ["libfoo-dev"]         # Optional: apt dependencies

[install]
requires_root = false             # true = runs as root (USER switch is automatic)
user_dirs = ["/home/${USERNAME}/.tool"]  # Optional: dirs to create with user ownership
volumes = ["/home/${USERNAME}/.tool"]    # Optional: persistent volume mounts (name auto-derived from path)
dockerfile = '''
# Dockerfile RUN instructions to install the tool
RUN curl -fsSL https://example.com/install.sh | sh
'''

[version]
strategy = "latest"               # "latest" or "pin"
pin = ""                          # Version string when strategy = "pin"
```

### Key rules

- **`requires_root`**: When `true`, the generator automatically wraps the dockerfile block with `USER root` / `USER ${USERNAME}`. Do **not** include manual `USER` directives — a validation warning is emitted if both are present.
- **`user_dirs`**: Directories that need to exist with user ownership before installation. All enabled plugins' directories are merged and created in a single `USER root` block before any plugin installs. Intermediate parent directories are automatically included.
- **`${USERNAME}`**: Use this variable in volume paths and dockerfile instructions. It is substituted at build time with the value from `workspace.toml`.
- **`[apt].packages`**: Dependencies are only installed when the plugin is enabled. Duplicates with the base package list (`config/apt-base-packages.conf`) are automatically detected.
- **`volumes`** (inside `[install]`): An array of absolute paths under `/home/${USERNAME}/`. Volume names are auto-derived from the path basename (leading dot stripped, e.g., `/home/${USERNAME}/.aws` → `aws`). Mount target directories are created with user permissions in the Dockerfile.
- **`dockerfile`**: Use triple-quoted strings (`'''...'''`). Each instruction should clean up after itself (`apt-get clean`, `rm -rf /tmp/*`).
- **`conflicts`**: List of plugin IDs that cannot be enabled simultaneously. When two plugins that conflict are both in the `[plugins].enable` list, the generator exits with an error. Both sides of the conflict should declare each other for documentation clarity, though a one-sided declaration is sufficient for detection.

### Plugin Conflicts

Some plugins are mutually exclusive — enabling both causes broken behavior (e.g., duplicate PS1 settings). Use the `conflicts` field in `[metadata]` to declare these relationships.

| Plugin | Conflicts With | Reason |
|--------|----------------|--------|
| `starship` | `custom-ps1` | Both write PS1 configuration to `~/.bashrc`. Starship takes full control of the prompt; custom-ps1 sets a static PS1 string. |

**Choosing between them:**
- **Starship** — Feature-rich, cross-shell prompt with git integration, execution time, language versions, and extensive theming via `starship.toml`
- **Custom PS1** — Lightweight, zero-dependency bash prompt with container name, git branch/status, and color coding

### Example: minimal plugin

```toml
[metadata]
name = "ripgrep"
description = "Fast recursive grep"

[install]
requires_root = true
dockerfile = '''
RUN apt-get update && \
    apt-get install -y --no-install-recommends ripgrep && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
'''

[version]
strategy = "latest"
```

## System Packages

Base packages are managed in `config/apt-base-packages.conf`. Project-specific extra packages can be added via `workspace.toml` under `[apt] packages`.

### Essential Packages
- **ca-certificates** - SSL/TLS certificate management for secure HTTPS connections
- **gnupg** - GNU Privacy Guard for data encryption and signing
- **openssh-client** - SSH client for secure remote connections

### Development Tools
- **git** - Version control system
- **make** - Build automation tool
- **build-essential** - C/C++ compilers and build tools (gcc, g++, make, libc-dev)
- **shellcheck** - Shell script static analysis tool
- **python3** - Python 3 interpreter (system Python for AI coding agents and general scripting)
- **python3-pip** - Python package installer
- **python3-venv** - Python virtual environment support
- **file** - File type identification utility
- **patch** - Apply diff/patch files
- **gettext-base** - Text processing utilities (envsubst)

### Editors
- **vim** - Powerful text editor
- **nano** - Simple, user-friendly text editor

### Compression & Archive Tools
- **zip/unzip** - ZIP archive utilities
- **tar** - Tape archive utility
- **gzip** - GNU gzip compression
- **bzip2** - bzip2 compression
- **xz-utils** - XZ compression format

### Network & Download Tools
- **curl** - Command-line HTTP client
- **wget** - Network downloader
- **rsync** - Fast file synchronization and transfer
- **dnsutils** - DNS diagnostic tools (dig, nslookup)
- **iputils-ping** - Network connectivity testing (ping)
- **net-tools** - Network configuration utilities (ifconfig, netstat, route)

### System Utilities
- **sudo** - Execute commands as another user
- **tree** - Directory structure visualization
- **jq** - JSON processor
- **bc** - Arbitrary precision calculator for shell scripts
- **less** - File pager
- **bash-completion** - Command auto-completion
- **procps** - Process monitoring utilities (ps, top, etc.)
- **iproute2** - Advanced networking utilities (ip command)
- **uuid-runtime** - UUID generation utility (uuidgen command)

### Development Libraries
- **libssl-dev** - SSL/TLS development libraries
- **zlib1g-dev** - Compression library
- **libbz2-dev** - bzip2 library
- **libreadline-dev** - Readline library for command-line editing
- **libsqlite3-dev** - SQLite3 database library
- **libncursesw5-dev** - Terminal UI library
- **tk-dev** - Tk GUI toolkit
- **libxml2-dev** - XML processing library
- **libxmlsec1-dev** - XML security library
- **libffi-dev** - Foreign function interface library
- **liblzma-dev** - XZ compression library

### Locale Support
- **locales** - Locale configuration (UTF-8 support for multilingual text)

## Locale Configuration

- **Default Locale**: `en_US.UTF-8`
- Automatically configured for proper multilingual text display
- Git operations correctly display Japanese filenames and diffs

## Shell Features

- **Bash Completion** - Command auto-completion
- **Git-integrated Prompt** - Branch and status display
- **Persistent History** - Command history persists across sessions
- **Custom Configuration** - User-specific settings via `config/.bashrc_custom` (editable from host)

### Using Custom Configuration File

The container supports a custom configuration file at `config/.bashrc_custom`. This file is:
- **Automatically loaded** by `.bashrc` on shell startup
- **Editable directly from host** (no need to enter container)
- **Part of workspace** for easy management and version control
- **Separate from Dockerfile settings** for better maintainability

**Setup:**

```bash
# Copy example file (from host)
cp config/.bashrc_custom.example config/.bashrc_custom

# Edit directly from host (using your favorite editor)
vim config/.bashrc_custom  # or code, nano, etc.
```

**Example content:**

```bash
# Custom aliases
alias ll="ls -lah"
alias gs="git status"

# Environment variables
export MY_CUSTOM_VAR=value

# Tool-specific configurations
# Example: Rust/Cargo environment (if installed via proto)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
```

**Apply changes:**
```bash
# From within container
source ~/.bashrc
```

**Benefits:**
- Edit from host without entering container
- Easy to find and manage (in workspace-docker/config/)
- Can be version controlled (add to git if desired)
- Settings apply automatically on container restart
- No conflicts with Dockerfile updates

## VS Code Extensions

VS Code extensions are configured in `workspace.toml` under the `[vscode]` section. These extensions are installed automatically when the Dev Container is created.

```toml
[vscode]
extensions = [
    "MS-CEINTL.vscode-language-pack-ja",
    "ms-azuretools.vscode-docker",
    "ms-python.python",
    "eamodio.gitlens",
    "github.copilot-chat",
]
```

Each extension is specified by its marketplace ID (`publisher.extension-name`). The list is written into `devcontainer.json` under `customizations.vscode.extensions` at generation time.

To find extension IDs: open VS Code Extensions panel → right-click an extension → "Copy Extension ID".

## Workspace Settings

`config/workspace-settings.json.example` defines default VS Code editor settings that are embedded into `.code-workspace` files generated by `generate-workspace.sh`.

To customize, copy `config/workspace-settings.json.example` to `config/workspace-settings.json` and edit. The generator uses `workspace-settings.json` if present, otherwise falls back to the `.example` file.

**Default settings:**

| Setting | Value | Description |
|---------|-------|-------------|
| `files.autoSave` | `afterDelay` | Auto-save files after a delay |
| `files.trimTrailingWhitespace` | `true` | Remove trailing whitespace on save |
| `files.insertFinalNewline` | `true` | Ensure files end with a newline |
| `editor.formatOnSave` | `true` | Format file on save |
| `editor.insertSpaces` | `true` | Use spaces instead of tabs |
| `editor.detectIndentation` | `false` | Use configured tabSize, don't auto-detect |
| `editor.tabSize` | `2` | Default indent size (4 for Python and Dockerfile) |

## Security Design

### NOPASSWD sudo

The container configures `NOPASSWD:ALL` sudo for the workspace user. This is an intentional design choice:

- **Development-only containers**: These containers are ephemeral, single-user development environments — not production servers
- **Plugin installation**: Some plugins (e.g., AWS CLI, AWS SAM CLI) require `sudo` for system-wide installation
- **Developer experience**: Eliminating password prompts removes friction in interactive shell usage

> **Note**: Do not use this container configuration for production workloads. The NOPASSWD sudo setting is appropriate only for local development environments.

## Testing

The project includes a comprehensive test suite with 8 test suites:

```bash
# Run all tests
bash tests/run_all.sh
```

### Test Suites

| Suite | Description |
|-------|-------------|
| `test_project_structure` | Template existence, script permissions, ShellCheck on all `.sh` files |
| `test_lib` | Unit tests for library functions (TOML parser, validators, generators, devcontainer) |
| `test_plugins` | Plugin TOML structure validation (metadata, install section, version) |
| `test_setup_docker` | Execution-based tests for `setup-docker.sh` (regeneration from workspace.toml) |
| `test_rebuild_container` | Container detection and devcontainer CLI wrapper tests |
| `test_generate_workspace` | Multi-root workspace file generation |
| `test_integration` | End-to-end generation and structural validity (Dockerfile, YAML, JSON) |
| `test_snapshot` | Snapshot regression tests comparing generated files against expected output |

## Project Files

### Core Scripts
- `setup-docker.sh` - Setup script (interactive or regenerate from `workspace.toml`)
- `rebuild-container.sh` - No-cache rebuild of Dev Container image using devcontainer CLI
- `generate-workspace.sh` - Multi-root workspace generator
- `clean-volumes.sh` - Delete all Docker volumes for this project
- `clean-docker.sh` - Interactive Docker resource cleanup (containers, build cache, images, networks, volumes)

### Configuration
- `workspace.toml` - User configuration (container name, username, plugins, ports, vscode extensions, custom volumes)
- `config/workspace-settings.json.example` - Default VS Code editor settings (copy to `workspace-settings.json` to customize)
- `config/apt-base-packages.conf` - Base apt packages installed in all containers
- `config/.bashrc_custom` - User-specific shell configuration loaded on shell startup

### Plugins (`plugins/`)
- `plugins/aws-cli.toml` - AWS CLI v2 plugin
- `plugins/aws-sam-cli.toml` - AWS SAM CLI plugin
- `plugins/claude-code.toml` - Claude Code plugin
- `plugins/copilot-cli.toml` - GitHub Copilot CLI plugin
- `plugins/custom-ps1.toml` - Custom PS1 prompt plugin (conflicts with starship)
- `plugins/docker-cli.toml` - Docker CLI plugin (default: on)
- `plugins/github-cli.toml` - GitHub CLI plugin
- `plugins/go.toml` - Go programming language plugin
- `plugins/lazygit.toml` - lazygit terminal UI plugin
- `plugins/proto.toml` - proto version manager plugin
- `plugins/rust.toml` - Rust toolchain plugin
- `plugins/starship.toml` - Starship cross-shell prompt plugin (conflicts with custom-ps1)
- `plugins/uv.toml` - uv package manager plugin
- `plugins/zig.toml` - Zig compiler plugin

Each plugin TOML contains `[metadata]` (name, description, default), `[install]` (Dockerfile instructions), and `[version]` (pinned or latest).

### Generators
- `lib/generators.py` - Programmatic generator for all output files (Dockerfile, docker-compose.yml, devcontainer.json, devcontainer docker-compose.yml)

### Libraries (`lib/`)

All `lib/*.sh` files use `set -uo pipefail` without `-e`. This is intentional: these files are sourced (not executed) by entry-point scripts, so `set -e` would propagate to the caller and cause unexpected exits on arithmetic expressions or subshell return codes. Only standalone entry-point scripts (`setup-docker.sh`, `rebuild-container.sh`, `clean-volumes.sh`, `clean-docker.sh`) use `set -euo pipefail`.

- `lib/generators.sh` - Python generator wrapper functions
- `lib/plugins.sh` - Plugin loading and Dockerfile snippet generation
- `lib/utils.sh` - General-purpose utilities (env parsing, symlink validation, Docker GID detection)
- `lib/certificates.sh` - Certificate validation and management
- `lib/toml_parser.py` - TOML parser (Python 3.11+ tomllib)
- `lib/validators.sh` - Input validation library (service names, usernames)
- `lib/i18n.sh` - Internationalization framework (`msg()`, `msgln()`)
- `lib/logging.sh` - Error handling and messaging library
- `lib/colors.sh` - Shared color constants for terminal output
- `lib/devcontainer.sh` - devcontainer CLI prerequisite checks and WSL-compatible wrapper

### Message Catalogs (`locale/`)
- `locale/en.sh` - English messages (default)
- `locale/ja.sh` - Japanese messages

### Tests (`tests/`)
- `tests/run_all.sh` - Test runner for all 8 suites
- `tests/test_helper.sh` - Shared assertion functions
- `tests/test_*.sh` - Individual test suites

### CI/CD
- `.github/workflows/ci.yml` - GitHub Actions workflow
  - ShellCheck static analysis
  - 8 test suites execution
  - Template validation and generator verification
  - Dockerfile linting with Hadolint
  - Docker build verification

## i18n

All user-facing messages support internationalization via the `lib/i18n.sh` framework.

### How It Works

- Message catalogs are stored in `locale/en.sh` (English, default) and `locale/ja.sh` (Japanese).
- Set `WORKSPACE_LANG=ja` to display messages in Japanese. Default is English.
- All scripts also accept `--lang ja` option (e.g., `bash setup-docker.sh --lang ja`).
- Messages use `printf`-style `%s` placeholders for dynamic values.

### Functions

| Function | Output | Use Case |
|----------|--------|----------|
| `msg key [args...]` | No newline (printf) | Inline interpolation: `info "$(msg key)"` |
| `msgln key [args...]` | With newline (printf) | Standalone output: `msgln key` |

### Adding Messages

1. Add the key to `locale/en.sh`: `_MSG[my_key]="English text %s"`
2. Add the translation to `locale/ja.sh`: `_MSG[my_key]="日本語 %s"`
3. Use in scripts: `msgln my_key "$value"` or `info "$(msg my_key "$value")"`

### Language Policy

| Context | Language | Rationale |
|---------|----------|----------|
| User-facing output (TUI, echo) | Configurable (EN/JA) | Controlled via `WORKSPACE_LANG` |
| Log/error messages via `logging.sh` | Configurable (EN/JA) | Uses `msg()` for message lookup |
| Code comments | English | Public repository on GitHub |
| Documentation | Both (EN + JA) | Maintain `docs/*.md` and `docs/*.ja.md` in parallel |
