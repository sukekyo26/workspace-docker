#!/bin/bash
# ============================================================
# tests/unit/plugins/test_aws-sam-cli.sh
# Plugin-specific tests for aws-sam-cli
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_aws-sam-cli.sh ]"

# ============================================================
# Test: aws-sam-cli plugin specifics
# ============================================================
test_aws_sam_cli() {
  section "aws-sam-cli specifics"

  load_plugin "aws-sam-cli"
  assert_eq "PLUGIN_NAME" "AWS SAM CLI" "$PLUGIN_NAME"
  local expected_default
  expected_default=$(get_plugin_default "aws-sam-cli")
  assert_eq "PLUGIN_DEFAULT" "$expected_default" "$PLUGIN_DEFAULT"
  assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
  assert_true "no volumes" test "${#PLUGIN_VOLUME_NAMES[@]}" -eq 0

  local result
  result=$(generate_plugin_installs "aws-sam-cli")
  assert_file_contains "install contains SAM" <(echo "$result") "SAM"
  assert_file_contains "install contains architecture detection" <(echo "$result") "dpkg --print-architecture"
  assert_file_contains "install uses TLS enforcement" <(echo "$result") "tlsv1.2"
}

# ============================================================
# Run
# ============================================================

test_aws_sam_cli

print_summary
