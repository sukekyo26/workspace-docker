# workspace-docker

A Docker-based Ubuntu development environment template optimized for Python, Node.js, and Docker development with pre-installed modern development tools.

## Features

- **Flexible Setup**: Choose between Normal (Quick start) or Custom (select software)
- **Modern Development Tools**: uv (Python), Volta (Node.js), Docker CLI, AWS CLI v2
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

**Optional:**
- VS Code + Dev Containers extension

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
     - Installs: Docker CLI, AWS CLI v2, uv, Volta
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
   - **uv**: Python package & version management (y/n)
   - **Volta**: Node.js version management (y/n)

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
INSTALL_UV=true
INSTALL_VOLTA=true
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
INSTALL_UV=true
INSTALL_VOLTA=false
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

| Tool | Purpose | Notes |
|------|---------|-------|
| **uv** | Python package & version management | Python 3.8+ |
| **Volta** | Node.js version management | Node.js, npm, yarn, pnpm |
| **Docker CLI** | Container operations (using host Docker) | - |
| **AWS CLI v2** | AWS resource management | - |

### System Tools

- **Git** - Version control
- **curl/wget** - HTTP clients
- **vim/nano** - Text editors
- **tree** - Directory structure visualization
- **jq** - JSON processor
- **build-essential** - C/C++ compilers
- **locales** - Locale configuration (UTF-8 support)
- **Development libraries** - SSL, SQLite, XML, etc.

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
| `uv-python` | `~/.local/share/uv` | uv installed Python |
| `volta-tools` | `~/.volta/tools` | Volta tools |
| `npm-cache` | `~/.npm` | npm cache |
| `pnpm-cache` | `~/.cache/pnpm` | pnpm metadata cache |
| `pnpm-store` | `~/.local/share/pnpm` | pnpm global store |
| `bash-history` | `~/.docker_history` | bash history |

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

### Security

- **Docker Socket**: The host Docker socket is mounted, allowing full control of the host Docker environment from within the container
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

- **Python**: System python3 package not included (managed by uv)
- **Node.js**: Version managed by Volta (includes npm, pnpm)
- **pnpm**: Fast package manager with persistent global store and cache
- **Ports**: Port 3000 is forwarded by default

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
