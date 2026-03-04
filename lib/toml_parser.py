#!/usr/bin/env python3
"""TOML parser helper for workspace-docker.

Parses workspace.toml and plugin TOML files, outputting shell-safe key=value
pairs using the Command pattern for extensible subcommand dispatch.

Architecture:
    ShellEncoder        - Encodes values for safe shell parsing
    TomlCommand (ABC)   - Base class for TOML parsing commands
    ├── WorkspaceCommand  - Parses workspace.toml
    ├── PluginCommand     - Parses plugin TOML files
    └── ListPluginsCommand - Lists all plugins in a directory

Usage:
    python3 lib/toml_parser.py workspace <file>
    python3 lib/toml_parser.py plugin <file>
    python3 lib/toml_parser.py list-plugins <dir>

Requires Python 3.11+ (tomllib).
"""

from __future__ import annotations

import os
import sys
import tomllib
from abc import ABC, abstractmethod
from typing import Any, cast

# ============================================================
# TOML loader
# ============================================================


def load_toml(filepath: str) -> dict[str, Any]:
    """Load and parse a TOML file."""
    with open(filepath, "rb") as f:
        return tomllib.load(f)


# ============================================================
# Shell-safe value encoder
# ============================================================


class ShellEncoder:
    """Encodes values for safe shell parsing without eval.

    Uses printf %b compatible encoding for escape sequences.
    Arrays use U+001F (unit separator) as element delimiter.
    Output format: S:KEY=scalar or A:KEY=elem1\\x1felem2
    """

    UNIT_SEP = "\x1f"

    @classmethod
    def encode(cls, value: Any) -> str:
        """Encode a value for safe shell parsing.

        Backslash → \\\\, Newline → \\n, Tab → \\t, CR → \\r.
        Arrays: elements joined by U+001F (unit separator).
        """
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, (int, float)):
            return str(value)
        if isinstance(value, list):
            return cls.UNIT_SEP.join(cls.encode(v) for v in cast("list[object]", value))
        s = str(value)
        # Escape for printf %b compatibility (order matters: backslash first)
        s = s.replace("\\", "\\\\")
        s = s.replace("\n", "\\n")
        s = s.replace("\r", "\\r")
        s = s.replace("\t", "\\t")
        return s

    @classmethod
    def print_kv(cls, key: str, value: Any) -> None:
        """Print a type-prefixed key=value pair for safe shell parsing.

        Format:
            S:KEY=encoded_scalar   (scalar value)
            A:KEY=elem1\\x1felem2  (array, elements separated by U+001F)
        """
        if isinstance(value, list):
            encoded_elements = [cls.encode(v) for v in cast("list[object]", value)]
            print(f"A:{key}={cls.UNIT_SEP.join(encoded_elements)}")
        else:
            print(f"S:{key}={cls.encode(value)}")


# ============================================================
# Command pattern for TOML parsing
# ============================================================


class TomlCommand(ABC):
    """Base class for TOML parsing commands."""

    @abstractmethod
    def execute(self, target: str) -> None:
        """Execute the command on the given target (file or directory)."""


class WorkspaceCommand(TomlCommand):
    """Parse workspace.toml and output shell variables."""

    def execute(self, target: str) -> None:
        data = load_toml(target)
        kv = ShellEncoder.print_kv

        container = data.get("container", {})
        kv("WS_SERVICE_NAME", container.get("service_name", "dev"))
        kv("WS_USERNAME", container.get("username", "developer"))
        kv("WS_UBUNTU_VERSION", container.get("ubuntu_version", "24.04"))

        plugins = data.get("plugins", {})
        kv("WS_PLUGINS", plugins.get("enable", []))

        ports = data.get("ports", {})
        kv("WS_FORWARD_PORTS", ports.get("forward", [3000]))

        apt = data.get("apt", {})
        kv("WS_APT_EXTRA", apt.get("extra_packages", []))

        # Custom volumes: name = path
        volumes = data.get("volumes", {})
        kv("WS_VOLUME_NAMES", list(volumes.keys()))
        kv("WS_VOLUME_PATHS", list(volumes.values()))

        # VSCode extensions
        vscode = data.get("vscode", {})
        kv("WS_VSCODE_EXTENSIONS", vscode.get("extensions", []))


class PluginCommand(TomlCommand):
    """Parse a plugin TOML file and output shell variables."""

    def execute(self, target: str) -> None:
        data = load_toml(target)
        kv = ShellEncoder.print_kv

        # Plugin ID from filename
        plugin_id = os.path.splitext(os.path.basename(target))[0]
        kv("PLUGIN_ID", plugin_id)

        metadata = data.get("metadata", {})
        kv("PLUGIN_NAME", metadata.get("name", plugin_id))
        kv("PLUGIN_DESCRIPTION", metadata.get("description", ""))
        kv("PLUGIN_DEFAULT", metadata.get("default", False))

        install = data.get("install", {})
        dockerfile = install.get("dockerfile", "")
        requires_root = install.get("requires_root", False)
        kv("PLUGIN_DOCKERFILE", dockerfile)
        kv("PLUGIN_REQUIRES_ROOT", requires_root)

        apt = data.get("apt", {})
        kv("PLUGIN_APT_PACKAGES", apt.get("packages", []))

        # Validate: requires_root=true should not have USER directives
        if requires_root and "USER " in dockerfile:
            print(
                f"WARNING: Plugin '{plugin_id}' has requires_root=true but "
                "contains USER directive in dockerfile. USER wrapping is "
                "automatic — remove manual USER directives.",
                file=sys.stderr,
            )

        # Volumes: name = path
        volumes = data.get("volumes", {})
        for vol_name, vol_path in volumes.items():
            if not vol_path.startswith("/"):
                print(
                    f"WARNING: Plugin '{plugin_id}' volume '{vol_name}' has "
                    f"non-absolute path: {vol_path}",
                    file=sys.stderr,
                )
        kv("PLUGIN_VOLUME_NAMES", list(volumes.keys()))
        kv("PLUGIN_VOLUME_PATHS", list(volumes.values()))

        version = data.get("version", {})
        kv("PLUGIN_VERSION_PIN", version.get("pin", ""))
        kv("PLUGIN_VERSION_STRATEGY", version.get("strategy", "latest"))


class ListPluginsCommand(TomlCommand):
    """List all plugin TOML files with their metadata."""

    def execute(self, target: str) -> None:
        if not os.path.isdir(target):
            print(f"ERROR: Directory not found: {target}", file=sys.stderr)
            sys.exit(1)

        plugins: list[dict[str, Any]] = []
        for fname in sorted(os.listdir(target)):
            if not fname.endswith(".toml"):
                continue
            fpath = os.path.join(target, fname)
            try:
                data = load_toml(fpath)
                plugin_id = os.path.splitext(fname)[0]
                metadata = data.get("metadata", {})
                plugins.append(
                    {
                        "id": plugin_id,
                        "name": metadata.get("name", plugin_id),
                        "description": metadata.get("description", ""),
                        "default": metadata.get("default", False),
                    }
                )
            except Exception as e:
                print(
                    f"WARNING: Failed to parse {fname}: {e}",
                    file=sys.stderr,
                )

        kv = ShellEncoder.print_kv
        kv("PLUGIN_IDS", [p["id"] for p in plugins])
        kv("PLUGIN_NAMES", [p["name"] for p in plugins])
        kv("PLUGIN_DESCRIPTIONS", [p["description"] for p in plugins])
        kv("PLUGIN_DEFAULTS", [p["default"] for p in plugins])


# ============================================================
# Command registry
# ============================================================

COMMANDS: dict[str, TomlCommand] = {
    "workspace": WorkspaceCommand(),
    "plugin": PluginCommand(),
    "list-plugins": ListPluginsCommand(),
}


# Backward-compatible aliases for external imports
encode_value = ShellEncoder.encode
print_kv = ShellEncoder.print_kv


def cmd_workspace(filepath: str) -> None:
    """Backward-compatible wrapper for WorkspaceCommand."""
    WorkspaceCommand().execute(filepath)


def cmd_plugin(filepath: str) -> None:
    """Backward-compatible wrapper for PluginCommand."""
    PluginCommand().execute(filepath)


# ============================================================
# CLI
# ============================================================


def _run_cli() -> None:
    """Parse CLI arguments and dispatch to the appropriate command."""
    if len(sys.argv) >= 2 and sys.argv[1] == "--check":
        sys.exit(0)

    if len(sys.argv) < 3:
        cmds = "|".join(COMMANDS)
        print(
            f"Usage: {sys.argv[0]} <{cmds}> <file|dir>",
            file=sys.stderr,
        )
        sys.exit(1)

    command_name = sys.argv[1]
    target = sys.argv[2]

    if command_name not in COMMANDS:
        print(f"Unknown command: {command_name}", file=sys.stderr)
        sys.exit(1)

    COMMANDS[command_name].execute(target)


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
