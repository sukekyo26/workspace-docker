#!/bin/bash
# ============================================================
# tests/unit/plugins/test_zig.sh
# Plugin-specific tests for zig
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_zig.sh ]"

# ============================================================
# Test: zig plugin specifics — version pinning
# ============================================================
test_zig() {
    section "zig specifics"

    load_plugin "zig"
    assert_eq "PLUGIN_VERSION_PIN is set" "0.14.0" "$PLUGIN_VERSION_PIN"
    assert_eq "PLUGIN_REQUIRES_ROOT" "true" "$PLUGIN_REQUIRES_ROOT"

    local result
    result=$(generate_plugin_installs "zig")
    assert_file_contains "contains 0.14.0" <(echo "$result") "0.14.0"
    assert_file_not_contains "no {{VERSION}} placeholder" <(echo "$result") '{{VERSION}}'
    assert_file_contains "contains sha256sum check" <(echo "$result") 'sha256sum -c -'
    assert_file_not_contains "no {{CHECKSUM_AMD64}} placeholder" <(echo "$result") '{{CHECKSUM_AMD64}}'
    assert_file_not_contains "no {{CHECKSUM_ARM64}} placeholder" <(echo "$result") '{{CHECKSUM_ARM64}}'
}

# ============================================================
# Run
# ============================================================

test_zig

print_summary
