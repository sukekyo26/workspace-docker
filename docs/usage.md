# Usage Guide

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

### Security

- **Docker Socket**: The host Docker socket is mounted, allowing full control of the host Docker environment from within the container
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
