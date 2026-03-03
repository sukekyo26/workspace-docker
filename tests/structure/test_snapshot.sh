#!/bin/bash
# ============================================================
# tests/test_snapshot.sh
# Snapshot tests: compare generated files against expected output
# ============================================================
# Usage:
#   ./tests/test_snapshot.sh           # Compare snapshots
#   ./tests/test_snapshot.sh --update  # Update snapshot files
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_snapshot.sh ]"

SNAPSHOT_DIR="$TESTS_DIR/snapshots"
FIXTURE_TOML="$TESTS_DIR/fixtures/snapshot.workspace.toml"

UPDATE_MODE=false
[[ "${1:-}" == "--update" ]] && UPDATE_MODE=true

# ============================================================
# Helper: create workspace and generate all files
# ============================================================
WORK_DIR=""

generate_all_files() {
    WORK_DIR=$(mktemp -d)

    # Copy Dockerfile template
    mkdir -p "$WORK_DIR/templates"
    cp "$PROJECT_ROOT/templates/Dockerfile.template" "$WORK_DIR/templates/"
    mkdir -p "$WORK_DIR/.devcontainer"

    # Copy libs and plugins
    cp -r "$PROJECT_ROOT/lib" "$WORK_DIR/"
    cp -r "$PROJECT_ROOT/plugins" "$WORK_DIR/"
    cp -r "$PROJECT_ROOT/config" "$WORK_DIR/"

    # Empty certs dir (no certificates for snapshot)
    mkdir -p "$WORK_DIR/certs"

    # Copy fixture workspace.toml
    cp "$FIXTURE_TOML" "$WORK_DIR/workspace.toml"

    # Generate all files
    (
        cd "$WORK_DIR" || exit 1
        source lib/generators.sh

        load_workspace_config "workspace.toml"

        generate_dockerfile_from_template \
            "templates/Dockerfile.template" "Dockerfile" "workspace.toml"

        generate_compose \
            "docker-compose.yml" "workspace.toml"

        generate_devcontainer_json \
            ".devcontainer/devcontainer.json" "workspace.toml"

        generate_devcontainer_compose \
            ".devcontainer/docker-compose.yml" "workspace.toml"
    )
}

cleanup() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    WORK_DIR=""
}

# ============================================================
# Snapshot targets
# ============================================================
declare -A SNAPSHOT_FILES=(
    ["Dockerfile"]="Dockerfile.expected"
    ["docker-compose.yml"]="docker-compose.yml.expected"
    [".devcontainer/devcontainer.json"]="devcontainer.json.expected"
    [".devcontainer/docker-compose.yml"]=".devcontainer/docker-compose.yml.expected"
)

# ============================================================
# Update mode: generate and save snapshots
# ============================================================
if [[ "$UPDATE_MODE" == true ]]; then
    echo "Updating snapshots..."
    generate_all_files

    for gen_file in "${!SNAPSHOT_FILES[@]}"; do
        local_snap="${SNAPSHOT_FILES[$gen_file]}"
        snap_path="$SNAPSHOT_DIR/$local_snap"
        mkdir -p "$(dirname "$snap_path")"
        cp "$WORK_DIR/$gen_file" "$snap_path"
        echo "  Updated: $local_snap"
    done

    cleanup
    echo "Snapshots updated. Please review and commit."
    exit 0
fi

# ============================================================
# Test mode: compare generated files with snapshots
# ============================================================
section "Snapshot comparison"

# Check fixture exists
if [[ ! -f "$FIXTURE_TOML" ]]; then
    echo "ERROR: Fixture not found: $FIXTURE_TOML"
    exit 1
fi

# Check snapshots exist
missing_snapshots=false
for gen_file in "${!SNAPSHOT_FILES[@]}"; do
    local_snap="${SNAPSHOT_FILES[$gen_file]}"
    if [[ ! -f "$SNAPSHOT_DIR/$local_snap" ]]; then
        echo "  Missing snapshot: $local_snap (run with --update to create)"
        missing_snapshots=true
    fi
done

if [[ "$missing_snapshots" == true ]]; then
    echo "Run: tests/test_snapshot.sh --update"
    exit 1
fi

# Generate files
generate_all_files

# Compare each file
for gen_file in "${!SNAPSHOT_FILES[@]}"; do
    local_snap="${SNAPSHOT_FILES[$gen_file]}"
    snap_path="$SNAPSHOT_DIR/$local_snap"

    if diff -u "$snap_path" "$WORK_DIR/$gen_file" > /dev/null 2>&1; then
        assert_eq "snapshot matches: $gen_file" "match" "match"
    else
        assert_eq "snapshot matches: $gen_file" "match" "differs"
        echo "      Diff for $gen_file:"
        diff -u "$snap_path" "$WORK_DIR/$gen_file" | head -20 | sed 's/^/      /'
        echo "      ..."
        echo "      Run: tests/test_snapshot.sh --update"
    fi
done

cleanup

print_summary
