#!/bin/bash
# ============================================================
# lib/plugins.sh - Plugin loading and generation functions
# ============================================================
# Provides functions for parsing workspace.toml and plugin TOML
# files, and generating Dockerfile/docker-compose.yml content
# from plugin definitions.
#
# Requires: Python 3.11+ (tomllib) or Python 3.x with tomli
# ============================================================

# Get the directory where this script is located
PLUGIN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOML_PARSER="$PLUGIN_LIB_DIR/toml_parser.py"

# Load utility functions (_safe_eval_toml_output)
# shellcheck source=utils.sh
source "$PLUGIN_LIB_DIR/utils.sh"

# ============================================================
# Python/TOML Prerequisites
# ============================================================

# Check if Python 3 and TOML parser are available
# Usage: check_python3
# Returns: 0 if available, 1 if not (with error message)
check_python3() {
    if ! command -v python3 &>/dev/null; then
        echo "ERROR: python3 is required but not found." >&2
        echo "  Install Python 3.11+ for built-in TOML support," >&2
        echo "  or install tomli: pip install tomli" >&2
        return 1
    fi

    if ! python3 "$TOML_PARSER" --help &>/dev/null 2>&1; then
        # Try running with a simple test to check TOML parser availability
        if ! python3 -c "
try:
    import tomllib
except ModuleNotFoundError:
    import tomli
" &>/dev/null 2>&1; then
            echo "ERROR: No TOML parser available." >&2
            echo "  Python 3.11+ includes tomllib." >&2
            echo "  For older Python: pip install tomli" >&2
            return 1
        fi
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
#       WS_VOLUME_NAMES, WS_VOLUME_PATHS,
#       WS_ENV_KEYS, WS_ENV_VALS
load_workspace_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: workspace.toml not found: $config_file" >&2
        return 1
    fi

    local output
    output=$(python3 "$TOML_PARSER" workspace "$config_file") || return 1
    _safe_eval_toml_output "$output" \
        WS_SERVICE_NAME WS_USERNAME WS_UBUNTU_VERSION \
        WS_PLUGINS WS_FORWARD_PORTS WS_APT_EXTRA \
        WS_VOLUME_NAMES WS_VOLUME_PATHS \
        WS_ENV_KEYS WS_ENV_VALS \
        WS_VSCODE_EXTENSIONS
}

# ============================================================
# Plugin Discovery and Loading
# ============================================================

# Get the plugins directory path
# Usage: get_plugins_dir
get_plugins_dir() {
    echo "$(cd "$PLUGIN_LIB_DIR/.." && pwd)/plugins"
}

# List available plugins with their metadata
# Usage: list_available_plugins
# Sets: PLUGIN_IDS, PLUGIN_NAMES, PLUGIN_DESCRIPTIONS, PLUGIN_DEFAULTS
list_available_plugins() {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    if [[ ! -d "$plugins_dir" ]]; then
        echo "ERROR: plugins directory not found: $plugins_dir" >&2
        return 1
    fi

    local output
    output=$(python3 "$TOML_PARSER" list-plugins "$plugins_dir") || return 1
    _safe_eval_toml_output "$output" \
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
        echo "ERROR: Plugin not found: $plugin_file" >&2
        return 1
    fi

    local output
    output=$(python3 "$TOML_PARSER" plugin "$plugin_file") || return 1
    _safe_eval_toml_output "$output" \
        PLUGIN_ID PLUGIN_NAME PLUGIN_DESCRIPTION PLUGIN_DEFAULT \
        PLUGIN_DOCKERFILE PLUGIN_REQUIRES_ROOT \
        PLUGIN_APT_PACKAGES \
        PLUGIN_VOLUME_NAMES PLUGIN_VOLUME_PATHS \
        PLUGIN_VERSION_PIN PLUGIN_VERSION_STRATEGY
}

# ============================================================
# Dockerfile Generation from Plugins
# ============================================================

# Generate combined Dockerfile install snippets for enabled plugins
# Usage: generate_plugin_installs "plugin1" "plugin2" ...
# Returns: combined Dockerfile content on stdout
#
# If a plugin has requires_root = true, USER root / USER ${USERNAME}
# is automatically wrapped around its snippet. Plugin TOMLs should NOT
# include these USER directives manually.
generate_plugin_installs() {
    local enabled_plugins=("$@")
    local result=""

    for plugin_id in "${enabled_plugins[@]}"; do
        load_plugin "$plugin_id" || continue

        local snippet="$PLUGIN_DOCKERFILE"
        if [[ -z "$snippet" ]]; then
            continue
        fi

        # Strip trailing newlines
        while [[ "$snippet" == *$'\n' ]]; do
            snippet="${snippet%$'\n'}"
        done

        # Replace {{VERSION}} with pinned version if available
        if [[ -n "$PLUGIN_VERSION_PIN" ]]; then
            snippet="${snippet//\{\{VERSION\}\}/$PLUGIN_VERSION_PIN}"
        fi

        # Auto-wrap with USER directives for root-requiring plugins
        if [[ "$PLUGIN_REQUIRES_ROOT" == "true" ]]; then
            snippet="USER root
${snippet}
USER \${USERNAME}"
        fi

        if [[ -n "$result" ]]; then
            result="${result}
"
        fi
        result="${result}${snippet}"
    done

    printf '%s' "$result"
}
