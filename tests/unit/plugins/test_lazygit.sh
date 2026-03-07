#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../../test_helper.sh
source "$(cd "$(dirname "$0")/../.." && pwd)/test_helper.sh"
# shellcheck source=plugin_test_helper.sh
source "$(cd "$(dirname "$0")" && pwd)/plugin_test_helper.sh"

test_lazygit() {
  section "lazygit specifics"

  load_plugin "lazygit"
  assert_eq "PLUGIN_NAME" "lazygit" "$PLUGIN_NAME"
  assert_eq "PLUGIN_REQUIRES_ROOT" "true" "$PLUGIN_REQUIRES_ROOT"
  assert_eq "PLUGIN_VERSION_PIN is set" "0.59.0" "$PLUGIN_VERSION_PIN"

  local default
  default=$(get_plugin_default "lazygit")
  assert_eq "PLUGIN_DEFAULT matches TOML" "$default" "$PLUGIN_DEFAULT"

  local result
  result=$(generate_plugin_installs "lazygit")
  assert_file_contains "contains lazygit" <(echo "$result") "lazygit"
  assert_file_contains "contains 0.59.0" <(echo "$result") "0.59.0"
  assert_file_not_contains "no {{VERSION}} placeholder" <(echo "$result") '{{VERSION}}'
  assert_file_contains "contains sha256sum check" <(echo "$result") 'sha256sum -c -'
  assert_file_not_contains "no {{CHECKSUM_AMD64}} placeholder" <(echo "$result") '{{CHECKSUM_AMD64}}'
  assert_file_not_contains "no {{CHECKSUM_ARM64}} placeholder" <(echo "$result") '{{CHECKSUM_ARM64}}'
  assert_file_contains "uses TLS 1.2" <(echo "$result") "tlsv1.2"
}

test_lazygit
print_summary
