"""Tests for JSON Schema validation — ValidateWorkspaceCommand and ValidatePluginsCommand.

Covers:
  - Valid workspace.toml acceptance
  - Invalid workspace.toml rejection (missing required, wrong types, unknown keys)
  - Valid plugin TOML acceptance
  - Invalid plugin TOML rejection
  - _format_validation_error output
  - CLI integration (exit codes)
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

LIB_DIR = Path(__file__).resolve().parent.parent.parent / "lib"
PROJECT_ROOT = LIB_DIR.parent
sys.path.insert(0, str(LIB_DIR))

from toml_parser import (
    ValidatePluginsCommand,
    ValidateWorkspaceCommand,
    _format_validation_error,
)


# ============================================================
# Helpers
# ============================================================


def _write_toml(content: str, *, suffix: str = ".toml") -> str:
    """Write TOML content to a temp file and return the path."""
    f = tempfile.NamedTemporaryFile(suffix=suffix, mode="w", delete=False)
    f.write(content)
    f.flush()
    f.close()
    return f.name


VALID_WORKSPACE_TOML = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["docker-cli"]

[ports]
forward = [3000]
"""

VALID_PLUGIN_TOML = """\
[metadata]
name = "Test Plugin"
description = "A test plugin"
default = false

[install]
requires_root = false
dockerfile = "RUN echo test"
"""


# ============================================================
# ValidateWorkspaceCommand
# ============================================================


class TestValidateWorkspaceValid:
    """Valid workspace.toml should be accepted."""

    def test_minimal_valid(self, capsys: pytest.CaptureFixture[str]) -> None:
        path = _write_toml(VALID_WORKSPACE_TOML)
        try:
            ValidateWorkspaceCommand().execute(path)
            assert "OK" in capsys.readouterr().out
        finally:
            os.unlink(path)

    def test_with_optional_sections(self, capsys: pytest.CaptureFixture[str]) -> None:
        content = VALID_WORKSPACE_TOML + """
[apt]
packages = ["jq", "tree"]

[vscode]
extensions = ["eamodio.gitlens"]

[volumes]
data = "/home/testuser/data"

[devcontainer]
remoteUser = "testuser"
"""
        path = _write_toml(content)
        try:
            ValidateWorkspaceCommand().execute(path)
            assert "OK" in capsys.readouterr().out
        finally:
            os.unlink(path)

    def test_empty_plugins(self, capsys: pytest.CaptureFixture[str]) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            ValidateWorkspaceCommand().execute(path)
            assert "OK" in capsys.readouterr().out
        finally:
            os.unlink(path)

    def test_multiple_ports(self, capsys: pytest.CaptureFixture[str]) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000, 8080, 5432]
"""
        path = _write_toml(content)
        try:
            ValidateWorkspaceCommand().execute(path)
            assert "OK" in capsys.readouterr().out
        finally:
            os.unlink(path)


class TestValidateWorkspaceInvalid:
    """Invalid workspace.toml should be rejected."""

    def test_missing_container(self) -> None:
        content = """\
[plugins]
enable = []

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_missing_plugins(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_missing_ports(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_invalid_service_name_uppercase(self) -> None:
        content = """\
[container]
service_name = "Dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_invalid_username_starts_with_digit(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "1user"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_invalid_ubuntu_version(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "latest"

[plugins]
enable = []

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_invalid_plugin_name(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["nonexistent-plugin"]

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_port_out_of_range(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [70000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_port_string_instead_of_int(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = ["3000"]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_additional_properties_rejected(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]

[unknown_section]
key = "value"
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_duplicate_plugins(self) -> None:
        # TOML itself doesn't allow duplicate array items with identical strings,
        # but the schema enforces uniqueItems
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["docker-cli", "docker-cli"]

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_invalid_vscode_extension_format(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = []

[ports]
forward = [3000]

[vscode]
extensions = ["not a valid extension id!"]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)

    def test_container_additional_properties_rejected(self) -> None:
        content = """\
[container]
service_name = "dev"
username = "testuser"
ubuntu_version = "24.04"
extra_field = "not allowed"

[plugins]
enable = []

[ports]
forward = [3000]
"""
        path = _write_toml(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidateWorkspaceCommand().execute(path)
        finally:
            os.unlink(path)


# ============================================================
# ValidatePluginsCommand
# ============================================================


class TestValidatePluginsValid:
    """Valid plugin TOMLs should be accepted."""

    def test_single_valid_plugin(self, capsys: pytest.CaptureFixture[str]) -> None:
        tmpdir = tempfile.mkdtemp()
        plugin_path = os.path.join(tmpdir, "test-plugin.toml")
        with open(plugin_path, "w") as f:
            f.write(VALID_PLUGIN_TOML)
        try:
            ValidatePluginsCommand().execute(tmpdir)
            assert "OK: 1 plugins validated" in capsys.readouterr().out
        finally:
            os.unlink(plugin_path)
            os.rmdir(tmpdir)

    def test_multiple_valid_plugins(self, capsys: pytest.CaptureFixture[str]) -> None:
        tmpdir = tempfile.mkdtemp()
        for name in ["alpha.toml", "beta.toml"]:
            with open(os.path.join(tmpdir, name), "w") as f:
                f.write(VALID_PLUGIN_TOML)
        try:
            ValidatePluginsCommand().execute(tmpdir)
            assert "OK: 2 plugins validated" in capsys.readouterr().out
        finally:
            for name in ["alpha.toml", "beta.toml"]:
                os.unlink(os.path.join(tmpdir, name))
            os.rmdir(tmpdir)

    def test_plugin_with_optional_fields(self, capsys: pytest.CaptureFixture[str]) -> None:
        content = """\
[metadata]
name = "Full Plugin"
description = "A full plugin"
default = true
conflicts = ["other-plugin"]

[apt]
packages = ["curl", "jq"]

[install]
requires_root = true
user_dirs = ["/home/dev/.config"]
dockerfile = "RUN echo install"
volumes = ["/home/${USERNAME}/.data"]

[version]
strategy = "pinned"
pin = "1.2.3"
checksum_amd64 = "abc123"
checksum_arm64 = "def456"
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "full.toml"), "w") as f:
            f.write(content)
        try:
            ValidatePluginsCommand().execute(tmpdir)
            assert "OK: 1 plugins validated" in capsys.readouterr().out
        finally:
            os.unlink(os.path.join(tmpdir, "full.toml"))
            os.rmdir(tmpdir)

    def test_non_toml_files_ignored(self, capsys: pytest.CaptureFixture[str]) -> None:
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "readme.md"), "w") as f:
            f.write("# Not a plugin")
        with open(os.path.join(tmpdir, "valid.toml"), "w") as f:
            f.write(VALID_PLUGIN_TOML)
        try:
            ValidatePluginsCommand().execute(tmpdir)
            out = capsys.readouterr().out
            assert "OK: 1 plugins validated" in out
        finally:
            os.unlink(os.path.join(tmpdir, "readme.md"))
            os.unlink(os.path.join(tmpdir, "valid.toml"))
            os.rmdir(tmpdir)

    def test_real_plugins_valid(self, capsys: pytest.CaptureFixture[str]) -> None:
        """All real plugin TOMLs in the project must pass validation."""
        plugins_dir = str(PROJECT_ROOT / "plugins")
        ValidatePluginsCommand().execute(plugins_dir)
        out = capsys.readouterr().out
        assert "OK:" in out


class TestValidatePluginsInvalid:
    """Invalid plugin TOMLs should be rejected."""

    def test_missing_metadata(self) -> None:
        content = """\
[install]
requires_root = false
dockerfile = "RUN echo test"
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)

    def test_missing_install(self) -> None:
        content = """\
[metadata]
name = "Bad"
description = "Missing install"
default = false
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)

    def test_missing_requires_root(self) -> None:
        content = """\
[metadata]
name = "Bad"
description = "Missing requires_root"
default = false

[install]
dockerfile = "RUN echo test"
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)

    def test_invalid_version_strategy(self) -> None:
        content = """\
[metadata]
name = "Bad"
description = "Bad version"
default = false

[install]
requires_root = false

[version]
strategy = "invalid"
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)

    def test_additional_properties_rejected(self) -> None:
        content = """\
[metadata]
name = "Bad"
description = "Extra section"
default = false

[install]
requires_root = false

[custom_section]
key = "value"
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)

    def test_invalid_volume_path(self) -> None:
        content = """\
[metadata]
name = "Bad"
description = "Bad volume"
default = false

[install]
requires_root = false
volumes = ["/tmp/bad-path"]
"""
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write(content)
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)

    def test_directory_not_found(self) -> None:
        with pytest.raises(SystemExit, match="1"):
            ValidatePluginsCommand().execute("/nonexistent/dir")

    def test_malformed_toml(self) -> None:
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write("this is not valid TOML [[[")
        try:
            with pytest.raises(SystemExit, match="1"):
                ValidatePluginsCommand().execute(tmpdir)
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)


# ============================================================
# _format_validation_error
# ============================================================


class TestFormatValidationError:
    """Test error message formatting."""

    def test_root_path(self) -> None:
        import jsonschema

        error = jsonschema.ValidationError("test message")
        result = _format_validation_error(error)
        assert "(root)" in result
        assert "test message" in result

    def test_nested_path(self) -> None:
        import jsonschema

        error = jsonschema.ValidationError(
            "bad value",
            path=["container", "service_name"],
        )
        # jsonschema uses deque for absolute_path; set it manually
        result = _format_validation_error(error)
        assert "bad value" in result


# ============================================================
# CLI integration
# ============================================================


class TestValidationCLI:
    """Test validation via CLI subprocess."""

    def test_validate_workspace_valid(self) -> None:
        path = _write_toml(VALID_WORKSPACE_TOML)
        try:
            result = subprocess.run(
                [sys.executable, str(LIB_DIR / "toml_parser.py"), "validate-workspace", path],
                capture_output=True,
                text=True,
                check=False,
            )
            assert result.returncode == 0
            assert "OK" in result.stdout
        finally:
            os.unlink(path)

    def test_validate_workspace_invalid(self) -> None:
        path = _write_toml("[plugins]\nenable = []\n")
        try:
            result = subprocess.run(
                [sys.executable, str(LIB_DIR / "toml_parser.py"), "validate-workspace", path],
                capture_output=True,
                text=True,
                check=False,
            )
            assert result.returncode == 1
            assert "ERROR" in result.stderr
        finally:
            os.unlink(path)

    def test_validate_plugins_valid(self) -> None:
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "test.toml"), "w") as f:
            f.write(VALID_PLUGIN_TOML)
        try:
            result = subprocess.run(
                [sys.executable, str(LIB_DIR / "toml_parser.py"), "validate-plugins", tmpdir],
                capture_output=True,
                text=True,
                check=False,
            )
            assert result.returncode == 0
            assert "OK" in result.stdout
        finally:
            os.unlink(os.path.join(tmpdir, "test.toml"))
            os.rmdir(tmpdir)

    def test_validate_plugins_invalid(self) -> None:
        tmpdir = tempfile.mkdtemp()
        with open(os.path.join(tmpdir, "bad.toml"), "w") as f:
            f.write("[metadata]\nname = 123\n")  # name should be string
        try:
            result = subprocess.run(
                [sys.executable, str(LIB_DIR / "toml_parser.py"), "validate-plugins", tmpdir],
                capture_output=True,
                text=True,
                check=False,
            )
            assert result.returncode == 1
            assert "ERROR" in result.stderr
        finally:
            os.unlink(os.path.join(tmpdir, "bad.toml"))
            os.rmdir(tmpdir)
