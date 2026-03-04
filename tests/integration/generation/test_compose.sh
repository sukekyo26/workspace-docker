#!/bin/bash
# ============================================================
# tests/integration/generation/test_compose.sh
# Integration tests for docker-compose.yml generation
# shellcheck disable=SC2031  # Variables defined before subshells are intentionally used after them
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"
# shellcheck source=../integration_helper.sh
source "$TESTS_DIR/integration/integration_helper.sh"

echo ""
echo "[ test_compose.sh ]"

# ============================================================
# Test: docker-compose.yml generation
# ============================================================
test_docker_compose_generation() {
    section "docker-compose.yml generation"

    setup_workspace
    local service_name="test-service"
    create_test_workspace_toml "$WORK_DIR" "$service_name" "testuser" \
        "aws-cli" "github-cli"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_compose \
            "docker-compose.yml" "workspace.toml"
    )

    assert_file_exists "docker-compose.yml generated" "$WORK_DIR/docker-compose.yml"
    assert_file_not_matches "no unreplaced {{...}}" "$WORK_DIR/docker-compose.yml" '\{\{.*\}\}'
    assert_file_contains "service name replaced" "$WORK_DIR/docker-compose.yml" "$service_name"
    assert_file_matches "volumes section exists" "$WORK_DIR/docker-compose.yml" '^volumes:'
    assert_file_contains "aws volume present" "$WORK_DIR/docker-compose.yml" 'aws:'
    assert_file_contains "gh-config volume present" "$WORK_DIR/docker-compose.yml" 'gh-config:'

    teardown_workspace
}

# ============================================================
# Test: docker-compose.yml YAML validity
# ============================================================
test_compose_yaml_validity() {
    section "docker-compose.yml YAML validity"

    if ! python3 -c "import yaml" 2>/dev/null; then
        skip_test "docker-compose.yml YAML validity" "python3 yaml module not available"
        return
    fi

    setup_workspace
    create_test_workspace_toml "$WORK_DIR" "yaml-test" "testuser" \
        "docker-cli" "aws-cli"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_compose \
            "docker-compose.yml" "workspace.toml"
    )

    local compose="$WORK_DIR/docker-compose.yml"

    # Replace ${...} env vars with dummy values for YAML parsing
    local clean_compose
    clean_compose=$(sed 's/\${[^}]*}/dummy/g' "$compose")

    # YAML parse
    if echo "$clean_compose" | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin)" 2>/dev/null; then
        assert_eq "docker-compose.yml is valid YAML" "valid" "valid"
    else
        assert_eq "docker-compose.yml is valid YAML" "valid" "invalid"
    fi

    # Compose structure: services key
    local has_services
    has_services=$(echo "$clean_compose" | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
print('yes' if 'services' in data else 'no')
" 2>/dev/null || echo "error")
    assert_eq "compose has services key" "yes" "$has_services"

    # Compose structure: volumes key
    local has_volumes
    has_volumes=$(echo "$clean_compose" | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
print('yes' if 'volumes' in data else 'no')
" 2>/dev/null || echo "error")
    assert_eq "compose has volumes key" "yes" "$has_volumes"

    # Service name match
    local svc_exists
    svc_exists=$(echo "$clean_compose" | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
print('yes' if 'yaml-test' in data.get('services', {}) else 'no')
" 2>/dev/null || echo "error")
    assert_eq "compose service name matches" "yes" "$svc_exists"

    teardown_workspace
}

# ============================================================
# Run
# ============================================================

test_docker_compose_generation
test_compose_yaml_validity

print_summary
