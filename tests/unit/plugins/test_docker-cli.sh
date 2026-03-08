#!/bin/bash
# ============================================================
# tests/unit/plugins/test_docker-cli.sh
# Plugin-specific tests for docker-cli
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_docker-cli.sh ]"

# ============================================================
# Test: docker-cli plugin specifics
# ============================================================
test_docker_cli() {
  section "docker-cli specifics"

  load_plugin "docker-cli"
  assert_eq "PLUGIN_NAME" "Docker CLI" "$PLUGIN_NAME"
  assert_eq "PLUGIN_REQUIRES_ROOT" "true" "$PLUGIN_REQUIRES_ROOT"
  assert_true "PLUGIN_DOCKERFILE is non-empty" test -n "$PLUGIN_DOCKERFILE"

  local result
  result=$(generate_plugin_installs "docker-cli")
  assert_file_contains "install contains Docker" <(echo "$result") "Docker"
}

# ============================================================
# Run
# ============================================================

test_docker_cli

print_summary
