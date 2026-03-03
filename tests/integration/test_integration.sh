#!/bin/bash
# ============================================================
# tests/test_integration.sh
# Integration tests: actually generate files and verify output
# shellcheck disable=SC2031  # Variables defined before subshells are intentionally used after them
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
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
    # Copy plugins
    cp -r "$PROJECT_ROOT/plugins" "$WORK_DIR/"
    # Copy config
    cp -r "$PROJECT_ROOT/config" "$WORK_DIR/"
    # Copy certs dir (may be empty)
    cp -r "$PROJECT_ROOT/certs" "$WORK_DIR/" 2>/dev/null || mkdir -p "$WORK_DIR/certs"
}

teardown_workspace() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    WORK_DIR=""
}

# Helper: create a workspace.toml for testing
create_test_workspace_toml() {
    local dir="$1"
    local service_name="$2"
    local username="$3"
    shift 3
    local plugins=("$@")

    local plugins_toml="["
    for ((i = 0; i < ${#plugins[@]}; i++)); do
        if [[ $i -gt 0 ]]; then plugins_toml+=", "; fi
        plugins_toml+="\"${plugins[$i]}\""
    done
    plugins_toml+="]"

    cat > "$dir/workspace.toml" << EOF
[container]
service_name = "$service_name"
username = "$username"
ubuntu_version = "24.04"

[plugins]
enable = $plugins_toml

[ports]
forward = [3000]
EOF
}

# ============================================================
# Test: Dockerfile generation — all plugins enabled
# ============================================================
test_dockerfile_all_enabled() {
    section "Dockerfile generation (all plugins)"

    setup_workspace
    create_test_workspace_toml "$WORK_DIR" "test-svc" "testuser" \
        "proto" "docker-cli" "aws-cli" "aws-sam-cli" "github-cli" "zig"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"
    )

    assert_file_exists "Dockerfile generated" "$WORK_DIR/Dockerfile"
    assert_file_not_contains "no unreplaced placeholders" "$WORK_DIR/Dockerfile" '{{.*}}'
    assert_file_contains "Docker CLI section present" "$WORK_DIR/Dockerfile" 'Docker CLI'
    assert_file_contains "AWS CLI section present" "$WORK_DIR/Dockerfile" 'AWS CLI'
    assert_file_contains "AWS SAM CLI section present" "$WORK_DIR/Dockerfile" 'AWS SAM CLI'
    assert_file_contains "GitHub CLI section present" "$WORK_DIR/Dockerfile" 'GitHub CLI'
    assert_file_contains "Zig section present" "$WORK_DIR/Dockerfile" 'Zig'
    assert_file_contains "proto section present" "$WORK_DIR/Dockerfile" 'proto'
    # proto is now a plugin; verify ENV is set correctly
    assert_file_contains "proto ENV present" "$WORK_DIR/Dockerfile" 'PROTO_HOME'

    teardown_workspace
}

# ============================================================
# Test: Dockerfile generation — no plugins enabled
# ============================================================
test_dockerfile_no_plugins() {
    section "Dockerfile generation (no plugins)"

    setup_workspace
    create_test_workspace_toml "$WORK_DIR" "test-svc" "testuser"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"
    )

    assert_file_exists "Dockerfile generated" "$WORK_DIR/Dockerfile"
    assert_file_not_contains "no unreplaced placeholders" "$WORK_DIR/Dockerfile" '{{.*}}'
    assert_file_not_contains "Docker CLI absent" "$WORK_DIR/Dockerfile" 'Install Docker CLI'
    assert_file_not_contains "AWS CLI absent" "$WORK_DIR/Dockerfile" 'Install AWS CLI'
    assert_file_not_contains "GitHub CLI absent" "$WORK_DIR/Dockerfile" 'Install GitHub CLI'
    assert_file_not_contains "Zig absent" "$WORK_DIR/Dockerfile" 'Install Zig'
    # proto is now a plugin — not present when plugins are empty
    assert_file_not_contains "proto absent" "$WORK_DIR/Dockerfile" 'proto'

    teardown_workspace
}

# ============================================================
# Test: Dockerfile generation — partial enablement
# ============================================================
test_dockerfile_partial() {
    section "Dockerfile generation (partial)"

    setup_workspace
    create_test_workspace_toml "$WORK_DIR" "test-svc" "testuser" \
        "docker-cli" "github-cli"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"
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
    create_test_workspace_toml "$WORK_DIR" "$service_name" "testuser" \
        "aws-cli" "github-cli"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_compose_from_template \
            "docker-compose.yml.template" "docker-compose.yml" \
            "$service_name" "workspace.toml"
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

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_json_from_template \
            ".devcontainer/devcontainer.json.template" \
            ".devcontainer/devcontainer.json" \
            "$service_name" "$username" "3000"
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

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_compose_from_template \
            ".devcontainer/docker-compose.yml.template" \
            ".devcontainer/docker-compose.yml" \
            "$service_name"
    )

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
        generate_compose_from_template \
            "docker-compose.yml.template" "docker-compose.yml" \
            "$service_name" "workspace.toml"

        # 2. Generate Dockerfile
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"

        # 3. Generate devcontainer.json
        generate_devcontainer_json_from_template \
            ".devcontainer/devcontainer.json.template" \
            ".devcontainer/devcontainer.json" \
            "$service_name" "$username" "3000"

        # 4. Generate .devcontainer/docker-compose.yml
        generate_devcontainer_compose_from_template \
            ".devcontainer/docker-compose.yml.template" \
            ".devcontainer/docker-compose.yml" \
            "$service_name"
    )

    # Verify all files exist
    assert_file_exists "Dockerfile" "$WORK_DIR/Dockerfile"
    assert_file_exists "docker-compose.yml" "$WORK_DIR/docker-compose.yml"
    assert_file_exists "devcontainer.json" "$WORK_DIR/.devcontainer/devcontainer.json"
    assert_file_exists ".devcontainer/docker-compose.yml" "$WORK_DIR/.devcontainer/docker-compose.yml"

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
# Test: Dockerfile structural validity
# ============================================================
test_dockerfile_structure() {
    section "Dockerfile structural validity"

    setup_workspace
    create_test_workspace_toml "$WORK_DIR" "struct-test" "testuser" \
        "docker-cli" "aws-cli" "aws-sam-cli" "github-cli" "zig"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"
    )

    local dockerfile="$WORK_DIR/Dockerfile"

    # Every non-empty, non-comment, non-continuation line must start with a
    # valid Dockerfile instruction
    local bad_lines
    bad_lines=$(awk '
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]+/  { next }
        /^(FROM|RUN|ENV|COPY|USER|WORKDIR|ARG|CMD|ENTRYPOINT|EXPOSE|ADD|LABEL|VOLUME|SHELL|HEALTHCHECK|STOPSIGNAL|ONBUILD)[[:space:]]/ { next }
        { print NR": "$0 }
    ' "$dockerfile" || true)

    if [[ -z "$bad_lines" ]]; then
        assert_eq "all lines are valid Dockerfile syntax" "valid" "valid"
    else
        echo "      Invalid lines:"
        echo "$bad_lines" | head -5 | sed 's/^/        /'
        assert_eq "all lines are valid Dockerfile syntax" "valid" "invalid"
    fi

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
        generate_compose_from_template \
            "docker-compose.yml.template" "docker-compose.yml" \
            "yaml-test" "workspace.toml"
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
# Test: devcontainer.json JSON validity
# ============================================================
test_devcontainer_json_validity() {
    section "devcontainer.json JSON validity"

    setup_workspace
    local service="json-test"
    local username="testuser"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_json_from_template \
            ".devcontainer/devcontainer.json.template" \
            ".devcontainer/devcontainer.json" \
            "$service" "$username" "3000"
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

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_devcontainer_compose_from_template \
            ".devcontainer/docker-compose.yml.template" \
            ".devcontainer/docker-compose.yml" \
            "$service"
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
# Test: apt extra_packages insertion
# ============================================================
test_apt_extra_packages() {
    section "apt extra_packages insertion"

    setup_workspace

    # Create workspace.toml with extra packages
    cat > "$WORK_DIR/workspace.toml" << 'EOF'
[container]
service_name = "apt-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]

[apt]
extra_packages = ["vim-nox", "tmux"]
EOF

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"
    )

    local dockerfile="$WORK_DIR/Dockerfile"

    # Extra packages should appear in the apt-get install block
    assert_file_contains "vim-nox in Dockerfile" "$dockerfile" 'vim-nox'
    assert_file_contains "tmux in Dockerfile" "$dockerfile" 'tmux'

    # Packages should appear before locale-gen (inside apt block)
    local pkg_line locale_line
    pkg_line=$(grep -n 'vim-nox' "$dockerfile" | head -1 | cut -d: -f1)
    locale_line=$(grep -n 'locale-gen' "$dockerfile" | head -1 | cut -d: -f1)
    if [[ -n "$pkg_line" && -n "$locale_line" && "$pkg_line" -lt "$locale_line" ]]; then
        assert_eq "extra packages before locale-gen" "yes" "yes"
    else
        assert_eq "extra packages before locale-gen" "yes" "no"
    fi

    # No unreplaced placeholder
    assert_file_not_contains "no APT_EXTRA placeholder" "$dockerfile" '{{APT_EXTRA_PACKAGES}}'

    teardown_workspace
}

# ============================================================
# Test: Certificate section structure
# ============================================================
test_certificate_section() {
    section "Certificate section structure"

    setup_workspace

    # Create a dummy certificate
    mkdir -p "$WORK_DIR/certs"
    cat > "$WORK_DIR/certs/test-ca.crt" << 'EOF'
-----BEGIN CERTIFICATE-----
MIIBojCCAUmgAwIBAgIRAIuvAAAAAAAAAAAAAAAAAAAA
-----END CERTIFICATE-----
EOF

    create_test_workspace_toml "$WORK_DIR" "cert-test" "testuser"

    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh
        generate_dockerfile_from_template \
            "Dockerfile.template" "Dockerfile" "workspace.toml"
    )

    local dockerfile="$WORK_DIR/Dockerfile"

    # Certificate section should have COPY, USER root, RUN update-ca-certificates
    assert_file_contains "cert COPY present" "$dockerfile" 'COPY certs/test-ca.crt'
    assert_file_contains "cert update-ca-certificates" "$dockerfile" 'update-ca-certificates'
    assert_file_contains "cert SSL_CERT_FILE env" "$dockerfile" 'SSL_CERT_FILE'

    # Verify COPY line is valid Dockerfile syntax
    local copy_line
    copy_line=$(grep 'COPY certs/test-ca.crt' "$dockerfile")
    if [[ "$copy_line" =~ ^COPY ]]; then
        assert_eq "COPY line valid syntax" "valid" "valid"
    else
        assert_eq "COPY line valid syntax" "valid" "invalid"
    fi

    teardown_workspace
}

# ============================================================
# Run
# ============================================================

test_dockerfile_all_enabled
test_dockerfile_no_plugins
test_dockerfile_partial
test_docker_compose_generation
test_devcontainer_json_generation
test_devcontainer_compose_generation
test_env_roundtrip
test_e2e_pipeline
test_detect_docker_gid
test_dockerfile_structure
test_compose_yaml_validity
test_devcontainer_json_validity
test_devcontainer_compose_validity
test_apt_extra_packages
test_certificate_section

print_summary
