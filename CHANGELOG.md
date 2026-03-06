# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `clean-volumes.sh` script to delete all Docker named volumes for the project
- Pre-definition workflow: create `workspace.toml` before `setup-docker.sh --init` to pre-define `[apt]`, `[vscode]`, and `[volumes]` sections (preserved during interactive setup)
- `select_multi` now supports cancel via `q` key — callers exit gracefully on cancellation
- Added `HEALTHCHECK` instruction to generated Dockerfile

### Changed
- **BREAKING**: Migrated to uv-managed Python project — `uv` is now required on the host
- **BREAKING**: Docker volume names now include `COMPOSE_PROJECT_NAME` prefix (`{project}_{service}_{volume}`) for project isolation
- **BREAKING**: All shell scripts and TOML files converted to 2-space indentation
- `docker-cli` plugin: replaced `lsb-release` dependency with `/etc/os-release` for Ubuntu codename detection
- i18n policy: all user-facing output (TUI, echo) and code comments changed from Japanese to English
- Removed Japanese comment from generated Dockerfile template
- All `python3` invocations replaced with `uv run python` via `_uv_python()` helper
- `check_python3()` renamed to `check_uv()` — verifies `uv` command availability
- PyYAML moved from dev dependency-group to project dependency in `pyproject.toml`
- `config/workspace-settings.json` renamed to `.example` — copy to `workspace-settings.json` to customize
- Removed personal settings (`localeOverride`) from example settings file

### Fixed
- Removed duplicate test files (`test_generators.sh`, `test_errors.sh`) that caused double execution
- Fixed `check_devcontainer_cli` trap overwrite that could clobber caller's EXIT trap
- Fixed path traversal vulnerability in `validate_symlink` — prefix match now uses trailing slash guard
- Added `set -uo pipefail` to `colors.sh` for consistency with other lib files
- `.env` generation now uses `printf` instead of unquoted here-doc to prevent shell expansion in values
- Added nameref scope pollution verification tests for `_parse_toml_output`
- Documented `set -e` design intent: lib files use `set -uo pipefail` (no `-e`) because they are sourced
- Exported `CURRENT_LOG_LEVEL` so subshells inherit the log level
- Added explicit `encoding="utf-8"` to `open()` calls in `generators.py`
- `_run_generator` now cleans up stale temp files from previous interrupted runs
- Fixed missing `uv` setup in CI docker-build job

## [4.0.0] - 2026-03-04

### Added
- **Plugin Architecture**: Extensible tool selection via `plugins/*.toml` TOML files
  - TOML parser helper (`lib/toml_parser.py`) using Python 3.11+ `tomllib`
  - Plugin loading library (`lib/plugins.sh`) for Dockerfile snippet generation
  - Plugin definitions for all existing tools: `proto`, `aws-cli`, `aws-sam-cli`, `copilot-cli`, `claude-code`, `docker-cli`, `github-cli`, `zig`
- **workspace.toml**: Single TOML configuration file replacing interactive-only setup
  - `[container]` section for service name, username, Ubuntu version
  - `[plugins]` section for tool selection
  - `[apt]` section for extra system packages
  - `[ports]` section for port forwarding
  - `[devcontainer]` section for devcontainer.json key overrides and deep merge
- `setup-docker.sh --yes` flag for non-interactive setup with default values
- SHA256 checksum verification for zig plugin downloads
- TLS enforcement (`--proto '=https' --tlsv1.2`) for curl|sh plugins (claude-code, uv, proto, copilot-cli)
- `.dockerignore` to exclude `.git/`, `tests/`, `docs/`, `agent/`, `.env` from build context
- `uv` plugin for fast Python package management
- Per-plugin apt dependency packages via `[apt].packages` in plugin TOML
- Plugin TOML validation for `requires_root` and volume path consistency
- Auto-inject `USER root` / `USER ${USERNAME}` for `requires_root` plugins
- VSCode extensions managed via `workspace.toml` `[vscode].extensions`
- Per-language `tabSize` overrides for Python and Dockerfile
- Auto-create `.devcontainer/` output directory in generator functions
- Extra apt packages support via `workspace.toml` `[apt].extra_packages`
- Configurable port forwarding via `workspace.toml` `[ports].forward`
- Conditional Docker volume generation based on enabled plugins
- Auto-copy `.bashrc_custom` skeleton from example on first setup
- Externalized base apt packages into `config/apt-base-packages.conf`
- Curl security hardening: eliminated curl-pipe-sh patterns and added `-f` flag to all curl calls
- `uuid-runtime`, `python3`, `python3-pip`, `python3-venv`, `file`, `patch`, `gettext-base` to system packages
- Interactive workspace generator script (`generate-workspace.sh`)
- DevContainer management scripts (`rebuild-container.sh`, `lib/devcontainer.sh`)
- Python type annotations, `pytest` tests, `mypy` strict, `ruff`, `pyright` strict static analysis
- Snapshot regression tests comparing generated files against expected output
- Structural validity tests for generated Dockerfile, YAML, and JSON files
- Execution-based tests replacing source-grep approach for more reliable validation
- Integration tests for end-to-end file generation pipeline
- Plugin TOML structure validation test suite
- Duplicate apt package detection with unit tests
- `.env` file permission set to 600 after generation

### Changed
- **BREAKING**: Rewritten `setup-docker.sh` with plugin-based architecture
- **BREAKING**: Rewritten `generators.sh` with plugin-based generation pipeline
- **BREAKING**: Removed `switch-env.sh` and `.envs/` multi-environment management
- Redesigned `generators.py` with `Generator` ABC and 4 subclasses (Compose, DevcontainerJson, DevcontainerCompose, Dockerfile)
- Redesigned `toml_parser.py` with `TomlCommand` ABC, `ShellEncoder`, and Command pattern
- Replaced `eval` with `declare`/`printf -v` (nameref) for secure TOML output parsing
- Migrated Compose and Dockerfile generation to Python with PyYAML
- Inlined Dockerfile template into `generators.py` (removed `templates/` directory)
- Simplified devcontainer.json generator by removing JSONC template comments
- Split `lib/` into focused modules with consistent naming
- Migrated Python dev dependencies to `uv` with lockfile
- Tests reorganized into genre-based subdirectories (`unit/`, `integration/`, `structure/`, `e2e/`)
- `ARG DOCKER_GID` conditional on docker-cli plugin enablement
- Default tools changed to minimal set (proto + Docker CLI only)
- All ShellCheck style-level warnings resolved with `.shellcheckrc` configuration
- README completely rewritten for plugin architecture and workspace.toml configuration
- README split into compact Quick Start (root) with detailed guides in `docs/`
  - `docs/setup.md` / `docs/setup.ja.md` — Full setup and configuration guide
  - `docs/usage.md` / `docs/usage.ja.md` — Development workflows, commands, mounted dirs
  - `docs/reference.md` / `docs/reference.ja.md` — Pre-installed software, project files
- Replaced pyenv references with proto in Python configuration examples
- `generators.sh` uses `trap` for safe temporary file cleanup on Python failure

### Removed
- `switch-env.sh` multi-environment switcher
- `.envs/` directory for environment profiles
- `test.sh` wrapper script (replaced by `tests/run_all.sh`)
- `[environment]` section dead code from `toml_parser.py` and `plugins.sh`
- Dead code: `validate_package_manager`, `confirm`, `generate_plugin_volumes`
- `templates/` directory (Dockerfile template inlined into `generators.py`)
- Deprecated version field from template substitution
- Non-functional `chat.instructionsFilesLocations` configuration

### Fixed
- `forwardPorts` now uses full `ports.forward` array in devcontainer.json
- JSONC comment stripping replaced with Python regex to preserve URLs
- `USER` double-wrap fix in `github-cli.toml`
- `check_python3 --check` logic corrected
- `pyright` `represent_scalar` Unknown type error resolved
- Removed GID 999 fallback in Docker GID detection
- APT_EXTRA_PACKAGES placeholder replacement handling leading whitespace
- Locale-gen restoration after APT_EXTRA_PACKAGES placeholder replacement
- CI template validation YAML parsing errors

### Security
- SHA256 checksum verification for zig plugin binary downloads
- TLS 1.2+ enforcement for curl|sh plugin installers
- `eval` completely removed from TOML output parsing pipeline

## [3.1.0] - 2026-01-19

### Added
- Automatic CA certificate installation from certs/ directory with environment variable support
- Zig toolchain for cargo-lambda cross-compilation (optional installation)
- Persistent volumes for Deno (~/.deno), Bun (~/.bun), and Go (~/go) workspaces
- Rust toolchain support with Cargo and Rustup persistent volumes (~/.cargo, ~/.rustup)
- Custom bash configuration support via config/.bashrc_custom
- Network diagnostic utilities (ping, traceroute, dnsutils) to system packages
- bc (arbitrary precision calculator) package to system utilities
- Test validation for new persistent volumes for language runtimes
- certs/.gitkeep for CA certificate directory structure
- config/.bashrc_custom.example as a template for custom bash configuration

### Changed
- Moved bash history from .docker_history to XDG-compliant ~/.local/state/.bash_history_docker
- Moved custom bash configuration from ~/.bashrc_custom to workspace-docker/config/ for easier host editing
- Updated VS Code extensions recommendations in devcontainer.json
- Enhanced setup-docker.sh with automatic CA certificate configuration prompts
- Enhanced switch-env.sh to regenerate CA certificate installation scripts
- Improved test.sh to validate CA certificate setup and persistent volumes

### Removed
- ~/.gitconfig mount (Dev Container now copies ~/.gitconfig automatically)
- ~/.git-credentials mount (no longer needed with Dev Container's automatic handling)

### Fixed
- ShellCheck SC2088 warnings in setup-docker.sh regarding tilde expansion

## [3.0.0] - 2026-01-01

### Changed
- **BREAKING**: Removed Simple/Custom setup mode selection - now directly prompts for tool installation
- **BREAKING**: Removed SETUP_MODE from environment variables
- **BREAKING**: Dockerfile.custom.template merged into Dockerfile.template with placeholder-based generation
- Simplified setup flow with proto always installed and other tools individually selectable (default: Yes)
- All tool selection prompts now default to Yes for faster setup
- Unified template system - single Dockerfile.template for all configurations

### Removed
- Dockerfile.custom.template (merged into Dockerfile.template)
- docker-compose.custom.template (no longer needed)
- validate_setup_mode function from lib/validators.sh
- SETUP_MODE variable from .env files
- Mode-related documentation from README files

### Fixed
- Reduced code complexity by removing 754 lines
- Improved user experience with streamlined setup process
- Eliminated confusion between Simple and Custom modes

## [2.2.0] - 2025-12-27

### Added
- Centralized version configuration file (lib/versions.conf)
- Shared generator functions library (lib/generators.sh)
- Input validation library (lib/validators.sh)
- Error handling library (lib/logging.sh)
- Safe environment variable parsing utility (read_env_var)
- Symlink validation utility (validate_symlink)
- Docker GID detection with fallback logic (detect_docker_gid)
- Service name prefixes to Docker volume names for scope isolation
- ShellCheck package to development environment
- GitHub Actions CI/CD workflow with:
  - ShellCheck static analysis
  - Automated test execution
  - Template validation
  - Dockerfile linting with Hadolint
  - Docker build verification
- Comprehensive test coverage for:
  - Validator functions
  - Error handling functions
  - Volume scoping
  - Utility functions

### Changed
- Refactored setup-docker.sh to use shared generator library
- Refactored switch-env.sh to use shared generator library
- All scripts now use centralized validation and error handling libraries
- NVM version now auto-detected from GitHub API (latest release)
- Dockerfile layers optimized with --no-install-recommends and improved cleanup
- Test suite updated to skip missing files in CI environment
- Hadolint rules configured for development environment compatibility
- Ubuntu version management centralized in lib/versions.conf
- Removed duplicate sections from English README

### Fixed
- All ShellCheck warnings resolved across shell scripts
- Volume naming conflicts prevented with service name prefixes
- Improved error messages with lib/logging.sh functions

## [2.1.0] - 2025-12-27

### Added
- AWS SAM CLI with automatic architecture detection (x86_64/aarch64)
- AWS configuration persistence via Docker volume (~/.aws)
- GitHub CLI (gh) with persistent configuration and authentication storage
- Multi-root workspace generator script (generate-workspace.sh)
- Comprehensive multi-root workspace documentation in README
- Volume support for AWS CLI and GitHub CLI configurations

### Changed
- AWS CLI configuration now persists in Docker volume instead of bind mount
- Dockerfile templates reorganized with improved tool installation order
- README updated with AWS SAM CLI and GitHub CLI setup instructions

### Fixed
- AWS credential path and permission issues resolved with volume-based persistence

## [2.0.0] - 2025-11-25

### Added
- Custom setup mode with flexible package manager selection
- Python package manager options: uv, poetry, pyenv+poetry, mise, or none
- Node.js version manager options: Volta, nvm, fnm, mise, or none
- Support for mise (multi-language version manager)
- Dockerfile.custom.template for custom mode configurations
- docker-compose.custom.template with volumes for all package managers
- Comprehensive test suite with 8 advanced validation checks:
  - Template placeholder consistency validation
  - Unreplaced placeholder detection in generated files
  - docker-compose.yml syntax validation
  - Shell script syntax checking
  - Environment file format validation
  - Package manager function testing
  - Mode-aware volume mount point validation (Normal/Custom)
  - .gitignore pattern coverage check
- Test skip functionality with separate counter
- Conditional python3 installation (only for poetry and pyenv+poetry)
- Volume support for poetry, pyenv, nvm, fnm, and mise
- switch-env.sh now regenerates Dockerfile and docker-compose.yml on environment switch
- Essential system packages (39 packages) to Dockerfile templates
- Detailed package manager documentation in README (English and Japanese)

### Changed
- **BREAKING**: setup-docker.sh interactive prompts changed from automatic installation to flexible package manager selection
- **BREAKING**: .envs/*.env file structure now includes PYTHON_MANAGER and NODEJS_MANAGER variables
- **BREAKING**: Configuration system redesigned to support Normal and Custom modes
- switch-env.sh now validates SETUP_MODE and regenerates all configuration files
- README.md and docs/README.ja.md updated with comprehensive package manager information
- Volume mount directories are now created for all package managers regardless of selection
- docker-compose.yml.template (Normal mode) now includes all package manager volumes for data safety

### Fixed
- switch-env.sh now properly regenerates Dockerfile and docker-compose.yml based on selected tools

## [1.0.0] - 2025-11-09

### Added
- Docker-based Ubuntu development environment
- Support for Python (uv), Node.js (Volta), Docker CLI, AWS CLI v2
- VS Code Dev Container integration
- Multi-environment management with .envs directory
- Automatic UID/GID/Docker GID detection
- Persistent volume support for development tools
- Environment variable validation in switch-env.sh
- SSH mount security documentation
- UTF-8 locale configuration for Japanese text display
- Test script (test.sh) for project validation with visual file status indicators
- Comprehensive Docker command reference in README
- CHANGELOG.md for version tracking
- LICENSE (MIT License)
