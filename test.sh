#!/bin/bash
# Wrapper script for backward compatibility.
# All tests are now in tests/. Run tests/run_all.sh directly or via this wrapper.
exec "$(dirname "$0")/tests/run_all.sh"
