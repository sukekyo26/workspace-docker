#!/bin/bash
# ============================================================
# tests/unit/plugins/plugin_test_helper.sh
# Shared helper for per-plugin unit tests
# ============================================================
# Source this file at the top of each plugin test script.
# Provides: test_helper.sh assertions + lib/generators.sh + generate_plugin_installs
#           + get_plugin_default (reads default from TOML)
# ============================================================

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

# Source libraries needed for plugin tests
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/generators.sh"

# Generate plugin install snippets via Python (single source of truth)
# Usage: generate_plugin_installs "plugin1" "plugin2" ...
generate_plugin_installs() {
    _uv_python "$PROJECT_ROOT/lib/generators.py" plugin-installs "$PROJECT_ROOT/plugins" "$@"
}

# Read a plugin's metadata.default value from its TOML file
# Usage: get_plugin_default "plugin-id"
# Returns: "true" or "false"
get_plugin_default() {
    local plugin_id="$1"
    _uv_python "$PROJECT_ROOT/lib/toml_parser.py" plugin "$PROJECT_ROOT/plugins/${plugin_id}.toml" \
        | grep '^S:PLUGIN_DEFAULT=' | sed 's/^S:PLUGIN_DEFAULT=//'
}
