#!/bin/bash
# ============================================================
# tests/unit/lib/test_utils.sh
# Tests for lib/utils.sh and lib/certificates.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_utils.sh ]"

source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/certificates.sh"

# ============================================================
# Test: read_env_var
# ============================================================
test_read_env_var() {
    section "read_env_var"

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
# Test: validate_symlink
# ============================================================
test_validate_symlink() {
    section "validate_symlink"

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
# Test: certificate functions
# ============================================================
test_certificate_functions() {
    section "Certificate functions"

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
# Run
# ============================================================

test_read_env_var
test_validate_symlink
test_certificate_functions

print_summary
