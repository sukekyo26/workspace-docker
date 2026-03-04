#!/bin/bash
# ============================================================
# tests/unit/plugins/test_uv.sh
# Plugin-specific tests for uv
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_uv.sh ]"

# ============================================================
# Test: uv plugin specifics
# ============================================================
test_uv() {
    section "uv specifics"

    load_plugin "uv"
    assert_eq "PLUGIN_NAME" "uv" "$PLUGIN_NAME"
    assert_eq "PLUGIN_DEFAULT" "false" "$PLUGIN_DEFAULT"
    assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
    assert_true "no volumes" test "${#PLUGIN_VOLUME_NAMES[@]}" -eq 0

    local result
    result=$(generate_plugin_installs "uv")
    assert_file_contains "install contains uv" <(echo "$result") "uv"
    assert_file_contains "install sets PATH" <(echo "$result") "PATH"
}

# ============================================================
# Run
# ============================================================

test_uv

print_summary
