#!/bin/bash
# ============================================================
# lib/generators.sh - Python generator wrappers
# ============================================================
# Provides: generate_compose, generate_devcontainer_json,
#           generate_devcontainer_compose, generate_dockerfile_from_template
# ============================================================
set -uo pipefail

# Get the directory where this script is located
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load plugin system
# shellcheck source=plugins.sh
source "$_LIB_DIR/plugins.sh"
# shellcheck source=i18n.sh
source "$_LIB_DIR/i18n.sh"

GENERATORS_PY="$_LIB_DIR/generators.py"

# Run Python generator safely with atomic write
# Usage: _run_generator "subcommand" "output_file" "workspace_toml"
# Note: Does NOT use trap to avoid overwriting caller's EXIT trap (ARCH-01)
_run_generator() {
  local subcommand="$1"
  local output_file="$2"
  local workspace_toml="$3"
  local plugins_dir
  plugins_dir="$(cd "$(dirname "$workspace_toml")" && pwd)/plugins"

  mkdir -p "$(dirname "$output_file")"

  # Remove stale temp files from previous interrupted runs
  rm -f "${output_file}".??????

  local tmp
  tmp=$(mktemp "${output_file}.XXXXXX")

  if ! _uv_python "$GENERATORS_PY" "$subcommand" "$workspace_toml" "$plugins_dir" > "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: $(msg err_generate_failed "$output_file" "$subcommand")" >&2
    return 1
  fi

  mv "$tmp" "$output_file"
}

# Generate docker-compose.yml programmatically
# Usage: generate_compose "output" "workspace_toml"
generate_compose() {
  _run_generator compose "$1" "$2"
}

# Generate devcontainer.json programmatically
# Usage: generate_devcontainer_json "output" "workspace_toml"
generate_devcontainer_json() {
  _run_generator devcontainer-json "$1" "$2"
}

# Generate .devcontainer/docker-compose.yml programmatically
# Usage: generate_devcontainer_compose "output" "workspace_toml"
generate_devcontainer_compose() {
  _run_generator devcontainer-compose "$1" "$2"
}

# Generate Dockerfile using plugin system (Python)
# Usage: generate_dockerfile_from_template "output" "workspace_toml"
generate_dockerfile_from_template() {
  _run_generator dockerfile "$1" "$2"
}
