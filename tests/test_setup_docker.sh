#!/bin/bash
# ============================================================
# tests/test_setup_docker.sh
# Tests for setup-docker.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

SCRIPT="$PROJECT_ROOT/setup-docker.sh"

echo ""
echo "[ test_setup_docker.sh ]"

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
# Test: Library sourcing
# ============================================================
test_library_sourcing() {
    section "Library sourcing"

    assert_file_contains "sources generators.sh" "$SCRIPT" 'source.*lib/generators.sh'
    assert_file_contains "sources validators.sh" "$SCRIPT" 'source.*lib/validators.sh'
    assert_file_contains "sources errors.sh" "$SCRIPT" 'source.*lib/errors.sh'
}

# ============================================================
# Test: Template file usage
# ============================================================
test_template_usage() {
    section "Template file usage"

    assert_file_contains "uses Dockerfile.template" "$SCRIPT" 'Dockerfile.template'
    assert_file_contains "uses docker-compose.yml.template" "$SCRIPT" 'docker-compose.yml.template'
    assert_file_contains "uses devcontainer.json.template" "$SCRIPT" 'devcontainer.json.template'
    assert_file_contains "uses docker-compose.yml.template (devcontainer)" "$SCRIPT" '.devcontainer/docker-compose.yml.template'
}

# ============================================================
# Test: User input prompts
# ============================================================
test_user_inputs() {
    section "User input prompts"

    assert_file_contains "prompts for service name" "$SCRIPT" 'container_service_name'
    assert_file_contains "prompts for username" "$SCRIPT" 'username'
    assert_file_contains "prompts for Docker CLI" "$SCRIPT" 'Install Docker CLI'
    assert_file_contains "prompts for AWS CLI" "$SCRIPT" 'Install AWS CLI'
    assert_file_contains "prompts for AWS SAM CLI" "$SCRIPT" 'Install AWS SAM CLI'
    assert_file_contains "prompts for GitHub CLI" "$SCRIPT" 'Install GitHub CLI'
    assert_file_contains "prompts for Zig" "$SCRIPT" 'Install Zig'
}

# ============================================================
# Test: Auto-detection
# ============================================================
test_auto_detection() {
    section "Auto-detection"

    assert_file_contains "detects UID" "$SCRIPT" 'id -u'
    assert_file_contains "detects GID" "$SCRIPT" 'id -g'
    assert_file_contains "detects Docker GID" "$SCRIPT" 'detect_docker_gid'
}

# ============================================================
# Test: .env generation
# ============================================================
test_env_generation() {
    section ".env generation"

    assert_file_contains "creates .envs directory" "$SCRIPT" 'mkdir -p .envs'
    assert_file_contains "generates .env file" "$SCRIPT" '\.envs/.*\.env'
    assert_file_contains "creates symlink" "$SCRIPT" 'ln -sf'
    assert_file_contains "validates symlink" "$SCRIPT" 'validate_symlink'
}

# ============================================================
# Test: shellcheck
# ============================================================
test_shellcheck() {
    section "shellcheck"

    if ! command -v shellcheck &>/dev/null; then
        skip_test "shellcheck setup-docker.sh" "shellcheck not installed"
        return
    fi

    local result
    result=$(shellcheck -S error "$SCRIPT" 2>&1 || true)
    if [[ -z "$result" ]]; then
        assert_eq "shellcheck passes (errors only)" "0" "0"
    else
        echo "$result" | head -10 | sed 's/^/      /'
        assert_eq "shellcheck passes (errors only)" "0" "1"
    fi
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_library_sourcing
test_template_usage
test_user_inputs
test_auto_detection
test_env_generation
test_shellcheck

print_summary
