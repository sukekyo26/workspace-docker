# workspace-docker

[日本語版 README](docs/README.ja.md)

A Docker-based Ubuntu development environment template with a plugin-based tool selection system.

## Features

- **Plugin Architecture**: Extensible tool selection via `plugins/*.toml` — add or customize tools by editing TOML files
- **TOML-based Configuration**: All settings in a single `workspace.toml` file — edit and re-run to regenerate
- **Custom CA Certificates**: Automatic installation of custom CA certificates for corporate proxy/VPN environments
- **Persistent Storage**: Plugin data and configurations persist across container recreations via named volumes
- **Externalized Package Management**: Base apt packages managed in `config/apt-base-packages.conf`, project-specific extras via `workspace.toml`
- **VS Code Dev Container Support**: Seamless integration with VS Code through `.devcontainer` configuration
- **Quality Assurance**: 29 test suites with GitHub Actions CI/CD (ShellCheck, Hadolint, snapshot tests)

## Quick Start

### Prerequisites

- Docker installed on host machine
- Bash 4.3+ (uses `declare -n` nameref)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- (Optional) VS Code + Dev Containers extension

### Setup

```bash
# 1. Install uv (if not installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Run setup script (interactive — generates workspace.toml and all config files)
bash setup-docker.sh

# 3. To reconfigure later, edit workspace.toml and re-run
vim workspace.toml
bash setup-docker.sh
```

#### workspace.toml

You can create `workspace.toml` before running `setup-docker.sh` to pre-define extensions, volumes, and apt packages. The interactive setup (`--init`) preserves these sections.

```toml
[container]
service_name = "dev"
username = "devuser"
ubuntu_version = "24.04"

[plugins]
enable = ["proto", "aws-cli", "docker-cli", "github-cli"]

[apt]
packages = ["ripgrep", "fd-find"]

[ports]
forward = [3000]

# Optional: VSCode extensions for Dev Container
[vscode]
extensions = ["ms-python.python", "eamodio.gitlens"]

# Optional: custom persistent volumes (volume-name = "/container/path")
[volumes]
my-data = "/home/devuser/.my-tool"
```

Available plugins: `proto`, `aws-cli`, `aws-sam-cli`, `claude-code`, `copilot-cli`, `docker-cli`, `github-cli`, `uv`, `zig` (defined in `plugins/*.toml`)

### Starting the Development Environment

**VS Code Dev Container (Recommended):**

1. Open this folder in VS Code
2. Run `Dev Containers: Open Folder in Container` (Ctrl+Shift+P)
3. Container automatically builds, starts, and connects

**Docker Compose (Manual):**

```bash
docker compose up -d --build
docker compose exec <service-name> bash
```

### Workspace Structure

The parent directory is mounted to `/home/<username>/workspace` inside the container:

```
Parent Directory/
├── workspace-docker/  ← This project
├── python-project/    ← Your projects
├── nodejs-project/
└── other-projects/
    ↓ Mounted as
Container: /home/<username>/workspace/
├── workspace-docker/
├── python-project/
├── nodejs-project/
└── other-projects/
```

## Documentation

| Document | Description |
|----------|-------------|
| [Setup Guide](docs/setup.md) | Full configuration, CA certificates, multi-root workspace, troubleshooting |
| [Usage Guide](docs/usage.md) | Development workflows, common commands, mounted directories |
| [Reference](docs/reference.md) | Pre-installed software, system packages, shell features, project files |
| [Changelog](CHANGELOG.md) | Version history |

## License

This project is licensed under the [MIT License](LICENSE).
