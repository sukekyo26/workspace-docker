#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../../test_helper.sh
source "$(cd "$(dirname "$0")/../.." && pwd)/test_helper.sh"
# shellcheck source=plugin_test_helper.sh
source "$(cd "$(dirname "$0")" && pwd)/plugin_test_helper.sh"

test_custom_ps1() {
  section "custom-ps1 specifics"

  load_plugin "custom-ps1"
  assert_eq "PLUGIN_NAME" "Custom PS1" "$PLUGIN_NAME"
  assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"

  local default
  default=$(get_plugin_default "custom-ps1")
  assert_eq "PLUGIN_DEFAULT matches TOML" "$default" "$PLUGIN_DEFAULT"

  local result
  result=$(generate_plugin_installs "custom-ps1")
  assert_file_contains "contains PS1" <(echo "$result") "PS1="
  assert_file_contains "contains GIT_PS1" <(echo "$result") "GIT_PS1_SHOWDIRTYSTATE"
  assert_file_contains "contains git_ps1" <(echo "$result") "__git_ps1"
}

test_custom_ps1
print_summary
