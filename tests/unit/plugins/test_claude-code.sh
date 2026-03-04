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
    assert_file_contains "install contains Claude" <(echo "$result") "Claude"
}

# ============================================================
# Run
# ============================================================

test_claude_code

print_summary
