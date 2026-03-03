#!/bin/bash
# ============================================================
# tests/integration/integration_helper.sh
# Shared helper for integration tests that generate files
# ============================================================
# Provides: setup_workspace, teardown_workspace, create_test_workspace_toml
# Source this AFTER test_helper.sh
# ============================================================

WORK_DIR=""

setup_workspace() {
    WORK_DIR=$(mktemp -d)
    mkdir -p "$WORK_DIR/.devcontainer"
    # Copy libs
    cp -r "$PROJECT_ROOT/lib" "$WORK_DIR/"
    # Copy plugins
    cp -r "$PROJECT_ROOT/plugins" "$WORK_DIR/"
    # Copy config
    cp -r "$PROJECT_ROOT/config" "$WORK_DIR/"
    # Copy certs dir (may be empty)
    cp -r "$PROJECT_ROOT/certs" "$WORK_DIR/" 2>/dev/null || mkdir -p "$WORK_DIR/certs"
}

teardown_workspace() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    WORK_DIR=""
}

# Helper: create a workspace.toml for testing
create_test_workspace_toml() {
    local dir="$1"
    local service_name="$2"
    local username="$3"
    shift 3
    local plugins=("$@")

    local plugins_toml="["
    for ((i = 0; i < ${#plugins[@]}; i++)); do
        if [[ $i -gt 0 ]]; then plugins_toml+=", "; fi
        plugins_toml+="\"${plugins[$i]}\""
    done
    plugins_toml+="]"

    cat > "$dir/workspace.toml" << EOF
[container]
service_name = "$service_name"
username = "$username"
ubuntu_version = "24.04"

[plugins]
enable = $plugins_toml

[ports]
forward = [3000]
EOF
}
