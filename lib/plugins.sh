#!/bin/bash
# ============================================================
# lib/plugins.sh - Plugin loading and generation functions
# ============================================================
# Provides functions for parsing workspace.toml and plugin TOML
# files, and generating Dockerfile/docker-compose.yml content
# from plugin definitions.
#
# Requires: uv (Python package manager) + Python 3.11+
# ============================================================
set -uo pipefail

# Get the directory where this script is located
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_ROOT="$(cd "$_LIB_DIR/.." && pwd)"
TOML_PARSER="$_LIB_DIR/toml_parser.py"

# Run Python via uv with correct project root
# Supports _UV_PROJECT_ROOT override for integration tests
_uv_python() {
  uv run --no-dev --project "${_UV_PROJECT_ROOT:-$_PROJECT_ROOT}" python "$@"
}

# Load utility functions (_parse_toml_output)
# shellcheck source=utils.sh
source "$_LIB_DIR/utils.sh"
# shellcheck source=i18n.sh
source "$_LIB_DIR/i18n.sh"

# ============================================================
# Python/TOML Prerequisites
# ============================================================

# Check if uv and Python are available
# Usage: check_uv
# Returns: 0 if available, 1 if not (with error message)
check_uv() {
  if ! command -v uv &>/dev/null; then
    echo "ERROR: $(msg err_uv_not_found)" >&2
    msgln err_uv_install_hint >&2
    return 1
  fi

  if ! _uv_python "$TOML_PARSER" --check &>/dev/null; then
    echo "ERROR: $(msg err_toml_check_failed)" >&2
    msgln err_toml_run_sync >&2
    return 1
  fi

  return 0
}

# ============================================================
# Workspace Config Loading
# ============================================================

# Load workspace.toml into shell variables
# Usage: load_workspace_config "workspace.toml"
# Sets: WS_SERVICE_NAME, WS_USERNAME, WS_UBUNTU_VERSION,
#       WS_PLUGINS, WS_FORWARD_PORTS, WS_APT_EXTRA,
#       WS_VOLUME_NAMES, WS_VOLUME_PATHS
load_workspace_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: $(msg err_workspace_toml_not_found "$config_file")" >&2
    return 1
  fi

  local output
  output=$(_uv_python "$TOML_PARSER" workspace "$config_file") || return 1
  _parse_toml_output "$output" \
    WS_SERVICE_NAME WS_USERNAME WS_UBUNTU_VERSION \
    WS_PLUGINS WS_FORWARD_PORTS WS_APT_EXTRA \
    WS_VOLUME_NAMES WS_VOLUME_PATHS \
    WS_VSCODE_EXTENSIONS
}

# ============================================================
# Plugin Discovery and Loading
# ============================================================

# Get the plugins directory path
# Usage: get_plugins_dir
get_plugins_dir() {
  echo "$(cd "$_LIB_DIR/.." && pwd)/plugins"
}

# Validate workspace.toml against JSON Schema
# Usage: validate_workspace_toml "workspace.toml"
# Returns: 0 if valid, 1 if invalid (with error messages)
validate_workspace_toml() {
  local config_file="$1"
  _uv_python "$TOML_PARSER" validate-workspace "$config_file"
}

# Validate all plugin TOML files against JSON Schema
# Usage: validate_plugin_tomls
# Returns: 0 if valid, 1 if invalid (with error messages)
validate_plugin_tomls() {
  local plugins_dir
  plugins_dir=$(get_plugins_dir)
  _uv_python "$TOML_PARSER" validate-plugins "$plugins_dir"
}

# Sync workspace.schema.json plugins enum from plugins/ directory
# Usage: sync_plugin_schema
sync_plugin_schema() {
  local plugins_dir
  plugins_dir=$(get_plugins_dir)
  _uv_python "$TOML_PARSER" sync-schema "$plugins_dir"
}

# Check if a TOML section exists in a file
# Usage: has_toml_section "workspace.toml" "container"
# Returns: 0 if section exists, 1 if not
has_toml_section() {
  local config_file="$1"
  local section="$2"
  local result
  result=$(_uv_python "$TOML_PARSER" has-section "$config_file" "$section") || return 1
  [[ "$result" == "true" ]]
}

# Dump [devcontainer] section as TOML text for preservation
# Usage: dump_devcontainer_section "workspace.toml"
# Outputs TOML text to stdout (empty if no [devcontainer])
dump_devcontainer_section() {
  local config_file="$1"
  _uv_python "$TOML_PARSER" dump-devcontainer "$config_file"
}

# List available plugins with their metadata
# Usage: list_available_plugins
# Sets: PLUGIN_IDS, PLUGIN_NAMES, PLUGIN_DESCRIPTIONS, PLUGIN_DEFAULTS
list_available_plugins() {
  local plugins_dir
  plugins_dir=$(get_plugins_dir)

  if [[ ! -d "$plugins_dir" ]]; then
    echo "ERROR: $(msg err_plugins_dir_not_found "$plugins_dir")" >&2
    return 1
  fi

  local output
  output=$(_uv_python "$TOML_PARSER" list-plugins "$plugins_dir") || return 1
  _parse_toml_output "$output" \
    PLUGIN_IDS PLUGIN_NAMES PLUGIN_DESCRIPTIONS PLUGIN_DEFAULTS
}

# Load a single plugin's definition
# Usage: load_plugin "plugin-id"
# Sets: PLUGIN_ID, PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_DEFAULT,
#       PLUGIN_DOCKERFILE, PLUGIN_REQUIRES_ROOT,
#       PLUGIN_VOLUME_NAMES, PLUGIN_VOLUME_PATHS,
#       PLUGIN_VERSION_PIN, PLUGIN_VERSION_STRATEGY
load_plugin() {
  local plugin_id="$1"
  local plugins_dir
  plugins_dir=$(get_plugins_dir)
  local plugin_file="$plugins_dir/${plugin_id}.toml"

  if [[ ! -f "$plugin_file" ]]; then
    echo "ERROR: $(msg err_plugin_not_found "$plugin_file")" >&2
    return 1
  fi

  local output
  output=$(_uv_python "$TOML_PARSER" plugin "$plugin_file") || return 1
  _parse_toml_output "$output" \
    PLUGIN_ID PLUGIN_NAME PLUGIN_DESCRIPTION PLUGIN_DEFAULT \
    PLUGIN_DOCKERFILE PLUGIN_REQUIRES_ROOT PLUGIN_USER_DIRS \
    PLUGIN_APT_PACKAGES \
    PLUGIN_VOLUME_NAMES PLUGIN_VOLUME_PATHS \
    PLUGIN_VERSION_PIN PLUGIN_VERSION_STRATEGY
}
