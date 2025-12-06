# workspace-docker

A Docker-based Ubuntu development environment template optimized for Python, Node.js, and Docker development with pre-installed modern development tools.

## Features

- **Flexible Setup**: Choose between Normal (Quick start) or Custom (select software)
- **Modern Development Tools**: uv (Python), Volta (Node.js), Docker CLI, AWS CLI v2, AWS SAM CLI, Slack CLI
- **Persistent Storage**: Development tool caches and configurations persist across container recreations
- **Workspace Integration**: Manage multiple projects in a unified development environment
- **VS Code Dev Container Support**: Seamless integration with VS Code through `.devcontainer` configuration
- **Host Docker Access**: Safely utilize host Docker from within the container
- **Automatic Environment Detection**: Auto-detects UID/GID/Docker GID to avoid permission issues
- **UTF-8 Locale**: Properly displays multilingual text including Japanese

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
- Docker Engine installed
- `~/.gitconfig` file (see below)
 - Docker (required for AWS SAM CLI `sam local` to run functions and API locally)

**Optional:**
- VS Code + Dev Containers extension
- For Slack CLI usage: set `SLACK_BOT_TOKEN` or `SLACK_USER_TOKEN` as environment variables (or configure via `slack` CLI auth flow)

The following host configuration files are mounted **read-only** inside the container:

- **`~/.gitconfig`** - Git configuration (required)
- `~/.aws/` - AWS CLI credentials and configuration (optional)
- `~/.ssh/` - SSH keys (optional)

> **Important**: If `~/.gitconfig` doesn't exist, the setup script will fail. At minimum, configure Git with:
> ```bash
> git config --global user.name "Your Name"
> git config --global user.email "your.email@example.com"
> ```

#### Installing Docker (Ubuntu)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Note: Re-login required for group changes to take effect.

### Setup

1. **Run the setup script**
   ```bash
   bash setup-docker.sh
   ```

2. **Setup Mode Selection**
   - **Normal (1)**: Quick start mode with recommended tools pre-installed
   - Installs: Docker CLI, AWS CLI v2, AWS SAM CLI, Slack CLI, uv, Volta
     - Recommended for Python & Node.js development
     - Fastest way to get started
   - **Custom (2)**: Select which software to install
     - Allows granular control over installed tools
     - Reduces image size if certain tools aren't needed
     - Note: Cache directories and volumes are created for all tools regardless of selection

3. **Required Input**
   - **Container/Service Name**:
     - Allowed characters: alphanumeric (`a-z`, `A-Z`, `0-9`), hyphen (`-`), underscore (`_`)
     - Length: 1-63 characters
     - Examples: `dev`, `my-container`, `app_server`
   - **Username**:
     - First character: lowercase letter (`a-z`) or underscore (`_`)
     - Allowed characters: lowercase letters (`a-z`), digits (`0-9`), hyphen (`-`), underscore (`_`)
     - Length: 1-32 characters
     - Examples: `user`, `dev_user`, `john-doe`

4. **Software Selection** (Custom mode only)
   - **Docker CLI**: Container operations (y/n)
   - **AWS CLI v2**: AWS resource management (y/n)
  - **AWS SAM CLI**: Build, test, and invoke Serverless apps locally (sam build, sam local invoke) (y/n)
  - **Slack CLI**: Slack command-line tooling for workspace interactions and API testing (y/n)
   - **Python Package Manager**: Choose from:
     1. **uv** (recommended): Fast, all-in-one Python package & version manager
     2. **poetry**: Project-focused dependency management
     3. **pyenv + poetry**: Version management + dependency management
     4. **mise**: Multi-language version manager (supports Python, Node.js, etc.)
     5. **none**: Skip Python tools
   - **Node.js Version Manager**: Choose from:
     1. **Volta** (recommended): Automatic version switching per project
     2. **nvm**: Traditional, widely-used Node.js version manager
     3. **fnm**: Fast Node Manager (Rust-based, fast alternative to nvm)
     4. **mise**: Multi-language version manager (supports Python, Node.js, etc.)
     5. **none**: Skip Node.js tools

5. **Auto-detected Information**
   - **UID/GID**: Automatically detects current user's UID/GID
   - **Docker GID**: Automatically detects host Docker group GID (from `/var/run/docker.sock`)

6. **Generated Files**
   - `Dockerfile` - Generated from template (normal or custom)
   - `docker-compose.yml` - Generated from template (normal or custom)
   - `.devcontainer/devcontainer.json` - VS Code Dev Container configuration
   - `.devcontainer/docker-compose.yml` - Dev Container docker-compose configuration
   - `.envs/<service_name>.env` - Environment variables (managed per service, includes software selection flags)
   - `.env` - Symbolic link to `.envs/<service_name>.env`

   > **When switching environments**: Using `switch-env.sh` automatically regenerates `.devcontainer` files along with the `.env` symbolic link

### Environment File (.env) Management

The setup script generates `.envs/<service_name>.env` files for each container service.

#### Managing Multiple Container Services

```bash
# First service (e.g., dev)
bash setup-docker.sh
# → Creates .envs/dev.env and .env → .envs/dev.env symlink

# Second service (e.g., prod)
bash setup-docker.sh
# → Creates .envs/prod.env and updates .env → .envs/prod.env symlink

# Switch services (Method 1: Use script)
bash switch-env.sh dev    # Switch to dev service
bash switch-env.sh prod   # Switch to prod service

# Or run without arguments for interactive selection
bash switch-env.sh

# Note: Script automatically regenerates .devcontainer files

# Switch services (Method 2: Manual symlink change)
ln -sf .envs/dev.env .env    # Switch to dev service
ln -sf .envs/prod.env .env   # Switch to prod service
```

#### Example .env File Content

**Normal Mode:**
```env
# Environment variables for dev
# Generated on Fri Nov  8 12:34:56 UTC 2025

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
SETUP_MODE=1
INSTALL_DOCKER=true
INSTALL_AWS_CLI=true
PYTHON_MANAGER=uv
NODEJS_MANAGER=volta
```

**Custom Mode:**
```env
# Environment variables for dev
# Generated on Fri Nov  8 12:34:56 UTC 2025

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
SETUP_MODE=2
INSTALL_DOCKER=true
INSTALL_AWS_CLI=false
PYTHON_MANAGER=poetry
NODEJS_MANAGER=nvm
```

### Starting the Development Environment

#### Method 1: VS Code Dev Container (Recommended)

1. Open this folder in VS Code
2. Run command `Dev Containers: Open Folder in Container` (Ctrl+Shift+P)
3. Container automatically builds, starts, and connects

#### Method 2: Docker Compose

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

## Development Workflows

### Python Development

```bash
# Install Python
uv python install 3.13

# Create project
uv init my-python-project
cd my-python-project

# Pin Python version
uv python pin 3.13

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
# Install Node.js and pnpm
volta install node@24
volta install pnpm

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

## Pre-installed Applications

### Development Tools

**Python Package Managers** (select one in Custom mode, default: uv in Normal mode):
- **uv**: Fast, all-in-one Python package & version manager (Rust-based, pip-compatible)
- **poetry**: Modern Python dependency management and packaging
- **pyenv + poetry**: Python version management (pyenv) + dependency management (poetry)
- **mise**: Multi-language version manager (Python, Node.js, Ruby, etc.)

**Node.js Version Managers** (select one in Custom mode, default: Volta in Normal mode):
- **Volta**: Seamless Node.js version management with automatic project-based switching
- **nvm**: Traditional Node.js version manager (most widely used)
- **fnm**: Fast Node Manager (Rust-based, faster alternative to nvm)
- **mise**: Multi-language version manager (Python, Node.js, Ruby, etc.)

**Other Tools**:
- **Docker CLI**: Container operations (using host Docker daemon via socket mount)
- **AWS CLI v2**: AWS resource management
 - **AWS SAM CLI**: Build, test and invoke serverless Lambda functions locally (Optional in Custom mode / installed by default in Normal mode)
 - **Slack CLI**: CLI tooling for Slack workspace integration and API testing (Optional in Custom mode / installed by default in Normal mode)

### System Packages (Always Installed)

The following packages are always installed in both Normal and Custom modes to provide a complete development environment.

#### Essential Packages
- **ca-certificates** - SSL/TLS certificate management for secure HTTPS connections
- **gnupg** - GNU Privacy Guard for data encryption and signing
- **openssh-client** - SSH client for secure remote connections

#### Development Tools
- **git** - Version control system
- **make** - Build automation tool
- **build-essential** - C/C++ compilers and build tools (gcc, g++, make, libc-dev)

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

#### System Utilities
- **sudo** - Execute commands as another user
- **tree** - Directory structure visualization
- **jq** - JSON processor
- **less** - File pager
- **bash-completion** - Command auto-completion
- **procps** - Process monitoring utilities (ps, top, etc.)
- **iproute2** - Advanced networking utilities (ip command)

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

## Mounted Directories

### Workspace

| Host | Container | Purpose |
|------|-----------|---------|
| `..` (parent directory) | `/home/<username>/workspace` | Development projects |

### Persistent Volumes

| Volume Name | Mount Path | Purpose |
|-------------|------------|---------|
| `pip-cache` | `~/.cache/pip` | pip cache |
| `uv-cache` | `~/.cache/uv` | uv cache |
| `uv-python` | `~/.local/share/uv` | uv installed Python versions |
| `poetry-cache` | `~/.cache/pypoetry` | Poetry cache |
| `poetry-data` | `~/.local/share/pypoetry` | Poetry data |
| `pyenv` | `~/.pyenv` | pyenv Python versions |
| `volta-tools` | `~/.volta/tools` | Volta tools |
| `nvm` | `~/.nvm` | nvm Node.js versions |
| `fnm` | `~/.local/share/fnm` | fnm Node.js versions |
| `mise-data` | `~/.local/share/mise` | mise installed tools |
| `mise-cache` | `~/.cache/mise` | mise cache |
| `npm-cache` | `~/.npm` | npm cache |
| `pnpm-cache` | `~/.cache/pnpm` | pnpm metadata cache |
| `pnpm-store` | `~/.local/share/pnpm` | pnpm global store |
| `bash-history` | `~/.docker_history` | bash history |

> **Note**: All volumes are created regardless of selected package managers for simplicity. Unused volumes remain empty and don't consume significant space.

### Read-only Mounts

| Host | Container | Purpose |
|------|-----------|---------|
| `~/.aws` | `~/.aws` | AWS configuration & credentials |
| `~/.gitconfig` | `~/.gitconfig` | Git configuration |
| `~/.ssh` | `~/.ssh` | SSH keys (for Git authentication, etc.) |

> **Customization**: To mount specific SSH keys only, specify them individually in `docker-compose.yml` (e.g., `~/.ssh/id_ed25519:/home/${USERNAME}/.ssh/id_ed25519:ro`)

### Dev Container Specific

| Host | Container | Purpose |
|------|-----------|---------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | Host Docker connection |

## Important Notes
- **Docker Socket**: The host Docker socket is mounted, allowing full control of the host Docker environment from within the container

### AWS SAM CLI requirements

- `sam local` uses Docker containers to emulate Lambda functions; ensure Docker is running on the host and the container has access to the Docker socket for local invocation and API testing.
- The Docker image automatically installs the SAM CLI for the container architecture (amd64 -> x86_64, arm64 -> aarch64). If you encounter issues, please verify the installed SAM binary and architecture compatibility.

### Slack CLI usage

- The Slack CLI requires valid Slack credentials for API calls. Configure tokens via environment variables (e.g., `SLACK_BOT_TOKEN`, `SLACK_USER_TOKEN`) or run the Slack CLI auth flow to store credentials.
- **Personal Settings**: `~/.aws`, `~/.gitconfig`, `~/.ssh` are mounted read-only
- **Sensitive Information**: Generated `.env` and `.envs/*.env` files contain user information (UID/GID/Docker GID)

> **Warning**: The entire `~/.ssh` directory is accessible from within the container. While read-only and cannot be modified, container processes can read the key files. Exercise caution when running untrusted code.

### File Management

- **Template Files Required**: `*.template` files are necessary
- **Generated Files**: `Dockerfile`, `docker-compose.yml`, `.devcontainer/devcontainer.json`, `.devcontainer/docker-compose.yml`, `.env`, `.envs/` should be excluded from Git (auto-generated)
- **Persistent Data**: Docker volume data is removed with `docker compose down --volumes`
- **Environment Variables**: Managed per service in `.envs/<service_name>.env`. `.env` is a switchable symbolic link
- **Symbolic Link**: `.env` is a relative path symbolic link. Run `docker compose` commands from the project root

### Development Environment

- **Python**: Managed by selected package manager (uv/poetry/pyenv/mise). System python3 is installed for poetry compatibility
- **Node.js**: Managed by selected version manager (Volta/nvm/fnm/mise)
- **pnpm**: Fast package manager with persistent global store and cache
- **Ports**: Port 3000 is forwarded by default
- **Package Managers**: Only selected tools are installed. All volume mount points are created for future use

### Environment Switching Notes

The project includes an environment switching script (`switch-env.sh`), but **changing the username (USERNAME) requires rebuilding the container**.

#### Environment Switching Procedure

1. **Switch environment**
```bash
bash switch-env.sh <environment-name>
```

2. **Required steps when username is changed**
```bash
# Stop and remove container
docker compose down

# Rebuild without cache (important!)
docker compose build --no-cache

# Start with new configuration
docker compose up -d
```

#### Reason
- When creating a user in the Docker image, the USERNAME build argument is used
- If the build cache remains after changing environment variables, the old username persists
- Use `--no-cache` option to completely rebuild ignoring the cache

### Troubleshooting

- **Permission Errors**: Verify UID/GID are correctly configured
- **Docker Connection Errors**: Verify Docker GID is auto-detected. Check host Docker GID with `getent group docker | cut -d: -f3`
- **Volume Issues**: Check volume status with `docker volume ls`
- **Username Not Updated**: See "Environment Switching Notes" above and rebuild without cache

## Common Commands

### Setup and Environment Switching

```bash
# Initial setup
bash setup-docker.sh

# Switch environment (interactive)
bash switch-env.sh

# Switch environment (specify argument)
bash switch-env.sh dev
bash switch-env.sh prod

# Check available environments
ls -la .envs/
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

```bash
# Complete rebuild after environment changes
docker compose down --volumes
docker compose build --no-cache
docker compose up -d
```

### Testing and Validation

```bash
# Project integrity test
bash test.sh

# Check generated files
cat .env
cat Dockerfile
cat docker-compose.yml
cat .devcontainer/devcontainer.json
cat .devcontainer/docker-compose.yml

# Or check all at once
ls -la .env Dockerfile docker-compose.yml .devcontainer/
```

### Cleanup

```bash
# Delete generated files (manual)
rm -f Dockerfile docker-compose.yml .env
rm -rf .devcontainer/devcontainer.json .devcontainer/docker-compose.yml

# Delete volumes
docker compose down --volumes

# Delete everything (including images)
docker compose down --volumes --rmi all
```

## Testing

A test script is included to validate project integrity:

```bash
# Run tests
bash test.sh
```

### Test Script Validation Items

1. **Template File Existence**
   - `Dockerfile.template`
   - `docker-compose.yml.template`
   - `.devcontainer/devcontainer.json.template`
   - `.devcontainer/docker-compose.yml.template`

2. **Script File Execute Permissions**
   - `setup-docker.sh` is executable
   - `switch-env.sh` is executable

3. **`.envs` Directory Check**
   - `.envs/` directory exists

4. **Generated File Check** (after setup)
   - `Dockerfile`, `docker-compose.yml`, `.env` exist
   - `.devcontainer/devcontainer.json`, `.devcontainer/docker-compose.yml` exist
   - `.env` is a symbolic link pointing to a valid file
   - Environment variable files (`*.env`) exist in `.envs/`

5. **Docker Environment Prerequisites**
   - Docker is installed
   - Docker Compose is available

Tests display results with color output and return exit code 1 if any test fails. If setup has not been run, a warning is displayed but tests do not fail.

## Project Files

- `setup-docker.sh` - Setup script with Normal/Custom mode selection
- `switch-env.sh` - Environment switching script
- `test.sh` - Test script
- `Dockerfile.template` - Dockerfile template for Normal mode (recommended tools for Python & Node.js)
- `Dockerfile.custom.template` - Dockerfile template for Custom mode (selective installation)
- `docker-compose.yml.template` - docker-compose.yml template for Normal mode
- `docker-compose.custom.template` - docker-compose.yml template for Custom mode
- `.devcontainer/devcontainer.json.template` - VS Code Dev Container configuration template
- `.devcontainer/docker-compose.yml.template` - Dev Container docker-compose configuration template

## Documentation

- [日本語版 README (Japanese)](docs/README.ja.md)
- [Changelog](CHANGELOG.md)

## License

This project is licensed under the [MIT License](LICENSE). See the [LICENSE](LICENSE) file for details.
