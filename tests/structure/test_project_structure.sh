#!/bin/bash
# ============================================================
# tests/structure/test_project_structure.sh
# Tests for overall project structure, syntax, and conventions
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_project_structure.sh ]"

# ============================================================
# Test: Required files exist
# ============================================================
test_required_files() {
    section "Required files"

    assert_file_exists "lib/generators.py" "$PROJECT_ROOT/lib/generators.py"
    assert_file_exists "README.md" "$PROJECT_ROOT/README.md"
    assert_file_exists "LICENSE" "$PROJECT_ROOT/LICENSE"
    assert_file_exists ".gitignore" "$PROJECT_ROOT/.gitignore"
    assert_dir_exists "certs/ directory" "$PROJECT_ROOT/certs"
    assert_dir_exists "config/ directory" "$PROJECT_ROOT/config"
    assert_file_exists "config/apt-base-packages.conf" "$PROJECT_ROOT/config/apt-base-packages.conf"
    assert_dir_exists "lib/ directory" "$PROJECT_ROOT/lib"
    assert_dir_exists "plugins/ directory" "$PROJECT_ROOT/plugins"
    assert_dir_exists "workspaces/ directory" "$PROJECT_ROOT/workspaces"
    assert_file_exists "workspaces/.gitkeep" "$PROJECT_ROOT/workspaces/.gitkeep"
    assert_file_exists "lib/toml_parser.py" "$PROJECT_ROOT/lib/toml_parser.py"
    assert_file_exists "lib/plugins.sh" "$PROJECT_ROOT/lib/plugins.sh"
}

# ============================================================
# Test: All scripts are executable
# ============================================================
test_scripts_executable() {
    section "Scripts are executable"

    local scripts=(
        "generate-workspace.sh"
        "setup-docker.sh"
        "rebuild-container.sh"
    )

    for script in "${scripts[@]}"; do
        local path="$PROJECT_ROOT/$script"
        if [[ -f "$path" ]]; then
            assert_true "$script is executable" test -x "$path"
        else
            skip_test "$script is executable" "file not found"
        fi
    done
}

# ============================================================
# Test: All scripts pass syntax check
# ============================================================
test_syntax_check() {
    section "Syntax check (bash -n)"

    local scripts=(
        "generate-workspace.sh"
        "setup-docker.sh"
        "rebuild-container.sh"
        "lib/generators.sh"
        "lib/validators.sh"
        "lib/logging.sh"
        "lib/devcontainer.sh"
        "lib/plugins.sh"
        "lib/utils.sh"
        "lib/certificates.sh"
    )

    for script in "${scripts[@]}"; do
        local path="$PROJECT_ROOT/$script"
        if [[ -f "$path" ]]; then
            assert_true "$script syntax OK" bash -n "$path"
        else
            skip_test "$script syntax OK" "file not found"
        fi
    done
}

# ============================================================
# Test: Template placeholder consistency
# ============================================================
test_template_placeholders() {
    section "Template placeholders"

    # Dockerfile template is now inlined in lib/generators.py
    # Verify the Python constant contains the required placeholders
    local gen_py="$PROJECT_ROOT/lib/generators.py"
    if [[ -f "$gen_py" ]]; then
        assert_file_contains "generators.py: {{PLUGIN_INSTALLS}}" "$gen_py" '{{PLUGIN_INSTALLS}}'
        assert_file_contains "generators.py: {{CUSTOM_CERTIFICATES}}" "$gen_py" '{{CUSTOM_CERTIFICATES}}'
    fi
}

# ============================================================
# Test: .gitignore patterns
# ============================================================
test_gitignore() {
    section ".gitignore patterns"

    local gi="$PROJECT_ROOT/.gitignore"
    assert_file_contains "ignores Dockerfile" "$gi" 'Dockerfile'
    assert_file_contains "ignores docker-compose.yml" "$gi" 'docker-compose.yml'
    assert_file_contains "ignores .env" "$gi" '\.env'
    assert_file_contains "ignores .code-workspace" "$gi" '\.code-workspace'
    assert_file_contains "ignores workspace.toml" "$gi" 'workspace.toml'
    assert_file_contains "ignores certs" "$gi" 'certs/'
}

# ============================================================
# Test: Docker prerequisites
# ============================================================
test_docker_prerequisites() {
    section "Docker prerequisites"

    if command -v docker &>/dev/null; then
        assert_true "Docker is installed" command -v docker
    else
        skip_test "Docker is installed" "docker not found"
    fi

    if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
        assert_true "Docker Compose is available" docker compose version
    else
        skip_test "Docker Compose is available" "docker compose not found"
    fi
}

# ============================================================
# Test: Generated files (if setup was run)
# ============================================================
test_generated_files() {
    section "Generated files (if setup done)"

    if [[ ! -f "$PROJECT_ROOT/workspace.toml" ]]; then
        skip_test "generated files check" "setup-docker.sh has not been run"
        return
    fi

    assert_file_exists "Dockerfile" "$PROJECT_ROOT/Dockerfile"
    assert_file_exists "docker-compose.yml" "$PROJECT_ROOT/docker-compose.yml"

    # .devcontainer/ is created by setup-docker.sh and gitignored
    if [[ -d "$PROJECT_ROOT/.devcontainer" ]]; then
        assert_file_exists ".devcontainer/devcontainer.json" "$PROJECT_ROOT/.devcontainer/devcontainer.json"
    else
        skip_test ".devcontainer/devcontainer.json" ".devcontainer/ not generated yet"
    fi

    # Check no unreplaced placeholders
    if [[ -f "$PROJECT_ROOT/Dockerfile" ]]; then
        assert_file_not_contains "Dockerfile: no unreplaced {{...}}" "$PROJECT_ROOT/Dockerfile" '{{.*}}'
    fi
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        assert_file_not_contains "docker-compose.yml: no unreplaced {{...}}" "$PROJECT_ROOT/docker-compose.yml" '{{.*}}'
    fi

    # docker-compose.yml syntax validation
    if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
        if docker compose -f "$PROJECT_ROOT/docker-compose.yml" config &>/dev/null; then
            assert_true "docker-compose.yml syntax is valid" true
        else
            assert_true "docker-compose.yml syntax is valid" false
        fi
    else
        skip_test "docker-compose.yml syntax validation" "docker compose not available"
    fi
}

# ============================================================
# Test: .env file format (if setup was run)
# ============================================================
test_env_format() {
    section "Environment file format"

    if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
        skip_test "env file format" ".env file not found (setup not run)"
        return
    fi

    local env_file="$PROJECT_ROOT/.env"
    local required_vars=(CONTAINER_SERVICE_NAME USERNAME UID GID DOCKER_GID UBUNTU_VERSION FORWARD_PORT)

    for var in "${required_vars[@]}"; do
        assert_file_contains ".env has $var" "$env_file" "^${var}="
    done
}

# ============================================================
# Test: Volume mount points (if setup was run)
# ============================================================
test_volume_mounts() {
    section "Volume mount points"

    if [[ ! -f "$PROJECT_ROOT/Dockerfile" || ! -f "$PROJECT_ROOT/workspace.toml" ]]; then
        skip_test "volume mount points" "setup-docker.sh has not been run"
        return
    fi

    # Load workspace config to check enabled plugins
    local enabled_plugins=""
    enabled_plugins=$(python3 "$PROJECT_ROOT/lib/toml_parser.py" workspace "$PROJECT_ROOT/workspace.toml" 2>/dev/null | grep '^WS_PLUGINS=' || true)

    # Determine which plugin-specific volumes to test based on workspace.toml
    # These are literal strings for grep-matching in Dockerfile, not paths for expansion
    # shellcheck disable=SC2088
    local paths_to_check=('~/.local')
    local volumes_to_check=(local)

    if echo "$enabled_plugins" | grep -q "'proto'"; then
        # shellcheck disable=SC2088
        paths_to_check+=('~/.proto')
        volumes_to_check+=(proto)
    fi

    for vol in "${paths_to_check[@]}"; do
        local escaped
        escaped=$(echo "$vol" | sed 's/[.]/\\./g; s|/|\\/|g')
        if grep -qE "${escaped}(\s|\\\\|\$)" "$PROJECT_ROOT/Dockerfile" 2>/dev/null; then
            assert_true "Dockerfile has mount point for $vol" true
        else
            assert_true "Dockerfile has mount point for $vol" false
        fi
    done

    # Check docker-compose.yml named volumes
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        for vol in "${volumes_to_check[@]}"; do
            assert_file_contains "docker-compose.yml defines volume '$vol'" \
                "$PROJECT_ROOT/docker-compose.yml" "^  ${vol}:"
        done
    fi
}

# ============================================================
# Test: shellcheck all scripts (consolidated)
# ============================================================
test_shellcheck_all() {
    section "shellcheck (all scripts)"

    if ! command -v shellcheck &>/dev/null; then
        skip_test "shellcheck all" "shellcheck not installed"
        return
    fi

    # Find all .sh files in the project (excluding .devcontainer)
    local scripts=()
    while IFS= read -r script; do
        scripts+=("$script")
    done < <(find "$PROJECT_ROOT" -name '*.sh' \
        -not -path '*/.devcontainer/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -path '*/local/*' | sort)

    for path in "${scripts[@]}"; do
        local relpath="${path#"$PROJECT_ROOT/"}"
        local result
        result=$(shellcheck "$path" 2>&1 || true)
        if [[ -z "$result" ]]; then
            assert_eq "shellcheck $relpath (errors)" "0" "0"
        else
            echo "$result" | head -5 | sed 's/^/      /'
            assert_eq "shellcheck $relpath (errors)" "0" "1"
        fi
    done
}

# ============================================================
# Run
# ============================================================

test_required_files
test_scripts_executable
test_syntax_check
test_template_placeholders
test_gitignore
test_docker_prerequisites
test_generated_files
test_env_format
test_volume_mounts
test_shellcheck_all

print_summary
