#!/bin/bash
# ============================================================
# tests/python/test_python.sh
# Wrapper to run Python tests (pytest + mypy + ruff) from bash test runner
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_python.sh ]"

# ============================================================
# Test: ruff lint
# ============================================================
test_ruff() {
    section "ruff lint"

    if ! command -v ruff &>/dev/null; then
        skip_test "ruff check" "ruff not installed"
        return
    fi

    if ruff check "$PROJECT_ROOT/lib/"*.py 2>/dev/null; then
        assert_true "ruff check lib/*.py" true
    else
        assert_true "ruff check lib/*.py" false
    fi
}

# ============================================================
# Test: mypy type check
# ============================================================
test_mypy() {
    section "mypy type check"

    if ! command -v mypy &>/dev/null; then
        skip_test "mypy check" "mypy not installed"
        return
    fi

    if mypy "$PROJECT_ROOT/lib/"*.py 2>/dev/null; then
        assert_true "mypy lib/*.py" true
    else
        assert_true "mypy lib/*.py" false
    fi
}

# ============================================================
# Test: pyright type check
# ============================================================
test_pyright() {
    section "pyright type check"

    if ! command -v pyright &>/dev/null; then
        skip_test "pyright check" "pyright not installed"
        return
    fi

    if pyright "$PROJECT_ROOT/lib/"*.py 2>/dev/null; then
        assert_true "pyright lib/*.py" true
    else
        assert_true "pyright lib/*.py" false
    fi
}

# ============================================================
# Test: pytest
# ============================================================
test_pytest() {
    section "pytest"

    if ! command -v pytest &>/dev/null; then
        skip_test "pytest" "pytest not installed"
        return
    fi

    local output
    if output=$(pytest "$TESTS_DIR/python/" -q 2>&1); then
        local count
        count=$(echo "$output" | grep -oP '^\d+(?= passed)' || echo "0")
        assert_true "pytest ($count tests passed)" true
    else
        echo "$output" | tail -10
        assert_true "pytest" false
    fi
}

# ============================================================
# Run
# ============================================================

test_ruff
test_mypy
test_pyright
test_pytest

print_summary
