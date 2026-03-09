#!/bin/bash
# locale/en.sh — English message catalog (default/fallback)
# shellcheck disable=SC2034,SC2154

# ============================================================
# validators.sh
# ============================================================
_MSG[err_service_name_empty]="Container service name cannot be empty"
_MSG[err_service_name_invalid]="Container service name must contain only alphanumeric characters, dashes, and underscores"
_MSG[err_service_name_too_long]="Container service name must be 64 characters or less"
_MSG[err_username_empty]="Username cannot be empty"
_MSG[err_username_invalid]="Username must start with lowercase letter or underscore, followed by lowercase letters, digits, underscores, or hyphens"
_MSG[err_username_too_long]="Username must be 32 characters or less"
_MSG[err_boolean_invalid]="Value must be 'true' or 'false'"
_MSG[err_file_not_found]="%s not found: %s"
_MSG[err_dir_not_found]="%s not found: %s"
_MSG[warn_apt_duplicate]="[apt] packages contains '%s', which is already in apt-base-packages.conf"
_MSG[warn_apt_remove_duplicates]="Remove duplicates from [apt] packages in workspace.toml to avoid redundant installs"

# ============================================================
# devcontainer.sh
# ============================================================
_MSG[dc_docker_not_installed]="Docker is not installed"
_MSG[dc_docker_install_url]="→ https://docs.docker.com/get-docker/"
_MSG[dc_docker_not_running]="Docker daemon is not running"
_MSG[dc_docker_start_hint]="→ Start Docker Desktop or run: sudo systemctl start docker"
_MSG[dc_cli_not_found]="devcontainer CLI not found"
_MSG[dc_install_prompt]="Install devcontainer CLI automatically?"
_MSG[dc_install_declined]="devcontainer CLI installation declined"
_MSG[dc_installing]="→ Installing..."
_MSG[dc_install_failed]="Failed to download install script"
_MSG[dc_install_not_in_path]="devcontainer CLI installed but not found in PATH"
_MSG[dc_path_added]="Added %s to PATH for this session"
_MSG[dc_path_persist_hint]="To persist, add to your shell profile: export PATH=\"%s:\$PATH\""
_MSG[dc_curl_not_found]="curl not found"
_MSG[dc_curl_install_hint]="curl is required to install devcontainer CLI:"
_MSG[dc_json_not_found]=".devcontainer/devcontainer.json not found"
_MSG[dc_run_setup_first]="→ Run setup-docker.sh first"
_MSG[dc_env_not_found]=".env not found"
_MSG[dc_checking_prereqs]="Checking prerequisites..."
_MSG[dc_docker_not_found_wsl]="docker not found inside WSL"

# ============================================================
# plugins.sh
# ============================================================
_MSG[err_uv_not_found]="uv is required but not found."
_MSG[err_uv_install_hint]="  Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
_MSG[err_toml_check_failed]="TOML parser check failed."
_MSG[err_toml_run_sync]="  Run: uv sync --no-dev (in the project root)"
_MSG[err_workspace_toml_not_found]="workspace.toml not found: %s"
_MSG[err_plugins_dir_not_found]="plugins directory not found: %s"
_MSG[err_plugin_not_found]="Plugin not found: %s"

# ============================================================
# generators.sh
# ============================================================
_MSG[err_generate_failed]="Failed to generate %s (%s)"

# ============================================================
# utils.sh
# ============================================================
_MSG[err_invalid_var_name]="Invalid variable name in TOML output: %s"
_MSG[err_unexpected_var]="Unexpected variable in TOML output: %s"
_MSG[err_unknown_type_prefix]="Unknown type prefix in TOML output: %s"

# ============================================================
# tui.sh
# ============================================================
_MSG[tui_move_confirm]="↑↓: Move  Enter: Confirm"
_MSG[tui_move_toggle]="↑↓: Move  Enter: Toggle  a: Select all  d: Done  q: Cancel"
_MSG[tui_select_at_least_one]="⚠ Select at least one item before pressing d"

# ============================================================
# setup-docker.sh
# ============================================================
_MSG[setup_unknown_arg]="Unknown argument: %s"
_MSG[setup_header_regenerate]="Regenerate from workspace.toml"
_MSG[setup_service_info]="Service: %s"
_MSG[setup_username_info]="Username: %s"
_MSG[setup_plugins_info]="Plugins: %s"
_MSG[setup_header_generate]="Generate Dockerfile for Ubuntu on Docker"
_MSG[setup_service_default]="Service name: %s (default)"
_MSG[setup_username_current]="Username: %s (current user)"
_MSG[setup_prompt_service_name]="Enter container service name: "
_MSG[setup_prompt_username]="Enter Ubuntu on Docker username: "
_MSG[setup_header_software]="Software Installation Selection"
_MSG[setup_plugin_enabled]="  %s: enabled (default)"
_MSG[setup_plugin_skipped]="  %s: skipped"
_MSG[setup_select_plugins]="Select plugins to install:"
_MSG[setup_port_default]="Forward port: %s (default)"
_MSG[setup_header_port]="Port Configuration"
_MSG[setup_prompt_port]="Forward port [3000]: "
_MSG[setup_invalid_port]="Please enter a valid port number (1-65535)"
_MSG[setup_gen_workspace_toml]="Generating workspace.toml..."
_MSG[setup_gen_compose]="Generating docker-compose.yml..."
_MSG[setup_gen_dockerfile]="Generating Dockerfile..."
_MSG[setup_header_certs]="Custom CA Certificates Detected"
_MSG[setup_certs_will_install]="The following certificates will be installed from certs/:"
_MSG[setup_gen_devcontainer_json]="Generating .devcontainer/devcontainer.json..."
_MSG[setup_gen_devcontainer_compose]="Generating .devcontainer/docker-compose.yml..."
_MSG[setup_gen_env]="Generating .env..."
_MSG[setup_created_bashrc]="Created config/.bashrc_custom from example"
_MSG[setup_docker_gid_failed]="Failed to detect Docker GID"
_MSG[setup_docker_gid_hint]="Tried: /var/run/docker.sock, rootless socket, docker group\nPlease ensure Docker is installed and running"
_MSG[setup_detected_docker_gid]="Detected Docker GID: %s"
_MSG[setup_complete]="=== Setup Complete ==="
_MSG[setup_result_service]="Container service name: %s"
_MSG[setup_result_username]="Username: %s"
_MSG[setup_result_uid_gid]="UID/GID: %s/%s (automatically detected)"
_MSG[setup_result_docker_gid]="Docker GID: %s (automatically detected)"
_MSG[setup_result_plugins]="Enabled plugins:"
_MSG[setup_result_plugin_item]="  - %s: Yes"
_MSG[setup_result_certs]="  - Custom CA Certificates: Yes (from certs/)"
_MSG[setup_result_port]="Port forwarding: %s"
_MSG[setup_result_files]="Generated files:"
_MSG[setup_build_hint]="You can build the Docker image with the following command:"
_MSG[setup_start_hint]="To start the container:"
_MSG[setup_access_hint]="To access the container:"
_MSG[setup_stop_hint]="To stop the container:"
_MSG[setup_reconfig_hint]="To reconfigure:"

# ============================================================
# generate-workspace.sh
# ============================================================
_MSG[gen_ws_no_folders]="No folders found in parent directory"
_MSG[gen_ws_cancelled]="Cancelled"
_MSG[gen_ws_no_selection]="No folders selected"
_MSG[gen_ws_file_generated]="✅ Workspace file generated:"
_MSG[gen_ws_included_projects]="Included projects:"
_MSG[gen_ws_prompt_filename]="Enter filename (.code-workspace is appended automatically): "
_MSG[gen_ws_empty_filename]="⚠ Please enter a filename"
_MSG[gen_ws_overwrite]="⚠ %s.code-workspace already exists. Overwrite?"
_MSG[gen_ws_confirm_yn]="[y/N]: "
_MSG[gen_ws_header]=".code-workspace File Generator"
_MSG[gen_ws_scan_target]="Scan target:"
_MSG[gen_ws_output_dir]="Output dir:"
_MSG[gen_ws_existing_files]="Existing workspace files:"
_MSG[gen_ws_select_action]="Select action:"
_MSG[gen_ws_update_existing]="Update existing file"
_MSG[gen_ws_create_new]="Create new"
_MSG[gen_ws_select_file]="Select file to update:"
_MSG[gen_ws_no_files]="No workspace files found. Creating new one."
_MSG[gen_ws_select_folders]="Select folders to include in workspace:"

# ============================================================
# rebuild-container.sh
# ============================================================
_MSG[rebuild_inside_container]="This script cannot be run from inside a container"
_MSG[rebuild_header]="No-cache Rebuild Script"
_MSG[rebuild_workspace]="Workspace:"
_MSG[rebuild_current_image]="Current image: %s"
_MSG[rebuild_created]="Created:       %s (%s days ago)"
_MSG[rebuild_image_not_found]="Image %s not found (first build)"
_MSG[rebuild_notice]="⚠ Notice:"
_MSG[rebuild_notice_1]="  - The Docker image will be rebuilt without cache"
_MSG[rebuild_notice_2]="  - The existing container will be deleted and recreated"
_MSG[rebuild_notice_3]="  - The rebuild may take several minutes"
_MSG[rebuild_confirm]="Proceed with rebuild? [y/N]: "
_MSG[rebuild_cancelled]="Cancelled"
_MSG[rebuild_starting]="🔨 Rebuilding without cache & starting..."
_MSG[rebuild_please_wait]="   This may take several minutes"
_MSG[rebuild_complete]="✅ Rebuild & startup complete"
_MSG[rebuild_new_image]="New image created: %s"
_MSG[rebuild_vscode_1]="📌 In VS Code, press Ctrl+Shift+P →"
_MSG[rebuild_vscode_2]="   'Dev Containers: Reopen in Container'"

# ============================================================
# clean-volumes.sh
# ============================================================
_MSG[clean_inside_container]="This script cannot be run from inside a container"
_MSG[clean_header]="Docker Volume Cleanup Script"
_MSG[clean_workspace]="Workspace:"
_MSG[clean_docker_not_found]="docker command not found"
_MSG[clean_docker_not_running]="Docker daemon is not running"
_MSG[clean_project_name]="Project name:"
_MSG[clean_service_name]="Service name:"
_MSG[clean_volume_prefix]="Volume prefix:"
_MSG[clean_no_volumes]="No volumes found to delete"
_MSG[clean_prefix_info]="  Prefix: %s"
_MSG[clean_volumes_header]="Volumes to delete (%s):"
_MSG[clean_notice]="⚠ Notice:"
_MSG[clean_notice_1]="  - All volumes listed above will be deleted"
_MSG[clean_notice_2]="  - Data in volumes cannot be recovered"
_MSG[clean_notice_3]="  - Stop running containers first"
_MSG[clean_confirm]="Proceed with deletion? [y/N]: "
_MSG[clean_cancelled]="Cancelled"
_MSG[clean_stopping]="Removing containers..."
_MSG[clean_deleting]="Deleting volumes..."
_MSG[clean_vol_failed]="%s (deletion failed — may be in use)"
_MSG[clean_all_deleted]="✅ All %s volumes deleted successfully"
_MSG[clean_partial]="⚠ %s deleted, %s failed"

# ============================================================
# clean-docker.sh
# ============================================================
_MSG[docker_clean_inside_container]="This script cannot be run from inside a container"
_MSG[docker_clean_header]="Docker Resource Cleanup"
_MSG[docker_clean_not_found]="docker command not found"
_MSG[docker_clean_not_running]="Docker daemon is not running"
_MSG[docker_clean_disk_usage]="Current Docker disk usage:"
_MSG[docker_clean_disk_usage_after]="Updated Docker disk usage:"
_MSG[docker_clean_select_title]="Select resources to clean up:"
_MSG[docker_clean_opt_containers]="Stopped containers (docker container prune)"
_MSG[docker_clean_opt_builder]="Build cache (docker builder prune)"
_MSG[docker_clean_opt_images]="Dangling images (docker image prune)"
_MSG[docker_clean_opt_networks]="Unused networks (docker network prune)"
_MSG[docker_clean_opt_volumes]="Unused volumes (docker volume prune) ⚠ DATA LOSS RISK"
_MSG[docker_clean_cancelled]="Cancelled"
_MSG[docker_clean_running_containers]="Removing stopped containers..."
_MSG[docker_clean_running_builder]="Removing build cache..."
_MSG[docker_clean_running_images]="Removing dangling images..."
_MSG[docker_clean_running_networks]="Removing unused networks..."
_MSG[docker_clean_running_volumes]="Removing unused volumes..."
_MSG[docker_clean_done_containers]="Stopped containers removed"
_MSG[docker_clean_done_builder]="Build cache removed"
_MSG[docker_clean_done_images]="Dangling images removed"
_MSG[docker_clean_done_networks]="Unused networks removed"
_MSG[docker_clean_done_volumes]="Unused volumes removed"
_MSG[docker_clean_fail_containers]="Failed to remove stopped containers"
_MSG[docker_clean_fail_builder]="Failed to remove build cache"
_MSG[docker_clean_fail_images]="Failed to remove dangling images"
_MSG[docker_clean_fail_networks]="Failed to remove unused networks"
_MSG[docker_clean_fail_volumes]="Failed to remove unused volumes"
_MSG[docker_clean_all_done]="✅ All %s cleanup operations completed successfully"
_MSG[docker_clean_partial_done]="⚠ %s completed, %s failed"
