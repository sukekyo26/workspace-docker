#!/bin/bash
# ============================================================
# tests/unit/plugins/test_copilot-cli.sh
# Plugin-specific tests for copilot-cli
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_copilot-cli.sh ]"

# ============================================================
# Test: copilot-cli plugin specifics
# ============================================================
test_copilot_cli() {
    section "copilot-cli specifics"

    load_plugin "copilot-cli"
    assert_eq "PLUGIN_NAME" "GitHub Copilot CLI" "$PLUGIN_NAME"
    assert_eq "PLUGIN_DEFAULT" "false" "$PLUGIN_DEFAULT"
    assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
    assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
    assert_eq "volume name is copilot" "copilot" "${PLUGIN_VOLUME_NAMES[0]}"

    local result
    result=$(generate_plugin_installs "copilot-cli")
    assert_true "install contains Copilot" echo "$result" | grep -q "Copilot"
}

# ============================================================
# Test: copilot-cli volume generation
# ============================================================
test_copilot_cli_volumes() {
    section "copilot-cli volume generation"

    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    cat > "$tmpfile" << 'EOF'
[container]
service_name = "vol-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["copilot-cli"]

[ports]
forward = [3000]
EOF

    load_workspace_config "$tmpfile"
    generate_plugin_volumes "copilot-cli"

    assert_true "mounts contain copilot" echo "$_OPTIONAL_VOLUME_MOUNTS" | grep -q "copilot"
    assert_true "definitions contain copilot" echo "$_OPTIONAL_VOLUME_DEFINITIONS" | grep -q "copilot"

    rm -f "$tmpfile"
}

# ============================================================
# Run
# ============================================================

test_copilot_cli
test_copilot_cli_volumes

print_summary
