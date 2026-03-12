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

import json
import os
import sys
import tomllib
import traceback
from abc import ABC, abstractmethod
from typing import Any, cast

import jsonschema

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
        kv("WS_APT_EXTRA", apt.get("packages", []))

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
        user_dirs: list[str] = install.get("user_dirs", [])
        kv("PLUGIN_DOCKERFILE", dockerfile)
        kv("PLUGIN_REQUIRES_ROOT", requires_root)
        kv("PLUGIN_USER_DIRS", user_dirs)

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

        # Volumes: array of paths, names auto-derived from basenames
        volumes: list[str] = install.get("volumes", [])
        vol_names: list[str] = []
        for vol_path in volumes:
            if not vol_path.startswith("/"):
                print(
                    f"WARNING: Plugin '{plugin_id}' has "
                    f"non-absolute volume path: {vol_path}",
                    file=sys.stderr,
                )
            # Derive name: basename, strip leading dot
            basename = vol_path.rstrip("/").rsplit("/", 1)[-1]
            vol_names.append(basename.lstrip("."))
        kv("PLUGIN_VOLUME_NAMES", vol_names)
        kv("PLUGIN_VOLUME_PATHS", volumes)

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
            except (tomllib.TOMLDecodeError, OSError) as e:
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
# Validation commands
# ============================================================


def _load_schema(schema_name: str) -> dict[str, Any]:
    """Load a JSON Schema file from the schemas/ directory."""
    lib_dir = os.path.dirname(os.path.abspath(__file__))
    schema_path = os.path.join(lib_dir, "..", "schemas", schema_name)
    with open(schema_path, encoding="utf-8") as f:
        return json.load(f)  # type: ignore[no-any-return]


def _format_validation_error(error: jsonschema.ValidationError) -> str:
    """Format a jsonschema ValidationError into a human-readable message."""
    path = ".".join(str(p) for p in error.absolute_path) if error.absolute_path else "(root)"
    return f"  {path}: {error.message}"


class ValidateWorkspaceCommand(TomlCommand):
    """Validate workspace.toml against the JSON Schema."""

    def execute(self, target: str) -> None:
        data = load_toml(target)
        schema = _load_schema("workspace.schema.json")

        errors = list(jsonschema.Draft7Validator(schema).iter_errors(data))  # pyright: ignore[reportUnknownMemberType]
        if not errors:
            print(f"OK: {target} is valid")
            return

        for error in sorted(errors, key=lambda e: list(e.absolute_path)):
            print(f"ERROR: {target}: {_format_validation_error(error)}", file=sys.stderr)
        sys.exit(1)


class ValidatePluginsCommand(TomlCommand):
    """Validate all plugin TOML files in a directory against the plugin schema."""

    def execute(self, target: str) -> None:
        if not os.path.isdir(target):
            print(f"ERROR: Directory not found: {target}", file=sys.stderr)
            sys.exit(1)

        schema = _load_schema("plugin.schema.json")
        validator = jsonschema.Draft7Validator(schema)
        has_errors = False
        validated = 0

        for fname in sorted(os.listdir(target)):
            if not fname.endswith(".toml"):
                continue
            fpath = os.path.join(target, fname)
            try:
                data = load_toml(fpath)
            except (tomllib.TOMLDecodeError, OSError) as e:
                print(f"ERROR: {fname}: Failed to parse: {e}", file=sys.stderr)
                has_errors = True
                continue

            errors = list(validator.iter_errors(data))  # pyright: ignore[reportUnknownMemberType]
            if errors:
                for error in sorted(errors, key=lambda e: list(e.absolute_path)):
                    print(f"ERROR: {fname}: {_format_validation_error(error)}", file=sys.stderr)
                has_errors = True
            validated += 1

        if has_errors:
            sys.exit(1)
        print(f"OK: {validated} plugins validated")


class SyncSchemaCommand(TomlCommand):
    """Sync workspace.schema.json plugins enum from plugins/ directory."""

    def execute(self, target: str) -> None:
        if not os.path.isdir(target):
            print(f"ERROR: Directory not found: {target}", file=sys.stderr)
            sys.exit(1)

        plugin_ids = sorted(
            fname.removesuffix(".toml")
            for fname in os.listdir(target)
            if fname.endswith(".toml")
        )

        schema_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "..", "schemas", "workspace.schema.json"
        )
        with open(schema_path, encoding="utf-8") as f:
            schema = json.load(f)

        schema["properties"]["plugins"]["properties"]["enable"]["items"]["enum"] = plugin_ids

        with open(schema_path, "w", encoding="utf-8") as f:
            json.dump(schema, f, indent=2, ensure_ascii=False)
            f.write("\n")


class HasSectionCommand(TomlCommand):
    """Check if a TOML section exists in a file.

    Usage: has-section <file> (reads section name from sys.argv[3])
    Prints 'true' or 'false'.
    """

    def execute(self, target: str) -> None:
        if len(sys.argv) < 4:
            print("ERROR: has-section requires a section name argument", file=sys.stderr)
            sys.exit(1)
        section = sys.argv[3]
        data = load_toml(target)
        print("true" if section in data else "false")


class DumpDevcontainerCommand(TomlCommand):
    """Dump [devcontainer] section as TOML text for preservation.

    Reads workspace.toml and outputs the [devcontainer] section
    as valid TOML that can be appended to a regenerated file.
    """

    def execute(self, target: str) -> None:
        data = load_toml(target)
        dc = data.get("devcontainer")
        if not dc:
            return
        lines = self._to_toml(dc, prefix="devcontainer")
        print("\n".join(lines))

    @staticmethod
    def _to_toml(obj: dict[str, Any], prefix: str) -> list[str]:
        """Convert a nested dict to TOML lines."""
        lines: list[str] = []
        scalars: list[str] = []
        tables: list[tuple[str, dict[str, Any]]] = []

        for key, val in obj.items():
            if isinstance(val, dict):
                tables.append((key, cast("dict[str, Any]", val)))
            else:
                scalars.append(f"{key} = {DumpDevcontainerCommand._to_toml_value(val)}")

        if scalars:
            lines.append(f"[{prefix}]")
            lines.extend(scalars)

        for key, val in tables:
            lines.extend(DumpDevcontainerCommand._to_toml(val, f"{prefix}.{key}"))

        return lines

    @staticmethod
    def _to_toml_value(val: Any) -> str:
        """Convert a Python value to a TOML value string."""
        if isinstance(val, bool):
            return "true" if val else "false"
        if isinstance(val, int):
            return str(val)
        if isinstance(val, float):
            return str(val)
        if isinstance(val, str):
            escaped = val.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
            return f'"{escaped}"'
        if isinstance(val, list):
            items = ", ".join(DumpDevcontainerCommand._to_toml_value(v) for v in cast("list[object]", val))
            return f"[{items}]"
        return f'"{val}"'


# ============================================================
# Command registry
# ============================================================

COMMANDS: dict[str, TomlCommand] = {
    "workspace": WorkspaceCommand(),
    "plugin": PluginCommand(),
    "list-plugins": ListPluginsCommand(),
    "validate-workspace": ValidateWorkspaceCommand(),
    "validate-plugins": ValidatePluginsCommand(),
    "sync-schema": SyncSchemaCommand(),
    "has-section": HasSectionCommand(),
    "dump-devcontainer": DumpDevcontainerCommand(),
}


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
    verbose = "--verbose" in sys.argv
    if verbose:
        sys.argv.remove("--verbose")
    try:
        _run_cli()
    except FileNotFoundError as e:
        print(
            f"ERROR: File not found: {e.filename or e}",
            file=sys.stderr,
        )
        if verbose:
            traceback.print_exc()
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        if verbose:
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
