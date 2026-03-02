# workspace-docker

A Docker-based Ubuntu development environment template with proto (multi-language version manager) and a plugin-based tool selection system.

## Features

- **Plugin Architecture**: Extensible tool selection via `plugins/*.toml` — add or customize tools by editing TOML files
- **TOML-based Configuration**: All settings in a single `workspace.toml` file — edit and re-run to regenerate
- **proto**: Unified multi-language version manager for Python, Node.js, Bun, Deno, Go, Rust, and 100+ more tools
- **Custom CA Certificates**: Automatic installation of custom CA certificates for corporate proxy/VPN environments
- **Persistent Storage**: proto tools and configurations persist across container recreations
- **VS Code Dev Container Support**: Seamless integration with VS Code through `.devcontainer` configuration
- **Quality Assurance**: 8 test suites with GitHub Actions CI/CD (ShellCheck, Hadolint, snapshot tests)

## Quick Start

### Prerequisites

- Docker installed on host machine
- (Optional) VS Code + Dev Containers extension

### Setup

```bash
# 1. Run setup script (interactive — generates workspace.toml and all config files)
bash setup-docker.sh

# 2. To reconfigure later, edit workspace.toml and re-run
vim workspace.toml
bash setup-docker.sh
```

#### workspace.toml

```toml
[container]
service_name = "dev"
username = "devuser"
ubuntu_version = "24.04"

[plugins]
enable = ["aws-cli", "aws-sam-cli", "docker-cli", "github-cli"]

[apt]
extra_packages = ["ripgrep", "fd-find"]

[ports]
forward = [3000]
```

Available plugins: `aws-cli`, `aws-sam-cli`, `docker-cli`, `github-cli`, `zig` (defined in `plugins/*.toml`)

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
| [日本語版 README](docs/README.ja.md) | Japanese documentation |
| [Setup Guide (日本語)](docs/setup.ja.md) | セットアップガイド |
| [Usage Guide (日本語)](docs/usage.ja.md) | 使い方ガイド |
| [Reference (日本語)](docs/reference.ja.md) | リファレンス |
| [Changelog](CHANGELOG.md) | Version history |

## License

This project is licensed under the [MIT License](LICENSE).
