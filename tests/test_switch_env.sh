#!/bin/bash
# ============================================================
# tests/test_switch_env.sh
# Tests for switch-env.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

SCRIPT="$PROJECT_ROOT/switch-env.sh"

echo ""
echo "[ test_switch_env.sh ]"

# ============================================================
# Test: Script basics
# ============================================================
test_script_basics() {
    section "Script basics"

    assert_file_exists "switch-env.sh exists" "$SCRIPT"
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
# Test: Argument handling
# ============================================================
test_argument_handling() {
    section "Argument handling"

    assert_file_contains "accepts CLI argument" "$SCRIPT" '\$# -eq 1'
    assert_file_contains "prompts if no arg" "$SCRIPT" 'read -rp'
    assert_file_contains "checks empty input" "$SCRIPT" 'service name cannot be empty'
}

# ============================================================
# Test: Environment switching logic
# ============================================================
test_switching_logic() {
    section "Environment switching logic"

    assert_file_contains "checks .envs file exists" "$SCRIPT" '\.envs/.*\.env'
    assert_file_contains "shows available envs" "$SCRIPT" 'Available environments'
    assert_file_contains "detects current env" "$SCRIPT" 'current_env'
    assert_file_contains "skips if already active" "$SCRIPT" 'Already using environment'
    assert_file_contains "creates symlink" "$SCRIPT" 'ln -sf'
    assert_file_contains "validates symlink" "$SCRIPT" 'validate_symlink'
}

# ============================================================
# Test: File regeneration
# ============================================================
test_file_regeneration() {
    section "File regeneration"

    assert_file_contains "regenerates docker-compose.yml" "$SCRIPT" 'Regenerating docker-compose.yml'
    assert_file_contains "regenerates Dockerfile" "$SCRIPT" 'Regenerating Dockerfile'
    assert_file_contains "regenerates devcontainer.json" "$SCRIPT" 'Regenerating .devcontainer/devcontainer.json'
    assert_file_contains "regenerates devcontainer docker-compose" "$SCRIPT" 'Regenerating .devcontainer/docker-compose.yml'
    assert_file_contains "uses generate_dockerfile_from_template" "$SCRIPT" 'generate_dockerfile_from_template'
}

# ============================================================
# Test: Safe env var reading
# ============================================================
test_env_var_reading() {
    section "Safe env var reading"

    assert_file_contains "uses read_env_var helper" "$SCRIPT" 'read_env_var'
    assert_file_contains "reads CONTAINER_SERVICE_NAME" "$SCRIPT" 'read_env_var "CONTAINER_SERVICE_NAME"'
    assert_file_contains "reads USERNAME" "$SCRIPT" 'read_env_var "USERNAME"'
}

# ============================================================
# Test: shellcheck
# ============================================================
test_shellcheck() {
    section "shellcheck"

    if ! command -v shellcheck &>/dev/null; then
        skip_test "shellcheck switch-env.sh" "shellcheck not installed"
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
test_argument_handling
test_switching_logic
test_file_regeneration
test_env_var_reading
test_shellcheck

print_summary
