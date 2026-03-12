#!/bin/bash
# ============================================================
# lib/devcontainer.sh - devcontainer CLI & Docker prerequisite checks
# ============================================================
# Shared library sourced by rebuild-container.sh.
#
# Functions:
#   check_docker            Verify Docker is installed and running
#   check_devcontainer_cli  Check / auto-install devcontainer CLI
#   check_devcontainer_json Verify devcontainer.json exists
#   check_env_file          Verify .env exists
#   check_all_prerequisites Run all checks above
#   is_wsl                  Detect WSL environment
#   run_devcontainer        WSL-aware devcontainer CLI wrapper
# ============================================================
set -uo pipefail

# Load shared color constants
_DC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=colors.sh
source "$_DC_LIB_DIR/colors.sh"
# shellcheck source=i18n.sh
source "$_DC_LIB_DIR/i18n.sh"

# ============================================================
# check_docker
# ============================================================
# Verify Docker is installed and the daemon is running.
# Exits with code 1 on failure.
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "  ${RED}✗${NC} $(msg dc_docker_not_installed)"
    echo "    $(msg dc_docker_install_url)"
    exit 1
  fi
  if ! docker info &> /dev/null 2>&1; then
    echo -e "  ${RED}✗${NC} $(msg dc_docker_not_running)"
    echo "    $(msg dc_docker_start_hint)"
    exit 1
  fi
  echo -e "  ${GREEN}✓${NC} Docker"
}

# ============================================================
# _ensure_devcontainer_path
# ============================================================
# Add devcontainer CLI install location to PATH if not already present.
# Also warns the user to persist the PATH change in their shell profile.
_ensure_devcontainer_path() {
  local dc_bin="$HOME/.devcontainers/bin"
  if [[ -d "$dc_bin" ]] && [[ ":$PATH:" != *":$dc_bin:"* ]]; then
    export PATH="$dc_bin:$PATH"
    echo -e "  ${YELLOW}!${NC} $(msg dc_path_added "$dc_bin")"
    echo -e "    $(msg dc_path_persist_hint "$dc_bin")"
  fi
}

# ============================================================
# check_devcontainer_cli
# ============================================================
# Check for devcontainer CLI and auto-install via curl if missing.
# Install URL:
#   https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh
_DEVCONTAINER_INSTALL_SHA256="3f7ff412801e382b944fbf300c4f1ff49cf2534fa6cc80995da0b2963924c9da"

check_devcontainer_cli() {
  # Try adding devcontainer install path if command not found initially
  if ! command -v devcontainer &> /dev/null; then
    _ensure_devcontainer_path
  fi

  if ! command -v devcontainer &> /dev/null; then
    echo -e "  ${YELLOW}✗${NC} $(msg dc_cli_not_found)"

    if ! command -v curl &> /dev/null; then
      echo -e "  ${RED}✗${NC} $(msg dc_curl_not_found)"
      echo "    $(msg dc_curl_install_hint)"
      echo "      curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh | sh"
      exit 1
    fi

    # Ask user for permission to install
    echo -e "    $(msg dc_install_prompt)"
    local confirm
    read -rp "    [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo -e "  ${RED}✗${NC} $(msg dc_install_declined)"
      exit 1
    fi

    echo -e "    ${CYAN}$(msg dc_installing)${NC}"
    local install_script
    install_script=$(mktemp)
    # Do NOT use trap here to avoid overwriting caller's EXIT trap (ARCH-01)
    if ! curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh -o "$install_script"; then
      rm -f "$install_script"
      echo -e "  ${RED}✗${NC} $(msg dc_install_failed)"
      exit 1
    fi
    if ! echo "$_DEVCONTAINER_INSTALL_SHA256  $install_script" | sha256sum -c - &>/dev/null; then
      rm -f "$install_script"
      echo -e "  ${RED}✗${NC} Install script SHA256 mismatch (possible tampering). Expected: $_DEVCONTAINER_INSTALL_SHA256"
      exit 1
    fi
    sh "$install_script"
    rm -f "$install_script"

    _ensure_devcontainer_path

    if ! command -v devcontainer &> /dev/null; then
      echo -e "  ${RED}✗${NC} $(msg dc_install_not_in_path)"
      exit 1
    fi

    echo -e "  ${GREEN}✓${NC} devcontainer CLI installed"
  else
    echo -e "  ${GREEN}✓${NC} devcontainer CLI"
  fi
}

# ============================================================
# check_devcontainer_json <workspace_dir>
# ============================================================
check_devcontainer_json() {
  local workspace_dir="$1"
  if [[ ! -f "$workspace_dir/.devcontainer/devcontainer.json" ]]; then
    echo -e "  ${RED}✗${NC} $(msg dc_json_not_found)"
    echo "    $(msg dc_run_setup_first)"
    exit 1
  fi
  echo -e "  ${GREEN}✓${NC} devcontainer.json"
}

# ============================================================
# check_env_file <workspace_dir>
# ============================================================
check_env_file() {
  local workspace_dir="$1"
  if [[ ! -f "$workspace_dir/.env" ]]; then
    echo -e "  ${RED}✗${NC} $(msg dc_env_not_found)"
    echo "    $(msg dc_run_setup_first)"
    exit 1
  fi
  echo -e "  ${GREEN}✓${NC} .env"
}

# ============================================================
# check_all_prerequisites <workspace_dir>
# ============================================================
# Check Docker, devcontainer CLI, devcontainer.json, and .env all at once.
check_all_prerequisites() {
  local workspace_dir="$1"

  echo ""
  echo -e "${CYAN}$(msg dc_checking_prereqs)${NC}"

  check_docker
  check_devcontainer_cli
  check_devcontainer_json "$workspace_dir"
  check_env_file "$workspace_dir"
}

# ============================================================
# is_wsl
# ============================================================
# Detect whether running inside a WSL (WSL1/WSL2) environment.
is_wsl() {
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    return 0
  fi
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    return 0
  fi
  return 1
}

# ============================================================
# run_devcontainer
# ============================================================
# Wrapper function for devcontainer CLI.
#
# In WSL, the devcontainer CLI detects WSL via /proc/version and bridges
# docker commands to the Windows side.  If Docker Desktop is not installed
# on Windows, the container startup fails with ENOENT.
#
# This function works around the issue in WSL by:
#   1. Exporting DOCKER_HOST to the WSL Docker socket
#   2. Specifying --docker-path to the WSL docker binary
#
# This prevents the CLI from looking for Docker on the Windows side and
# uses the Docker daemon running inside WSL directly.
#
# On regular Linux environments (e.g. EC2), WSL is not detected so the
# CLI runs as-is.
#
# Usage:
#   run_devcontainer up --workspace-folder "$DIR"
#   run_devcontainer up --workspace-folder "$DIR" --build-no-cache
run_devcontainer() {
  if is_wsl; then
    local docker_path
    docker_path=$(command -v docker 2>/dev/null || true)

    if [[ -z "$docker_path" ]]; then
      echo -e "  ${RED}✗${NC} $(msg dc_docker_not_found_wsl)"
      exit 1
    fi

    export DOCKER_HOST="unix:///var/run/docker.sock"
    devcontainer "$@" --docker-path "$docker_path"
  else
    devcontainer "$@"
  fi
}
