#!/bin/bash
# ============================================================
# tests/test_project_structure.sh
# Tests for overall project structure, syntax, and conventions
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_project_structure.sh ]"

# ============================================================
# Test: Required files exist
# ============================================================
test_required_files() {
    section "Required files"

    assert_file_exists "Dockerfile.template" "$PROJECT_ROOT/Dockerfile.template"
    assert_file_exists "docker-compose.yml.template" "$PROJECT_ROOT/docker-compose.yml.template"
    assert_file_exists ".devcontainer/devcontainer.json.template" "$PROJECT_ROOT/.devcontainer/devcontainer.json.template"
    assert_file_exists ".devcontainer/docker-compose.yml.template" "$PROJECT_ROOT/.devcontainer/docker-compose.yml.template"
    assert_file_exists "README.md" "$PROJECT_ROOT/README.md"
    assert_file_exists "LICENSE" "$PROJECT_ROOT/LICENSE"
    assert_file_exists ".gitignore" "$PROJECT_ROOT/.gitignore"
    assert_dir_exists "certs/ directory" "$PROJECT_ROOT/certs"
    assert_dir_exists "config/ directory" "$PROJECT_ROOT/config"
    assert_dir_exists "lib/ directory" "$PROJECT_ROOT/lib"
    assert_dir_exists "workspaces/ directory" "$PROJECT_ROOT/workspaces"
    assert_file_exists "workspaces/.gitkeep" "$PROJECT_ROOT/workspaces/.gitkeep"
}

# ============================================================
# Test: All scripts are executable
# ============================================================
test_scripts_executable() {
    section "Scripts are executable"

    local scripts=(
        "generate-workspace.sh"
        "setup-docker.sh"
        "switch-env.sh"
        "rebuild-container.sh"
        "test.sh"
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
        "switch-env.sh"
        "rebuild-container.sh"
        "test.sh"
        "lib/generators.sh"
        "lib/validators.sh"
        "lib/errors.sh"
        "lib/devcontainer.sh"
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

    local tmpl

    tmpl="$PROJECT_ROOT/Dockerfile.template"
    if [[ -f "$tmpl" ]]; then
        assert_file_contains "Dockerfile.template: {{DOCKER_INSTALL}}" "$tmpl" '{{DOCKER_INSTALL}}'
        assert_file_contains "Dockerfile.template: {{AWS_CLI_INSTALL}}" "$tmpl" '{{AWS_CLI_INSTALL}}'
        assert_file_contains "Dockerfile.template: {{GITHUB_CLI_INSTALL}}" "$tmpl" '{{GITHUB_CLI_INSTALL}}'
        assert_file_contains "Dockerfile.template: {{ZIG_INSTALL}}" "$tmpl" '{{ZIG_INSTALL}}'
        assert_file_contains "Dockerfile.template: {{CUSTOM_CERTIFICATES}}" "$tmpl" '{{CUSTOM_CERTIFICATES}}'
    fi

    tmpl="$PROJECT_ROOT/docker-compose.yml.template"
    if [[ -f "$tmpl" ]]; then
        assert_file_contains "docker-compose.yml.template: {{CONTAINER_SERVICE_NAME}}" "$tmpl" '{{CONTAINER_SERVICE_NAME}}'
    fi

    tmpl="$PROJECT_ROOT/.devcontainer/devcontainer.json.template"
    if [[ -f "$tmpl" ]]; then
        assert_file_contains "devcontainer.json.template: {{CONTAINER_SERVICE_NAME}}" "$tmpl" '{{CONTAINER_SERVICE_NAME}}'
        assert_file_contains "devcontainer.json.template: {{USERNAME}}" "$tmpl" '{{USERNAME}}'
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
    assert_file_contains "ignores certs" "$gi" 'certs/'
}

# ============================================================
# Test: Generated files (if setup was run)
# ============================================================
test_generated_files() {
    section "Generated files (if setup done)"

    if [[ -L "$PROJECT_ROOT/.env" && -e "$PROJECT_ROOT/.env" ]]; then
        assert_file_exists "Dockerfile" "$PROJECT_ROOT/Dockerfile"
        assert_file_exists "docker-compose.yml" "$PROJECT_ROOT/docker-compose.yml"
        assert_file_exists ".devcontainer/devcontainer.json" "$PROJECT_ROOT/.devcontainer/devcontainer.json"

        # Check no unreplaced placeholders
        if [[ -f "$PROJECT_ROOT/Dockerfile" ]]; then
            assert_file_not_contains "Dockerfile: no unreplaced {{...}}" "$PROJECT_ROOT/Dockerfile" '{{.*}}'
        fi
        if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
            assert_file_not_contains "docker-compose.yml: no unreplaced {{...}}" "$PROJECT_ROOT/docker-compose.yml" '{{.*}}'
        fi
    else
        skip_test "generated files check" "setup-docker.sh has not been run"
    fi
}

# ============================================================
# Test: shellcheck all scripts
# ============================================================
test_shellcheck_all() {
    section "shellcheck (all scripts)"

    if ! command -v shellcheck &>/dev/null; then
        skip_test "shellcheck all" "shellcheck not installed"
        return
    fi

    local scripts=(
        "generate-workspace.sh"
        "rebuild-container.sh"
    )

    for script in "${scripts[@]}"; do
        local path="$PROJECT_ROOT/$script"
        if [[ -f "$path" ]]; then
            local result
            result=$(shellcheck -S error "$path" 2>&1 || true)
            if [[ -z "$result" ]]; then
                assert_eq "shellcheck $script (errors)" "0" "0"
            else
                echo "$result" | head -5 | sed 's/^/      /'
                assert_eq "shellcheck $script (errors)" "0" "1"
            fi
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
test_generated_files
test_shellcheck_all

print_summary
