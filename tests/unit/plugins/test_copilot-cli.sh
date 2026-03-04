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
    assert_file_contains "install contains Copilot" <(echo "$result") "Copilot"
}

# ============================================================
# Run
# ============================================================

test_copilot_cli

print_summary
