#!/bin/bash
# ============================================================
# tests/unit/plugins/test_go.sh
# Plugin-specific tests for go
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_go.sh ]"

# ============================================================
# Test: go plugin specifics
# ============================================================
test_go() {
  section "go specifics"

  load_plugin "go"
  assert_eq "PLUGIN_NAME" "Go" "$PLUGIN_NAME"
  local expected_default
  expected_default=$(get_plugin_default "go")
  assert_eq "PLUGIN_DEFAULT" "$expected_default" "$PLUGIN_DEFAULT"
  assert_eq "PLUGIN_REQUIRES_ROOT" "true" "$PLUGIN_REQUIRES_ROOT"
  assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
  assert_eq "volume name go" "go" "${PLUGIN_VOLUME_NAMES[0]}"
  assert_ne "VERSION_PIN is set" "" "$PLUGIN_VERSION_PIN"

  local result
  result=$(generate_plugin_installs "go")
  assert_file_contains "install contains go" <(echo "$result") "go.dev"
  assert_file_contains "install sets GOPATH" <(echo "$result") "GOPATH"
  assert_file_contains "TLS enforcement" <(echo "$result") "tlsv1.2"
}

# ============================================================
# Run
# ============================================================

test_go

print_summary
