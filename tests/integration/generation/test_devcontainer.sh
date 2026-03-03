#!/bin/bash
# ============================================================
# tests/integration/generation/test_devcontainer.sh
# Integration tests for devcontainer.json and
# .devcontainer/docker-compose.yml generation
# shellcheck disable=SC2031  # Variables defined before subshells are intentionally used after them
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"
# shellcheck source=../integration_helper.sh
source "$TESTS_DIR/integration/integration_helper.sh"

echo ""
echo "[ test_devcontainer.sh ]"

# ============================================================
# Test: devcontainer.json generation
# ============================================================
test_devcontainer_json_generation() {
    section "devcontainer.json generation"

    setup_workspace
    local service_name="test-service"
    local username="testuser"

    create_test_workspace_toml "$WORK_DIR" "$service_name" "$username"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_json \
            ".devcontainer/devcontainer.json" "workspace.toml"
    )

    assert_file_exists "devcontainer.json generated" "$WORK_DIR/.devcontainer/devcontainer.json"
    assert_file_not_contains "no unreplaced {{...}}" "$WORK_DIR/.devcontainer/devcontainer.json" '{{.*}}'
    assert_file_contains "service name in devcontainer.json" "$WORK_DIR/.devcontainer/devcontainer.json" "$service_name"
    assert_file_contains "username in devcontainer.json" "$WORK_DIR/.devcontainer/devcontainer.json" "$username"

    teardown_workspace
}

# ============================================================
# Test: .devcontainer/docker-compose.yml generation
# ============================================================
test_devcontainer_compose_generation() {
    section ".devcontainer/docker-compose.yml generation"

    setup_workspace
    local service_name="test-service"

    create_test_workspace_toml "$WORK_DIR" "$service_name" "testuser"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_compose \
            ".devcontainer/docker-compose.yml" "workspace.toml"
    )

    assert_file_exists ".devcontainer/docker-compose.yml generated" "$WORK_DIR/.devcontainer/docker-compose.yml"
    assert_file_not_contains "no unreplaced {{...}}" "$WORK_DIR/.devcontainer/docker-compose.yml" '{{.*}}'
    assert_file_contains "service name replaced" "$WORK_DIR/.devcontainer/docker-compose.yml" "$service_name"

    teardown_workspace
}

# ============================================================
# Test: devcontainer.json JSON validity
# ============================================================
test_devcontainer_json_validity() {
    section "devcontainer.json JSON validity"

    setup_workspace
    local service="json-test"
    local username="testuser"

    create_test_workspace_toml "$WORK_DIR" "$service" "$username"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_json \
            ".devcontainer/devcontainer.json" "workspace.toml"
    )

    local dcjson="$WORK_DIR/.devcontainer/devcontainer.json"

    # Strip // comments for JSON parsing (jsonc -> json)
    local clean_json
    clean_json=$(sed 's|//.*||' "$dcjson")

    if echo "$clean_json" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        assert_eq "devcontainer.json is valid JSON" "valid" "valid"
    else
        assert_eq "devcontainer.json is valid JSON" "valid" "invalid"
    fi

    # Check required fields
    local has_name has_service
    has_name=$(echo "$clean_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('yes' if 'name' in data else 'no')
" 2>/dev/null || echo "error")
    assert_eq "devcontainer.json has name" "yes" "$has_name"

    has_service=$(echo "$clean_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('yes' if data.get('service') == '$service' else 'no')
" 2>/dev/null || echo "error")
    assert_eq "devcontainer.json service matches" "yes" "$has_service"

    teardown_workspace
}

# ============================================================
# Test: .devcontainer/docker-compose.yml YAML validity
# ============================================================
test_devcontainer_compose_validity() {
    section ".devcontainer/docker-compose.yml YAML validity"

    if ! python3 -c "import yaml" 2>/dev/null; then
        skip_test ".devcontainer/docker-compose.yml YAML validity" "python3 yaml module not available"
        return
    fi

    setup_workspace
    local service="dc-yaml-test"

    create_test_workspace_toml "$WORK_DIR" "$service" "testuser"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_compose \
            ".devcontainer/docker-compose.yml" "workspace.toml"
    )

    local compose="$WORK_DIR/.devcontainer/docker-compose.yml"

    # Replace ${...} env vars with dummy values for YAML parsing
    local clean_compose
    clean_compose=$(sed 's/\${[^}]*}/dummy/g' "$compose")

    if echo "$clean_compose" | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin)" 2>/dev/null; then
        assert_eq ".devcontainer/docker-compose.yml is valid YAML" "valid" "valid"
    else
        assert_eq ".devcontainer/docker-compose.yml is valid YAML" "valid" "invalid"
    fi

    local svc_exists
    svc_exists=$(echo "$clean_compose" | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
print('yes' if '$service' in data.get('services', {}) else 'no')
" 2>/dev/null || echo "error")
    assert_eq ".devcontainer compose service matches" "yes" "$svc_exists"

    teardown_workspace
}

# ============================================================
# Run
# ============================================================

test_devcontainer_json_generation
test_devcontainer_compose_generation
test_devcontainer_json_validity
test_devcontainer_compose_validity

print_summary
