#!/bin/bash
# ============================================================
# lib/generators.sh - Python generator wrappers
# ============================================================
# Provides: generate_compose, generate_devcontainer_json,
#           generate_devcontainer_compose, generate_dockerfile_from_template
# ============================================================

# Get the directory where this script is located
_GEN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load plugin system
# shellcheck source=plugins.sh
source "$_GEN_LIB_DIR/plugins.sh"

GENERATORS_PY="$_GEN_LIB_DIR/generators.py"

# Generate docker-compose.yml programmatically
# Usage: generate_compose "output" "workspace_toml"
generate_compose() {
    local output_file="$1"
    local workspace_toml="$2"
    local plugins_dir
    plugins_dir="$(cd "$(dirname "$workspace_toml")" && pwd)/plugins"

    python3 "$GENERATORS_PY" compose "$workspace_toml" "$plugins_dir" > "$output_file"
}

# Generate devcontainer.json programmatically
# Usage: generate_devcontainer_json "output" "workspace_toml"
generate_devcontainer_json() {
    local output_file="$1"
    local workspace_toml="$2"
    local plugins_dir
    plugins_dir="$(cd "$(dirname "$workspace_toml")" && pwd)/plugins"

    mkdir -p "$(dirname "$output_file")"
    python3 "$GENERATORS_PY" devcontainer-json "$workspace_toml" "$plugins_dir" > "$output_file"
}

# Generate .devcontainer/docker-compose.yml programmatically
# Usage: generate_devcontainer_compose "output" "workspace_toml"
generate_devcontainer_compose() {
    local output_file="$1"
    local workspace_toml="$2"
    local plugins_dir
    plugins_dir="$(cd "$(dirname "$workspace_toml")" && pwd)/plugins"

    mkdir -p "$(dirname "$output_file")"
    python3 "$GENERATORS_PY" devcontainer-compose "$workspace_toml" "$plugins_dir" > "$output_file"
}

# Generate Dockerfile using plugin system (Python)
# Usage: generate_dockerfile_from_template "output" "workspace_toml"
generate_dockerfile_from_template() {
    local output_file="$1"
    local workspace_toml="$2"
    local plugins_dir
    plugins_dir="$(cd "$(dirname "$workspace_toml")" && pwd)/plugins"

    python3 "$GENERATORS_PY" dockerfile "$workspace_toml" "$plugins_dir" > "$output_file"
}
