#!/bin/bash
# Error handling and logging functions
# This library provides consistent error messages and logging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log levels (exported for external use)
export LOG_LEVEL_ERROR=0
export LOG_LEVEL_WARN=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3

# Default log level
CURRENT_LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Format and print error message
# Usage: error "message"
error() {
    echo -e "${RED}ERROR:${NC} $*" >&2
}

# Format and print warning message
# Usage: warn "message"
warn() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_WARN ]]; then
        echo -e "${YELLOW}WARNING:${NC} $*" >&2
    fi
}

# Format and print info message
# Usage: info "message"
info() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        echo -e "${CYAN}INFO:${NC} $*"
    fi
}

# Format and print success message
# Usage: success "message"
success() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        echo -e "${GREEN}✓${NC} $*"
    fi
}

# Format and print debug message
# Usage: debug "message"
debug() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]]; then
        echo -e "${CYAN}DEBUG:${NC} $*" >&2
    fi
}

# Die with error message
# Usage: die "message"
die() {
    error "$*"
    exit 1
}

# Error with hint
# Usage: error_with_hint "error message" "hint message"
error_with_hint() {
    local error_msg="$1"
    local hint_msg="$2"

    error "$error_msg"
    if [[ -n "$hint_msg" ]]; then
        echo -e "${YELLOW}HINT:${NC} $hint_msg" >&2
    fi
}

# Die with error message and hint
# Usage: die_with_hint "error message" "hint message"
die_with_hint() {
    error_with_hint "$1" "$2"
    exit 1
}

# Print section header
# Usage: section_header "Section Title"
section_header() {
    echo ""
    echo -e "${CYAN}=== $* ===${NC}"
}

# Print subsection header
# Usage: subsection_header "Subsection Title"
subsection_header() {
    echo ""
    echo -e "${GREEN}--- $* ---${NC}"
}

# Confirm action with user
# Usage: confirm "Do you want to continue?" && action
confirm() {
    local prompt="$1"
    local response

    read -rp "$prompt [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
