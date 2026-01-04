#!/bin/bash
# Test script for workspace-docker project
#
# ShellCheck directives:
# - SC2031: Color variables are read-only after initialization, subshell warning is false positive
# - SC2034: CONTAINER_SERVICE_NAME is used in grep pattern string interpolation
# - SC2088: Tilde paths are intentional string literals for Dockerfile content matching
# shellcheck disable=SC2031,SC2034,SC2088

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"

    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++)) || true
    elif [ "$result" = "skip" ]; then
        echo -e "${YELLOW}⊘${NC} $test_name (skipped)"
        ((TESTS_SKIPPED++)) || true
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++)) || true
    fi
}

echo "Running workspace-docker tests..."
echo "=================================="
echo ""

# Test 1: Check required template files exist
echo "Testing template files..."
template_files_ok=true

if [ -f "Dockerfile.template" ]; then
    echo -e "${GREEN}  ✓${NC} Dockerfile.template"
else
    echo -e "${RED}  ✗${NC} Dockerfile.template"
    template_files_ok=false
fi

if [ -f "docker-compose.yml.template" ]; then
    echo -e "${GREEN}  ✓${NC} docker-compose.yml.template"
else
    echo -e "${RED}  ✗${NC} docker-compose.yml.template"
    template_files_ok=false
fi

if [ -f ".devcontainer/devcontainer.json.template" ]; then
    echo -e "${GREEN}  ✓${NC} .devcontainer/devcontainer.json.template"
else
    echo -e "${RED}  ✗${NC} .devcontainer/devcontainer.json.template"
    template_files_ok=false
fi

if [ -f ".devcontainer/docker-compose.yml.template" ]; then
    echo -e "${GREEN}  ✓${NC} .devcontainer/docker-compose.yml.template"
else
    echo -e "${RED}  ✗${NC} .devcontainer/docker-compose.yml.template"
    template_files_ok=false
fi

if [ -f "lib/generators.sh" ]; then
    echo -e "${GREEN}  ✓${NC} lib/generators.sh"
else
    echo -e "${RED}  ✗${NC} lib/generators.sh"
    template_files_ok=false
fi

if [ -f "lib/versions.conf" ]; then
    echo -e "${GREEN}  ✓${NC} lib/versions.conf"
else
    echo -e "${RED}  ✗${NC} lib/versions.conf"
    template_files_ok=false
fi

if [ "$template_files_ok" = true ]; then
    test_result "All template files exist" "pass"
else
    test_result "All template files exist" "fail"
fi

# Test 2: Check setup script exists and is executable
echo ""
echo "Testing setup script..."
if [ -f "setup-docker.sh" ] && [ -x "setup-docker.sh" ]; then
    test_result "setup-docker.sh is executable" "pass"
else
    test_result "setup-docker.sh is executable" "fail"
fi

# Test 3: Check switch-env script exists and is executable
if [ -f "switch-env.sh" ] && [ -x "switch-env.sh" ]; then
    test_result "switch-env.sh is executable" "pass"
else
    test_result "switch-env.sh is executable" "fail"
fi

# Test 4: Check .envs directory structure
echo ""
echo "Testing .envs directory..."
if [ -d ".envs" ]; then
    test_result ".envs directory exists" "pass"
else
    # In CI, .envs may not exist yet (created by setup-docker.sh)
    test_result ".envs directory exists" "skip"
fi

# Test 5: Check if generated files exist (if setup was run)
echo ""
echo "Testing generated files (if setup was run)..."

# Check if .env symlink exists (even if broken)
if [ -L ".env" ]; then
    # .env symlink exists, so we should check all files
    all_files_ok=true

    if [ -f "Dockerfile" ]; then
        echo -e "${GREEN}  ✓${NC} Dockerfile"
    else
        echo -e "${RED}  ✗${NC} Dockerfile"
        all_files_ok=false
    fi

    if [ -f "docker-compose.yml" ]; then
        echo -e "${GREEN}  ✓${NC} docker-compose.yml"
    else
        echo -e "${RED}  ✗${NC} docker-compose.yml"
        all_files_ok=false
    fi

    if [ -e ".env" ]; then
        echo -e "${GREEN}  ✓${NC} .env (valid symlink)"
    else
        echo -e "${RED}  ✗${NC} .env (broken symlink)"
        all_files_ok=false
    fi

    if [ -f ".devcontainer/devcontainer.json" ]; then
        echo -e "${GREEN}  ✓${NC} .devcontainer/devcontainer.json"
    else
        echo -e "${RED}  ✗${NC} .devcontainer/devcontainer.json"
        all_files_ok=false
    fi

    if [ -f ".devcontainer/docker-compose.yml" ]; then
        echo -e "${GREEN}  ✓${NC} .devcontainer/docker-compose.yml"
    else
        echo -e "${RED}  ✗${NC} .devcontainer/docker-compose.yml"
        all_files_ok=false
    fi

    if [ "$all_files_ok" = true ]; then
        test_result "All generated files exist" "pass"
        test_result ".env is a valid symlink" "pass"

        # Also check .envs contains the target file
        shopt -s nullglob
        env_files=(.envs/*.env)
        shopt -u nullglob

        if [ ${#env_files[@]} -gt 0 ]; then
            test_result ".envs contains environment files" "pass"
        else
            test_result ".envs contains environment files" "fail"
        fi
    else
        # Some files are missing or .env symlink is broken
        if [ -f "Dockerfile" ] && [ -f "docker-compose.yml" ]; then
            test_result "All generated files exist" "pass"
        else
            test_result "All generated files exist" "fail"
        fi

        if [ -e ".env" ]; then
            test_result ".env is a valid symlink" "pass"
        else
            test_result ".env is a valid symlink" "fail"
        fi

        # Check .envs anyway
        shopt -s nullglob
        env_files=(.envs/*.env)
        shopt -u nullglob

        if [ ${#env_files[@]} -gt 0 ]; then
            test_result ".envs contains environment files" "pass"
        else
            test_result ".envs contains environment files" "fail"
        fi
    fi
elif [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
    # Some generated files exist but .env doesn't
    echo -e "${RED}  ✗${NC} Incomplete setup detected"

    [ -f "Dockerfile" ] && echo -e "${GREEN}  ✓${NC} Dockerfile" || echo -e "${RED}  ✗${NC} Dockerfile"
    [ -f "docker-compose.yml" ] && echo -e "${GREEN}  ✓${NC} docker-compose.yml" || echo -e "${RED}  ✗${NC} docker-compose.yml"
    echo -e "${RED}  ✗${NC} .env"
    [ -f ".devcontainer/devcontainer.json" ] && echo -e "${GREEN}  ✓${NC} .devcontainer/devcontainer.json" || echo -e "${RED}  ✗${NC} .devcontainer/devcontainer.json"
    [ -f ".devcontainer/docker-compose.yml" ] && echo -e "${GREEN}  ✓${NC} .devcontainer/docker-compose.yml" || echo -e "${RED}  ✗${NC} .devcontainer/docker-compose.yml"

    test_result "All generated files exist" "fail"
    test_result ".env is a valid symlink" "fail"
else
    # No generated files at all - this is OK (setup not run yet)
    echo -e "${YELLOW}⊘${NC} Generated files do not exist (run setup-docker.sh first)"
fi

# Test 6: Check Docker prerequisites
echo ""
echo "Testing Docker prerequisites..."
if command -v docker >/dev/null 2>&1; then
    test_result "Docker is installed" "pass"
else
    test_result "Docker is installed" "fail"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    test_result "Docker Compose is available" "pass"
else
    test_result "Docker Compose is available" "fail"
fi

# Test 7: Validate template placeholders
echo ""
echo "Testing template placeholder consistency..."
placeholders_ok=true

# Define expected placeholders for each template
declare -A expected_placeholders=(
    ["Dockerfile.template"]="DOCKER_INSTALL AWS_CLI_INSTALL AWS_SAM_CLI_INSTALL GITHUB_CLI_INSTALL"
    ["docker-compose.yml.template"]="CONTAINER_SERVICE_NAME"
    [".devcontainer/devcontainer.json.template"]="CONTAINER_SERVICE_NAME USERNAME"
    [".devcontainer/docker-compose.yml.template"]="CONTAINER_SERVICE_NAME"
)

for template in "${!expected_placeholders[@]}"; do
    if [ -f "$template" ]; then
        for placeholder in ${expected_placeholders[$template]}; do
            if grep -q "{{$placeholder}}" "$template"; then
                echo -e "  ${GREEN}✓${NC} $template has {{$placeholder}}"
            else
                echo -e "  ${RED}✗${NC} $template missing {{$placeholder}}"
                placeholders_ok=false
            fi
        done
    fi
done

if [ "$placeholders_ok" = true ]; then
    test_result "Template placeholders are consistent" "pass"
else
    test_result "Template placeholders are consistent" "fail"
fi

# Test 8: Check for unreplaced placeholders in generated files
echo ""
echo "Testing for unreplaced placeholders in generated files..."
if [ -f "Dockerfile" ] && [ -f "docker-compose.yml" ]; then
    unreplaced_found=false

    if grep -q '{{.*}}' Dockerfile; then
        echo -e "  ${RED}✗${NC} Dockerfile contains unreplaced placeholders:"
        grep '{{.*}}' Dockerfile | sed 's/^/    /'
        unreplaced_found=true
    fi

    if grep -q '{{.*}}' docker-compose.yml; then
        echo -e "  ${RED}✗${NC} docker-compose.yml contains unreplaced placeholders:"
        grep '{{.*}}' docker-compose.yml | sed 's/^/    /'
        unreplaced_found=true
    fi

    if [ -f ".devcontainer/devcontainer.json" ] && grep -q '{{.*}}' .devcontainer/devcontainer.json; then
        echo -e "  ${RED}✗${NC} devcontainer.json contains unreplaced placeholders:"
        grep '{{.*}}' .devcontainer/devcontainer.json | sed 's/^/    /'
        unreplaced_found=true
    fi

    if [ "$unreplaced_found" = false ]; then
        test_result "No unreplaced placeholders in generated files" "pass"
    else
        test_result "No unreplaced placeholders in generated files" "fail"
    fi
else
    test_result "No unreplaced placeholders in generated files" "skip"
fi

# Test 9: Validate docker-compose.yml syntax
echo ""
echo "Testing docker-compose.yml syntax..."
if [ -f "docker-compose.yml" ]; then
    if docker compose -f docker-compose.yml config >/dev/null 2>&1; then
        test_result "docker-compose.yml syntax is valid" "pass"
    else
        echo -e "  ${RED}Error output:${NC}"
        docker compose -f docker-compose.yml config 2>&1 | sed 's/^/    /'
        test_result "docker-compose.yml syntax is valid" "fail"
    fi
else
    test_result "docker-compose.yml syntax is valid" "skip"
fi

# Test 10: Check shell script syntax
echo ""
echo "Testing shell script syntax..."
scripts_ok=true

for script in setup-docker.sh switch-env.sh test.sh lib/generators.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $script syntax is valid"
        else
            echo -e "  ${RED}✗${NC} $script has syntax errors:"
            bash -n "$script" 2>&1 | sed 's/^/    /'
            scripts_ok=false
        fi
    fi
done

# Also check lib/versions.conf exists
if [ -f "lib/versions.conf" ]; then
    echo -e "  ${GREEN}✓${NC} lib/versions.conf exists"
else
    echo -e "  ${RED}✗${NC} lib/versions.conf is missing"
    scripts_ok=false
fi

if [ "$scripts_ok" = true ]; then
    test_result "All shell scripts have valid syntax" "pass"
else
    test_result "All shell scripts have valid syntax" "fail"
fi

# Test 11: Validate environment file format
echo ""
echo "Testing environment file format..."
if [ -d ".envs" ]; then
    shopt -s nullglob
    env_files=(.envs/*.env)
    shopt -u nullglob

    if [ ${#env_files[@]} -gt 0 ]; then
        env_format_ok=true
        required_vars=("CONTAINER_SERVICE_NAME" "USERNAME" "UID" "GID" "DOCKER_GID")

        for env_file in "${env_files[@]}"; do
            echo -e "  ${CYAN}Checking${NC} $env_file"
            for var in "${required_vars[@]}"; do
                if grep -q "^${var}=" "$env_file"; then
                    echo -e "    ${GREEN}✓${NC} $var is defined"
                else
                    echo -e "    ${RED}✗${NC} $var is missing"
                    env_format_ok=false
                fi
            done

            # Check for tool installation variables (Docker CLI, AWS CLI, AWS SAM CLI, GitHub CLI)
            for var in "INSTALL_DOCKER" "INSTALL_AWS_CLI" "INSTALL_AWS_SAM_CLI" "INSTALL_GITHUB_CLI"; do
                if grep -q "^${var}=" "$env_file"; then
                    echo -e "    ${GREEN}✓${NC} $var is defined"
                else
                    echo -e "    ${RED}✗${NC} $var is missing"
                    env_format_ok=false
                fi
            done
        done

        if [ "$env_format_ok" = true ]; then
            test_result "Environment files have required variables" "pass"
        else
            test_result "Environment files have required variables" "fail"
        fi
    else
        test_result "Environment files have required variables" "skip"
    fi
else
    test_result "Environment files have required variables" "skip"
fi

# Test 12: Test generator library functions
echo ""
echo "Testing lib/generators.sh functions..."
if [ -f "lib/generators.sh" ]; then
    # Source the functions in a subshell to avoid side effects
    (
        # Source the generator library
        source lib/generators.sh

        # Test uv installation function
        if type generate_uv_install &>/dev/null; then
            output=$(generate_uv_install "uv")
            if echo "$output" | grep -q "uv (Python package manager"; then
                echo -e "  ${GREEN}✓${NC} generate_uv_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_uv_install output is unexpected"
                exit 1
            fi
        fi

        # Test volta installation function
        if type generate_volta_install &>/dev/null; then
            output=$(generate_volta_install "volta")
            if echo "$output" | grep -q "Volta (Node.js version manager)"; then
                echo -e "  ${GREEN}✓${NC} generate_volta_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_volta_install output is unexpected"
                exit 1
            fi
        fi

        # Test poetry installation function
        if type generate_poetry_install &>/dev/null; then
            output=$(generate_poetry_install "poetry")
            if echo "$output" | grep -q "Poetry (Python dependency management)"; then
                echo -e "  ${GREEN}✓${NC} generate_poetry_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_poetry_install output is unexpected"
                exit 1
            fi
        fi

        # Test nvm installation function
        if type generate_nvm_install &>/dev/null; then
            output=$(generate_nvm_install "nvm")
            if echo "$output" | grep -q "nvm (Node.js version manager"; then
                echo -e "  ${GREEN}✓${NC} generate_nvm_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_nvm_install output is unexpected"
                exit 1
            fi
        fi

        # Test python3 installation function
        if type generate_python3_install &>/dev/null; then
            output=$(generate_python3_install "poetry")
            if echo "$output" | grep -q "Install python3 for poetry"; then
                echo -e "  ${GREEN}✓${NC} generate_python3_install produces output for poetry"
            else
                echo -e "  ${RED}✗${NC} generate_python3_install output is unexpected"
                exit 1
            fi

            output=$(generate_python3_install "uv")
            if [ -z "$output" ]; then
                echo -e "  ${GREEN}✓${NC} generate_python3_install returns empty for uv"
            else
                echo -e "  ${RED}✗${NC} generate_python3_install should return empty for uv"
                exit 1
            fi
        fi

        # Test AWS CLI installation function
        if type generate_aws_cli_install &>/dev/null; then
            output=$(generate_aws_cli_install true)
            if echo "$output" | grep -q "AWS CLI"; then
                echo -e "  ${GREEN}✓${NC} generate_aws_cli_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_aws_cli_install output is unexpected"
                exit 1
            fi

            output=$(generate_aws_cli_install false)
            if [ -z "$output" ]; then
                echo -e "  ${GREEN}✓${NC} generate_aws_cli_install returns empty when disabled"
            else
                echo -e "  ${RED}✗${NC} generate_aws_cli_install should return empty when disabled"
                exit 1
            fi
        fi

        # Test AWS SAM CLI installation function
        if type generate_aws_sam_cli_install &>/dev/null; then
            output=$(generate_aws_sam_cli_install true)
            if echo "$output" | grep -q "AWS SAM CLI"; then
                echo -e "  ${GREEN}✓${NC} generate_aws_sam_cli_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_aws_sam_cli_install output is unexpected"
                exit 1
            fi
        fi

        # Test GitHub CLI installation function
        if type generate_github_cli_install &>/dev/null; then
            output=$(generate_github_cli_install true)
            if echo "$output" | grep -q "GitHub CLI"; then
                echo -e "  ${GREEN}✓${NC} generate_github_cli_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_github_cli_install output is unexpected"
                exit 1
            fi
        fi

        # Test Docker CLI installation function
        if type generate_docker_install &>/dev/null; then
            output=$(generate_docker_install true)
            if echo "$output" | grep -q "Docker CLI"; then
                echo -e "  ${GREEN}✓${NC} generate_docker_install produces expected output"
            else
                echo -e "  ${RED}✗${NC} generate_docker_install output is unexpected"
                exit 1
            fi
        fi

        # Test utility functions
        # Test read_env_var function
        if type read_env_var &>/dev/null; then
            # Create a temporary test env file
            test_env_file=$(mktemp)
            cat > "$test_env_file" << 'TESTENV'
SIMPLE_VAR=simple_value
QUOTED_VAR="quoted value"
EQUALS_VAR=value=with=equals
EMPTY_VAR=
TESTENV
            # Test simple value
            output=$(read_env_var "SIMPLE_VAR" "$test_env_file")
            if [ "$output" = "simple_value" ]; then
                echo -e "  ${GREEN}✓${NC} read_env_var handles simple values"
            else
                echo -e "  ${RED}✗${NC} read_env_var failed for simple value: got '$output'"
                rm -f "$test_env_file"
                exit 1
            fi

            # Test value with equals sign
            output=$(read_env_var "EQUALS_VAR" "$test_env_file")
            if [ "$output" = "value=with=equals" ]; then
                echo -e "  ${GREEN}✓${NC} read_env_var handles values with equals signs"
            else
                echo -e "  ${RED}✗${NC} read_env_var failed for equals value: got '$output'"
                rm -f "$test_env_file"
                exit 1
            fi

            rm -f "$test_env_file"
        fi

        # Test detect_docker_gid function
        if type detect_docker_gid &>/dev/null; then
            output=$(detect_docker_gid)
            if [[ "$output" =~ ^[0-9]+$ ]]; then
                echo -e "  ${GREEN}✓${NC} detect_docker_gid returns numeric GID: $output"
            else
                echo -e "  ${RED}✗${NC} detect_docker_gid failed to return numeric GID"
                exit 1
            fi
        fi

        # Test validate_symlink function
        if type validate_symlink &>/dev/null; then
            # Create a temporary test directory
            test_dir=$(mktemp -d)
            mkdir -p "$test_dir/target"
            echo "test" > "$test_dir/target/file.txt"
            ln -sf target/file.txt "$test_dir/valid_link"
            ln -sf nonexistent "$test_dir/broken_link"

            # Test valid symlink
            if validate_symlink "$test_dir/valid_link" "target/"; then
                echo -e "  ${GREEN}✓${NC} validate_symlink detects valid symlink"
            else
                echo -e "  ${RED}✗${NC} validate_symlink failed for valid symlink"
                rm -rf "$test_dir"
                exit 1
            fi

            # Test broken symlink
            if ! validate_symlink "$test_dir/broken_link" ""; then
                echo -e "  ${GREEN}✓${NC} validate_symlink detects broken symlink"
            else
                echo -e "  ${RED}✗${NC} validate_symlink failed to detect broken symlink"
                rm -rf "$test_dir"
                exit 1
            fi

            rm -rf "$test_dir"
        fi
    ) && test_result "Generator library functions work correctly" "pass" || test_result "Generator library functions work correctly" "fail"
else
    test_result "Package manager functions work correctly" "skip"
fi

# Test 12b: Test validator library functions
echo ""
echo "Testing lib/validators.sh functions..."
if [ -f "lib/validators.sh" ]; then
    (
        source lib/validators.sh

        # Test validate_service_name
        if type validate_service_name &>/dev/null; then
            if validate_service_name "my-service-123" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_service_name accepts valid names"
            else
                echo -e "  ${RED}✗${NC} validate_service_name rejected valid name"
                exit 1
            fi

            if ! validate_service_name "" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_service_name rejects empty names"
            else
                echo -e "  ${RED}✗${NC} validate_service_name accepted empty name"
                exit 1
            fi

            if ! validate_service_name "invalid name!" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_service_name rejects invalid characters"
            else
                echo -e "  ${RED}✗${NC} validate_service_name accepted invalid characters"
                exit 1
            fi
        fi

        # Test validate_username
        if type validate_username &>/dev/null; then
            if validate_username "testuser" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_username accepts valid usernames"
            else
                echo -e "  ${RED}✗${NC} validate_username rejected valid username"
                exit 1
            fi

            if ! validate_username "InvalidUser" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_username rejects uppercase letters"
            else
                echo -e "  ${RED}✗${NC} validate_username accepted uppercase letters"
                exit 1
            fi
        fi

        # Test validate_boolean
        if type validate_boolean &>/dev/null; then
            if validate_boolean "true" 2>/dev/null && validate_boolean "false" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_boolean accepts true/false"
            else
                echo -e "  ${RED}✗${NC} validate_boolean failed for true/false"
                exit 1
            fi

            if ! validate_boolean "yes" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_boolean rejects non-boolean values"
            else
                echo -e "  ${RED}✗${NC} validate_boolean accepted non-boolean value"
                exit 1
            fi
        fi

        # Test validate_package_manager
        if type validate_package_manager &>/dev/null; then
            if validate_package_manager "uv" "python" 2>/dev/null && \
               validate_package_manager "volta" "nodejs" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_package_manager accepts valid managers"
            else
                echo -e "  ${RED}✗${NC} validate_package_manager rejected valid managers"
                exit 1
            fi

            if ! validate_package_manager "invalid" "python" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} validate_package_manager rejects invalid managers"
            else
                echo -e "  ${RED}✗${NC} validate_package_manager accepted invalid manager"
                exit 1
            fi
        fi
    ) && test_result "Validator library functions work correctly" "pass" || test_result "Validator library functions work correctly" "fail"
else
    test_result "Validator library functions work correctly" "skip"
fi

# Test 12c: Test error handling library
echo ""
echo "Testing lib/errors.sh functions..."
if [ -f "lib/errors.sh" ]; then
    (
        source lib/errors.sh

        # Test error message functions exist
        if type error &>/dev/null && \
           type warn &>/dev/null && \
           type info &>/dev/null && \
           type success &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} All error handling functions are defined"
        else
            echo -e "  ${RED}✗${NC} Some error handling functions are missing"
            exit 1
        fi

        # Test error output (capture stderr)
        output=$(error "test message" 2>&1)
        if echo "$output" | grep -q "ERROR:"; then
            echo -e "  ${GREEN}✓${NC} error function formats messages correctly"
        else
            echo -e "  ${RED}✗${NC} error function output is unexpected"
            exit 1
        fi
    ) && test_result "Error handling library functions work correctly" "pass" || test_result "Error handling library functions work correctly" "fail"
else
    test_result "Error handling library functions work correctly" "skip"
fi

# Test 13: Check volume mount points in Dockerfile
echo ""
echo "Testing volume mount directories in Dockerfile..."
if [ -f "Dockerfile" ] && [ -f ".env" ]; then
    # Note: These are literal strings to match Dockerfile content, not paths for expansion
    expected_volumes=(
        # proto
        "~/.proto"
        # AWS
        "~/.aws"
        # GitHub CLI
        "~/.config/gh"
        # Rust
        "~/.cargo"
        "~/.rustup"
        # Deno
        "~/.deno"
        # Bun
        "~/.bun"
        # Go
        "~/go"
        # .local (includes bash history in ~/.local/state)
        "~/.local"
    )

    volumes_ok=true
    # Check if volume path exists in Dockerfile (handles multiline mkdir -p)
    for vol in "${expected_volumes[@]}"; do
        # Escape special characters for grep and check if path appears in file
        escaped_vol=$(echo "$vol" | sed 's/[.]/\\./g; s|/|\\/|g')
        # Match path followed by whitespace, backslash, or end of line
        if grep -E "${escaped_vol}(\s|\\\\|$)" Dockerfile >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Volume mount point for $vol"
        else
            echo -e "  ${RED}✗${NC} Volume mount point for $vol is missing"
            volumes_ok=false
        fi
    done

    if [ "$volumes_ok" = true ]; then
        test_result "Volume mount points are created in Dockerfile" "pass"
    else
        test_result "Volume mount points are created in Dockerfile" "fail"
    fi
else
    test_result "Volume mount points are created in Dockerfile" "skip"
fi

# Test 14: Check volume mounts in docker-compose.yml
echo ""
echo "Testing volume mounts in docker-compose.yml..."
if [ -f "docker-compose.yml" ]; then
    # Expected named volumes in docker-compose.yml
    expected_named_volumes=(
        "proto"
        "aws"
        "gh-config"
        "cargo"
        "rustup"
        "deno"
        "bun"
        "go"
        "local"
    )

    compose_volumes_ok=true
    for vol in "${expected_named_volumes[@]}"; do
        # Check in volumes: section (top-level definition)
        if grep -q "^  ${vol}:" docker-compose.yml; then
            echo -e "  ${GREEN}✓${NC} Named volume '$vol' is defined"
        else
            echo -e "  ${RED}✗${NC} Named volume '$vol' is missing from volumes section"
            compose_volumes_ok=false
        fi
    done

    if [ "$compose_volumes_ok" = true ]; then
        test_result "All named volumes are defined in docker-compose.yml" "pass"
    else
        test_result "All named volumes are defined in docker-compose.yml" "fail"
    fi

    # Test volume name scoping (HIGH-5 fix)
    echo ""
    echo "Testing volume name scoping..."
    if [ -f ".env" ]; then
        CONTAINER_SERVICE_NAME=$(grep '^CONTAINER_SERVICE_NAME=' .env | cut -d'=' -f2-)
        scoped_volumes_ok=true
        for volume in "${expected_named_volumes[@]}"; do
            volume_name=$(echo "$volume" | tr '-' '_')
            if grep -q "name: \"\${CONTAINER_SERVICE_NAME}_$volume_name\"" docker-compose.yml; then
                echo -e "  ${GREEN}✓${NC} Volume '$volume' has service name prefix"
            else
                echo -e "  ${RED}✗${NC} Volume '$volume' missing service name prefix"
                scoped_volumes_ok=false
            fi
        done

        if [ "$scoped_volumes_ok" = true ]; then
            test_result "Volumes are scoped with service name prefix" "pass"
        else
            test_result "Volumes are scoped with service name prefix" "fail"
        fi
    else
        test_result "Volumes are scoped with service name prefix" "skip"
    fi
else
    test_result "All named volumes are defined in docker-compose.yml" "skip"
fi

# Test 15: Validate template file existence
echo ""
echo "Testing template file existence..."
if [ -f "docker-compose.yml.template" ] && [ -f "Dockerfile.template" ]; then
    # Check that required templates exist
    template_ok=true
    for template in "docker-compose.yml.template" "Dockerfile.template" ".devcontainer/devcontainer.json.template" ".devcontainer/docker-compose.yml.template"; do
        if [ -f "$template" ]; then
            echo -e "  ${GREEN}✓${NC} $template exists"
        else
            echo -e "  ${RED}✗${NC} $template is missing"
            template_ok=false
        fi
    done

    if [ "$template_ok" = true ]; then
        test_result "All required template files exist" "pass"
    else
        test_result "All required template files exist" "fail"
    fi
else
    test_result "All required template files exist" "skip"
fi

# Test 16: Validate .gitignore patterns
echo ""
echo "Testing .gitignore coverage..."
if [ -f ".gitignore" ]; then
    critical_patterns=("Dockerfile" "docker-compose.yml" ".env" ".envs/")
    gitignore_ok=true

    for pattern in "${critical_patterns[@]}"; do
        if grep -q "^${pattern}$" .gitignore || grep -q "^/${pattern}$" .gitignore; then
            echo -e "  ${GREEN}✓${NC} $pattern is in .gitignore"
        else
            echo -e "  ${RED}✗${NC} $pattern is missing from .gitignore"
            gitignore_ok=false
        fi
    done

    if [ "$gitignore_ok" = true ]; then
        test_result ".gitignore has critical patterns" "pass"
    else
        test_result ".gitignore has critical patterns" "fail"
    fi
else
    test_result ".gitignore has critical patterns" "skip"
fi

# Summary
echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
