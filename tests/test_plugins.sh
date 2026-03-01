#!/bin/bash
# ============================================================
# tests/test_plugins.sh
# Tests for TOML parser, plugin loading, and generation
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_plugins.sh ]"

# Source libraries needed for tests
source "$PROJECT_ROOT/lib/errors.sh"
source "$PROJECT_ROOT/lib/generators.sh"

# ============================================================
# Test: Plugin infrastructure files exist
# ============================================================
test_plugin_files() {
    section "Plugin infrastructure files"

    assert_file_exists "toml_parser.py exists" "$PROJECT_ROOT/lib/toml_parser.py"
    assert_file_exists "plugin.sh exists" "$PROJECT_ROOT/lib/plugin.sh"
    assert_dir_exists "plugins/ directory exists" "$PROJECT_ROOT/plugins"
    assert_true "plugin.sh syntax valid" bash -n "$PROJECT_ROOT/lib/plugin.sh"
}

# ============================================================
# Test: Python TOML parser prerequisites
# ============================================================
test_python_prerequisites() {
    section "Python TOML parser prerequisites"

    assert_true "python3 is available" command -v python3
    assert_true "check_python3 passes" check_python3
}

# ============================================================
# Test: Plugin TOML files exist and are valid
# ============================================================
test_plugin_toml_files() {
    section "Plugin TOML files"

    local plugins_dir="$PROJECT_ROOT/plugins"

    # At least one plugin must exist
    shopt -s nullglob
    local toml_files=("$plugins_dir"/*.toml)
    shopt -u nullglob

    assert_true "at least one plugin exists" test "${#toml_files[@]}" -gt 0

    # Each TOML file must be parseable
    for toml_file in "${toml_files[@]}"; do
        local name
        name=$(basename "$toml_file" .toml)
        assert_true "$name.toml is valid TOML" python3 "$PROJECT_ROOT/lib/toml_parser.py" plugin "$toml_file"
    done
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
    output=$(python3 "$PROJECT_ROOT/lib/toml_parser.py" workspace "$tmpfile")
    assert_eq "exit code 0" "0" "$?"

    # Eval and check variables
    eval "$output"
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

[volumes]
test-data = "/home/${USERNAME}/.test"

[version]
pin = "1.2.3"
TOML

    local output
    output=$(python3 "$PROJECT_ROOT/lib/toml_parser.py" plugin "$tmpfile")
    assert_eq "exit code 0" "0" "$?"

    eval "$output"
    assert_eq "PLUGIN_NAME" "Test Tool" "$PLUGIN_NAME"
    assert_eq "PLUGIN_DESCRIPTION" "A test plugin" "$PLUGIN_DESCRIPTION"
    assert_eq "PLUGIN_DEFAULT" "true" "$PLUGIN_DEFAULT"
    assert_true "PLUGIN_DOCKERFILE contains RUN" echo "$PLUGIN_DOCKERFILE" | grep -q "RUN"
    assert_eq "PLUGIN_VOLUME_NAMES[0]" "test-data" "${PLUGIN_VOLUME_NAMES[0]}"
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

    # docker-cli should be in the list (with default=true)
    local found_docker=false
    for ((i = 0; i < ${#PLUGIN_IDS[@]}; i++)); do
        if [[ "${PLUGIN_IDS[$i]}" == "docker-cli" ]]; then
            found_docker=true
            assert_eq "docker-cli default is true" "true" "${PLUGIN_DEFAULTS[$i]}"
        fi
    done
    assert_eq "docker-cli found in plugins" "true" "$found_docker"
}

# ============================================================
# Test: load_plugin
# ============================================================
test_load_plugin() {
    section "load_plugin"

    load_plugin "docker-cli"
    assert_eq "PLUGIN_NAME is set" "Docker CLI" "$PLUGIN_NAME"
    assert_true "PLUGIN_DOCKERFILE is non-empty" test -n "$PLUGIN_DOCKERFILE"

    load_plugin "zig"
    assert_eq "zig PLUGIN_VERSION_PIN is set" "0.14.0" "$PLUGIN_VERSION_PIN"
}

# ============================================================
# Test: generate_plugin_installs
# ============================================================
test_generate_plugin_installs() {
    section "generate_plugin_installs"

    local result
    result=$(generate_plugin_installs "docker-cli")
    assert_true "docker-cli install contains Docker" echo "$result" | grep -q "Docker"

    result=$(generate_plugin_installs "zig")
    assert_true "zig install contains version" echo "$result" | grep -q "0.14.0"
    assert_file_not_contains "zig install has no {{VERSION}}" <(echo "$result") '{{VERSION}}'

    result=$(generate_plugin_installs "docker-cli" "github-cli")
    assert_true "multi-plugin contains Docker" echo "$result" | grep -q "Docker"
    assert_true "multi-plugin contains GitHub" echo "$result" | grep -q "GitHub"
}

# ============================================================
# Test: generate_plugin_volumes
# ============================================================
test_generate_plugin_volumes() {
    section "generate_plugin_volumes"

    # Create a minimal workspace.toml for the test
    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    cat > "$tmpfile" << 'EOF'
[container]
service_name = "vol-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["aws-cli", "github-cli"]

[ports]
forward = [3000]
EOF

    load_workspace_config "$tmpfile"
    generate_plugin_volumes "aws-cli" "github-cli"

    assert_true "mounts contain aws" echo "$_OPTIONAL_VOLUME_MOUNTS" | grep -q "aws"
    assert_true "mounts contain gh" echo "$_OPTIONAL_VOLUME_MOUNTS" | grep -q "gh"
    assert_true "definitions contain aws" echo "$_OPTIONAL_VOLUME_DEFINITIONS" | grep -q "aws"

    rm -f "$tmpfile"
}

# ============================================================
# Test: Version replacement in plugin installs
# ============================================================
test_version_replacement() {
    section "Version replacement"

    local result
    result=$(generate_plugin_installs "zig")

    # Should contain actual version, not placeholder
    assert_file_contains "contains 0.14.0" <(echo "$result") "0.14.0"
    assert_file_not_contains "no {{VERSION}} placeholder" <(echo "$result") '{{VERSION}}'
}

# ============================================================
# Run
# ============================================================

test_plugin_files
test_python_prerequisites
test_plugin_toml_files
test_toml_parser_workspace
test_toml_parser_plugin
test_list_available_plugins
test_load_plugin
test_generate_plugin_installs
test_generate_plugin_volumes
test_version_replacement

print_summary
