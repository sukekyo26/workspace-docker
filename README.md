# workspace-docker

A Docker-based Ubuntu development environment template with proto (multi-language version manager) and a plugin-based tool selection system.

## Features

- **Plugin Architecture**: Extensible tool selection via `plugins/*.toml` — add or customize tools by editing TOML files
- **TOML-based Configuration**: All settings in a single `workspace.toml` file — edit and re-run to regenerate
- **proto**: Unified multi-language version manager for Python, Node.js, Bun, Deno, Go, Rust, and 100+ more tools
- **Custom CA Certificates**: Automatic installation of custom CA certificates for corporate proxy/VPN environments
- **Persistent Storage**: proto tools and configurations persist across container recreations
- **Workspace Integration**: Manage multiple projects in a unified development environment
- **VS Code Dev Container Support**: Seamless integration with VS Code through `.devcontainer` configuration
- **Host Docker Access**: Safely utilize host Docker from within the container
- **Automatic Environment Detection**: Auto-detects UID/GID/Docker GID to avoid permission issues
- **UTF-8 Locale**: Properly displays multilingual text including Japanese
- **Quality Assurance**: 8 test suites with GitHub Actions CI/CD (ShellCheck, Hadolint, snapshot tests)

## Workspace Structure

The parent directory is mounted to `/home/<username>/workspace` inside the container, allowing unified development across multiple projects:

```
Parent Directory/ (e.g., /home/user/work/)
├── workspace-docker/  ← Docker configuration (this project)
├── python-project/    ← Python project
├── nodejs-project/    ← Node.js project
└── other-projects/    ← Other projects
    ↓ Mounted as
Container: /home/<username>/workspace/
├── workspace-docker/
├── python-project/
├── nodejs-project/
└── other-projects/
```

## Quick Start

### Prerequisites

**Required:**
- Docker installed on host machine

**Optional:**
- VS Code + Dev Containers extension

The following host configuration files are mounted inside the container:

- `~/.ssh/` - SSH keys (synchronized with host)

#### Installing Docker (Ubuntu)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Note: Re-login required for group changes to take effect.

### Setup

1. **Run the setup script (first time — interactive mode)**
   ```bash
   bash setup-docker.sh
   ```
   You will be prompted for a container service name, username, and plugin selection.
   This generates `workspace.toml` and all Docker configuration files.

2. **Reconfigure (edit workspace.toml and regenerate)**

   After initial setup, simply edit `workspace.toml` and re-run the script:
   ```bash
   # Edit configuration
   vim workspace.toml

   # Regenerate all files from workspace.toml
   bash setup-docker.sh
   ```

   To re-run the interactive setup, use the `--init` flag:
   ```bash
   bash setup-docker.sh --init
   ```

3. **workspace.toml Configuration**

   ```toml
   # workspace.toml — workspace-docker configuration
   # Edit this file and run setup-docker.sh to regenerate

   [container]
   service_name = "dev"
   username = "devuser"
   ubuntu_version = "24.04"

   [plugins]
   enable = ["aws-cli", "aws-sam-cli", "docker-cli", "github-cli"]

   [apt]
   extra_packages = ["ripgrep", "fd-find"]  # optional

   [ports]
   forward = [3000]
   ```

   Available plugins are defined in `plugins/*.toml`. Each plugin is a self-contained TOML file with install instructions:
   - `aws-cli` — AWS CLI v2
   - `aws-sam-cli` — AWS SAM CLI
   - `docker-cli` — Docker CLI (host Docker via socket mount)
   - `github-cli` — GitHub CLI
   - `zig` — Zig compiler (for cargo-lambda cross-compilation)

4. **Auto-detected Information**
   - **UID/GID**: Automatically detects current user's UID/GID
   - **Docker GID**: Automatically detects host Docker group GID (from `/var/run/docker.sock`)

5. **Generated Files**
   - `workspace.toml` - Configuration file (edit this)
   - `Dockerfile` - Generated from template + plugins
   - `docker-compose.yml` - Generated from template
   - `.devcontainer/devcontainer.json` - VS Code Dev Container configuration
   - `.devcontainer/docker-compose.yml` - Dev Container docker-compose configuration
   - `.env` - Environment variables for docker-compose (auto-generated from workspace.toml)

### Environment File (.env)

The `.env` file is auto-generated from `workspace.toml` each time you run `setup-docker.sh`. Do not edit it manually.

#### Example .env File Content

```env
# Environment variables for docker-compose
# Auto-generated from workspace.toml — do not edit manually
# Regenerate with: ./setup-docker.sh

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
UBUNTU_VERSION=24.04
FORWARD_PORT=3000
```

### Custom CA Certificates (for Corporate Proxy/VPN)

If you're working in an environment with SSL/TLS inspection (corporate proxy, VPN), you may need to install custom CA certificates to avoid certificate validation errors with tools like curl, pip, npm, and apt.

#### Setup

1. **Place certificate files** in the `certs/` directory (PEM format with `.crt` extension):
   ```bash
   # Copy your corporate/proxy certificates
   cp /path/to/corporate-proxy-ca.crt ./certs/
   cp /path/to/internal-ca.crt ./certs/
   ```

2. **Run setup** - certificates are automatically detected:
   ```bash
   bash setup-docker.sh
   ```

3. **Rebuild the container**:
   ```bash
   bash rebuild-container.sh
   ```

#### Certificate Requirements

- **Format**: PEM-encoded X.509 certificates
- **Extension**: `.crt` only
- **Content**: Must start with `-----BEGIN CERTIFICATE-----` and end with `-----END CERTIFICATE-----`
- **Multiple certificates**: Supported (all certificates are installed and merged into `/etc/ssl/certs/ca-certificates.crt`)

#### Environment Variables Set

When certificates are installed, the following environment variables are automatically configured:

| Variable | Used By |
|----------|---------|
| `SSL_CERT_FILE` | OpenSSL, Python, and many other tools |
| `CURL_CA_BUNDLE` | curl |
| `REQUESTS_CA_BUNDLE` | Python requests library |
| `NODE_EXTRA_CA_CERTS` | Node.js |

All point to `/etc/ssl/certs/ca-certificates.crt` which includes your custom certificates.

#### Security Note

Certificate files (`.crt`, `.pem`) in the `certs/` directory are excluded from git via `.gitignore`. Do not commit certificates to version control.

### Starting the Development Environment

#### Method 1: VS Code Dev Container (Recommended)

**For single project:**
1. Open this folder in VS Code (on WSL/SSH/EC2, open via Remote extension)
2. Run command `Dev Containers: Open Folder in Container` (Ctrl+Shift+P)
3. Container automatically builds, starts, and connects

**For multi-root workspace (multiple projects):**

If you want to work with multiple projects simultaneously with independent settings, use the multi-root workspace feature:

1. Generate workspace file (first time only):
   ```bash
   ./generate-workspace.sh
   ```

2. After connecting to Dev Container, open workspace file from within the container:
   - Open Command Palette (Ctrl+Shift+P) and select "File: Open Workspace from File..."
   - Choose `/home/<username>/workspace/workspace-docker/multi-project.code-workspace`

This will open all projects as separate workspace folders, each with independent settings.

See [Multi-Root Workspace Support](#multi-root-workspace-support) section below for more details.

#### Method 2: Docker Compose (Manual)

```bash
# Build image
docker compose build

# Build without cache (when environment variables change)
docker compose build --no-cache

# Start container (detached mode)
docker compose up -d

# Build and start together
docker compose up -d --build

# Access container
docker compose exec <service-name> bash

# View logs
docker compose logs
docker compose logs -f  # Follow mode

# Check container status
docker compose ps

# Stop container
docker compose down

# Stop and remove volumes
docker compose down --volumes

# Complete cleanup (containers, volumes, networks, images)
docker compose down --volumes --rmi all
```

### Multi-Root Workspace Support

This setup supports VS Code's multi-root workspace feature, allowing you to manage multiple projects in the parent directory as separate workspace folders with independent settings.

#### Benefits
- Each project folder is recognized as an independent workspace
- Different Python/Node.js versions can be configured per project
- Project-specific settings (e.g., `.vscode/settings.json`) work independently
- Easy navigation between multiple projects

#### Generating Workspace File

Run the provided script to automatically generate a workspace file:

```bash
./generate-workspace.sh
```

This scans all directories in the parent directory (excluding hidden directories) and generates:
- `multi-project.code-workspace` (in the workspace-docker directory)

The generated file includes all project folders found in the parent directory.

#### Opening Multi-Root Workspace

**From Container**
1. Connect to container via Dev Containers as a single folder
2. Open Command Palette (`Ctrl+Shift+P`)
3. Select "File: Open Workspace from File..."
4. Choose `/home/<username>/workspace/workspace-docker/multi-project.code-workspace`

Once opened, VS Code remembers it in "Recent Files" for easy access (though you'll need to reconnect to the devcontainer each time).

#### Configuring Per-Project Python Versions

Create `.vscode/settings.json` in each project folder to specify the Python interpreter.

**Example 1: Using virtual environment (recommended)**

First, create a virtual environment with your desired Python version:
```bash
cd /home/<username>/workspace/project-a
# Using proto + uv
proto install python 3.11
proto install uv
uv venv

cd /home/<username>/workspace/project-b
# Using proto + uv
proto install python 3.12
uv venv
```

Then configure VS Code to use it:

**project-a/.vscode/settings.json (Python 3.11 via venv)**
```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

**project-b/.vscode/settings.json (Python 3.12 via venv)**
```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

**Example 2: Using proto-installed Python directly**

**project-a/.vscode/settings.json (proto Python 3.11)**
```json
{
  "python.defaultInterpreterPath": "~/.proto/tools/python/3.11.9/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

**Example 3: Using uv Python selector**

```json
{
  "python.defaultInterpreterPath": "python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

With this setting, VS Code will use the Python version managed by uv for the project.

## Development Workflows

### Python Development

```bash
# Install Python and uv via proto
proto install python 3.13
proto install uv

# Create project
uv init my-python-project
cd my-python-project

# Add dependencies
uv add requests pandas
uv add --dev pytest black ruff

# Run script
uv run python main.py

# Run tests
uv run pytest
```

### Node.js Development

```bash
# Install Node.js and pnpm via proto
proto install node 22
proto install pnpm

# Create project
pnpm init
pnpm add express

# Add dev dependencies
pnpm add -D typescript @types/node

# Run script
pnpm start

# Or run directly
node app.js
```

### Other Languages with proto

```bash
# Install other runtimes
proto install bun
proto install deno
proto install go
proto install rust

# List installed tools
proto list

# Pin tool version for project (creates .prototools file)
proto pin node 22
proto pin python 3.13
```

## Pre-installed Applications

### Development Tools

**proto** (always installed):
- **proto**: Unified multi-language version manager supporting:
  - **Python** (+ poetry, uv)
  - **Node.js** (+ npm, pnpm, yarn)
  - **Bun**, **Deno**, **Go**, **Rust**, **Ruby**
  - 100+ third-party tools via plugins
  - Project-based version switching via `.prototools` file

**Plugin Tools** (configured via `workspace.toml`, defined in `plugins/*.toml`):
- **Docker CLI** (`docker-cli`) — Container operations (using host Docker daemon via socket mount)
- **AWS CLI v2** (`aws-cli`) — AWS resource management
- **AWS SAM CLI** (`aws-sam-cli`) — Build, test and invoke serverless Lambda functions locally
- **GitHub CLI** (`github-cli`) — GitHub command-line interface for repository management and workflows
- **Zig** (`zig`) — Zig compiler for cargo-lambda cross-compilation (supports x86_64 and aarch64)

Each plugin is a self-contained TOML file in `plugins/` with metadata, Dockerfile instructions, and version info. To add a new tool, create a new `plugins/<name>.toml` file.

### System Packages (Always Installed)

The following packages are always installed to provide a complete development environment.

#### Essential Packages
- **ca-certificates** - SSL/TLS certificate management for secure HTTPS connections
- **gnupg** - GNU Privacy Guard for data encryption and signing
- **openssh-client** - SSH client for secure remote connections

#### Development Tools
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

#### Editors
- **vim** - Powerful text editor
- **nano** - Simple, user-friendly text editor

#### Compression & Archive Tools
- **zip/unzip** - ZIP archive utilities
- **tar** - Tape archive utility
- **gzip** - GNU gzip compression
- **bzip2** - bzip2 compression
- **xz-utils** - XZ compression format

#### Network & Download Tools
- **curl** - Command-line HTTP client
- **wget** - Network downloader
- **rsync** - Fast file synchronization and transfer
- **dnsutils** - DNS diagnostic tools (dig, nslookup)
- **iputils-ping** - Network connectivity testing (ping)
- **net-tools** - Network configuration utilities (ifconfig, netstat, route)

#### System Utilities
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

#### Development Libraries
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

#### Locale Support
- **locales** - Locale configuration (UTF-8 support for multilingual text)

### Locale Configuration

- **Default Locale**: `en_US.UTF-8`
- Automatically configured for proper multilingual text display
- Git operations correctly display Japanese filenames and diffs

### Shell Features

- **Bash Completion** - Command auto-completion
- **Git-integrated Prompt** - Branch and status display
- **Persistent History** - Command history persists across sessions
- **Custom Configuration** - User-specific settings via `workspace-docker/config/.bashrc_custom` (editable from host)

#### Using Custom Configuration File

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

## Mounted Directories

### Workspace

| Host | Container | Purpose |
|------|-----------|---------|
| `..` (parent directory) | `/home/<username>/workspace` | Development projects |

### Persistent Volumes

| Volume Name | Mount Path | Purpose |
|-------------|------------|---------|
| `proto` | `~/.proto` | proto installed tools and versions |
| `aws` | `~/.aws` | AWS CLI credentials and configuration |
| `gh-config` | `~/.config/gh` | GitHub CLI configuration and credentials |
| `cargo` | `~/.cargo` | Rust/Cargo tools and packages |
| `rustup` | `~/.rustup` | Rust toolchain management |
| `deno` | `~/.deno` | Deno runtime and cached modules |
| `bun` | `~/.bun` | Bun runtime and packages |
| `go` | `~/go` | Go workspace (GOPATH) |
| `local` | `~/.local` | User-installed packages (pipx, uv, etc.) and bash history |

### Host Synchronized Mounts

| Host | Container | Purpose |
|------|-----------|---------|
| `~/.ssh` | `~/.ssh` | SSH keys (for Git authentication, etc.) |

> **Note**: These files are synchronized with the host, allowing changes made inside the container to persist on the host and vice versa.
>
> **Customization**: To mount specific SSH keys only, specify them individually in `docker-compose.yml` (e.g., `~/.ssh/id_ed25519:/home/${USERNAME}/.ssh/id_ed25519`)

### Dev Container Specific

| Host | Container | Purpose |
|------|-----------|---------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | Host Docker connection |

## Important Notes
- **Docker Socket**: The host Docker socket is mounted, allowing full control of the host Docker environment from within the container

### Security and Personal Settings

- **Personal Settings**: `~/.ssh` is synchronized with the host for development convenience
- **Sensitive Information**: Generated `.env` file contains user information (UID/GID/Docker GID)

> **Warning**: The entire `~/.ssh` directory is accessible from within the container. Container processes can both read and modify these files. Exercise caution when running untrusted code.

### File Management

- **Template Files Required**: `*.template` files are necessary
- **Generated Files**: `Dockerfile`, `docker-compose.yml`, `.devcontainer/devcontainer.json`, `.devcontainer/docker-compose.yml`, `.env` are auto-generated — exclude from Git
- **Configuration**: `workspace.toml` is the single source of truth — edit this and re-run `setup-docker.sh`
- **Persistent Data**: Docker volume data is removed with `docker compose down --volumes`

### Development Environment

- **proto**: Unified version manager for Python, Node.js, and 100+ other tools
- **Plugin tools**: Configured in `workspace.toml`, defined in `plugins/*.toml`
- **Ports**: Configurable in `workspace.toml` (default: 3000)

### Reconfiguration Notes

To change the configuration, edit `workspace.toml` and run `setup-docker.sh`. **Changing the username (USERNAME) requires rebuilding the container**.

#### Reconfiguration Procedure

1. **Edit configuration**
```bash
vim workspace.toml
bash setup-docker.sh
```

2. **Required steps when username is changed**
```bash
# Stop and remove container
docker compose down

# Rebuild without cache (important!)
bash rebuild-container.sh
```

#### Reason
- When creating a user in the Docker image, the USERNAME build argument is used
- If the build cache remains after changing the username, the old username persists
- Use `rebuild-container.sh` to completely rebuild ignoring the cache

### Troubleshooting

- **Permission Errors**: Verify UID/GID are correctly configured
- **Docker Connection Errors**: Verify Docker GID is auto-detected. Check host Docker GID with `getent group docker | cut -d: -f3`
- **Volume Issues**: Check volume status with `docker volume ls`
- **Username Not Updated**: See "Reconfiguration Notes" above and rebuild without cache

## Common Commands

### Setup and Reconfiguration

```bash
# Initial setup (interactive)
bash setup-docker.sh

# Reconfigure: edit workspace.toml, then regenerate
bash setup-docker.sh

# Re-run interactive setup
bash setup-docker.sh --init
```

### Docker Operations

```bash
# Build image
docker compose build
docker compose build --no-cache  # Without cache

# Start container
docker compose up -d
docker compose up -d --build     # Build and start together

# Stop and remove container
docker compose down
docker compose down --volumes    # Remove volumes too

# Launch shell in container
docker compose exec <service-name> bash

# View logs
docker compose logs
docker compose logs -f           # Real-time display

# Check container status
docker compose ps

# Check resource usage
docker compose stats
```

### Complete Rebuild

Using `rebuild-container.sh` (recommended):

```bash
bash rebuild-container.sh
```

This runs `devcontainer up --build-no-cache --remove-existing-container`, which handles devcontainer.json features, VS Code extension settings, and Docker image rebuild in one step.

Or manually with Docker Compose:

```bash
docker compose down --volumes
docker compose build --no-cache
docker compose up -d
```

### Testing and Validation

```bash
# Run all test suites (8 suites)
bash tests/run_all.sh

# Check generated files
cat workspace.toml
cat .env
cat Dockerfile
cat docker-compose.yml
cat .devcontainer/devcontainer.json
cat .devcontainer/docker-compose.yml
```

### Cleanup

```bash
# Delete generated files (keep workspace.toml for reconfiguration)
rm -f Dockerfile docker-compose.yml .env
rm -f .devcontainer/devcontainer.json .devcontainer/docker-compose.yml

# Delete volumes
docker compose down --volumes

# Delete everything (including images)
docker compose down --volumes --rmi all
```

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
- `workspace.toml` - User configuration (container name, username, plugins, ports)

### Plugins (`plugins/`)
- `plugins/aws-cli.toml` - AWS CLI v2 plugin
- `plugins/aws-sam-cli.toml` - AWS SAM CLI plugin
- `plugins/docker-cli.toml` - Docker CLI plugin
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

## Documentation

- [日本語版 README (Japanese)](docs/README.ja.md)
- [Changelog](CHANGELOG.md)

## License

This project is licensed under the [MIT License](LICENSE). See the [LICENSE](LICENSE) file for details.
