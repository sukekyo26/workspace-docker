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
# Test: toml_parser.py basic functionality
# ============================================================
test_toml_parser() {
    section "toml_parser.py"

    assert_true "toml_parser.py prints usage" python3 "$PROJECT_ROOT/lib/toml_parser.py" plugin "$PROJECT_ROOT/plugins/docker-cli.toml"
    assert_true "toml_parser.py can parse plugin" python3 "$PROJECT_ROOT/lib/toml_parser.py" plugin "$PROJECT_ROOT/plugins/docker-cli.toml"
}

# ============================================================
# Test: devcontainer.sh - function definitions
# ============================================================
test_devcontainer_functions() {
    section "devcontainer.sh functions"

    local dc="$PROJECT_ROOT/lib/devcontainer.sh"

    # Required functions exist
    assert_file_contains "check_docker defined" "$dc" 'check_docker()'
    assert_file_contains "check_devcontainer_cli defined" "$dc" 'check_devcontainer_cli()'
    assert_file_contains "check_devcontainer_json defined" "$dc" 'check_devcontainer_json()'
    assert_file_contains "check_env_file defined" "$dc" 'check_env_file()'
    assert_file_contains "check_all_prerequisites defined" "$dc" 'check_all_prerequisites()'
    assert_file_contains "is_wsl defined" "$dc" 'is_wsl()'
    assert_file_contains "run_devcontainer defined" "$dc" 'run_devcontainer()'

    # curl installer, NOT npm
    assert_file_contains "uses curl installer" "$dc" 'curl -fsSL.*devcontainers/cli.*install.sh'
    assert_file_not_contains "does NOT use npm" "$dc" 'npm install.*@devcontainers/cli'

    # WSL detection & Docker path handling
    assert_file_contains "checks /proc/version for WSL" "$dc" '/proc/version'
    assert_file_contains "sets DOCKER_HOST for WSL" "$dc" 'DOCKER_HOST'
    assert_file_contains "passes --docker-path" "$dc" '\-\-docker-path'
}

# ============================================================
# Test: shellcheck on lib files
# ============================================================
test_shellcheck() {
    section "shellcheck"

    if ! command -v shellcheck &>/dev/null; then
        skip_test "shellcheck lib/*.sh" "shellcheck not installed"
        return
    fi

    local scripts=("lib/generators.sh" "lib/validators.sh" "lib/errors.sh" "lib/devcontainer.sh" "lib/plugin.sh")
    for script in "${scripts[@]}"; do
        local path="$PROJECT_ROOT/$script"
        local result
        result=$(shellcheck -S error "$path" 2>&1 || true)
        if [[ -z "$result" ]]; then
            assert_eq "shellcheck $script (errors only)" "0" "0"
        else
            echo "$result" | head -10 | sed 's/^/      /'
            assert_eq "shellcheck $script (errors only)" "0" "1"
        fi
    done
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
test_shellcheck

print_summary
