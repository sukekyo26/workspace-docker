#!/bin/bash
# ============================================================
# tests/unit/test_plugins.sh
# Tests for plugin infrastructure: TOML parser, plugin loading,
# and auto-discovery validation of all plugins
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_plugins.sh ]"

# Source libraries needed for tests
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/generators.sh"

# Generate plugin install snippets via Python (single source of truth)
# Usage: generate_plugin_installs "plugin1" "plugin2" ...
generate_plugin_installs() {
  _uv_python "$PROJECT_ROOT/lib/generators.py" plugin-installs "$PROJECT_ROOT/plugins" "$@"
}

# ============================================================
# Test: Plugin infrastructure files exist
# ============================================================
test_plugin_files() {
  section "Plugin infrastructure files"

  assert_file_exists "toml_parser.py exists" "$PROJECT_ROOT/lib/toml_parser.py"
  assert_file_exists "plugins.sh exists" "$PROJECT_ROOT/lib/plugins.sh"
  assert_dir_exists "plugins/ directory exists" "$PROJECT_ROOT/plugins"
  assert_true "plugins.sh syntax valid" bash -n "$PROJECT_ROOT/lib/plugins.sh"
}

# ============================================================
# Test: Python TOML parser prerequisites
# ============================================================
test_python_prerequisites() {
  section "uv and Python prerequisites"

  assert_true "uv is available" command -v uv
  assert_true "check_uv passes" check_uv
}

# ============================================================
# Test: toml_parser.py workspace subcommand
# ============================================================
test_toml_parser_workspace() {
  section "toml_parser.py workspace"

  local tmpfile
  tmpfile=$(mktemp --suffix=.toml)
  cat > "$tmpfile" << 'EOF'
[container]
service_name = "test-svc"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["docker-cli", "zig"]

[ports]
forward = [3000, 8080]
EOF

  local output
  output=$(_uv_python "$PROJECT_ROOT/lib/toml_parser.py" workspace "$tmpfile")
  assert_eq "exit code 0" "0" "$?"

  # Eval via whitelist
  _parse_toml_output "$output" \
    WS_SERVICE_NAME WS_USERNAME WS_UBUNTU_VERSION \
    WS_PLUGINS WS_FORWARD_PORTS WS_APT_EXTRA \
    WS_VOLUME_NAMES WS_VOLUME_PATHS \
    WS_VSCODE_EXTENSIONS
  assert_eq "WS_SERVICE_NAME" "test-svc" "$WS_SERVICE_NAME"
  assert_eq "WS_USERNAME" "testuser" "$WS_USERNAME"
  assert_eq "WS_UBUNTU_VERSION" "24.04" "$WS_UBUNTU_VERSION"
  assert_eq "WS_PLUGINS count" "2" "${#WS_PLUGINS[@]}"
  assert_eq "WS_PLUGINS[0]" "docker-cli" "${WS_PLUGINS[0]}"
  assert_eq "WS_PLUGINS[1]" "zig" "${WS_PLUGINS[1]}"
  assert_eq "WS_FORWARD_PORTS count" "2" "${#WS_FORWARD_PORTS[@]}"
  assert_eq "WS_FORWARD_PORTS[0]" "3000" "${WS_FORWARD_PORTS[0]}"

  rm -f "$tmpfile"
}

# ============================================================
# Test: toml_parser.py plugin subcommand
# ============================================================
test_toml_parser_plugin() {
  section "toml_parser.py plugin"

  local tmpfile
  tmpfile=$(mktemp --suffix=.toml)
  cat > "$tmpfile" << 'TOML'
[metadata]
name = "Test Tool"
description = "A test plugin"
default = true

[install]
dockerfile = '''
# Install Test Tool
RUN curl -fsSL https://example.com/install.sh | bash
'''
volumes = ["/home/${USERNAME}/.test"]

[version]
pin = "1.2.3"
TOML

  local output
  output=$(_uv_python "$PROJECT_ROOT/lib/toml_parser.py" plugin "$tmpfile")
  assert_eq "exit code 0" "0" "$?"

  _parse_toml_output "$output" \
    PLUGIN_ID PLUGIN_NAME PLUGIN_DESCRIPTION PLUGIN_DEFAULT \
    PLUGIN_DOCKERFILE PLUGIN_REQUIRES_ROOT PLUGIN_USER_DIRS \
    PLUGIN_APT_PACKAGES \
    PLUGIN_VOLUME_NAMES PLUGIN_VOLUME_PATHS \
    PLUGIN_VERSION_PIN PLUGIN_VERSION_STRATEGY
  assert_eq "PLUGIN_NAME" "Test Tool" "$PLUGIN_NAME"
  assert_eq "PLUGIN_DESCRIPTION" "A test plugin" "$PLUGIN_DESCRIPTION"
  assert_eq "PLUGIN_DEFAULT" "true" "$PLUGIN_DEFAULT"
  assert_file_contains "PLUGIN_DOCKERFILE contains RUN" <(echo "$PLUGIN_DOCKERFILE") "RUN"
  assert_eq "PLUGIN_VOLUME_NAMES[0]" "test" "${PLUGIN_VOLUME_NAMES[0]}"
  # shellcheck disable=SC2016
  assert_eq "PLUGIN_VOLUME_PATHS[0]" '/home/${USERNAME}/.test' "${PLUGIN_VOLUME_PATHS[0]}"
  assert_eq "PLUGIN_VERSION_PIN" "1.2.3" "$PLUGIN_VERSION_PIN"

  rm -f "$tmpfile"
}

# ============================================================
# Test: list_available_plugins
# ============================================================
test_list_available_plugins() {
  section "list_available_plugins"

  list_available_plugins

  assert_true "PLUGIN_IDS is non-empty" test "${#PLUGIN_IDS[@]}" -gt 0
}

# ============================================================
# Test: All plugins common validation (auto-discovery)
# ============================================================
test_all_plugins_common() {
  section "All plugins common validation"

  local plugins_dir="$PROJECT_ROOT/plugins"

  shopt -s nullglob
  local toml_files=("$plugins_dir"/*.toml)
  shopt -u nullglob

  assert_true "at least one plugin exists" test "${#toml_files[@]}" -gt 0

  for toml_file in "${toml_files[@]}"; do
    local plugin_id
    plugin_id=$(basename "$toml_file" .toml)

    # TOML must be parseable
    assert_true "$plugin_id: TOML is valid" \
      _uv_python "$PROJECT_ROOT/lib/toml_parser.py" plugin "$toml_file"

    # Load and verify required fields
    load_plugin "$plugin_id"
    assert_true "$plugin_id: PLUGIN_NAME is set" test -n "$PLUGIN_NAME"
    assert_true "$plugin_id: PLUGIN_DESCRIPTION is set" test -n "$PLUGIN_DESCRIPTION"
    assert_true "$plugin_id: PLUGIN_DEFAULT is true or false" \
      test "$PLUGIN_DEFAULT" = "true" -o "$PLUGIN_DEFAULT" = "false"
    assert_true "$plugin_id: PLUGIN_DOCKERFILE is non-empty" test -n "$PLUGIN_DOCKERFILE"

    # generate_plugin_installs produces non-empty output
    local result
    result=$(generate_plugin_installs "$plugin_id")
    assert_true "$plugin_id: generate_plugin_installs produces output" test -n "$result"

    # If version is pinned, {{VERSION}} must be replaced
    if [[ -n "$PLUGIN_VERSION_PIN" ]]; then
      assert_file_not_contains "$plugin_id: no {{VERSION}} placeholder" \
        <(echo "$result") '{{VERSION}}'
      assert_file_contains "$plugin_id: contains pinned version" \
        <(echo "$result") "$PLUGIN_VERSION_PIN"
    fi
  done
}

# ============================================================
# Run
# ============================================================

test_plugin_files
test_python_prerequisites
test_toml_parser_workspace
test_toml_parser_plugin
test_list_available_plugins
test_all_plugins_common

print_summary
