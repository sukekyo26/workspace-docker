#!/usr/bin/env python3
"""Programmatic generator for docker-compose.yml and devcontainer files.

Generates YAML/JSON output directly from workspace.toml and plugin definitions,
replacing the template-based approach for all files except Dockerfile.

Usage:
    python3 lib/generators.py compose <workspace.toml> <plugins_dir>
    python3 lib/generators.py devcontainer-json <workspace.toml> <plugins_dir>
    python3 lib/generators.py devcontainer-compose <workspace.toml> <plugins_dir>

Requires Python 3.11+ (tomllib) or tomli package for older versions.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib  # type: ignore[no-redef,import-not-found]
    except ModuleNotFoundError:
        print(
            "ERROR: No TOML parser available. "
            "Python 3.11+ includes tomllib. "
            "For older Python, run: pip install tomli",
            file=sys.stderr,
        )
        sys.exit(1)


def load_toml(filepath: str) -> dict[str, Any]:
    """Load and parse a TOML file."""
    with open(filepath, "rb") as f:
        return tomllib.load(f)


def get_plugin_volumes(
    plugins_dir: str, enabled_plugins: list[str]
) -> list[tuple[str, str, str]]:
    """Get volumes from enabled plugins.

    Returns list of (plugin_name, vol_name, vol_path) tuples.
    """
    volumes = []
    for plugin_id in enabled_plugins:
        plugin_file = os.path.join(plugins_dir, f"{plugin_id}.toml")
        if not os.path.exists(plugin_file):
            continue
        data = load_toml(plugin_file)
        name = data.get("metadata", {}).get("name", plugin_id)
        vols = data.get("volumes", {})
        for vol_name, vol_path in vols.items():
            volumes.append((name, vol_name, vol_path))
    return volumes


# ============================================================
# docker-compose.yml generator
# ============================================================

def generate_compose(workspace_data: dict[str, Any], plugins_dir: str) -> str:
    """Generate docker-compose.yml content."""
    service_name = workspace_data.get("container", {}).get("service_name", "dev")
    enabled_plugins = workspace_data.get("plugins", {}).get("enable", [])
    plugin_volumes = get_plugin_volumes(plugins_dir, enabled_plugins)
    custom_volumes = workspace_data.get("volumes", {})

    lines = [
        "services:",
        f"  {service_name}:",
        "    container_name: ${CONTAINER_SERVICE_NAME}",
        "    build:",
        "      context: .",
        "      args:",
        "        - UBUNTU_VERSION=${UBUNTU_VERSION}",
        "        - USERNAME=${USERNAME}",
        "        - UID=${UID}",
        "        - GID=${GID}",
        "        - DOCKER_GID=${DOCKER_GID}",
        '    user: "${UID}:${GID}"',
        "    environment:",
        "      - CONTAINER_SERVICE_NAME=${CONTAINER_SERVICE_NAME}",
        "    volumes:",
        "      # ワークスペース",
        "      - ..:/home/${USERNAME}/workspace",
        "",
        "      # 個人設定（ホストと同期）",
        "      - ~/.ssh:/home/${USERNAME}/.ssh",
        "",
        "      # .local（永続化）- pipx, uv等のユーザーインストールパッケージ",
        "      - local:/home/${USERNAME}/.local",
    ]

    # Plugin volume mounts (blank line before first entry)
    if plugin_volumes or custom_volumes:
        lines.append("")
    for plugin_name, vol_name, vol_path in plugin_volumes:
        lines.append(f"      # {plugin_name}（永続化）")
        lines.append(f"      - {vol_name}:{vol_path}")

    # Custom volume mounts
    for vol_name, vol_path in custom_volumes.items():
        lines.append("      # ユーザー定義ボリューム")
        lines.append(f"      - {vol_name}:{vol_path}")

    lines.extend([
        "    ports:",
        '      - "${FORWARD_PORT:-3000}:${FORWARD_PORT:-3000}"',
        "    tty: true",
        "",
        "volumes:",
        "  local:",
        '    name: "${CONTAINER_SERVICE_NAME}_local"',
    ])

    # Plugin volume definitions
    for _, vol_name, _ in plugin_volumes:
        lines.append(f"  {vol_name}:")
        lines.append(f'    name: "${{CONTAINER_SERVICE_NAME}}_{vol_name}"')

    # Custom volume definitions
    for vol_name in custom_volumes:
        lines.append(f"  {vol_name}:")
        lines.append(f'    name: "${{CONTAINER_SERVICE_NAME}}_{vol_name}"')

    lines.append("")  # trailing newline
    return "\n".join(lines) + "\n"


# ============================================================
# devcontainer.json generator (JSONC with comments)
# ============================================================

def generate_devcontainer_json(workspace_data: dict[str, Any], _plugins_dir: str) -> str:
    """Generate .devcontainer/devcontainer.json content (JSONC)."""
    service_name = workspace_data.get("container", {}).get("service_name", "dev")
    username = workspace_data.get("container", {}).get("username", "developer")
    forward_ports = workspace_data.get("ports", {}).get("forward", [3000])
    forward_port = forward_ports[0] if forward_ports else 3000
    extensions = workspace_data.get("vscode", {}).get("extensions", [])

    # Build extensions block
    if extensions:
        ext_lines = []
        for i, ext in enumerate(extensions):
            comma = "," if i < len(extensions) - 1 else ""
            ext_lines.append(f"\t\t\t\t{json.dumps(ext)}{comma}")
        ext_block = "\t\t\t\"extensions\": [\n" + "\n".join(ext_lines) + "\n\t\t\t]"
    else:
        ext_block = '\t\t\t"extensions": []'

    lines = [
        "// For format details, see https://aka.ms/devcontainer.json. For config options, see the",
        "// README at: https://github.com/devcontainers/templates/tree/main/src/docker-existing-docker-compose",
        "{",
        '\t"name": "Existing Docker Compose (Extend)",',
        "",
        "\t// Update the 'dockerComposeFile' list if you have more compose files or use different names.",
        "\t// The .devcontainer/docker-compose.yml file contains any overrides you need/want to make.",
        '\t"dockerComposeFile": [',
        '\t\t"../docker-compose.yml",',
        '\t\t"docker-compose.yml"',
        "\t],",
        "",
        "\t// The 'service' property is the name of the service for the container that VS Code should",
        "\t// use. Update this value and .devcontainer/docker-compose.yml to the real service name.",
        f"\t\"service\": {json.dumps(service_name)},",
        "",
        "\t// The optional 'workspaceFolder' property is the path VS Code should open by default when",
        "\t// connected. This is typically a file mount in .devcontainer/docker-compose.yml",
        f'\t"workspaceFolder": "/home/{username}/workspace",',
        "",
        "\t// Features to add to the dev container. More info: https://containers.dev/features.",
        '\t// "features": {},',
        "",
        "\t// Use 'forwardPorts' to make a list of ports inside the container available locally.",
        f'\t"forwardPorts": [{forward_port}],',
        "",
        "\t// Uncomment the next line if you want start specific services in your Docker Compose config.",
        '\t// "runServices": [],',
        "",
        "\t// Uncomment the next line if you want to keep your containers running after VS Code shuts down.",
        '\t"shutdownAction": "stopCompose",',
        "",
        "\t// Uncomment the next line to run commands after the container is created.",
        '\t// "postCreateCommand": "cat /etc/os-release",',
        "",
        "\t// Configure tool-specific properties.",
        '\t"customizations": {',
        '\t\t"vscode": {',
        ext_block,
        "\t\t}",
        "\t}",
        "",
        "\t// Uncomment to connect as an existing user other than the container default. More info: https://aka.ms/dev-containers-non-root.",
        '\t// "remoteUser": "devcontainer"',
        "}",
    ]

    return "\n".join(lines) + "\n"


# ============================================================
# .devcontainer/docker-compose.yml generator
# ============================================================

def generate_devcontainer_compose(workspace_data: dict[str, Any], _plugins_dir: str) -> str:
    """Generate .devcontainer/docker-compose.yml content."""
    service_name = workspace_data.get("container", {}).get("service_name", "dev")

    lines = [
        "services:",
        "  # Update this to the name of the service you want to work with in your docker-compose.yml file",
        f"  {service_name}:",
        "    # Uncomment if you want to override the service's Dockerfile to one in the .devcontainer",
        "    # folder. Note that the path of the Dockerfile and context is relative to the *primary*",
        '    # docker-compose.yml file (the first in the devcontainer.json "dockerComposeFile"',
        "    # array). The sample below assumes your primary file is in the root of your project.",
        "    #",
        "    # build:",
        "    #   context: .",
        "    #   dockerfile: .devcontainer/Dockerfile",
        "",
        "    volumes:",
        "      # Update this to wherever you want VS Code to mount the folder of your project",
        "      - ..:/home/${USERNAME}/workspace:cached",
        "      # Mount host Docker socket to use host's Docker daemon",
        "      - /var/run/docker.sock:/var/run/docker.sock",
        "",
        "    # Add host's docker group GID to allow socket access.",
        "    # This is automatically detected and set by setup-docker.sh",
        "    group_add:",
        '      - "${DOCKER_GID}"',
        "",
        "    # Uncomment the next four lines if you will use a ptrace-based debugger like C++, Go, and Rust.",
        "    # cap_add:",
        "    #   - SYS_PTRACE",
        "    # security_opt:",
        "    #   - seccomp:unconfined",
        "",
        "    # Overrides default command so things don't shut down after the process ends.",
        "    command: sleep infinity",
    ]

    return "\n".join(lines) + "\n"


# ============================================================
# CLI
# ============================================================

COMMANDS = {
    "compose": generate_compose,
    "devcontainer-json": generate_devcontainer_json,
    "devcontainer-compose": generate_devcontainer_compose,
}


def main() -> None:
    if len(sys.argv) < 4:
        cmds = "|".join(COMMANDS)
        print(
            f"Usage: {sys.argv[0]} <{cmds}> <workspace.toml> <plugins_dir>",
            file=sys.stderr,
        )
        sys.exit(1)

    command = sys.argv[1]
    workspace_toml = sys.argv[2]
    plugins_dir = sys.argv[3]

    if command not in COMMANDS:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)

    workspace_data = load_toml(workspace_toml)
    output = COMMANDS[command](workspace_data, plugins_dir)
    sys.stdout.write(output)


if __name__ == "__main__":
    main()
