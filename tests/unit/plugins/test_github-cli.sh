#!/bin/bash
# ============================================================
# tests/unit/plugins/test_github-cli.sh
# Plugin-specific tests for github-cli
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_github-cli.sh ]"

# ============================================================
# Test: github-cli plugin specifics
# ============================================================
test_github_cli() {
    section "github-cli specifics"

    load_plugin "github-cli"
    assert_eq "PLUGIN_NAME" "GitHub CLI" "$PLUGIN_NAME"
    assert_eq "PLUGIN_REQUIRES_ROOT" "true" "$PLUGIN_REQUIRES_ROOT"
    assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
    assert_eq "volume name is gh-config" "gh-config" "${PLUGIN_VOLUME_NAMES[0]}"

    local result
    result=$(generate_plugin_installs "github-cli")
    assert_file_contains "install contains GitHub" <(echo "$result") "GitHub"
}

# ============================================================
# Run
# ============================================================

test_github_cli

print_summary
