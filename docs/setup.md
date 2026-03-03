# Setup Guide

## Prerequisites

**Required:**
- Docker installed on host machine

**Optional:**
- VS Code + Dev Containers extension

The following host configuration files are mounted inside the container:

- `~/.ssh/` - SSH keys (synchronized with host)

### Installing Docker (Ubuntu)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Note: Re-login required for group changes to take effect.

## Setup

1. **Run the setup script (first time — interactive mode)**
   ```bash
   bash setup-docker.sh
   ```
   You will be prompted for a container service name, username, and plugin selection.
   This generates `workspace.toml` and all Docker configuration files.

2. **Reconfigure (edit workspace.toml and regenerate)**

   After initial setup, simply edit `workspace.toml` and re-run the script:
   ```bash
   vim workspace.toml
   bash setup-docker.sh
   ```

   To re-run the interactive setup, use the `--init` flag:
   ```bash
   bash setup-docker.sh --init
   ```

## workspace.toml Configuration

```toml
# workspace.toml — workspace-docker configuration
# Edit this file and run setup-docker.sh to regenerate

[container]
service_name = "dev"
username = "devuser"
ubuntu_version = "24.04"

[plugins]
enable = ["proto", "aws-cli", "docker-cli", "github-cli"]

[apt]
extra_packages = ["ripgrep", "fd-find"]  # optional

[ports]
forward = [3000]

# Optional: VSCode extensions to install in Dev Container
[vscode]
extensions = [
    "MS-CEINTL.vscode-language-pack-ja",
    "ms-python.python",
    "eamodio.gitlens",
]

# Optional: custom persistent volumes (volume-name = "/container/path")
# Use this to persist paths not covered by plugins.
# e.g., proto-managed tool data, project-specific caches
[volumes]
node-data = "/home/devuser/.node"
```

Available plugins are defined in `plugins/*.toml`. Each plugin is a self-contained TOML file with install instructions:
- `proto` — Multi-language version manager (default: on)
- `aws-cli` — AWS CLI v2
- `aws-sam-cli` — AWS SAM CLI
- `claude-code` — Claude Code (AI coding assistant)
- `copilot-cli` — GitHub Copilot CLI
- `docker-cli` — Docker CLI (host Docker via socket mount, default: on)
- `github-cli` — GitHub CLI
- `uv` — uv (fast Python package manager by Astral)
- `zig` — Zig compiler (for cargo-lambda cross-compilation)

## Custom Volume Mounts

Plugins automatically add their own persistent volumes (e.g., `proto` mounts `~/.proto`). To add volumes not covered by plugins — for example, paths used by proto-managed tools — use the `[volumes]` section:

```toml
[volumes]
node-data = "/home/devuser/.node"
python-data = "/home/devuser/.python"
custom-cache = "/home/devuser/.cache/my-tool"
```

- **Key**: volume name (used as Docker named volume name, prefixed with `${CONTAINER_SERVICE_NAME}_`)
- **Value**: absolute path inside the container
- Changes take effect after running `setup-docker.sh` and `rebuild-container.sh`

## Auto-detected Information

- **UID/GID**: Automatically detects current user's UID/GID
- **Docker GID**: Automatically detects host Docker group GID (from `/var/run/docker.sock`)

## Generated Files

- `workspace.toml` - Configuration file (edit this)
- `Dockerfile` - Generated from template + plugins
- `docker-compose.yml` - Generated from template
- `.devcontainer/devcontainer.json` - VS Code Dev Container configuration
- `.devcontainer/docker-compose.yml` - Dev Container docker-compose configuration
- `.env` - Environment variables for docker-compose (auto-generated from workspace.toml)

## Environment File (.env)

The `.env` file is auto-generated from `workspace.toml` each time you run `setup-docker.sh`. Do not edit it manually.

### Example .env File Content

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

## Custom CA Certificates (for Corporate Proxy/VPN)

If you're working in an environment with SSL/TLS inspection (corporate proxy, VPN), you may need to install custom CA certificates to avoid certificate validation errors with tools like curl, pip, npm, and apt.

### Setup

1. **Place certificate files** in the `certs/` directory (PEM format with `.crt` extension):
   ```bash
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

### Certificate Requirements

- **Format**: PEM-encoded X.509 certificates
- **Extension**: `.crt` only
- **Content**: Must start with `-----BEGIN CERTIFICATE-----` and end with `-----END CERTIFICATE-----`
- **Multiple certificates**: Supported (all certificates are installed and merged into `/etc/ssl/certs/ca-certificates.crt`)

### Environment Variables Set

When certificates are installed, the following environment variables are automatically configured:

| Variable | Used By |
|----------|---------|
| `SSL_CERT_FILE` | OpenSSL, Python, and many other tools |
| `CURL_CA_BUNDLE` | curl |
| `REQUESTS_CA_BUNDLE` | Python requests library |
| `NODE_EXTRA_CA_CERTS` | Node.js |

All point to `/etc/ssl/certs/ca-certificates.crt` which includes your custom certificates.

### Security Note

Certificate files (`.crt`, `.pem`) in the `certs/` directory are excluded from git via `.gitignore`. Do not commit certificates to version control.

## Starting the Development Environment

### Method 1: VS Code Dev Container (Recommended)

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

See [Multi-Root Workspace Support](#multi-root-workspace-support) section below for more details.

### Method 2: Docker Compose (Manual)

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

## Multi-Root Workspace Support

This setup supports VS Code's multi-root workspace feature, allowing you to manage multiple projects in the parent directory as separate workspace folders with independent settings.

### Benefits
- Each project folder is recognized as an independent workspace
- Different Python/Node.js versions can be configured per project
- Project-specific settings (e.g., `.vscode/settings.json`) work independently
- Easy navigation between multiple projects

### Generating Workspace File

Run the provided script to automatically generate a workspace file:

```bash
./generate-workspace.sh
```

This scans all directories in the parent directory (excluding hidden directories) and generates:
- `multi-project.code-workspace` (in the workspace-docker directory)

### Opening Multi-Root Workspace

**From Container**
1. Connect to container via Dev Containers as a single folder
2. Open Command Palette (`Ctrl+Shift+P`)
3. Select "File: Open Workspace from File..."
4. Choose `/home/<username>/workspace/workspace-docker/multi-project.code-workspace`

Once opened, VS Code remembers it in "Recent Files" for easy access (though you'll need to reconnect to the devcontainer each time).

### Configuring Per-Project Python Versions

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

## Reconfiguration Notes

To change the configuration, edit `workspace.toml` and run `setup-docker.sh`. **Changing the username (USERNAME) requires rebuilding the container**.

### Reconfiguration Procedure

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

## Troubleshooting

- **Permission Errors**: Verify UID/GID are correctly configured
- **Docker Connection Errors**: Verify Docker GID is auto-detected. Check host Docker GID with `getent group docker | cut -d: -f3`
- **Volume Issues**: Check volume status with `docker volume ls`
- **Username Not Updated**: See "Reconfiguration Notes" above and rebuild without cache
