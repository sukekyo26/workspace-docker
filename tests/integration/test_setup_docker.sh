#!/bin/bash
# ============================================================
# tests/test_setup_docker.sh
# Tests for setup-docker.sh — execution-based tests
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"
# shellcheck source=integration_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/integration_helper.sh"

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
    mkdir -p "$tmpdir/certs"
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

    create_test_workspace_toml "$tmpdir" "setup-test" "testuser" 8080 "docker-cli" "github-cli"

    (cd "$tmpdir" && bash setup-docker.sh 2>/dev/null)
    local exit_code=$?

    assert_eq "setup-docker.sh exits 0" "0" "$exit_code"

    # Verify .devcontainer/ directory is created automatically
    assert_true ".devcontainer/ dir created" test -d "$tmpdir/.devcontainer"

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

    # Verify .env file permission is 600
    local perm
    perm=$(stat -c '%a' "$tmpdir/.env")
    assert_eq ".env permission is 600" "600" "$perm"

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

    create_test_workspace_toml "$tmpdir" "all-plugins" "devuser" 3000 \
        "docker-cli" "aws-cli" "aws-sam-cli" "github-cli" "copilot-cli" "claude-code" "uv" "zig"

    (cd "$tmpdir" && bash setup-docker.sh 2>/dev/null)

    assert_file_exists "Dockerfile generated" "$tmpdir/Dockerfile"
    assert_file_contains "Docker CLI present" "$tmpdir/Dockerfile" 'Docker CLI'
    assert_file_contains "AWS CLI present" "$tmpdir/Dockerfile" 'AWS CLI'
    assert_file_contains "AWS SAM CLI present" "$tmpdir/Dockerfile" 'AWS SAM CLI'
    assert_file_contains "GitHub CLI present" "$tmpdir/Dockerfile" 'GitHub CLI'
    assert_file_contains "Copilot CLI present" "$tmpdir/Dockerfile" 'Copilot CLI'
    assert_file_contains "Claude Code present" "$tmpdir/Dockerfile" 'Claude Code'
    assert_file_contains "uv present" "$tmpdir/Dockerfile" 'uv'
    assert_file_contains "Zig present" "$tmpdir/Dockerfile" 'Zig'
    assert_file_contains "aws volume" "$tmpdir/docker-compose.yml" 'aws:'
    assert_file_contains "gh-config volume" "$tmpdir/docker-compose.yml" 'gh-config:'
    assert_file_contains "copilot volume" "$tmpdir/docker-compose.yml" 'copilot:'
    assert_file_contains "claude volume" "$tmpdir/docker-compose.yml" 'claude:'

    rm -rf "$tmpdir"
}

# ============================================================
# Test: Regenerate with no plugins
# ============================================================
test_regenerate_no_plugins() {
    section "Regenerate with no plugins"

    local tmpdir
    tmpdir=$(setup_test_dir)

    create_test_workspace_toml "$tmpdir" "minimal" "testuser" 3000

    (cd "$tmpdir" && bash setup-docker.sh 2>/dev/null)

    assert_file_exists "Dockerfile generated" "$tmpdir/Dockerfile"
    assert_file_not_contains "no Docker CLI" "$tmpdir/Dockerfile" 'Install Docker CLI'
    assert_file_not_contains "no AWS CLI" "$tmpdir/Dockerfile" 'Install AWS CLI'
    # proto is now a plugin — not present when plugins are empty
    assert_file_not_contains "proto absent when not enabled" "$tmpdir/Dockerfile" 'proto'

    rm -rf "$tmpdir"
}

# ============================================================
# Test: Non-interactive setup with --init --yes
# ============================================================
test_init_with_yes_flag() {
    section "--init --yes non-interactive setup"

    local tmpdir
    tmpdir=$(setup_test_dir)

    # Should not prompt for input — uses defaults
    (cd "$tmpdir" && bash setup-docker.sh --init --yes 2>/dev/null)
    local exit_code=$?

    assert_eq "setup-docker.sh --init --yes exits 0" "0" "$exit_code"

    # workspace.toml should be generated
    assert_file_exists "workspace.toml generated" "$tmpdir/workspace.toml"

    # Verify default values
    assert_file_contains "default service name" "$tmpdir/workspace.toml" 'service_name = "dev"'
    assert_file_contains "default port" "$tmpdir/workspace.toml" 'forward = \[3000\]'

    # Verify generated files
    assert_file_exists "Dockerfile generated" "$tmpdir/Dockerfile"
    assert_file_exists "docker-compose.yml generated" "$tmpdir/docker-compose.yml"
    assert_file_exists ".env generated" "$tmpdir/.env"
    assert_file_exists "devcontainer.json generated" "$tmpdir/.devcontainer/devcontainer.json"

    # Default plugins (docker-cli, proto) should be enabled
    assert_file_contains "docker-cli enabled" "$tmpdir/workspace.toml" 'docker-cli'
    assert_file_contains "proto enabled" "$tmpdir/workspace.toml" 'proto'

    # [vscode] section should be present with empty extensions
    assert_file_contains "vscode section" "$tmpdir/workspace.toml" '\[vscode\]'
    assert_file_contains "extensions empty" "$tmpdir/workspace.toml" 'extensions = \[\]'

    rm -rf "$tmpdir"
}

# ============================================================
# Test: --yes without --init is ignored (regenerate mode)
# ============================================================
test_yes_flag_with_existing_toml() {
    section "--yes with existing workspace.toml"

    local tmpdir
    tmpdir=$(setup_test_dir)

    create_test_workspace_toml "$tmpdir" "existing-svc" "testuser" 8080 "github-cli"

    (cd "$tmpdir" && bash setup-docker.sh --yes 2>/dev/null)
    local exit_code=$?

    assert_eq "exits 0" "0" "$exit_code"
    # workspace.toml should NOT be overwritten
    assert_file_contains "service preserved" "$tmpdir/workspace.toml" 'service_name = "existing-svc"'

    rm -rf "$tmpdir"
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_regenerate_from_toml
test_regenerate_all_plugins
test_regenerate_no_plugins
test_init_with_yes_flag
test_yes_flag_with_existing_toml

print_summary
