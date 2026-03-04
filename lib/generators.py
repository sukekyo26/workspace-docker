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

import yaml

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

# Custom YAML representer to output strings without unnecessary quoting
# while preserving ${...} variable references as plain scalars
def _str_representer(dumper: yaml.Dumper, data: str) -> yaml.ScalarNode:
    """Represent strings using double quotes only when they contain YAML-special characters."""
    # Use double quotes for strings that need it (e.g., containing ${...}:... patterns)
    if any(c in data for c in ':{}\n'):
        return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='"')
    return dumper.represent_scalar('tag:yaml.org,2002:str', data)


def _make_compose_dumper() -> type[yaml.SafeDumper]:
    """Create a customized YAML dumper for docker-compose output."""
    dumper: type[yaml.SafeDumper] = type('ComposeDumper', (yaml.SafeDumper,), {})
    dumper.add_representer(str, _str_representer)  # type: ignore[arg-type]
    return dumper


def generate_compose(workspace_data: dict[str, Any], plugins_dir: str) -> str:
    """Generate docker-compose.yml content."""
    service_name = workspace_data.get("container", {}).get("service_name", "dev")
    enabled_plugins = workspace_data.get("plugins", {}).get("enable", [])
    plugin_volumes = get_plugin_volumes(plugins_dir, enabled_plugins)
    custom_volumes = workspace_data.get("volumes", {})

    # Build volumes list for service
    volume_mounts: list[str] = [
        "..:/home/${USERNAME}/workspace",
        "~/.ssh:/home/${USERNAME}/.ssh",
        "local:/home/${USERNAME}/.local",
    ]
    for _, vol_name, vol_path in plugin_volumes:
        volume_mounts.append(f"{vol_name}:{vol_path}")
    for vol_name, vol_path in custom_volumes.items():
        volume_mounts.append(f"{vol_name}:{vol_path}")

    # Build service config
    service: dict[str, Any] = {
        "container_name": "${CONTAINER_SERVICE_NAME}",
        "build": {
            "context": ".",
            "args": [
                "UBUNTU_VERSION=${UBUNTU_VERSION}",
                "USERNAME=${USERNAME}",
                "UID=${UID}",
                "GID=${GID}",
                "DOCKER_GID=${DOCKER_GID}",
            ],
        },
        "user": "${UID}:${GID}",
        "environment": [
            "CONTAINER_SERVICE_NAME=${CONTAINER_SERVICE_NAME}",
        ],
        "volumes": volume_mounts,
        "ports": [
            "${FORWARD_PORT:-3000}:${FORWARD_PORT:-3000}",
        ],
        "tty": True,
    }

    # Build top-level volume definitions
    vol_defs: dict[str, dict[str, str]] = {
        "local": {"name": "${CONTAINER_SERVICE_NAME}_local"},
    }
    for _, vol_name, _ in plugin_volumes:
        vol_defs[vol_name] = {"name": f"${{CONTAINER_SERVICE_NAME}}_{vol_name}"}
    for vn in custom_volumes:
        vol_defs[vn] = {"name": f"${{CONTAINER_SERVICE_NAME}}_{vn}"}

    compose: dict[str, Any] = {
        "services": {service_name: service},
        "volumes": vol_defs,
    }

    dumper = _make_compose_dumper()
    result: str = yaml.dump(compose, Dumper=dumper, default_flow_style=False,
                            sort_keys=False, allow_unicode=True)
    return result


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
    # Quote service name for safe YAML key usage
    safe_name = json.dumps(service_name) if any(c in service_name for c in ':{}[]#&*!|>%@, ') else service_name

    lines = [
        "services:",
        "  # Update this to the name of the service you want to work with in your docker-compose.yml file",
        f"  {safe_name}:",
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
# Dockerfile generator
# ============================================================

def _read_apt_packages(config_dir: str) -> str:
    """Read apt-base-packages.conf and return formatted Dockerfile lines."""
    conf_file = os.path.join(config_dir, "apt-base-packages.conf")
    if not os.path.exists(conf_file):
        return ""
    lines: list[str] = []
    with open(conf_file) as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith('#'):
                continue
            lines.append(f"    {line} \\")
    return "\n".join(lines) + "\n" if lines else ""


def _collect_plugin_apt_packages(
    plugins_dir: str, enabled_plugins: list[str], base_packages: set[str],
) -> str:
    """Collect apt packages from enabled plugins and return formatted Dockerfile lines.

    Packages already present in base_packages are silently deduplicated.
    Duplicates across plugins are also silently deduplicated.
    """
    seen: set[str] = set()
    packages: list[str] = []
    for plugin_id in enabled_plugins:
        plugin_file = os.path.join(plugins_dir, f"{plugin_id}.toml")
        if not os.path.exists(plugin_file):
            continue
        data = load_toml(plugin_file)
        apt_pkgs: list[str] = data.get("apt", {}).get("packages", [])
        for pkg in apt_pkgs:
            if pkg not in seen and pkg not in base_packages:
                seen.add(pkg)
                packages.append(pkg)
    if not packages:
        return ""
    lines = [f"    {pkg} \\" for pkg in packages]
    return "\n".join(lines) + "\n"


def _generate_plugin_installs(plugins_dir: str, enabled_plugins: list[str]) -> str:
    """Generate combined Dockerfile install snippets for enabled plugins."""
    parts: list[str] = []
    for plugin_id in enabled_plugins:
        plugin_file = os.path.join(plugins_dir, f"{plugin_id}.toml")
        if not os.path.exists(plugin_file):
            continue
        data = load_toml(plugin_file)

        install = data.get("install", {})
        snippet = install.get("dockerfile", "")
        if not snippet:
            continue

        # Strip trailing newlines
        snippet = snippet.rstrip("\n")

        # Validate: requires_root should not have manual USER directives
        requires_root = install.get("requires_root", False)
        if requires_root and "USER " in snippet:
            print(
                f"WARNING: Plugin '{plugin_id}' has requires_root=true but "
                "contains USER directive. USER wrapping is automatic.",
                file=sys.stderr,
            )

        # Validate volume paths
        volumes = data.get("volumes", {})
        for vol_name, vol_path in volumes.items():
            if not vol_path.startswith("/"):
                print(
                    f"WARNING: Plugin '{plugin_id}' volume '{vol_name}' has "
                    f"non-absolute path: {vol_path}",
                    file=sys.stderr,
                )

        # Replace {{VERSION}} with pinned version
        version = data.get("version", {})
        pin = version.get("pin", "")
        if pin:
            snippet = snippet.replace("{{VERSION}}", pin)

        # Auto-wrap with USER directives for root-requiring plugins
        if requires_root:
            snippet = f"USER root\n{snippet}\nUSER ${{USERNAME}}"

        parts.append(snippet)

    return "\n".join(parts)


def _generate_certificate_install(certs_dir: str) -> str:
    """Generate certificate install block for Dockerfile."""
    if not os.path.isdir(certs_dir):
        return ""

    crt_files = sorted(f for f in os.listdir(certs_dir) if f.endswith('.crt'))
    if not crt_files:
        return ""

    # Validate PEM format
    valid_certs: list[str] = []
    for fname in crt_files:
        filepath = os.path.join(certs_dir, fname)
        with open(filepath) as f:
            content = f.read()
        if '-----BEGIN CERTIFICATE-----' in content and '-----END CERTIFICATE-----' in content:
            valid_certs.append(fname)

    if not valid_certs:
        return ""

    copy_lines = [f"COPY certs/{name} /tmp/certs/{name}" for name in valid_certs]
    cp_parts = [
        f"    cp /tmp/certs/{name} /usr/local/share/ca-certificates/{name}"
        for name in valid_certs
    ]

    copy_block = "\n".join(copy_lines)
    cp_block = " && \\\n".join(cp_parts)

    return (
        "# Install custom CA certificates for corporate proxy/VPN environments\n"
        "USER root\n"
        f"{copy_block}\n"
        "RUN mkdir -p /usr/local/share/ca-certificates && \\\n"
        f"{cp_block} && \\\n"
        "    update-ca-certificates && \\\n"
        "    rm -rf /tmp/certs && \\\n"
        "    echo 'export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt'"
        " >> /home/${USERNAME}/.bashrc && \\\n"
        "    echo 'export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt'"
        " >> /home/${USERNAME}/.bashrc && \\\n"
        "    echo 'export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt'"
        " >> /home/${USERNAME}/.bashrc && \\\n"
        "    echo 'export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt'"
        " >> /home/${USERNAME}/.bashrc\n"
        "USER ${USERNAME}\n"
        "\n"
        "# Set certificate environment variables for various tools\n"
        "ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt\n"
        "ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt\n"
        "ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt\n"
        "ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt"
    )


_DOCKERFILE_TEMPLATE = """\
ARG UBUNTU_VERSION
FROM ubuntu:${UBUNTU_VERSION}

ARG USERNAME
ARG UID
ARG GID

RUN apt-get update && \\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \\
{{APT_BASE_PACKAGES}}
{{APT_PLUGIN_PACKAGES}}
{{APT_EXTRA_PACKAGES}}
    && locale-gen en_US.UTF-8 \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 既存の ubuntu ユーザー/グループ (UID/GID=1000) を削除してから新規作成
RUN userdel -r ubuntu 2>/dev/null || true && \\
    groupdel ubuntu 2>/dev/null || true && \\
    groupadd -g ${GID} ${USERNAME} && \\
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USERNAME} && \\
    usermod -aG sudo ${USERNAME} && \\
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \\
    chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Set locale environment variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Enable bash completion
RUN echo 'if [ -f /usr/share/bash-completion/bash_completion ]; then' >> ~/.bashrc && \\
    echo '  . /usr/share/bash-completion/bash_completion' >> ~/.bashrc && \\
    echo 'fi' >> ~/.bashrc

# Custom PS1 with Docker container name, user/host, working directory, and git status
RUN echo 'GIT_PS1_SHOWDIRTYSTATE=1' >> ~/.bashrc && \\
    echo 'GIT_PS1_SHOWUNTRACKEDFILES=1' >> ~/.bashrc && \\
    echo 'GIT_PS1_SHOWUPSTREAM="auto"' >> ~/.bashrc && \\
    echo 'PS1='"'"'\\\\[\\\\033[01;35m\\\\][Docker $CONTAINER_SERVICE_NAME]\\\\[\\\\033[00m\\\\] \\\\[\\\\033[01;32m\\\\]\\\\u@\\\\h:\\\\[\\\\033[01;34m\\\\]\\\\w\\\\[\\\\033[00m\\\\]$(__git_ps1 " \\\\[\\\\033[01;33m\\\\](%s)\\\\[\\\\033[00m\\\\]" 2>/dev/null) \\\\$ '"'"'' >> ~/.bashrc

{{CUSTOM_CERTIFICATES}}

{{PLUGIN_INSTALLS}}

# create volume mount directories for permission
RUN mkdir -p ~/.local

# Setup persistent bash history
RUN echo 'export HISTFILE=~/.local/state/.bash_history_docker' >> ~/.bashrc && \\
    echo 'export HISTSIZE=10000' >> ~/.bashrc && \\
    echo 'export HISTFILESIZE=20000' >> ~/.bashrc && \\
    mkdir -p ~/.local/state && touch ~/.local/state/.bash_history_docker

# Custom configuration file support (workspace-docker/config/.bashrc_custom)
RUN echo '' >> ~/.bashrc && \\
    echo '# Load custom configuration from workspace-docker/config/.bashrc_custom' >> ~/.bashrc && \\
    echo '[ -f "$HOME/workspace/workspace-docker/config/.bashrc_custom" ] && . "$HOME/workspace/workspace-docker/config/.bashrc_custom"' >> ~/.bashrc

WORKDIR /home/${USERNAME}/workspace
"""


def generate_dockerfile(
    workspace_data: dict[str, Any], plugins_dir: str,
    workspace_root: str | None = None,
) -> str:
    """Generate Dockerfile content from inline template and plugins.

    Args:
        workspace_data: Parsed workspace.toml data.
        plugins_dir: Path to the plugins directory.
        workspace_root: Root directory of the workspace (derived from plugins_dir parent if not given).
    """
    if workspace_root is None:
        workspace_root = os.path.dirname(os.path.abspath(plugins_dir))

    config_dir = os.path.join(workspace_root, "config")
    certs_dir = os.path.join(workspace_root, "certs")

    template = _DOCKERFILE_TEMPLATE

    # Generate components
    enabled_plugins: list[str] = workspace_data.get("plugins", {}).get("enable", [])
    plugin_installs = _generate_plugin_installs(plugins_dir, enabled_plugins)
    certificate_install = _generate_certificate_install(certs_dir)

    apt_base = _read_apt_packages(config_dir)

    # Parse base package names for deduplication
    base_pkg_names: set[str] = set()
    if apt_base:
        for line in apt_base.split("\n"):
            stripped = line.strip().rstrip("\\").strip()
            if stripped:
                base_pkg_names.add(stripped)

    apt_plugin = _collect_plugin_apt_packages(plugins_dir, enabled_plugins, base_pkg_names)

    apt_extra_pkgs: list[str] = workspace_data.get("apt", {}).get("extra_packages", [])
    apt_extra = ""
    for pkg in apt_extra_pkgs:
        apt_extra += f"    {pkg} \\\n"

    # Replace placeholders line-by-line
    # When placeholder content is empty, the placeholder line is removed entirely
    placeholders: dict[str, str] = {
        "{{PLUGIN_INSTALLS}}": plugin_installs,
        "{{CUSTOM_CERTIFICATES}}": certificate_install,
        "{{APT_BASE_PACKAGES}}": apt_base.rstrip("\n") if apt_base else "",
        "{{APT_PLUGIN_PACKAGES}}": apt_plugin.rstrip("\n") if apt_plugin else "",
        "{{APT_EXTRA_PACKAGES}}": apt_extra.rstrip("\n") if apt_extra else "",
    }

    result_lines: list[str] = []
    for line in template.split("\n"):
        matched = False
        for placeholder, content in placeholders.items():
            if placeholder in line:
                matched = True
                if content:
                    result_lines.append(content)
                # If content is empty, skip line entirely
                break
        if not matched:
            result_lines.append(line)

    return "\n".join(result_lines)


# ============================================================
# CLI
# ============================================================

_GeneratorFn = Any  # Union of (dict, str) -> str and (dict, str, str|None) -> str
COMMANDS: dict[str, _GeneratorFn] = {
    "compose": generate_compose,
    "devcontainer-json": generate_devcontainer_json,
    "devcontainer-compose": generate_devcontainer_compose,
    "dockerfile": generate_dockerfile,
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
