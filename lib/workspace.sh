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

# ディレクトリが直下にファイルを含まずフォルダのみかを判定
# Usage: is_folder_only_dir <dir>
is_folder_only_dir() {
  local dir="$1"
  local file_count
  file_count=$(find "$dir" -mindepth 1 -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)
  [[ "$file_count" -eq 0 ]]
}

# 親ディレクトリ配下のフォルダ一覧を取得（隠しフォルダ除く）
# フォルダのみを含むディレクトリは配下のサブディレクトリも展開する
# Usage: get_available_dirs <parent_dir>
# 出力: parent_dir からの相対パス（例: workspace-docker, groupA/repo1）
get_available_dirs() {
  local parent_dir="$1"
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    local full_path="$parent_dir/$dir"
    echo "$dir"

    # フォルダのみを含むディレクトリはサブディレクトリも展開
    if is_folder_only_dir "$full_path"; then
      while IFS= read -r subdir; do
        [[ -z "$subdir" ]] && continue
        echo "$dir/$subdir"
      done < <(find "$full_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)
    fi
  done < <(find "$parent_dir" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)
}

# 既存の .code-workspace ファイル一覧を取得
# Usage: get_workspace_files <workspaces_dir>
get_workspace_files() {
  local workspaces_dir="$1"
  find "$workspaces_dir" -maxdepth 1 -name "*.code-workspace" -printf '%f\n' 2>/dev/null | sort
}

# ワークスペースファイルから現在のフォルダ一覧を取得（path から ../../ を除去）
# Usage: get_current_folders <workspace_file>
get_current_folders() {
  local file="$1"
  grep '"path":' "$file" | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/' | sed 's|^\.\./\.\./||'
}

# ワークスペースファイル生成
# Usage: generate_workspace_file <output_file> <settings_file> <folder1> [folder2 ...]
generate_workspace_file() {
  local output_file="$1"
  local settings_file="$2"
  shift 2
  local folders=("$@")

  {
    printf '{\n'
    printf '\t"folders": [\n'

    local i=0
    local count=${#folders[@]}
    local folder
    for folder in "${folders[@]}"; do
      i=$((i + 1))
      local comma=""
      if [[ "$i" -lt "$count" ]]; then
        comma=","
      fi
      local name
      name=$(basename "$folder")
      printf '\t\t{\n'
      printf '\t\t\t"name": "%s",\n' "$name"
      printf '\t\t\t"path": "../../%s"\n' "$folder"
      printf '\t\t}%s\n' "$comma"
    done

    printf '\t],\n'
    printf '\t"settings": '
    sed '1!s/^/\t/' "$settings_file"
    printf '}\n'
  } > "$output_file"
}
