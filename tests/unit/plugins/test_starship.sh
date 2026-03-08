#!/bin/bash
# ============================================================
# tests/unit/plugins/test_starship.sh
# Plugin-specific tests for starship
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_starship.sh ]"

# ============================================================
# Test: starship plugin specifics
# ============================================================
test_starship() {
  section "starship specifics"

  load_plugin "starship"
  assert_eq "PLUGIN_NAME" "Starship" "$PLUGIN_NAME"
  local expected_default
  expected_default=$(get_plugin_default "starship")
  assert_eq "PLUGIN_DEFAULT" "$expected_default" "$PLUGIN_DEFAULT"
  assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
  assert_ne "VERSION_PIN is set" "" "$PLUGIN_VERSION_PIN"

  local result
  result=$(generate_plugin_installs "starship")
  assert_file_contains "install contains starship" <(echo "$result") "starship"
  assert_file_contains "install verifies checksum" <(echo "$result") "sha256sum"
  assert_file_contains "TLS enforcement" <(echo "$result") "tlsv1.2"
}

# ============================================================
# Run
# ============================================================

test_starship

print_summary
