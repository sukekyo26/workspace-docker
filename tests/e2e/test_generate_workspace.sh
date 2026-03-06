#!/bin/bash
# ============================================================
# tests/test_generate_workspace.sh
# Tests for generate-workspace.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_generate_workspace.sh ]"

# ============================================================
# Test: set -e safety (root cause of previous TUI bugs)
# ============================================================
test_set_e_safety() {
  section "set -e safety"

  local cursor=0
  [[ "$cursor" -gt 0 ]] && cursor=$((cursor - 1))
  assert_eq "cursor=0, -gt 0 => no change" "0" "$cursor"

  cursor=0
  [[ "$cursor" -lt 4 ]] && cursor=$((cursor + 1))
  assert_eq "cursor=0, -lt 4 => increment" "1" "$cursor"

  cursor=4
  [[ "$cursor" -lt 4 ]] && cursor=$((cursor + 1))
  assert_eq "cursor=4, -lt 4 => no change" "4" "$cursor"

  # Subshell + set -e safety with [[ ]]
  local result
  result=$(
    set -euo pipefail
    local c=0
    [[ "$c" -gt 0 ]] && c=$((c - 1))
    echo "$c"
  )
  assert_eq "subshell+set -e: [[ 0 -gt 0 ]] survives" "0" "$result"

  result=$(
    set -euo pipefail
    local c=3
    local max=3
    [[ "$c" -lt $((max - 1)) ]] && c=$((c + 1))
    echo "$c"
  )
  assert_eq "subshell+set -e: [[ 3 -lt 2 ]] survives" "3" "$result"
}

# ============================================================
# Test: Key parsing logic
# ============================================================
test_key_parsing() {
  section "Key parsing logic"

  local result_key

  # UP arrow: ESC [ A
  local seq1="[" seq2="A"
  case "${seq1}${seq2}" in
    "[A") result_key="UP" ;;
    "[B") result_key="DOWN" ;;
    *)    result_key="IGNORE" ;;
  esac
  assert_eq "ESC[A => UP" "UP" "$result_key"

  # DOWN arrow: ESC [ B
  seq1="["; seq2="B"
  case "${seq1}${seq2}" in
    "[A") result_key="UP" ;;
    "[B") result_key="DOWN" ;;
    *)    result_key="IGNORE" ;;
  esac
  assert_eq "ESC[B => DOWN" "DOWN" "$result_key"

  # Enter
  local key=""
  [[ "$key" == "" ]] && result_key="ENTER"
  assert_eq "empty => ENTER" "ENTER" "$result_key"

  # Space => ENTER
  key=" "
  [[ "$key" == " " ]] && result_key="ENTER"
  assert_eq "space => ENTER" "ENTER" "$result_key"

  # 'a' => TOGGLE_ALL
  key="a"
  [[ "$key" == "a" || "$key" == "A" ]] && result_key="TOGGLE_ALL"
  assert_eq "'a' => TOGGLE_ALL" "TOGGLE_ALL" "$result_key"

  # 'd' => DONE
  key="d"
  [[ "$key" == "d" || "$key" == "D" ]] && result_key="DONE"
  assert_eq "'d' => DONE" "DONE" "$result_key"
}

# ============================================================
# Test: TUI cursor movement logic
# ============================================================
test_tui_cursor_logic() {
  section "TUI cursor movement"

  local cursor count

  cursor=0; count=5
  [[ "$cursor" -gt 0 ]] && cursor=$((cursor - 1))
  assert_eq "cursor=0 UP => stays 0" "0" "$cursor"

  cursor=4; count=5
  [[ "$cursor" -lt $((count - 1)) ]] && cursor=$((cursor + 1))
  assert_eq "cursor=max DOWN => stays max" "4" "$cursor"

  cursor=3; count=5
  [[ "$cursor" -gt 0 ]] && cursor=$((cursor - 1))
  assert_eq "cursor=3 UP => 2" "2" "$cursor"

  cursor=2; count=5
  [[ "$cursor" -lt $((count - 1)) ]] && cursor=$((cursor + 1))
  assert_eq "cursor=2 DOWN => 3" "3" "$cursor"
}

# ============================================================
# Test: Toggle / select-all logic
# ============================================================
test_toggle_logic() {
  section "Toggle & select-all logic"

  local sel=("0" "0" "1" "0")
  local cursor=1

  # Toggle on
  if [[ "${sel[cursor]}" == "1" ]]; then sel[cursor]="0"; else sel[cursor]="1"; fi
  assert_eq "toggle cursor=1 ON" "1" "${sel[1]}"

  # Toggle off
  if [[ "${sel[cursor]}" == "1" ]]; then sel[cursor]="0"; else sel[cursor]="1"; fi
  assert_eq "toggle cursor=1 OFF" "0" "${sel[1]}"

  # Select-all detection
  sel=("0" "1" "0" "1")
  local all_on=true
  local s
  for s in "${sel[@]}"; do
    [[ "$s" == "0" ]] && all_on=false && break
  done
  assert_eq "partial => all_on=false" "false" "$all_on"

  sel=("1" "1" "1" "1")
  all_on=true
  for s in "${sel[@]}"; do
    [[ "$s" == "0" ]] && all_on=false && break
  done
  assert_eq "all selected => all_on=true" "true" "$all_on"
}

# ============================================================
# Test: Workspace file generation
# ============================================================
test_workspace_file_generation() {
  section "Workspace file generation"

  # Replicate generate_workspace_file logic
  local settings_file="$PROJECT_ROOT/config/workspace-settings.json"
  if [[ ! -f "$settings_file" ]]; then
    settings_file="$PROJECT_ROOT/config/workspace-settings.json.example"
  fi
  _gen() {
    local output_file="$1"; shift
    local folders=("$@")
    {
      printf '{\n'
      printf '\t"folders": [\n'
      local i=0 count=${#folders[@]}
      for folder in "${folders[@]}"; do
        i=$((i + 1))
        local comma=""; [[ "$i" -lt "$count" ]] && comma=","
        local name
        name=$(basename "$folder")
        printf '\t\t{\n\t\t\t"name": "%s",\n\t\t\t"path": "../../%s"\n\t\t}%s\n' "$name" "$folder" "$comma"
      done
      printf '\t],\n'
      printf '\t"settings": '
      sed '1!s/^/\t/' "$settings_file"
      printf '}\n'
    } > "$output_file"
  }

  local tmpdir
  tmpdir=$(mktemp -d)

  # Single folder
  _gen "$tmpdir/t1.code-workspace" "project-a"
  assert_file_exists "single folder file created" "$tmpdir/t1.code-workspace"

  local name_count
  name_count=$(grep -c '"name":' "$tmpdir/t1.code-workspace")
  assert_eq "single folder => 1 name entry" "1" "$name_count"

  local path_val
  path_val=$(grep '"path":' "$tmpdir/t1.code-workspace" | head -1 | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/')
  assert_eq "path is ../../project-a" "../../project-a" "$path_val"

  # Multiple folders
  _gen "$tmpdir/t2.code-workspace" "alpha" "beta" "gamma"
  assert_file_exists "multi folder file created" "$tmpdir/t2.code-workspace"
  name_count=$(grep -c '"name":' "$tmpdir/t2.code-workspace")
  assert_eq "3 folders => 3 name entries" "3" "$name_count"

  # Nested folder (e.g., groupA/repo1)
  _gen "$tmpdir/t3.code-workspace" "groupA/repo1" "project-b"
  assert_file_exists "nested folder file created" "$tmpdir/t3.code-workspace"
  local nested_name
  nested_name=$(grep '"name":' "$tmpdir/t3.code-workspace" | head -1 | sed 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/')
  assert_eq "nested folder name is basename" "repo1" "$nested_name"
  local nested_path
  nested_path=$(grep '"path":' "$tmpdir/t3.code-workspace" | head -1 | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/')
  assert_eq "nested folder path is ../../groupA/repo1" "../../groupA/repo1" "$nested_path"

  # Settings section exists
  assert_file_contains "settings section present" "$tmpdir/t2.code-workspace" '"settings"'

  # JSON validity (if jq available)
  if command -v jq &>/dev/null; then
    local valid
    valid=$(jq '.' "$tmpdir/t2.code-workspace" >/dev/null 2>&1 && echo "valid" || echo "invalid")
    assert_eq "jq can parse workspace file" "valid" "$valid"
    local folder_count
    folder_count=$(jq '.folders | length' "$tmpdir/t2.code-workspace")
    assert_eq "jq: folders length = 3" "3" "$folder_count"
  else
    skip_test "jq JSON validation" "jq not installed"
  fi

  rm -rf "$tmpdir"
}

# ============================================================
# Test: get_available_dirs logic
# ============================================================
test_get_available_dirs() {
  section "get_available_dirs logic"

  local tmpdir
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/project-a" "$tmpdir/project-b" "$tmpdir/.hidden"

  local dirs=()
  while IFS= read -r dir; do
    [[ -n "$dir" ]] && dirs+=("$dir")
  done < <(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)

  assert_eq "hidden excluded, 2 dirs found" "2" "${#dirs[@]}"
  assert_eq "sorted: project-a first" "project-a" "${dirs[0]}"
  assert_eq "sorted: project-b second" "project-b" "${dirs[1]}"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: is_folder_only_dir logic
# ============================================================
test_is_folder_only_dir() {
  section "is_folder_only_dir logic"

  local tmpdir
  tmpdir=$(mktemp -d)

  # Directory with only subdirectories
  mkdir -p "$tmpdir/group-a/repo1" "$tmpdir/group-a/repo2"
  local file_count
  file_count=$(find "$tmpdir/group-a" -mindepth 1 -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)
  assert_eq "folder-only dir has 0 files" "0" "$file_count"

  # Directory with files
  mkdir -p "$tmpdir/project-b"
  echo "content" > "$tmpdir/project-b/README.md"
  file_count=$(find "$tmpdir/project-b" -mindepth 1 -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)
  assert_eq "dir with file has 1 file" "1" "$file_count"

  # Directory with hidden files only (should count as folder-only)
  mkdir -p "$tmpdir/group-b/repo3"
  echo "hidden" > "$tmpdir/group-b/.gitkeep"
  file_count=$(find "$tmpdir/group-b" -mindepth 1 -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)
  assert_eq "hidden-only dir has 0 visible files" "0" "$file_count"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: Subdirectory expansion for folder-only dirs
# ============================================================
test_subdir_expansion() {
  section "Subdirectory expansion"

  local tmpdir
  tmpdir=$(mktemp -d)

  # Create a folder-only parent with subdirectories
  mkdir -p "$tmpdir/group-a/repo1" "$tmpdir/group-a/repo2"
  # Create a regular project with files
  mkdir -p "$tmpdir/project-b"
  echo "readme" > "$tmpdir/project-b/README.md"

  # Simulate get_available_dirs logic
  local result=()
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    local full_path="$tmpdir/$dir"
    result+=("$dir")

    local file_count
    file_count=$(find "$full_path" -mindepth 1 -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
      while IFS= read -r subdir; do
        [[ -n "$subdir" ]] && result+=("$dir/$subdir")
      done < <(find "$full_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)
    fi
  done < <(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort)

  assert_eq "total entries (parent + subs + regular)" "4" "${#result[@]}"
  assert_eq "1st: group-a (parent)" "group-a" "${result[0]}"
  assert_eq "2nd: group-a/repo1" "group-a/repo1" "${result[1]}"
  assert_eq "3rd: group-a/repo2" "group-a/repo2" "${result[2]}"
  assert_eq "4th: project-b" "project-b" "${result[3]}"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: get_current_folders from path (not name)
# ============================================================
test_get_current_folders() {
  section "get_current_folders extracts paths"

  local tmpdir
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/test.code-workspace" <<'EOF'
{
\t"folders": [
\t\t{
\t\t\t"name": "repo1",
\t\t\t"path": "../../groupA/repo1"
\t\t},
\t\t{
\t\t\t"name": "project-b",
\t\t\t"path": "../../project-b"
\t\t}
\t]
}
EOF

  local folders=()
  while IFS= read -r folder; do
    [[ -n "$folder" ]] && folders+=("$folder")
  done < <(grep '"path":' "$tmpdir/test.code-workspace" | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/' | sed 's|^\.\./\.\./||')

  assert_eq "2 folders found" "2" "${#folders[@]}"
  assert_eq "first folder" "groupA/repo1" "${folders[0]}"
  assert_eq "second folder" "project-b" "${folders[1]}"

  rm -rf "$tmpdir"
}

# ============================================================
# Test: Script does NOT use set -e
# ============================================================
test_no_set_e() {
  section "No set -e in generate-workspace.sh"

  local has_set_e
  has_set_e=$(grep -cE '^set -[a-z]*e' "$PROJECT_ROOT/generate-workspace.sh" || true)
  assert_eq "no set -e pattern found" "0" "$has_set_e"
}

# ============================================================
# Test: Existing workspace file integrity
# ============================================================
test_existing_workspaces() {
  section "Existing workspace files"

  local ws_dir="$PROJECT_ROOT/workspaces"
  if [[ ! -d "$ws_dir" ]]; then
    skip_test "workspace file check" "workspaces/ not found"
    return
  fi

  local files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(find "$ws_dir" -maxdepth 1 -name "*.code-workspace" -printf '%f\n' 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    skip_test "workspace file check" "no workspace files"
    return
  fi

  for f in "${files[@]}"; do
    local path="$ws_dir/$f"
    local bad_paths
    bad_paths=$(grep '"path":' "$path" | grep -v '../../' || true)
    if [[ -z "$bad_paths" ]]; then
      assert_eq "$f: paths start with ../../" "0" "0"
    else
      assert_eq "$f: paths start with ../../" "0" "1"
    fi
  done
}

# ============================================================
# Test: workspace-settings.json.example exists and is valid
# ============================================================
test_workspace_settings_file() {
  section "workspace-settings.json.example"

  local settings_file="$PROJECT_ROOT/config/workspace-settings.json.example"
  assert_file_exists "example settings file exists" "$settings_file"

  if command -v jq &>/dev/null; then
    local valid
    valid=$(jq '.' "$settings_file" >/dev/null 2>&1 && echo "valid" || echo "invalid")
    assert_eq "settings file is valid JSON" "valid" "$valid"

    local key_count
    key_count=$(jq 'keys | length' "$settings_file")
    assert_true "settings has at least 1 key" test "$key_count" -ge 1
  else
    skip_test "settings JSON validation" "jq not installed"
  fi
}

# ============================================================
# Run
# ============================================================

test_set_e_safety
test_key_parsing
test_tui_cursor_logic
test_toggle_logic
test_workspace_file_generation
test_get_available_dirs
test_is_folder_only_dir
test_subdir_expansion
test_get_current_folders
test_no_set_e
test_existing_workspaces
test_workspace_settings_file

print_summary
