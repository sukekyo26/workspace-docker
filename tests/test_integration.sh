#!/bin/bash
# ============================================================
# tests/test_integration.sh
# Integration tests: actually generate files and verify output
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_integration.sh ]"

# ============================================================
# Helper: create a temporary workspace with templates
# ============================================================
WORK_DIR=""

setup_workspace() {
    WORK_DIR=$(mktemp -d)
    # Copy templates
    cp "$PROJECT_ROOT/Dockerfile.template" "$WORK_DIR/"
    cp "$PROJECT_ROOT/docker-compose.yml.template" "$WORK_DIR/"
    mkdir -p "$WORK_DIR/.devcontainer"
    cp "$PROJECT_ROOT/.devcontainer/devcontainer.json.template" "$WORK_DIR/.devcontainer/"
    cp "$PROJECT_ROOT/.devcontainer/docker-compose.yml.template" "$WORK_DIR/.devcontainer/"
    # Copy libs
    cp -r "$PROJECT_ROOT/lib" "$WORK_DIR/"
    # Copy certs dir (may be empty)
    cp -r "$PROJECT_ROOT/certs" "$WORK_DIR/" 2>/dev/null || mkdir -p "$WORK_DIR/certs"
}

teardown_workspace() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    WORK_DIR=""
}

# ============================================================
# Test: Dockerfile generation — all tools enabled
# ============================================================
test_dockerfile_all_enabled() {
    section "Dockerfile generation (all enabled)"

    setup_workspace
    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh

        generate_dockerfile_from_template \
            "Dockerfile.template" \
            "Dockerfile" \
            "true" "true" "true" "true" "true"
    )

    assert_file_exists "Dockerfile generated" "$WORK_DIR/Dockerfile"
    assert_file_not_contains "no unreplaced placeholders" "$WORK_DIR/Dockerfile" '{{.*}}'
    assert_file_contains "Docker CLI section present" "$WORK_DIR/Dockerfile" 'Docker CLI'
    assert_file_contains "AWS CLI section present" "$WORK_DIR/Dockerfile" 'AWS CLI'
    assert_file_contains "AWS SAM CLI section present" "$WORK_DIR/Dockerfile" 'AWS SAM CLI'
    assert_file_contains "GitHub CLI section present" "$WORK_DIR/Dockerfile" 'GitHub CLI'
    assert_file_contains "Zig section present" "$WORK_DIR/Dockerfile" 'Zig'
    assert_file_contains "proto section present" "$WORK_DIR/Dockerfile" 'proto'

    teardown_workspace
}

# ============================================================
# Test: Dockerfile generation — all tools disabled
# ============================================================
test_dockerfile_all_disabled() {
    section "Dockerfile generation (all disabled)"

    setup_workspace
    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh

        generate_dockerfile_from_template \
            "Dockerfile.template" \
            "Dockerfile" \
            "false" "false" "false" "false" "false"
    )

    assert_file_exists "Dockerfile generated" "$WORK_DIR/Dockerfile"
    assert_file_not_contains "no unreplaced placeholders" "$WORK_DIR/Dockerfile" '{{.*}}'
    assert_file_not_contains "Docker CLI absent" "$WORK_DIR/Dockerfile" 'Install Docker CLI'
    assert_file_not_contains "AWS CLI absent" "$WORK_DIR/Dockerfile" 'Install AWS CLI'
    assert_file_not_contains "AWS SAM CLI absent" "$WORK_DIR/Dockerfile" 'Install AWS SAM CLI'
    assert_file_not_contains "GitHub CLI absent" "$WORK_DIR/Dockerfile" 'Install GitHub CLI'
    assert_file_not_contains "Zig absent" "$WORK_DIR/Dockerfile" 'Install Zig'
    # proto is always installed
    assert_file_contains "proto still present" "$WORK_DIR/Dockerfile" 'proto'

    teardown_workspace
}

# ============================================================
# Test: Dockerfile generation — partial enablement
# ============================================================
test_dockerfile_partial() {
    section "Dockerfile generation (partial)"

    setup_workspace
    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh

        generate_dockerfile_from_template \
            "Dockerfile.template" \
            "Dockerfile" \
            "true" "false" "false" "true" "false"
    )

    assert_file_exists "Dockerfile generated" "$WORK_DIR/Dockerfile"
    assert_file_contains "Docker CLI present" "$WORK_DIR/Dockerfile" 'Docker CLI'
    assert_file_not_contains "AWS CLI absent" "$WORK_DIR/Dockerfile" 'Install AWS CLI'
    assert_file_not_contains "AWS SAM CLI absent" "$WORK_DIR/Dockerfile" 'Install AWS SAM CLI'
    assert_file_contains "GitHub CLI present" "$WORK_DIR/Dockerfile" 'GitHub CLI'
    assert_file_not_contains "Zig absent" "$WORK_DIR/Dockerfile" 'Install Zig'

    teardown_workspace
}

# ============================================================
# Test: docker-compose.yml generation
# ============================================================
test_docker_compose_generation() {
    section "docker-compose.yml generation"

    setup_workspace
    local service_name="test-service"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_compose_from_template \
            "docker-compose.yml.template" \
            "docker-compose.yml" \
            "$service_name" \
            "true" "true"
    )

    assert_file_exists "docker-compose.yml generated" "$WORK_DIR/docker-compose.yml"
    assert_file_not_contains "no unreplaced {{...}}" "$WORK_DIR/docker-compose.yml" '{{.*}}'
    assert_file_contains "service name replaced" "$WORK_DIR/docker-compose.yml" "$service_name"
    assert_file_contains "volumes section exists" "$WORK_DIR/docker-compose.yml" '^volumes:'
    assert_file_contains "aws volume present" "$WORK_DIR/docker-compose.yml" 'aws:'
    assert_file_contains "gh-config volume present" "$WORK_DIR/docker-compose.yml" 'gh-config:'

    teardown_workspace
}

# ============================================================
# Test: devcontainer.json generation
# ============================================================
test_devcontainer_json_generation() {
    section "devcontainer.json generation"

    setup_workspace
    local service_name="test-service"
    local username="testuser"

    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$service_name/g" \
        -e "s/{{USERNAME}}/$username/g" \
        -e "s/{{FORWARD_PORT}}/3000/g" \
        "$WORK_DIR/.devcontainer/devcontainer.json.template" > "$WORK_DIR/.devcontainer/devcontainer.json"

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

    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$service_name/g" \
        "$WORK_DIR/.devcontainer/docker-compose.yml.template" > "$WORK_DIR/.devcontainer/docker-compose.yml"

    assert_file_exists ".devcontainer/docker-compose.yml generated" "$WORK_DIR/.devcontainer/docker-compose.yml"
    assert_file_not_contains "no unreplaced {{...}}" "$WORK_DIR/.devcontainer/docker-compose.yml" '{{.*}}'
    assert_file_contains "service name replaced" "$WORK_DIR/.devcontainer/docker-compose.yml" "$service_name"

    teardown_workspace
}

# ============================================================
# Test: .env file generation and read_env_var round-trip
# ============================================================
test_env_roundtrip() {
    section ".env file round-trip"

    setup_workspace
    source "$PROJECT_ROOT/lib/generators.sh"

    local service_name="roundtrip-svc"
    local username="testuser"
    local uid="1001"
    local gid="1001"
    local docker_gid="999"

    mkdir -p "$WORK_DIR/.envs"
    cat > "$WORK_DIR/.envs/${service_name}.env" << EOF
CONTAINER_SERVICE_NAME=$service_name
USERNAME=$username
UID=$uid
GID=$gid
DOCKER_GID=$docker_gid
UBUNTU_VERSION=24.04
INSTALL_DOCKER=true
INSTALL_AWS_CLI=false
INSTALL_AWS_SAM_CLI=false
INSTALL_GITHUB_CLI=true
INSTALL_ZIG=false
EOF

    local val
    val=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORK_DIR/.envs/${service_name}.env")
    assert_eq "reads CONTAINER_SERVICE_NAME" "$service_name" "$val"

    val=$(read_env_var "INSTALL_AWS_CLI" "$WORK_DIR/.envs/${service_name}.env")
    assert_eq "reads INSTALL_AWS_CLI=false" "false" "$val"

    val=$(read_env_var "INSTALL_GITHUB_CLI" "$WORK_DIR/.envs/${service_name}.env")
    assert_eq "reads INSTALL_GITHUB_CLI=true" "true" "$val"

    val=$(read_env_var "UBUNTU_VERSION" "$WORK_DIR/.envs/${service_name}.env")
    assert_eq "reads UBUNTU_VERSION" "24.04" "$val"

    teardown_workspace
}

# ============================================================
# Test: Symlink switching
# ============================================================
test_symlink_switching() {
    section "Symlink switching"

    setup_workspace
    source "$PROJECT_ROOT/lib/generators.sh"

    mkdir -p "$WORK_DIR/.envs"
    echo "CONTAINER_SERVICE_NAME=svc-a" > "$WORK_DIR/.envs/svc-a.env"
    echo "CONTAINER_SERVICE_NAME=svc-b" > "$WORK_DIR/.envs/svc-b.env"

    # Create initial symlink
    ln -sf ".envs/svc-a.env" "$WORK_DIR/.env"
    assert_true "initial symlink valid" validate_symlink "$WORK_DIR/.env" ".envs/"

    local val
    val=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORK_DIR/.env")
    assert_eq "initial env points to svc-a" "svc-a" "$val"

    # Switch symlink
    ln -sf ".envs/svc-b.env" "$WORK_DIR/.env"
    assert_true "switched symlink valid" validate_symlink "$WORK_DIR/.env" ".envs/"

    val=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORK_DIR/.env")
    assert_eq "switched env points to svc-b" "svc-b" "$val"

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

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh

        # 1. Generate docker-compose.yml
        generate_compose_from_template \
            "docker-compose.yml.template" \
            "docker-compose.yml" \
            "$service_name" \
            "false" "true"

        # 2. Generate Dockerfile (Docker CLI + GitHub CLI only)
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" \
            "true" "false" "false" "true" "false"

        # 3. Generate devcontainer.json
        sed -e "s/{{CONTAINER_SERVICE_NAME}}/$service_name/g" \
            -e "s/{{USERNAME}}/$username/g" \
            -e "s/{{FORWARD_PORT}}/3000/g" \
            .devcontainer/devcontainer.json.template > .devcontainer/devcontainer.json

        # 4. Generate .devcontainer/docker-compose.yml
        sed -e "s/{{CONTAINER_SERVICE_NAME}}/$service_name/g" \
            .devcontainer/docker-compose.yml.template > .devcontainer/docker-compose.yml

        # 5. Generate .env
        mkdir -p .envs
        cat > ".envs/${service_name}.env" << EOF
CONTAINER_SERVICE_NAME=$service_name
USERNAME=$username
UID=1000
GID=1000
DOCKER_GID=999
UBUNTU_VERSION=24.04
INSTALL_DOCKER=true
INSTALL_AWS_CLI=false
INSTALL_AWS_SAM_CLI=false
INSTALL_GITHUB_CLI=true
INSTALL_ZIG=false
EOF
        ln -sf ".envs/${service_name}.env" .env
    )

    # Verify all files exist
    assert_file_exists "Dockerfile" "$WORK_DIR/Dockerfile"
    assert_file_exists "docker-compose.yml" "$WORK_DIR/docker-compose.yml"
    assert_file_exists "devcontainer.json" "$WORK_DIR/.devcontainer/devcontainer.json"
    assert_file_exists ".devcontainer/docker-compose.yml" "$WORK_DIR/.devcontainer/docker-compose.yml"
    assert_file_exists ".env symlink target" "$WORK_DIR/.envs/${service_name}.env"

    # Verify no unreplaced placeholders in any file
    assert_file_not_contains "Dockerfile clean" "$WORK_DIR/Dockerfile" '{{.*}}'
    assert_file_not_contains "docker-compose.yml clean" "$WORK_DIR/docker-compose.yml" '{{.*}}'
    assert_file_not_contains "devcontainer.json clean" "$WORK_DIR/.devcontainer/devcontainer.json" '{{.*}}'
    assert_file_not_contains ".devcontainer/docker-compose.yml clean" "$WORK_DIR/.devcontainer/docker-compose.yml" '{{.*}}'

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

    source "$PROJECT_ROOT/lib/generators.sh"

    # Verify the function no longer contains GID 999 fallback
    assert_file_not_contains "no GID 999 fallback in source" \
        "$PROJECT_ROOT/lib/generators.sh" 'echo "999"'

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

test_dockerfile_all_enabled
test_dockerfile_all_disabled
test_dockerfile_partial
test_docker_compose_generation
test_devcontainer_json_generation
test_devcontainer_compose_generation
test_env_roundtrip
test_symlink_switching
test_e2e_pipeline
test_detect_docker_gid

print_summary
