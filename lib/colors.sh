#!/bin/bash
# ============================================================
# lib/colors.sh - Shared color constants for terminal output
# ============================================================
# Sourced by other scripts; variables are used externally.
# Supports NO_COLOR (https://no-color.org/): when set, all
# color variables are empty strings.
# shellcheck disable=SC2034

if [[ -n "${NO_COLOR:-}" ]]; then
  RED=''
  GREEN=''
  CYAN=''
  YELLOW=''
  BOLD=''
  DIM=''
  NC=''
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
fi
