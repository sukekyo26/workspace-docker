#!/bin/bash
# ============================================================
# tests/unit/plugins/test_nerd-fonts.sh
# Plugin-specific tests for nerd-fonts
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_nerd-fonts.sh ]"

# ============================================================
# Test: nerd-fonts plugin specifics
# ============================================================
test_nerd_fonts() {
  section "nerd-fonts specifics"

  load_plugin "nerd-fonts"
  assert_eq "PLUGIN_NAME" "Nerd Fonts" "$PLUGIN_NAME"
  local expected_default
  expected_default=$(get_plugin_default "nerd-fonts")
  assert_eq "PLUGIN_DEFAULT" "$expected_default" "$PLUGIN_DEFAULT"
  assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
  assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
  assert_eq "volume name is fonts" "fonts" "${PLUGIN_VOLUME_NAMES[0]}"

  local result
  result=$(generate_plugin_installs "nerd-fonts")
  assert_file_contains "install downloads Meslo" <(echo "$result") "Meslo"
  assert_file_contains "install runs fc-cache" <(echo "$result") "fc-cache"
  assert_file_contains "TLS enforcement" <(echo "$result") "tlsv1.2"
  assert_file_contains "installs to .fonts" <(echo "$result") ".fonts"
}

# ============================================================
# Run
# ============================================================

test_nerd_fonts

print_summary
