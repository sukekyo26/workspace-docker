#!/bin/bash
# ============================================================
# tests/unit/plugins/test_proto.sh
# Plugin-specific tests for proto
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=plugin_test_helper.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/plugin_test_helper.sh"

echo ""
echo "[ test_proto.sh ]"

# ============================================================
# Test: proto plugin specifics
# ============================================================
test_proto() {
    section "proto specifics"

    load_plugin "proto"
    assert_eq "PLUGIN_NAME" "proto" "$PLUGIN_NAME"
    assert_eq "PLUGIN_DEFAULT" "true" "$PLUGIN_DEFAULT"
    assert_eq "PLUGIN_REQUIRES_ROOT" "false" "$PLUGIN_REQUIRES_ROOT"
    assert_true "has volume names" test "${#PLUGIN_VOLUME_NAMES[@]}" -gt 0
    assert_eq "volume name is proto" "proto" "${PLUGIN_VOLUME_NAMES[0]}"

    local result
    result=$(generate_plugin_installs "proto")
    assert_true "install contains proto" echo "$result" | grep -q "proto"
    assert_true "install contains PROTO_HOME" echo "$result" | grep -q "PROTO_HOME"
    assert_true "install sets PATH" echo "$result" | grep -q "PATH"
}

# ============================================================
# Test: proto volume generation
# ============================================================
test_proto_volumes() {
    section "proto volume generation"

    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    cat > "$tmpfile" << 'EOF'
[container]
service_name = "vol-test"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["proto"]

[ports]
forward = [3000]
EOF

    load_workspace_config "$tmpfile"
    generate_plugin_volumes "proto"

    assert_true "mounts contain proto" echo "$_OPTIONAL_VOLUME_MOUNTS" | grep -q "proto"
    assert_true "definitions contain proto" echo "$_OPTIONAL_VOLUME_DEFINITIONS" | grep -q "proto"

    rm -f "$tmpfile"
}

# ============================================================
# Run
# ============================================================

test_proto
test_proto_volumes

print_summary
