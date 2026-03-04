#!/bin/bash
# ============================================================
# tests/unit/lib/test_validators.sh
# Tests for lib/validators.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_validators.sh ]"

source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/validators.sh"

# ============================================================
# Test: validate_service_name
# ============================================================
test_validate_service_name() {
    section "validate_service_name"

    assert_true "valid name: dev" validate_service_name "dev"
    assert_true "valid name: my-container" validate_service_name "my-container"
    assert_true "valid name: my_container_1" validate_service_name "my_container_1"
    assert_false "invalid: empty string" validate_service_name ""
    assert_false "invalid: contains space" validate_service_name "my container"
    assert_false "invalid: contains dot" validate_service_name "my.container"
}

# ============================================================
# Test: validate_username
# ============================================================
test_validate_username() {
    section "validate_username"

    assert_true "valid: shogo" validate_username "shogo"
    assert_true "valid: _admin" validate_username "_admin"
    assert_true "valid: user-1" validate_username "user-1"
    assert_false "invalid: empty" validate_username ""
    assert_false "invalid: starts with number" validate_username "1user"
    assert_false "invalid: uppercase" validate_username "User"
}

# ============================================================
# Test: validate_boolean
# ============================================================
test_validate_boolean() {
    section "validate_boolean"

    assert_true "valid: true" validate_boolean "true"
    assert_true "valid: false" validate_boolean "false"
    assert_false "invalid: yes" validate_boolean "yes"
    assert_false "invalid: 1" validate_boolean "1"
    assert_false "invalid: empty" validate_boolean ""
}

# ============================================================
# Test: validate_file_exists
# ============================================================
test_validate_file_exists() {
    section "validate_file_exists"

    local tmpfile
    tmpfile=$(mktemp)
    assert_true "existing file validates" validate_file_exists "$tmpfile" "test file"
    assert_false "non-existent file fails" validate_file_exists "/nonexistent/file" "missing file"
    rm -f "$tmpfile"
}

# ============================================================
# Test: validate_no_duplicate_apt_packages
# ============================================================
test_validate_no_duplicate_apt_packages() {
    section "validate_no_duplicate_apt_packages"

    local tmpconf
    tmpconf=$(mktemp)
    cat > "$tmpconf" << 'EOF'
# Base packages
curl
git
wget
sudo
EOF

    # No duplicates — should pass
    assert_true "no duplicates passes" validate_no_duplicate_apt_packages "$tmpconf" "vim" "tmux"

    # Duplicate detected — should fail
    assert_false "duplicate 'curl' detected" validate_no_duplicate_apt_packages "$tmpconf" "curl"

    # Multiple extras, one duplicate
    assert_false "duplicate among multiple extras" validate_no_duplicate_apt_packages "$tmpconf" "vim" "git" "htop"

    # Empty extras — should pass
    assert_true "empty extras passes" validate_no_duplicate_apt_packages "$tmpconf"

    # Empty extras with empty string — should pass
    assert_true "empty string extras passes" validate_no_duplicate_apt_packages "$tmpconf" ""

    # Non-existent conf file — should pass (graceful)
    assert_true "missing conf passes" validate_no_duplicate_apt_packages "/nonexistent/file" "vim"

    rm -f "$tmpconf"
}

# ============================================================
# Run
# ============================================================

test_validate_service_name
test_validate_username
test_validate_boolean
test_validate_file_exists
test_validate_no_duplicate_apt_packages

print_summary
