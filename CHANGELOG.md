# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.1.0] - 2026-01-19

### Added
- Automatic CA certificate installation from certs/ directory with environment variable support
- Zig toolchain for cargo-lambda cross-compilation (optional installation)
- Persistent volumes for Deno (~/.deno), Bun (~/.bun), and Go (~/.go) workspaces
- Rust toolchain support with Cargo and Rustup persistent volumes (~/.cargo, ~/.rustup)
- Custom bash configuration support via workspace-docker/config/.bashrc_custom
- Network diagnostic utilities (ping, traceroute, dnsutils) to system packages
- bc (arbitrary precision calculator) package to system utilities
- Test validation for new persistent volumes for language runtimes
- certs/.gitkeep for CA certificate directory structure
- config/.bashrc_custom.example as a template for custom bash configuration

### Changed
- Moved bash history from .docker_history to XDG-compliant ~/.local/state/bash/history
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
- Error handling library (lib/errors.sh)
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
- Improved error messages with lib/errors.sh functions

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
