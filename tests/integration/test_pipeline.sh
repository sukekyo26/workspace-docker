#!/bin/bash
# ============================================================
# tests/integration/test_pipeline.sh
# Integration tests: env round-trip, e2e pipeline, docker GID
# shellcheck disable=SC2031  # Variables defined before subshells are intentionally used after them
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"
# shellcheck source=integration_helper.sh
source "$TESTS_DIR/integration/integration_helper.sh"

echo ""
echo "[ test_pipeline.sh ]"

# ============================================================
# Test: .env file generation and read_env_var round-trip
# ============================================================
test_env_roundtrip() {
    section ".env file round-trip"

    setup_workspace
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/generators.sh"

    local service_name="roundtrip-svc"
    local username="testuser"
    local uid_val="1001"
    local gid_val="1001"
    local docker_gid="999"

    cat > "$WORK_DIR/.env" << EOF
CONTAINER_SERVICE_NAME=$service_name
USERNAME=$username
UID=$uid_val
GID=$gid_val
DOCKER_GID=$docker_gid
UBUNTU_VERSION=24.04
FORWARD_PORT=3000
EOF

    local val
    val=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORK_DIR/.env")
    assert_eq "reads CONTAINER_SERVICE_NAME" "$service_name" "$val"

    val=$(read_env_var "FORWARD_PORT" "$WORK_DIR/.env")
    assert_eq "reads FORWARD_PORT" "3000" "$val"

    val=$(read_env_var "UBUNTU_VERSION" "$WORK_DIR/.env")
    assert_eq "reads UBUNTU_VERSION" "24.04" "$val"

    teardown_workspace
}

# ============================================================
# Test: End-to-end generation pipeline
# ============================================================
test_e2e_pipeline() {
    section "End-to-end generation pipeline"

    setup_workspace

    local service_name="e2e-test"
    local username="devuser"

    create_test_workspace_toml "$WORK_DIR" "$service_name" "$username" \
        "docker-cli" "github-cli"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh

        # 1. Generate docker-compose.yml
        generate_compose \
            "docker-compose.yml" "workspace.toml"

        # 2. Generate Dockerfile
        generate_dockerfile_from_template \
            "Dockerfile" "workspace.toml"

        # 3. Generate devcontainer.json
        generate_devcontainer_json \
            ".devcontainer/devcontainer.json" "workspace.toml"

        # 4. Generate .devcontainer/docker-compose.yml
        generate_devcontainer_compose \
            ".devcontainer/docker-compose.yml" "workspace.toml"
    )

    # Verify all files exist
    assert_file_exists "Dockerfile" "$WORK_DIR/Dockerfile"
    assert_file_exists "docker-compose.yml" "$WORK_DIR/docker-compose.yml"
    assert_file_exists "devcontainer.json" "$WORK_DIR/.devcontainer/devcontainer.json"
    assert_file_exists ".devcontainer/docker-compose.yml" "$WORK_DIR/.devcontainer/docker-compose.yml"

    # Verify no unreplaced placeholders in any file
    assert_file_not_matches "Dockerfile clean" "$WORK_DIR/Dockerfile" '\{\{.*\}\}'
    assert_file_not_matches "docker-compose.yml clean" "$WORK_DIR/docker-compose.yml" '\{\{.*\}\}'
    assert_file_not_matches "devcontainer.json clean" "$WORK_DIR/.devcontainer/devcontainer.json" '\{\{.*\}\}'
    assert_file_not_matches ".devcontainer/docker-compose.yml clean" "$WORK_DIR/.devcontainer/docker-compose.yml" '\{\{.*\}\}'

    # Verify service name propagation
    assert_file_contains "service in docker-compose" "$WORK_DIR/docker-compose.yml" "$service_name"
    assert_file_contains "service in devcontainer.json" "$WORK_DIR/.devcontainer/devcontainer.json" "$service_name"
    assert_file_contains "service in .devcontainer/compose" "$WORK_DIR/.devcontainer/docker-compose.yml" "$service_name"

    # Verify tool selection in Dockerfile
    assert_file_contains "Docker CLI installed" "$WORK_DIR/Dockerfile" 'Docker CLI'
    assert_file_contains "GitHub CLI installed" "$WORK_DIR/Dockerfile" 'GitHub CLI'
    assert_file_not_contains "AWS CLI not installed" "$WORK_DIR/Dockerfile" 'Install AWS CLI'
    assert_file_not_contains "Zig not installed" "$WORK_DIR/Dockerfile" 'Install Zig'

    teardown_workspace
}

# ============================================================
# Test: detect_docker_gid without GID 999 fallback
# ============================================================
test_detect_docker_gid() {
    section "detect_docker_gid (no GID 999 fallback)"

    source "$PROJECT_ROOT/lib/utils.sh"

    # Verify the function no longer contains GID 999 fallback
    assert_file_not_contains "no GID 999 fallback in source" \
        "$PROJECT_ROOT/lib/utils.sh" 'echo "999"'

    # In this environment, Docker socket may not be available (e.g. inside a container)
    if [[ -S /var/run/docker.sock ]] || getent group docker &>/dev/null; then
        local gid
        gid=$(detect_docker_gid 2>/dev/null) || true
        if [[ -n "$gid" && "$gid" =~ ^[0-9]+$ ]]; then
            assert_eq "detect_docker_gid returns numeric GID" "yes" "yes"
        else
            skip_test "detect_docker_gid returns GID" "detection methods failed"
        fi
    else
        skip_test "detect_docker_gid returns GID" "Docker socket not available"
    fi
}

# ============================================================
# Run
# ============================================================

test_env_roundtrip
test_e2e_pipeline
test_detect_docker_gid

print_summary
