#!/bin/bash
# ============================================================
# tests/test_lib.sh
# Tests for lib/generators.sh, lib/validators.sh, lib/errors.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_lib.sh ]"

# ============================================================
# Test: Library file basics
# ============================================================
test_lib_basics() {
    section "Library file basics"

    assert_file_exists "generators.sh exists" "$PROJECT_ROOT/lib/generators.sh"
    assert_file_exists "validators.sh exists" "$PROJECT_ROOT/lib/validators.sh"
    assert_file_exists "errors.sh exists" "$PROJECT_ROOT/lib/errors.sh"
    assert_file_exists "devcontainer.sh exists" "$PROJECT_ROOT/lib/devcontainer.sh"
    assert_file_exists "plugin.sh exists" "$PROJECT_ROOT/lib/plugin.sh"
    assert_file_exists "toml_parser.py exists" "$PROJECT_ROOT/lib/toml_parser.py"

    assert_true "generators.sh syntax valid" bash -n "$PROJECT_ROOT/lib/generators.sh"
    assert_true "validators.sh syntax valid" bash -n "$PROJECT_ROOT/lib/validators.sh"
    assert_true "errors.sh syntax valid" bash -n "$PROJECT_ROOT/lib/errors.sh"
    assert_true "devcontainer.sh syntax valid" bash -n "$PROJECT_ROOT/lib/devcontainer.sh"
    assert_true "plugin.sh syntax valid" bash -n "$PROJECT_ROOT/lib/plugin.sh"
}

# ============================================================
# Test: validators.sh - validate_service_name
# ============================================================
test_validate_service_name() {
    section "validate_service_name"

    # Source validators (needs errors.sh for some functions)
    source "$PROJECT_ROOT/lib/errors.sh"
    source "$PROJECT_ROOT/lib/validators.sh"

    assert_true "valid name: dev" validate_service_name "dev"
    assert_true "valid name: my-container" validate_service_name "my-container"
    assert_true "valid name: my_container_1" validate_service_name "my_container_1"
    assert_false "invalid: empty string" validate_service_name ""
    assert_false "invalid: contains space" validate_service_name "my container"
    assert_false "invalid: contains dot" validate_service_name "my.container"
}

# ============================================================
# Test: validators.sh - validate_username
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
# Test: validators.sh - validate_boolean
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
# Test: validators.sh - validate_file_exists
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
# Test: generators.sh - read_env_var
# ============================================================
test_read_env_var() {
    section "read_env_var"

    source "$PROJECT_ROOT/lib/generators.sh"

    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile" << 'EOF'
CONTAINER_SERVICE_NAME=dev
USERNAME=shogo
UID=1000
INSTALL_DOCKER=true
EMPTY_VAR=
VALUE_WITH_EQUALS=a=b=c
EOF

    local val
    val=$(read_env_var "CONTAINER_SERVICE_NAME" "$tmpfile")
    assert_eq "reads CONTAINER_SERVICE_NAME" "dev" "$val"

    val=$(read_env_var "USERNAME" "$tmpfile")
    assert_eq "reads USERNAME" "shogo" "$val"

    val=$(read_env_var "INSTALL_DOCKER" "$tmpfile")
    assert_eq "reads boolean INSTALL_DOCKER" "true" "$val"

    val=$(read_env_var "VALUE_WITH_EQUALS" "$tmpfile")
    assert_eq "reads value containing =" "a=b=c" "$val"

    val=$(read_env_var "NONEXISTENT" "$tmpfile")
    assert_eq "non-existent var returns empty" "" "$val"

    rm -f "$tmpfile"
}

# ============================================================
# Test: generators.sh - validate_symlink
# ============================================================
test_validate_symlink() {
    section "validate_symlink"

    source "$PROJECT_ROOT/lib/generators.sh"

    local tmpdir
    tmpdir=$(mktemp -d)

    # Valid symlink
    echo "test" > "$tmpdir/target.env"
    ln -sf "target.env" "$tmpdir/link"
    assert_exit_code "valid symlink returns 0" 0 validate_symlink "$tmpdir/link" ""

    # Broken symlink
    ln -sf "nonexistent" "$tmpdir/broken"
    assert_exit_code "broken symlink returns 1" 1 validate_symlink "$tmpdir/broken" ""

    # Not a symlink
    echo "test" > "$tmpdir/regular"
    assert_exit_code "not a symlink returns 2" 2 validate_symlink "$tmpdir/regular" ""

    rm -rf "$tmpdir"
}

# ============================================================
# Test: generators.sh - certificate functions
# ============================================================
test_certificate_functions() {
    section "Certificate functions"

    source "$PROJECT_ROOT/lib/generators.sh"

    # validate_certificate with a fake cert
    local tmpdir
    tmpdir=$(mktemp -d)

    # Valid PEM certificate
    cat > "$tmpdir/test.crt" << 'EOF'
-----BEGIN CERTIFICATE-----
MIIBojCCAUmgAwIBAgIRAIuvAAAAAAAAAAAAAAAAAAAA
-----END CERTIFICATE-----
EOF
    assert_true "valid .crt passes" validate_certificate "$tmpdir/test.crt"

    # Invalid extension
    cp "$tmpdir/test.crt" "$tmpdir/test.pem"
    assert_false "non-.crt extension fails" validate_certificate "$tmpdir/test.pem"

    # Missing BEGIN
    echo "not a certificate" > "$tmpdir/bad.crt"
    assert_false "non-PEM content fails" validate_certificate "$tmpdir/bad.crt"

    rm -rf "$tmpdir"
}

# ============================================================
# Test: errors.sh - logging functions
# ============================================================
test_error_functions() {
    section "Error/logging functions"

    source "$PROJECT_ROOT/lib/errors.sh"

    # Test error output goes to stderr
    local output
    output=$(error "test error" 2>&1)
    assert_file_contains "error() outputs ERROR:" <(echo "$output") "ERROR:"

    output=$(warn "test warning" 2>&1)
    assert_file_contains "warn() outputs WARNING:" <(echo "$output") "WARNING:"

    output=$(info "test info" 2>&1)
    assert_file_contains "info() outputs INFO:" <(echo "$output") "INFO:"

    output=$(success "test success" 2>&1)
    assert_true "success() produces output" test -n "$output"
}

# ============================================================
# Test: toml_parser.py - detailed output verification
# ============================================================
test_toml_parser() {
    section "toml_parser.py"

    # Test workspace parsing
    local tmptoml
    tmptoml=$(mktemp)
    cat > "$tmptoml" << 'EOF'
[container]
service_name = "parser-test"
username = "devuser"
ubuntu_version = "24.04"

[plugins]
enable = ["docker-cli", "aws-cli"]

[ports]
forward = [8080]

[apt]
extra_packages = ["htop", "tmux"]
EOF

    local output
    output=$(python3 "$PROJECT_ROOT/lib/toml_parser.py" workspace "$tmptoml")
    assert_true "toml_parser.py runs without error" test $? -eq 0

    # Verify each parsed value
    eval "$output"
    assert_eq "WS_SERVICE_NAME" "parser-test" "$WS_SERVICE_NAME"
    assert_eq "WS_USERNAME" "devuser" "$WS_USERNAME"
    assert_eq "WS_UBUNTU_VERSION" "24.04" "$WS_UBUNTU_VERSION"
    assert_eq "WS_PLUGINS count" "2" "${#WS_PLUGINS[@]}"
    assert_eq "WS_PLUGINS[0]" "docker-cli" "${WS_PLUGINS[0]}"
    assert_eq "WS_PLUGINS[1]" "aws-cli" "${WS_PLUGINS[1]}"
    assert_eq "WS_FORWARD_PORTS[0]" "8080" "${WS_FORWARD_PORTS[0]}"
    assert_eq "WS_APT_EXTRA count" "2" "${#WS_APT_EXTRA[@]}"
    assert_eq "WS_APT_EXTRA[0]" "htop" "${WS_APT_EXTRA[0]}"
    assert_eq "WS_APT_EXTRA[1]" "tmux" "${WS_APT_EXTRA[1]}"

    rm -f "$tmptoml"

    # Test plugin parsing
    output=$(python3 "$PROJECT_ROOT/lib/toml_parser.py" plugin "$PROJECT_ROOT/plugins/docker-cli.toml")
    eval "$output"
    assert_eq "PLUGIN_ID" "docker-cli" "$PLUGIN_ID"
    assert_eq "PLUGIN_NAME" "Docker CLI" "$PLUGIN_NAME"
    assert_eq "PLUGIN_REQUIRES_ROOT" "true" "$PLUGIN_REQUIRES_ROOT"

    # Test list-plugins
    output=$(python3 "$PROJECT_ROOT/lib/toml_parser.py" list-plugins "$PROJECT_ROOT/plugins")
    eval "$output"
    assert_true "PLUGIN_IDS has entries" test "${#PLUGIN_IDS[@]}" -gt 0
}

# ============================================================
# Test: devcontainer.sh - function execution
# ============================================================
test_devcontainer_functions() {
    section "devcontainer.sh functions"

    source "$PROJECT_ROOT/lib/devcontainer.sh"

    # Functions are defined and callable
    assert_true "check_docker is a function" declare -f check_docker
    assert_true "check_devcontainer_cli is a function" declare -f check_devcontainer_cli
    assert_true "check_all_prerequisites is a function" declare -f check_all_prerequisites
    assert_true "is_wsl is a function" declare -f is_wsl
    assert_true "run_devcontainer is a function" declare -f run_devcontainer

    # is_wsl returns meaningful result (not error)
    is_wsl 2>/dev/null
    local wsl_rc=$?
    assert_true "is_wsl returns 0 or 1" test "$wsl_rc" -le 1

    # check_docker runs (Docker available in this container)
    if command -v docker &>/dev/null; then
        assert_true "check_docker succeeds" check_docker
    else
        skip_test "check_docker execution" "docker not installed"
    fi
}

# ============================================================
# Run
# ============================================================

test_lib_basics
test_validate_service_name
test_validate_username
test_validate_boolean
test_validate_file_exists
test_read_env_var
test_validate_symlink
test_certificate_functions
test_error_functions
test_devcontainer_functions
test_toml_parser

print_summary
