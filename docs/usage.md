# Usage Guide

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

### Generating Workspace Files

Use `generate-workspace.sh` to create or update `.code-workspace` files interactively:

```bash
bash generate-workspace.sh
```

The script provides a TUI (Terminal User Interface) for folder selection:

1. **Scans** the parent directory (`..`) for available project folders
2. **Displays** a multi-select list with arrow keys, Enter to toggle, `a` for select all, `d` to confirm
3. **Outputs** the `.code-workspace` file to `workspaces/`

**Flows:**

| Scenario | Behavior |
|----------|----------|
| No existing workspace files | Prompts for folder selection and filename, creates new file |
| Existing workspace files found | Choose "Update existing" or "Create new" |
| Updating | Pre-selects currently included folders, allows modification |

**Features:**
- Auto-expands directories that contain only subdirectories (e.g., `group/repo1`, `group/repo2`)
- Embeds VS Code settings from `config/workspace-settings.json` (or `.example` fallback) into generated files
- Overwrites confirmation when creating a file with an existing name

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

### Volume Management

Use `clean-volumes.sh` to delete all Docker named volumes associated with this project:

```bash
bash clean-volumes.sh
```

This script:
- Detects volumes by project name prefix
- Stops running containers if needed
- Deletes all matching volumes
- Cannot be run from inside the container

### Testing and Validation

```bash
# Run all test suites
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

# Delete all project volumes
bash clean-volumes.sh

# Delete volumes via docker compose
docker compose down --volumes

# Delete everything (including images)
docker compose down --volumes --rmi all
```

## Important Notes

### Security

- **Docker Socket**: The host Docker socket is mounted, allowing full control of the host Docker environment from within the container
- **Personal Settings**: `~/.ssh` is synchronized with the host for development convenience
- **Sensitive Information**: Generated `.env` file contains user information (UID/GID/Docker GID)

> **Warning**: The entire `~/.ssh` directory is accessible from within the container. Container processes can both read and modify these files. Exercise caution when running untrusted code.
