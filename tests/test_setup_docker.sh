#!/bin/bash
# ============================================================
# tests/test_setup_docker.sh
# Tests for setup-docker.sh — execution-based tests
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

SCRIPT="$PROJECT_ROOT/setup-docker.sh"

echo ""
echo "[ test_setup_docker.sh ]"

# ============================================================
# Helper: create a tmpdir with all project files needed
# ============================================================
setup_test_dir() {
    local tmpdir
    tmpdir=$(mktemp -d)

    cp "$SCRIPT" "$tmpdir/"
    cp -r "$PROJECT_ROOT/lib" "$tmpdir/"
    cp -r "$PROJECT_ROOT/plugins" "$tmpdir/"
    cp -r "$PROJECT_ROOT/config" "$tmpdir/"
    cp "$PROJECT_ROOT/Dockerfile.template" "$tmpdir/"
    cp "$PROJECT_ROOT/docker-compose.yml.template" "$tmpdir/"
    mkdir -p "$tmpdir/.devcontainer" "$tmpdir/certs" "$tmpdir/config"
    cp "$PROJECT_ROOT/.devcontainer/"*.template "$tmpdir/.devcontainer/"
    if [[ -f "$PROJECT_ROOT/config/.bashrc_custom.example" ]]; then
        cp "$PROJECT_ROOT/config/.bashrc_custom.example" "$tmpdir/config/"
    fi

    echo "$tmpdir"
}

# ============================================================
# Test: Script basics
# ============================================================
test_script_basics() {
    section "Script basics"

    assert_file_exists "setup-docker.sh exists" "$SCRIPT"
    assert_true "script is executable" test -x "$SCRIPT"
    assert_true "bash syntax valid" bash -n "$SCRIPT"
}

# ============================================================
# Test: Regenerate from existing workspace.toml
# ============================================================
test_regenerate_from_toml() {
    section "Regenerate from workspace.toml"

    local tmpdir
    tmpdir=$(setup_test_dir)

    cat > "$tmpdir/workspace.toml" << 'EOF'
[container]
service_name = "setup-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["docker-cli", "github-cli"]

[ports]
forward = [8080]
EOF

    (cd "$tmpdir" && bash setup-docker.sh 2>/dev/null)
    local exit_code=$?

    assert_eq "setup-docker.sh exits 0" "0" "$exit_code"

    # Verify all generated files exist
    assert_file_exists "Dockerfile generated" "$tmpdir/Dockerfile"
    assert_file_exists "docker-compose.yml generated" "$tmpdir/docker-compose.yml"
    assert_file_exists ".env generated" "$tmpdir/.env"
    assert_file_exists "devcontainer.json generated" "$tmpdir/.devcontainer/devcontainer.json"
    assert_file_exists ".devcontainer/compose generated" "$tmpdir/.devcontainer/docker-compose.yml"

    # Verify .env content
    local val
    val=$(grep '^CONTAINER_SERVICE_NAME=' "$tmpdir/.env" | cut -d= -f2)
    assert_eq ".env CONTAINER_SERVICE_NAME" "setup-test" "$val"

    val=$(grep '^USERNAME=' "$tmpdir/.env" | cut -d= -f2)
    assert_eq ".env USERNAME" "testuser" "$val"

    val=$(grep '^FORWARD_PORT=' "$tmpdir/.env" | cut -d= -f2)
    assert_eq ".env FORWARD_PORT" "8080" "$val"

    # Verify Dockerfile has correct plugins
    assert_file_contains "Docker CLI in Dockerfile" "$tmpdir/Dockerfile" 'Docker CLI'
    assert_file_contains "GitHub CLI in Dockerfile" "$tmpdir/Dockerfile" 'GitHub CLI'
    assert_file_not_contains "AWS CLI absent" "$tmpdir/Dockerfile" 'Install AWS CLI'

    # Verify service name propagation
    assert_file_contains "service in compose" "$tmpdir/docker-compose.yml" 'setup-test'
    assert_file_contains "service in devcontainer.json" "$tmpdir/.devcontainer/devcontainer.json" 'setup-test'

    # Verify .bashrc_custom auto-copy
    if [[ -f "$PROJECT_ROOT/config/.bashrc_custom.example" ]]; then
        assert_file_exists ".bashrc_custom auto-copied" "$tmpdir/config/.bashrc_custom"
    fi

    rm -rf "$tmpdir"
}

# ============================================================
# Test: Regenerate with all plugins
# ============================================================
test_regenerate_all_plugins() {
    section "Regenerate with all plugins"

    local tmpdir
    tmpdir=$(setup_test_dir)

    cat > "$tmpdir/workspace.toml" << 'EOF'
[container]
service_name = "all-plugins"
username = "devuser"
ubuntu_version = "24.04"

[plugins]
enable = ["docker-cli", "aws-cli", "aws-sam-cli", "github-cli", "zig"]

[ports]
forward = [3000]
EOF

    (cd "$tmpdir" && bash setup-docker.sh 2>/dev/null)

    assert_file_exists "Dockerfile generated" "$tmpdir/Dockerfile"
    assert_file_contains "Docker CLI present" "$tmpdir/Dockerfile" 'Docker CLI'
    assert_file_contains "AWS CLI present" "$tmpdir/Dockerfile" 'AWS CLI'
    assert_file_contains "AWS SAM CLI present" "$tmpdir/Dockerfile" 'AWS SAM CLI'
    assert_file_contains "GitHub CLI present" "$tmpdir/Dockerfile" 'GitHub CLI'
    assert_file_contains "Zig present" "$tmpdir/Dockerfile" 'Zig'
    assert_file_contains "aws volume" "$tmpdir/docker-compose.yml" 'aws:'
    assert_file_contains "gh-config volume" "$tmpdir/docker-compose.yml" 'gh-config:'

    rm -rf "$tmpdir"
}

# ============================================================
# Test: Regenerate with no plugins
# ============================================================
test_regenerate_no_plugins() {
    section "Regenerate with no plugins"

    local tmpdir
    tmpdir=$(setup_test_dir)

    cat > "$tmpdir/workspace.toml" << 'EOF'
[container]
service_name = "minimal"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]
EOF

    (cd "$tmpdir" && bash setup-docker.sh 2>/dev/null)

    assert_file_exists "Dockerfile generated" "$tmpdir/Dockerfile"
    assert_file_not_contains "no Docker CLI" "$tmpdir/Dockerfile" 'Install Docker CLI'
    assert_file_not_contains "no AWS CLI" "$tmpdir/Dockerfile" 'Install AWS CLI'
    # proto is now a plugin — not present when plugins are empty
    assert_file_not_contains "proto absent when not enabled" "$tmpdir/Dockerfile" 'proto'

    rm -rf "$tmpdir"
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_regenerate_from_toml
test_regenerate_all_plugins
test_regenerate_no_plugins

print_summary
