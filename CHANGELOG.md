# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
