#!/bin/bash
# ============================================================
# lib/workspace.sh - Business logic for generate-workspace.sh
# ============================================================
# Testable functions for .code-workspace file generation.
# Separated from TUI interaction for unit testing.
#
# Functions:
#   is_folder_only_dir     Check if directory contains only subdirectories
#   get_available_dirs     List candidate folders for workspace
#   get_workspace_files    List existing .code-workspace files
#   get_current_folders    Extract folder list from workspace file
#   generate_workspace_file  Generate .code-workspace JSON file
# ============================================================
set -uo pipefail

# Check if a directory contains only subdirectories (no files)
# Usage: is_folder_only_dir <dir>
is_folder_only_dir() {
  local dir="$1"
  local file_count
  file_count=$(find "$dir" -mindepth 1 -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)
  [[ "$file_count" -eq 0 ]]
}

# List folders under parent directory (excluding hidden folders)
# Directories containing only subdirectories are expanded
# Usage: get_available_dirs <parent_dir>
# Output: relative paths from parent_dir (e.g. workspace-docker, groupA/repo1)
get_available_dirs() {
  local parent_dir="$1"
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    local full_path="$parent_dir/$dir"
    echo "$dir"

    # Expand subdirectories for folder-only directories
    if is_folder_only_dir "$full_path"; then
      while IFS= read -r subdir; do
        [[ -z "$subdir" ]] && continue
        echo "$dir/$subdir"
      done < <(find "$full_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)
    fi
  done < <(find "$parent_dir" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)
}

# List existing .code-workspace files
# Usage: get_workspace_files <workspaces_dir>
get_workspace_files() {
  local workspaces_dir="$1"
  find "$workspaces_dir" -maxdepth 1 -name "*.code-workspace" -printf '%f\n' 2>/dev/null | sort
}

# Extract current folder list from workspace file (strip ../../ from path)
# Usage: get_current_folders <workspace_file>
get_current_folders() {
  local file="$1"
  grep '"path":' "$file" | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/' | sed 's|^\.\./\.\./||'
}

# Generate workspace file
# Usage: generate_workspace_file <output_file> <settings_file> <folder1> [folder2 ...]
generate_workspace_file() {
  local output_file="$1"
  local settings_file="$2"
  shift 2
  local folders=("$@")

  local folders_json
  folders_json=$(printf '%s\n' "${folders[@]}" | jq -R '{
    name: (split("/") | last),
    path: ("../../" + .)
  }' | jq -s '.')

  jq -n --tab \
    --argjson folders "$folders_json" \
    --slurpfile settings "$settings_file" \
    '{folders: $folders, settings: $settings[0]}' > "$output_file"
}
