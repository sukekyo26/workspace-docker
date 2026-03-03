#!/bin/bash
# ============================================================
# tests/integration/generation/test_dockerfile.sh
# Integration tests for Dockerfile generation
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"
# shellcheck source=../integration_helper.sh
source "$TESTS_DIR/integration/integration_helper.sh"

echo ""
echo "[ test_dockerfile.sh ]"

# ============================================================
# Test: Dockerfile generation — all plugins enabled
# ============================================================
test_dockerfile_all_enabled() {
    section "Dockerfile generation (all plugins)"

    setup_workspace
    create_test_workspace_toml "$WORK_DIR" "test-svc" "testuser" \
        "proto" "docker-cli" "aws-cli" "aws-sam-cli" "github-cli" "copilot-cli" "claude-code" "uv" "zig"

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
    assert_file_contains "Copilot CLI section present" "$WORK_DIR/Dockerfile" 'Copilot CLI'
    assert_file_contains "Claude Code section present" "$WORK_DIR/Dockerfile" 'Claude Code'
    assert_file_contains "uv section present" "$WORK_DIR/Dockerfile" 'uv'
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
    # ARG DOCKER_GID should not be present without docker-cli
    assert_file_not_contains "DOCKER_GID absent" "$WORK_DIR/Dockerfile" 'DOCKER_GID'

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
test_dockerfile_structure
test_apt_extra_packages
test_certificate_section

print_summary
