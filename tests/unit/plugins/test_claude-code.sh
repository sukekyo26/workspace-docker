#!/bin/bash
# ============================================================
# tests/unit/plugins/test_claude-code.sh
# Plugin-specific tests for claude-code
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_claude-code.sh ]"

# ============================================================
# Test: claude-code plugin specifics
# ============================================================
test_claude_code() {
    section "claude-code specifics"

    load_plugin "claude-code"
    assert_eq "PLUGIN_NAME" "Claude Code" "$PLUGIN_NAME"
    assert_eq "PLUGIN_DEFAULT" "false" "$PLUGIN_DEFAULT"
    assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
    assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
    assert_eq "volume name is claude" "claude" "${PLUGIN_VOLUME_NAMES[0]}"

    local result
    result=$(generate_plugin_installs "claude-code")
    assert_true "install contains Claude" echo "$result" | grep -q "Claude"
}

# ============================================================
# Test: claude-code volume generation
# ============================================================
test_claude_code_volumes() {
    section "claude-code volume generation"

    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    cat > "$tmpfile" << 'EOF'
[container]
service_name = "vol-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["claude-code"]

[ports]
forward = [3000]
EOF

    load_workspace_config "$tmpfile"
    generate_plugin_volumes "claude-code"

    assert_true "mounts contain claude" echo "$_OPTIONAL_VOLUME_MOUNTS" | grep -q "claude"
    assert_true "definitions contain claude" echo "$_OPTIONAL_VOLUME_DEFINITIONS" | grep -q "claude"

    rm -f "$tmpfile"
}

# ============================================================
# Run
# ============================================================

test_claude_code
test_claude_code_volumes

print_summary
