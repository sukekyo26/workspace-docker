#!/bin/bash
# ============================================================
# tests/run_coverage.sh - Python code coverage measurement
# ============================================================
# Usage: ./tests/run_coverage.sh [--html]
#
#   --html  Generate HTML report in htmlcov/
#
# Measures coverage for lib/*.py using pytest test suite.
# ============================================================

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"

cd "$PROJECT_ROOT"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Python Code Coverage                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Run pytest with coverage
uv run coverage run -m pytest tests/python/ -q

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Coverage Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

uv run coverage report

if [[ "${1:-}" == "--html" ]]; then
  uv run coverage html
  echo ""
  echo "HTML report: $PROJECT_ROOT/htmlcov/index.html"
fi
