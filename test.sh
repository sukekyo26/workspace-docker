#!/bin/bash
# Test script for workspace-docker project

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"

    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++)) || true
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
    test_result ".envs directory exists" "fail"
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

# Summary
echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
