#!/bin/bash
# ============================================================
# tests/unit/plugins/test_aws-cli.sh
# Plugin-specific tests for aws-cli
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_aws-cli.sh ]"

# ============================================================
# Test: aws-cli plugin specifics — volumes
# ============================================================
test_aws_cli() {
    section "aws-cli specifics"

    load_plugin "aws-cli"
    assert_eq "PLUGIN_NAME" "AWS CLI v2" "$PLUGIN_NAME"
    assert_eq "PLUGIN_DEFAULT" "false" "$PLUGIN_DEFAULT"
    assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
    assert_eq "volume name is aws" "aws" "${PLUGIN_VOLUME_NAMES[0]}"

    local result
    result=$(generate_plugin_installs "aws-cli")
    assert_true "install contains AWS" echo "$result" | grep -q "AWS"
}

# ============================================================
# Test: aws-cli volume generation
# ============================================================
test_aws_cli_volumes() {
    section "aws-cli volume generation"

    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    cat > "$tmpfile" << 'EOF'
[container]
service_name = "vol-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["aws-cli"]

[ports]
forward = [3000]
EOF

    load_workspace_config "$tmpfile"
    generate_plugin_volumes "aws-cli"

    assert_true "mounts contain aws" echo "$_OPTIONAL_VOLUME_MOUNTS" | grep -q "aws"
    assert_true "definitions contain aws" echo "$_OPTIONAL_VOLUME_DEFINITIONS" | grep -q "aws"

    rm -f "$tmpfile"
}

# ============================================================
# Run
# ============================================================

test_aws_cli
test_aws_cli_volumes

print_summary
