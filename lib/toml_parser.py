#!/usr/bin/env python3
"""TOML parser helper for workspace-docker.

Parses workspace.toml and plugin TOML files, outputting shell-safe key=value pairs.

Usage:
    python3 lib/toml_parser.py workspace <file>
    python3 lib/toml_parser.py plugin <file>
    python3 lib/toml_parser.py list-plugins <dir>

Requires Python 3.11+ (tomllib) or tomli package for older versions.
"""

import sys
import os

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        print(
            "ERROR: No TOML parser available. "
            "Python 3.11+ includes tomllib. "
            "For older Python, run: pip install tomli",
            file=sys.stderr,
        )
        sys.exit(1)


def shell_quote(value):
    """Quote a value for safe use in shell eval."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        # Output as space-separated, parenthesized bash array
        items = " ".join(shell_quote(v) for v in value)
        return f"({items})"
    s = str(value)
    return "'" + s.replace("'", "'\\''") + "'"


def print_kv(key, value):
    """Print a shell-safe key=value pair."""
    print(f"{key}={shell_quote(value)}")


def cmd_workspace(filepath):
    """Parse workspace.toml and output shell variables."""
    with open(filepath, "rb") as f:
        data = tomllib.load(f)

    container = data.get("container", {})
    print_kv("WS_SERVICE_NAME", container.get("service_name", "dev"))
    print_kv("WS_USERNAME", container.get("username", "developer"))
    print_kv("WS_UBUNTU_VERSION", container.get("ubuntu_version", "24.04"))

    plugins = data.get("plugins", {})
    print_kv("WS_PLUGINS", plugins.get("enable", []))

    ports = data.get("ports", {})
    forward = ports.get("forward", [3000])
    print_kv("WS_FORWARD_PORTS", forward)

    apt = data.get("apt", {})
    print_kv("WS_APT_EXTRA", apt.get("extra_packages", []))

    # Custom volumes: name = path
    volumes = data.get("volumes", {})
    vol_names = list(volumes.keys())
    vol_paths = list(volumes.values())
    print_kv("WS_VOLUME_NAMES", vol_names)
    print_kv("WS_VOLUME_PATHS", vol_paths)

    # Environment variables
    env = data.get("environment", {})
    env_keys = list(env.keys())
    env_vals = list(str(v) for v in env.values())
    print_kv("WS_ENV_KEYS", env_keys)
    print_kv("WS_ENV_VALS", env_vals)


def cmd_plugin(filepath):
    """Parse a plugin TOML file and output shell variables."""
    with open(filepath, "rb") as f:
        data = tomllib.load(f)

    # Plugin ID from filename (e.g., plugins/aws-cli.toml -> aws-cli)
    plugin_id = os.path.splitext(os.path.basename(filepath))[0]
    print_kv("PLUGIN_ID", plugin_id)

    metadata = data.get("metadata", {})
    print_kv("PLUGIN_NAME", metadata.get("name", plugin_id))
    print_kv("PLUGIN_DESCRIPTION", metadata.get("description", ""))
    print_kv("PLUGIN_DEFAULT", metadata.get("default", False))

    install = data.get("install", {})
    print_kv("PLUGIN_DOCKERFILE", install.get("dockerfile", ""))
    print_kv("PLUGIN_REQUIRES_ROOT", install.get("requires_root", False))

    # Volumes: name = path
    volumes = data.get("volumes", {})
    vol_names = list(volumes.keys())
    vol_paths = list(volumes.values())
    print_kv("PLUGIN_VOLUME_NAMES", vol_names)
    print_kv("PLUGIN_VOLUME_PATHS", vol_paths)

    version = data.get("version", {})
    print_kv("PLUGIN_VERSION_PIN", version.get("pin", ""))
    print_kv("PLUGIN_VERSION_STRATEGY", version.get("strategy", "latest"))


def cmd_list_plugins(dirpath):
    """List all plugin TOML files with their metadata."""
    if not os.path.isdir(dirpath):
        print(f"ERROR: Directory not found: {dirpath}", file=sys.stderr)
        sys.exit(1)

    plugins = []
    for fname in sorted(os.listdir(dirpath)):
        if not fname.endswith(".toml"):
            continue
        filepath = os.path.join(dirpath, fname)
        try:
            with open(filepath, "rb") as f:
                data = tomllib.load(f)
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
            print(f"WARNING: Failed to parse {fname}: {e}", file=sys.stderr)

    # Output as parallel arrays for bash
    ids = [p["id"] for p in plugins]
    names = [p["name"] for p in plugins]
    descriptions = [p["description"] for p in plugins]
    defaults = [p["default"] for p in plugins]

    print_kv("PLUGIN_IDS", ids)
    print_kv("PLUGIN_NAMES", names)
    print_kv("PLUGIN_DESCRIPTIONS", descriptions)
    print_kv("PLUGIN_DEFAULTS", defaults)


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <workspace|plugin|list-plugins> <file|dir>", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]
    target = sys.argv[2]

    if command == "workspace":
        cmd_workspace(target)
    elif command == "plugin":
        cmd_plugin(target)
    elif command == "list-plugins":
        cmd_list_plugins(target)
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
