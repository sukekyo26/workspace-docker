#!/bin/bash
# ============================================================
# tests/unit/plugins/test_rust.sh
# Plugin-specific tests for rust
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_rust.sh ]"

# ============================================================
# Test: rust plugin specifics
# ============================================================
test_rust() {
  section "rust specifics"

  load_plugin "rust"
  assert_eq "PLUGIN_NAME" "Rust" "$PLUGIN_NAME"
  local expected_default
  expected_default=$(get_plugin_default "rust")
  assert_eq "PLUGIN_DEFAULT" "$expected_default" "$PLUGIN_DEFAULT"
  assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
  assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
  assert_eq "volume name cargo" "cargo" "${PLUGIN_VOLUME_NAMES[0]}"
  assert_eq "volume name rustup" "rustup" "${PLUGIN_VOLUME_NAMES[1]}"

  local result
  result=$(generate_plugin_installs "rust")
  assert_file_contains "install contains rustup" <(echo "$result") "rustup"
  assert_file_contains "install sets PATH" <(echo "$result") "PATH"
  assert_file_contains "TLS enforcement" <(echo "$result") "tlsv1.2"
}

# ============================================================
# Run
# ============================================================

test_rust

print_summary
