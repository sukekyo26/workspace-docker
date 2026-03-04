#!/usr/bin/env python3
"""File generators for workspace-docker.

Generates docker-compose.yml, devcontainer.json, and Dockerfile content
from workspace.toml and plugin definitions using a class-based architecture.

Architecture:
    Generator (ABC)
    ├── ComposeGenerator              - docker-compose.yml (YAML)
    ├── DevcontainerJsonGenerator     - devcontainer.json (JSONC)
    ├── DevcontainerComposeGenerator  - .devcontainer/docker-compose.yml
    └── DockerfileGenerator           - Dockerfile

Usage:
    python3 lib/generators.py compose <workspace.toml> <plugins_dir>
    python3 lib/generators.py devcontainer-json <workspace.toml> <plugins_dir>
    python3 lib/generators.py devcontainer-compose <workspace.toml> <plugins_dir>
    python3 lib/generators.py dockerfile <workspace.toml> <plugins_dir>
    python3 lib/generators.py plugin-installs <plugins_dir> <plugin-id>...

Requires Python 3.11+ (tomllib) or tomli package for older versions.
"""

from __future__ import annotations

import json
import os
import sys
from abc import ABC, abstractmethod
from typing import Any

import yaml

from toml_parser import load_toml

# ============================================================
# Generator base class
# ============================================================


class Generator(ABC):
    """Abstract base class for all file generators.

    Provides common workspace configuration access and plugin volume
    resolution. Subclasses implement generate() to produce file content.
    """

    def __init__(self, workspace_data: dict[str, Any], plugins_dir: str) -> None:
        self._data = workspace_data
        self._plugins_dir = plugins_dir

    @abstractmethod
    def generate(self) -> str:
        """Generate the file content as a string."""

    @property
    def service_name(self) -> str:
        return str(self._data.get("container", {}).get("service_name", "dev"))

    @property
    def username(self) -> str:
        return str(self._data.get("container", {}).get("username", "developer"))

    @property
    def enabled_plugins(self) -> list[str]:
        return list(self._data.get("plugins", {}).get("enable", []))

    @staticmethod
    def get_plugin_volumes(
        plugins_dir: str,
        enabled_plugins: list[str],
    ) -> list[tuple[str, str, str]]:
        """Get volumes from enabled plugins.

        Returns list of (plugin_name, vol_name, vol_path) tuples.
        """
        volumes: list[tuple[str, str, str]] = []
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


class ComposeGenerator(Generator):
    """Generates docker-compose.yml content using PyYAML."""

    YAML_SPECIAL_CHARS = frozenset(":{}#&*!|>%@`'\"[]?,\n")

    @staticmethod
    def str_representer(dumper: yaml.Dumper, data: str) -> yaml.ScalarNode:
        """Represent strings with double quotes only when YAML-special chars are present."""
        if any(c in ComposeGenerator.YAML_SPECIAL_CHARS for c in data):
            return dumper.represent_scalar("tag:yaml.org,2002:str", data, style='"')
        return dumper.represent_scalar("tag:yaml.org,2002:str", data)

    @staticmethod
    def make_dumper() -> type[yaml.SafeDumper]:
        """Create a customized YAML dumper for docker-compose output."""
        dumper: type[yaml.SafeDumper] = type("ComposeDumper", (yaml.SafeDumper,), {})
        dumper.add_representer(str, ComposeGenerator.str_representer)  # type: ignore[arg-type]
        return dumper

    def generate(self) -> str:
        plugin_volumes = self.get_plugin_volumes(
            self._plugins_dir,
            self.enabled_plugins,
        )
        custom_volumes = self._data.get("volumes", {})

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
            "services": {self.service_name: service},
            "volumes": vol_defs,
        }

        dumper = self.make_dumper()
        return yaml.dump(
            compose,
            Dumper=dumper,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
        )


# ============================================================
# devcontainer.json generator (JSONC with comments)
# ============================================================


class DevcontainerJsonGenerator(Generator):
    """Generates .devcontainer/devcontainer.json as JSON.

    Uses json.dumps for clean, machine-readable output.
    A header comment marks the file as auto-generated.

    Users can add a ``[devcontainer]`` section in workspace.toml to inject
    arbitrary devcontainer.json properties.  Values are deep-merged into the
    base config so that, e.g., ``[devcontainer.customizations.vscode]``
    ``settings = { ... }`` coexists with ``[vscode].extensions``.
    """

    _HEADER = "// Auto-generated from workspace.toml — do not edit directly.\n"

    def generate(self) -> str:
        config = self._build_config()
        body = json.dumps(config, indent="\t", ensure_ascii=False)
        return self._HEADER + body + "\n"

    def _build_config(self) -> dict[str, Any]:
        """Build the devcontainer.json configuration dictionary."""
        forward_ports = self._data.get("ports", {}).get("forward", [3000])
        extensions = self._data.get("vscode", {}).get("extensions", [])

        base: dict[str, Any] = {
            "name": "Existing Docker Compose (Extend)",
            "dockerComposeFile": ["../docker-compose.yml", "docker-compose.yml"],
            "service": self.service_name,
            "workspaceFolder": f"/home/{self.username}/workspace",
            "forwardPorts": forward_ports,
            "shutdownAction": "stopCompose",
            "customizations": {
                "vscode": {
                    "extensions": extensions,
                },
            },
        }

        overrides = self._data.get("devcontainer", {})
        if overrides:
            self._deep_merge(base, overrides)

        return base

    @staticmethod
    def _deep_merge(base: dict[str, Any], override: dict[str, Any]) -> None:
        """Recursively merge *override* into *base* in place.

        - dict values are merged recursively.
        - All other types (lists, scalars) in *override* replace *base*.
        """
        for key, val in override.items():
            if key in base and isinstance(base[key], dict) and isinstance(val, dict):
                DevcontainerJsonGenerator._deep_merge(base[key], val)
            else:
                base[key] = val


# ============================================================
# .devcontainer/docker-compose.yml generator
# ============================================================


class DevcontainerComposeGenerator(Generator):
    """Generates .devcontainer/docker-compose.yml content."""

    def generate(self) -> str:
        safe_name = (
            json.dumps(self.service_name)
            if any(c in self.service_name for c in ":{}[]#&*!|>%@, ")
            else self.service_name
        )

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


class DockerfileGenerator(Generator):
    """Generates Dockerfile content from inline template and plugins."""

    _TEMPLATE = """\
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

    def __init__(
        self,
        workspace_data: dict[str, Any],
        plugins_dir: str,
        workspace_root: str | None = None,
    ) -> None:
        super().__init__(workspace_data, plugins_dir)
        if workspace_root is None:
            workspace_root = os.path.dirname(os.path.abspath(plugins_dir))
        self._workspace_root = workspace_root

    def generate(self) -> str:
        config_dir = os.path.join(self._workspace_root, "config")
        certs_dir = os.path.join(self._workspace_root, "certs")

        plugin_installs = self.generate_plugin_installs(
            self._plugins_dir,
            self.enabled_plugins,
        )
        certificate_install = self._generate_certificate_install(certs_dir)

        apt_base = self._read_apt_packages(config_dir)

        # Parse base package names for deduplication
        base_pkg_names: set[str] = set()
        if apt_base:
            for line in apt_base.split("\n"):
                stripped = line.strip().rstrip("\\").strip()
                if stripped:
                    base_pkg_names.add(stripped)

        apt_plugin = self.collect_plugin_apt_packages(
            self._plugins_dir,
            self.enabled_plugins,
            base_pkg_names,
        )

        apt_extra_pkgs: list[str] = self._data.get("apt", {}).get(
            "extra_packages",
            [],
        )
        apt_extra = ""
        for pkg in apt_extra_pkgs:
            apt_extra += f"    {pkg} \\\n"

        # Replace placeholders; empty content removes the placeholder line
        placeholders: dict[str, str] = {
            "{{PLUGIN_INSTALLS}}": plugin_installs,
            "{{CUSTOM_CERTIFICATES}}": certificate_install,
            "{{APT_BASE_PACKAGES}}": apt_base.rstrip("\n") if apt_base else "",
            "{{APT_PLUGIN_PACKAGES}}": (apt_plugin.rstrip("\n") if apt_plugin else ""),
            "{{APT_EXTRA_PACKAGES}}": (apt_extra.rstrip("\n") if apt_extra else ""),
        }

        result_lines: list[str] = []
        for line in self._TEMPLATE.split("\n"):
            matched = False
            for placeholder, content in placeholders.items():
                if placeholder in line:
                    matched = True
                    if content:
                        result_lines.append(content)
                    break
            if not matched:
                result_lines.append(line)

        return "\n".join(result_lines)

    @staticmethod
    def generate_plugin_installs(
        plugins_dir: str,
        enabled_plugins: list[str],
    ) -> str:
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

            snippet = snippet.rstrip("\n")

            requires_root = install.get("requires_root", False)
            if requires_root and "USER " in snippet:
                print(
                    f"WARNING: Plugin '{plugin_id}' has requires_root=true but "
                    "contains USER directive. USER wrapping is automatic.",
                    file=sys.stderr,
                )

            volumes = data.get("volumes", {})
            for vol_name, vol_path in volumes.items():
                if not vol_path.startswith("/"):
                    print(
                        f"WARNING: Plugin '{plugin_id}' volume '{vol_name}' has non-absolute path: {vol_path}",
                        file=sys.stderr,
                    )

            version = data.get("version", {})
            pin = version.get("pin", "")
            if pin:
                snippet = snippet.replace("{{VERSION}}", pin)

            if requires_root:
                snippet = f"USER root\n{snippet}\nUSER ${{USERNAME}}"

            parts.append(snippet)

        return "\n".join(parts)

    @staticmethod
    def collect_plugin_apt_packages(
        plugins_dir: str,
        enabled_plugins: list[str],
        base_packages: set[str],
    ) -> str:
        """Collect apt packages from enabled plugins.

        Packages in base_packages and duplicates across plugins are deduplicated.
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

    @staticmethod
    def _read_apt_packages(config_dir: str) -> str:
        """Read apt-base-packages.conf and return formatted Dockerfile lines."""
        conf_file = os.path.join(config_dir, "apt-base-packages.conf")
        if not os.path.exists(conf_file):
            return ""
        lines: list[str] = []
        with open(conf_file) as f:
            for raw_line in f:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                lines.append(f"    {line} \\")
        return "\n".join(lines) + "\n" if lines else ""

    @staticmethod
    def _generate_certificate_install(certs_dir: str) -> str:
        """Generate certificate install block for Dockerfile."""
        if not os.path.isdir(certs_dir):
            return ""

        crt_files = sorted(f for f in os.listdir(certs_dir) if f.endswith(".crt"))
        if not crt_files:
            return ""

        valid_certs: list[str] = []
        for fname in crt_files:
            filepath = os.path.join(certs_dir, fname)
            with open(filepath) as f:
                content = f.read()
            if "-----BEGIN CERTIFICATE-----" in content and "-----END CERTIFICATE-----" in content:
                valid_certs.append(fname)

        if not valid_certs:
            return ""

        copy_lines = [f"COPY certs/{name} /tmp/certs/{name}" for name in valid_certs]
        cp_parts = [f"    cp /tmp/certs/{name} /usr/local/share/ca-certificates/{name}" for name in valid_certs]

        copy_block = "\n".join(copy_lines)
        cp_block = " && \\\n".join(cp_parts)

        return (
            "# Install custom CA certificates for corporate proxy/VPN"
            " environments\n"
            "USER root\n"
            f"{copy_block}\n"
            "RUN mkdir -p /usr/local/share/ca-certificates && \\\n"
            f"{cp_block} && \\\n"
            "    update-ca-certificates && \\\n"
            "    rm -rf /tmp/certs && \\\n"
            "    echo 'export SSL_CERT_FILE="
            "/etc/ssl/certs/ca-certificates.crt'"
            " >> /home/${USERNAME}/.bashrc && \\\n"
            "    echo 'export CURL_CA_BUNDLE="
            "/etc/ssl/certs/ca-certificates.crt'"
            " >> /home/${USERNAME}/.bashrc && \\\n"
            "    echo 'export REQUESTS_CA_BUNDLE="
            "/etc/ssl/certs/ca-certificates.crt'"
            " >> /home/${USERNAME}/.bashrc && \\\n"
            "    echo 'export NODE_EXTRA_CA_CERTS="
            "/etc/ssl/certs/ca-certificates.crt'"
            " >> /home/${USERNAME}/.bashrc\n"
            "USER ${USERNAME}\n"
            "\n"
            "# Set certificate environment variables for various tools\n"
            "ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt\n"
            "ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt\n"
            "ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt\n"
            "ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt"
        )


# ============================================================
# Generator registry
# ============================================================

GENERATORS: dict[str, type[Generator]] = {
    "compose": ComposeGenerator,
    "devcontainer-json": DevcontainerJsonGenerator,
    "devcontainer-compose": DevcontainerComposeGenerator,
    "dockerfile": DockerfileGenerator,
}


# ============================================================
# CLI
# ============================================================


def _run_cli() -> None:
    """Parse CLI arguments and run the appropriate generator."""
    if len(sys.argv) < 3:
        cmds = "|".join(GENERATORS)
        print(
            f"Usage: {sys.argv[0]} <{cmds}|plugin-installs> <workspace.toml|plugins_dir> <plugins_dir|plugin-id...>",
            file=sys.stderr,
        )
        sys.exit(1)

    command = sys.argv[1]

    # plugin-installs subcommand
    if command == "plugin-installs":
        if len(sys.argv) < 4:
            print(
                f"Usage: {sys.argv[0]} plugin-installs <plugins_dir> <plugin-id> ...",
                file=sys.stderr,
            )
            sys.exit(1)
        output = DockerfileGenerator.generate_plugin_installs(
            sys.argv[2],
            sys.argv[3:],
        )
        sys.stdout.write(output)
        return

    if len(sys.argv) < 4:
        cmds = "|".join(GENERATORS)
        print(
            f"Usage: {sys.argv[0]} <{cmds}> <workspace.toml> <plugins_dir>",
            file=sys.stderr,
        )
        sys.exit(1)

    workspace_toml = sys.argv[2]
    plugins_dir = sys.argv[3]

    if command not in GENERATORS:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)

    workspace_data = load_toml(workspace_toml)
    generator = GENERATORS[command](workspace_data, plugins_dir)
    sys.stdout.write(generator.generate())


def main() -> None:
    """Entry point with user-friendly error handling."""
    try:
        _run_cli()
    except FileNotFoundError as e:
        print(
            f"ERROR: File not found: {e.filename or e}",
            file=sys.stderr,
        )
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
