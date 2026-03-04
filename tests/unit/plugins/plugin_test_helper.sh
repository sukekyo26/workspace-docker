#!/bin/bash
# ============================================================
# tests/unit/plugins/plugin_test_helper.sh
# Shared helper for per-plugin unit tests
# ============================================================
# Source this file at the top of each plugin test script.
# Provides: test_helper.sh assertions + lib/errors.sh + lib/generators.sh
# ============================================================

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

# Source libraries needed for plugin tests
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/generators.sh"
