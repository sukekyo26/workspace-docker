#!/bin/bash
# ============================================================
# tests/unit/lib/test_workspace.sh
# Unit tests for lib/workspace.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# shellcheck source=../../../lib/workspace.sh
source "$PROJECT_ROOT/lib/workspace.sh"

echo ""
echo "[ test_workspace.sh ]"

# ============================================================
# Test: is_folder_only_dir
# ============================================================
test_is_folder_only_dir() {
  section "is_folder_only_dir"

  local tmpdir
  tmpdir=$(mktemp -d)

  # Directory with only subdirs → true
  mkdir -p "$tmpdir/only-dirs/sub1" "$tmpdir/only-dirs/sub2"
  assert_true "dir with only subdirs" is_folder_only_dir "$tmpdir/only-dirs"

  # Directory with files → false
  mkdir -p "$tmpdir/has-files"
  touch "$tmpdir/has-files/file.txt"
  assert_false "dir with files returns false" is_folder_only_dir "$tmpdir/has-files"

  # Empty directory → true (no files)
  mkdir -p "$tmpdir/empty"
  assert_true "empty dir" is_folder_only_dir "$tmpdir/empty"

  # Hidden files should be ignored
  mkdir -p "$tmpdir/hidden-only"
  touch "$tmpdir/hidden-only/.hidden"
  assert_true "dir with only hidden files" is_folder_only_dir "$tmpdir/hidden-only"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: get_available_dirs
# ============================================================
test_get_available_dirs() {
  section "get_available_dirs"

  local tmpdir
  tmpdir=$(mktemp -d)

  # Create test structure
  mkdir -p "$tmpdir/project-a"
  touch "$tmpdir/project-a/file.txt"
  mkdir -p "$tmpdir/project-b"
  touch "$tmpdir/project-b/file.txt"
  mkdir -p "$tmpdir/.hidden-dir"

  local dirs
  dirs=$(get_available_dirs "$tmpdir")

  assert_file_contains "lists project-a" <(echo "$dirs") "project-a"
  assert_file_contains "lists project-b" <(echo "$dirs") "project-b"
  assert_file_not_contains "excludes hidden dirs" <(echo "$dirs") ".hidden-dir"

  # Test subdirectory expansion for folder-only dirs
  mkdir -p "$tmpdir/group/repo1" "$tmpdir/group/repo2"
  dirs=$(get_available_dirs "$tmpdir")
  assert_file_contains "expands group/repo1" <(echo "$dirs") "group/repo1"
  assert_file_contains "expands group/repo2" <(echo "$dirs") "group/repo2"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: get_workspace_files
# ============================================================
test_get_workspace_files() {
  section "get_workspace_files"

  local tmpdir
  tmpdir=$(mktemp -d)

  # No files
  local result
  result=$(get_workspace_files "$tmpdir")
  assert_eq "empty when no files" "" "$result"

  # With workspace files
  touch "$tmpdir/test.code-workspace"
  touch "$tmpdir/other.code-workspace"
  touch "$tmpdir/not-workspace.txt"

  result=$(get_workspace_files "$tmpdir")
  assert_file_contains "lists test.code-workspace" <(echo "$result") "test.code-workspace"
  assert_file_contains "lists other.code-workspace" <(echo "$result") "other.code-workspace"
  assert_file_not_contains "excludes non-workspace" <(echo "$result") "not-workspace.txt"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: get_current_folders
# ============================================================
test_get_current_folders() {
  section "get_current_folders"

  local tmpdir
  tmpdir=$(mktemp -d)

  cat > "$tmpdir/test.code-workspace" << 'JSON'
{
  "folders": [
    {
      "name": "project-a",
      "path": "../../project-a"
    },
    {
      "name": "project-b",
      "path": "../../project-b"
    }
  ]
}
JSON

  local result
  result=$(get_current_folders "$tmpdir/test.code-workspace")
  assert_file_contains "extracts project-a" <(echo "$result") "project-a"
  assert_file_contains "extracts project-b" <(echo "$result") "project-b"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: generate_workspace_file
# ============================================================
test_generate_workspace_file() {
  section "generate_workspace_file"

  local tmpdir
  tmpdir=$(mktemp -d)

  # Create minimal settings
  echo '{ "editor.tabSize": 2 }' > "$tmpdir/settings.json"

  generate_workspace_file "$tmpdir/output.code-workspace" "$tmpdir/settings.json" "project-a" "project-b"

  assert_true "output file created" test -f "$tmpdir/output.code-workspace"

  local content
  content=$(cat "$tmpdir/output.code-workspace")

  assert_file_contains "has folders key" <(echo "$content") '"folders"'
  assert_file_contains "has project-a name" <(echo "$content") '"name": "project-a"'
  assert_file_contains "has project-a path" <(echo "$content") '"path": "../../project-a"'
  assert_file_contains "has project-b name" <(echo "$content") '"name": "project-b"'
  assert_file_contains "has settings" <(echo "$content") '"settings"'
  assert_file_contains "has tabSize" <(echo "$content") '"editor.tabSize"'

  # Valid JSON check
  assert_true "output is valid JSON" uv run --project "$PROJECT_ROOT" python -c "import json; json.load(open('$tmpdir/output.code-workspace'))"

  # Single folder (no trailing comma)
  generate_workspace_file "$tmpdir/single.code-workspace" "$tmpdir/settings.json" "solo-project"
  assert_true "single folder is valid JSON" uv run --project "$PROJECT_ROOT" python -c "import json; json.load(open('$tmpdir/single.code-workspace'))"

  # Folder name with JSON special characters (quotes, backslash)
  mkdir -p "$tmpdir/special"
  generate_workspace_file "$tmpdir/special.code-workspace" "$tmpdir/settings.json" 'has"quote' 'has\backslash'
  assert_true "special chars produce valid JSON" uv run --project "$PROJECT_ROOT" python -c "import json; json.load(open('$tmpdir/special.code-workspace'))"
  assert_file_contains "escaped quote in name" <(cat "$tmpdir/special.code-workspace") 'has\"quote'
  assert_file_contains "escaped backslash in name" <(cat "$tmpdir/special.code-workspace") 'has\\backslash'

  rm -rf "$tmpdir"
}

# ============================================================
# Run
# ============================================================

test_is_folder_only_dir
test_get_available_dirs
test_get_workspace_files
test_get_current_folders
test_generate_workspace_file

print_summary
