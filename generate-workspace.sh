#!/bin/bash

# ============================================================
# generate-workspace.sh - .code-workspace file generator
# ============================================================
# Interactively select folders to include in a workspace and
# create or update a .code-workspace file in workspaces/.
#
# Controls (single select):
#   Up/Down   Move cursor
#   Enter     Confirm
#
# Controls (multi select):
#   Up/Down   Move cursor
#   Enter     Toggle selection
#   a         Select/deselect all
#   d         Done
#
# Usage: ./generate-workspace.sh
# ============================================================

# set -e is not used because it causes issues with arithmetic exit codes and subshells
set -uo pipefail

# ===== Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="$SCRIPT_DIR/workspaces"

# ===== Colors =====
# shellcheck source=lib/colors.sh
source "$SCRIPT_DIR/lib/colors.sh"

# ===== TUI Components =====
# shellcheck source=lib/tui.sh
source "$SCRIPT_DIR/lib/tui.sh"

# ===== Business Logic =====
# shellcheck source=lib/workspace.sh
source "$SCRIPT_DIR/lib/workspace.sh"

# Restore cursor
cleanup() {
  tui_cleanup
}
trap cleanup EXIT

# ============================================================
# Business Logic Functions (TUI-dependent)
# ============================================================
# Pure business logic is in lib/workspace.sh
# Below are TUI-dependent orchestration functions

# Interactive folder selection
# Args: $1 = workspace file path to update (optional)
# Result: SELECTED_FOLDERS array populated with selected folder names
SELECTED_FOLDERS=()
interactive_select_folders() {
  local current_file="${1:-}"

  # Available folders
  local dirs=()
  while IFS= read -r dir; do
    [[ -n "$dir" ]] && dirs+=("$dir")
  done < <(get_available_dirs "$PARENT_DIR")

  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR:${NC} No folders found in parent directory" >&2
    exit 1
  fi

  # When updating: build initial selection from current folder structure
  local preselected=""
  if [[ -n "$current_file" && -f "$current_file" ]]; then
    local current_folders=()
    while IFS= read -r folder; do
      [[ -n "$folder" ]] && current_folders+=("$folder")
    done < <(get_current_folders "$current_file")

    local indices=()
    local i cf
    for i in "${!dirs[@]}"; do
      for cf in "${current_folders[@]}"; do
        if [[ "${dirs[$i]}" == "$cf" ]]; then
          indices+=("$i")
          break
        fi
      done
    done
    if [[ ${#indices[@]} -gt 0 ]]; then
      local IFS=','
      preselected="${indices[*]}"
    fi
  fi

  # Run TUI multi-select (result stored in TUI_MULTI_RESULT)
  select_multi "${BOLD}Select folders to include in workspace:${NC}" "$preselected" "${dirs[@]}" || {
    echo "Cancelled" >&2
    exit 0
  }

  if [[ ${#TUI_MULTI_RESULT[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR:${NC} No folders selected" >&2
    exit 1
  fi

  # Store selected folder names in array
  SELECTED_FOLDERS=()
  local idx
  for idx in "${TUI_MULTI_RESULT[@]}"; do
    SELECTED_FOLDERS+=("${dirs[$idx]}")
  done
}

# Generate workspace file (TUI output wrapper)
_generate_workspace_file_with_output() {
  local output_file="$1"
  shift
  local folders=("$@")
  local settings_file="$SCRIPT_DIR/config/workspace-settings.json"
  if [[ ! -f "$settings_file" ]]; then
    settings_file="$SCRIPT_DIR/config/workspace-settings.json.example"
  fi

  generate_workspace_file "$output_file" "$settings_file" "${folders[@]}"

  echo "" >&2
  echo -e "${GREEN}✅ Workspace file generated:${NC}" >&2
  echo -e "   ${BOLD}workspaces/$(basename "$output_file")${NC}" >&2
  echo "" >&2
  echo "Included projects:" >&2
  for folder in "${folders[@]}"; do
    echo "  - $folder" >&2
  done
}

# Filename input (loop on empty input)
create_new_workspace() {
  local selected_folders=("$@")
  local filename=""

  while true; do
    echo "" >&2
    read -rp "Enter filename (.code-workspace is appended automatically): " filename
    filename=$(echo "$filename" | xargs)
    if [[ -n "$filename" ]]; then
      break
    fi
    echo -e "${YELLOW}⚠ Please enter a filename${NC}" >&2
  done

  filename="${filename%.code-workspace}"
  local output_path="$WORKSPACES_DIR/${filename}.code-workspace"

  if [[ -f "$output_path" ]]; then
    echo -e "${YELLOW}⚠ ${filename}.code-workspace already exists. Overwrite?${NC}" >&2
    read -rp "[y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Cancelled" >&2
      exit 0
    fi
  fi

  _generate_workspace_file_with_output "$output_path" "${selected_folders[@]}"
}

# ============================================================
# Main
# ============================================================

main() {
  # Ensure workspaces directory exists
  if [[ ! -d "$WORKSPACES_DIR" ]]; then
    mkdir -p "$WORKSPACES_DIR"
  fi

  echo "" >&2
  echo -e "${BOLD}========================================" >&2
  echo " .code-workspace File Generator" >&2
  echo -e "========================================${NC}" >&2
  echo "" >&2
  echo -e "Scan target:    ${BOLD}${PARENT_DIR}${NC}" >&2
  echo -e "Output dir:     ${BOLD}workspaces/${NC}" >&2
  echo "" >&2

  # Search for existing .code-workspace files
  local workspace_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && workspace_files+=("$file")
  done < <(get_workspace_files "$WORKSPACES_DIR")

  if [[ ${#workspace_files[@]} -gt 0 ]]; then
    # ===== Existing files found =====
    echo -e "${CYAN}Existing workspace files:${NC}" >&2
    local f
    for f in "${workspace_files[@]}"; do
      echo "  - $f" >&2
    done
    echo "" >&2

    # Select update / create new
    select_single "${BOLD}Select action:${NC}" "Update existing file" "Create new"
    local action_idx="$TUI_SINGLE_RESULT"

    case "$action_idx" in
      0)
        # === Update existing file ===
        echo "" >&2
        select_single "${BOLD}Select file to update:${NC}" "${workspace_files[@]}"
        local file_idx="$TUI_SINGLE_RESULT"

        local target_file="${workspace_files[$file_idx]}"
        local output_path="$WORKSPACES_DIR/$target_file"

        echo "" >&2
        interactive_select_folders "$output_path"
        _generate_workspace_file_with_output "$output_path" "${SELECTED_FOLDERS[@]}"
        ;;
      1)
        # === Create new ===
        echo "" >&2
        interactive_select_folders
        create_new_workspace "${SELECTED_FOLDERS[@]}"
        ;;
    esac
  else
    # ===== No existing files — create new =====
    echo "No workspace files found. Creating new one." >&2
    echo "" >&2

    interactive_select_folders
    create_new_workspace "${SELECTED_FOLDERS[@]}"
  fi
}

main
