# Reference

## Pre-installed Applications

### Development Tools

**Plugin Tools** (configured via `workspace.toml`, defined in `plugins/*.toml`):
- **proto** (`proto`, default: on) — Unified multi-language version manager (Python, Node.js, Bun, Deno, Go, Rust, 100+ tools)
- **Docker CLI** (`docker-cli`, default: on) — Container operations (using host Docker daemon via socket mount)
- **AWS CLI v2** (`aws-cli`) — AWS resource management
- **AWS SAM CLI** (`aws-sam-cli`) — Build, test and invoke serverless Lambda functions locally
- **GitHub CLI** (`github-cli`) — GitHub command-line interface for repository management and workflows
- **GitHub Copilot CLI** (`copilot-cli`) — AI-powered command-line assistant
- **Claude Code** (`claude-code`) — AI-powered coding assistant by Anthropic
- **Zig** (`zig`) — Zig compiler for cargo-lambda cross-compilation (supports x86_64 and aarch64)

Each plugin is a self-contained TOML file in `plugins/` with metadata, Dockerfile instructions, and version info. To add a new tool, create a new `plugins/<name>.toml` file.

## System Packages

Base packages are managed in `config/apt-base-packages.conf`. Project-specific extra packages can be added via `workspace.toml` under `[apt] extra_packages`.

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
- **lsb-release** - Linux Standard Base version reporting utility
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
- **Custom Configuration** - User-specific settings via `workspace-docker/config/.bashrc_custom` (editable from host)

### Using Custom Configuration File

The container supports a custom configuration file at `workspace-docker/config/.bashrc_custom`. This file is:
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

### Configuration
- `workspace.toml` - User configuration (container name, username, plugins, ports, custom volumes)

### Plugins (`plugins/`)
- `plugins/proto.toml` - proto version manager plugin (default: on)
- `plugins/aws-cli.toml` - AWS CLI v2 plugin
- `plugins/aws-sam-cli.toml` - AWS SAM CLI plugin
- `plugins/claude-code.toml` - Claude Code plugin
- `plugins/copilot-cli.toml` - GitHub Copilot CLI plugin
- `plugins/docker-cli.toml` - Docker CLI plugin (default: on)
- `plugins/github-cli.toml` - GitHub CLI plugin
- `plugins/zig.toml` - Zig compiler plugin

Each plugin TOML contains `[metadata]` (name, description, default), `[install]` (Dockerfile instructions), and `[version]` (pinned or latest).

### Templates
- `Dockerfile.template` - Dockerfile template with placeholders
- `docker-compose.yml.template` - docker-compose.yml template
- `.devcontainer/devcontainer.json.template` - VS Code Dev Container configuration template
- `.devcontainer/docker-compose.yml.template` - Dev Container docker-compose configuration template

### Libraries (`lib/`)
- `lib/generators.sh` - Template generation functions
- `lib/plugin.sh` - Plugin loading and Dockerfile snippet generation
- `lib/toml_parser.py` - TOML parser (Python 3.11+ tomllib)
- `lib/validators.sh` - Input validation library (service names, usernames)
- `lib/errors.sh` - Error handling and messaging library
- `lib/devcontainer.sh` - devcontainer CLI prerequisite checks and WSL-compatible wrapper

### Tests (`tests/`)
- `tests/run_all.sh` - Test runner for all 8 suites
- `tests/test_helper.sh` - Shared assertion functions
- `tests/test_*.sh` - Individual test suites

### CI/CD
- `.github/workflows/ci.yml` - GitHub Actions workflow
  - ShellCheck static analysis
  - 8 test suites execution
  - Template validation (YAML/JSON)
  - Dockerfile linting with Hadolint
  - Docker build verification
