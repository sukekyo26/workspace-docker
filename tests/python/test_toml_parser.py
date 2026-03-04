"""Tests for lib/toml_parser.py — ShellEncoder, Command pattern, and CLI."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

# Add lib/ to import path
LIB_DIR = Path(__file__).resolve().parent.parent.parent / "lib"
sys.path.insert(0, str(LIB_DIR))

from toml_parser import (
    PluginCommand,
    ShellEncoder,
    WorkspaceCommand,
    cmd_plugin,
    cmd_workspace,
)


class TestShellEncoder:
    """Test ShellEncoder.encode() — value encoding for shell safety."""

    def test_simple_string(self) -> None:
        assert ShellEncoder.encode("hello") == "hello"

    def test_string_with_backslash(self) -> None:
        assert ShellEncoder.encode("path\\to") == "path\\\\to"

    def test_string_with_newline(self) -> None:
        assert ShellEncoder.encode("line1\nline2") == "line1\\nline2"

    def test_string_with_tab(self) -> None:
        assert ShellEncoder.encode("col1\tcol2") == "col1\\tcol2"

    def test_string_with_carriage_return(self) -> None:
        assert ShellEncoder.encode("line1\rline2") == "line1\\rline2"

    def test_boolean_true(self) -> None:
        assert ShellEncoder.encode(True) == "true"

    def test_boolean_false(self) -> None:
        assert ShellEncoder.encode(False) == "false"

    def test_integer(self) -> None:
        assert ShellEncoder.encode(42) == "42"

    def test_float(self) -> None:
        assert ShellEncoder.encode(3.14) == "3.14"

    def test_list(self) -> None:
        result = ShellEncoder.encode(["a", "b", "c"])
        assert result == "a\x1fb\x1fc"

    def test_empty_list(self) -> None:
        assert ShellEncoder.encode([]) == ""

    def test_empty_string(self) -> None:
        assert ShellEncoder.encode("") == ""

    def test_multiline_dockerfile(self) -> None:
        """Multi-line Dockerfile content must be single-line output."""
        content = "RUN apt-get update && \\\n    apt-get install -y curl"
        result = ShellEncoder.encode(content)
        assert "\n" not in result
        assert "\\n" in result

    def test_unit_separator_constant(self) -> None:
        assert ShellEncoder.UNIT_SEP == "\x1f"


class TestShellEncoderPrintKv:
    """Test ShellEncoder.print_kv() — type-prefixed output."""

    def test_scalar_output(self, capsys: pytest.CaptureFixture[str]) -> None:
        ShellEncoder.print_kv("KEY", "value")
        assert capsys.readouterr().out == "S:KEY=value\n"

    def test_boolean_output(self, capsys: pytest.CaptureFixture[str]) -> None:
        ShellEncoder.print_kv("FLAG", True)
        assert capsys.readouterr().out == "S:FLAG=true\n"

    def test_array_output(self, capsys: pytest.CaptureFixture[str]) -> None:
        ShellEncoder.print_kv("LIST", ["a", "b"])
        assert capsys.readouterr().out == "A:LIST=a\x1fb\n"

    def test_empty_array_output(self, capsys: pytest.CaptureFixture[str]) -> None:
        ShellEncoder.print_kv("EMPTY", [])
        assert capsys.readouterr().out == "A:EMPTY=\n"


class TestWorkspaceCommand:
    """Test WorkspaceCommand (workspace.toml parsing)."""

    def test_basic_workspace(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write(
                '[container]\nservice_name = "test"\nusername = "dev"\n'
                'ubuntu_version = "24.04"\n\n[plugins]\nenable = ["proto"]\n\n'
                "[ports]\nforward = [3000]\n"
            )
            f.flush()
            try:
                WorkspaceCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "S:WS_SERVICE_NAME=" in output
                assert "S:WS_USERNAME=" in output
                assert "A:WS_PLUGINS=" in output
            finally:
                os.unlink(f.name)

    def test_workspace_defaults(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write("")  # Empty TOML
            f.flush()
            try:
                WorkspaceCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "S:WS_SERVICE_NAME=dev" in output
                assert "S:WS_USERNAME=developer" in output
            finally:
                os.unlink(f.name)

    def test_workspace_with_volumes(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write(
                '[container]\nservice_name = "test"\n\n'
                '[volumes]\ndata = "/home/dev/data"\n'
            )
            f.flush()
            try:
                WorkspaceCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "A:WS_VOLUME_NAMES=" in output
                assert "A:WS_VOLUME_PATHS=" in output
            finally:
                os.unlink(f.name)

    def test_backward_compat_wrapper(self, capsys: pytest.CaptureFixture[str]) -> None:
        """cmd_workspace() should delegate to WorkspaceCommand."""
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write('[container]\nservice_name = "compat"\n')
            f.flush()
            try:
                cmd_workspace(f.name)
                output = capsys.readouterr().out
                assert "S:WS_SERVICE_NAME=compat" in output
            finally:
                os.unlink(f.name)


class TestPluginCommand:
    """Test PluginCommand (plugin TOML parsing)."""

    def test_plugin_parsing(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="test-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "Test Plugin"\ndescription = "A test"\n'
                "default = true\n\n[install]\nrequires_root = false\n"
                'dockerfile = "RUN echo test"\n\n[version]\nstrategy = "latest"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "S:PLUGIN_NAME=Test Plugin" in output
                assert "S:PLUGIN_REQUIRES_ROOT=false" in output
                assert "S:PLUGIN_DOCKERFILE=" in output
            finally:
                os.unlink(f.name)

    def test_plugin_with_volumes(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="vol-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "Vol Plugin"\n\n[install]\nrequires_root = false\n'
                'dockerfile = ""\n\n[volumes]\ndata = "/home/dev/.data"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "A:PLUGIN_VOLUME_NAMES=data" in output
            finally:
                os.unlink(f.name)

    def test_requires_root_with_user_directive_warns(
        self, capsys: pytest.CaptureFixture[str],
    ) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="bad-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "Bad Plugin"\n\n[install]\nrequires_root = true\n'
                'dockerfile = "USER root\\nRUN echo test\\nUSER ${USERNAME}"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                captured = capsys.readouterr()
                assert "WARNING" in captured.err
                assert "USER" in captured.err
            finally:
                os.unlink(f.name)

    def test_requires_root_without_user_no_warning(
        self, capsys: pytest.CaptureFixture[str],
    ) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="good-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "Good Plugin"\n\n[install]\nrequires_root = true\n'
                'dockerfile = "RUN apt-get install -y curl"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                captured = capsys.readouterr()
                assert "WARNING" not in captured.err
            finally:
                os.unlink(f.name)

    def test_non_absolute_volume_path_warns(
        self, capsys: pytest.CaptureFixture[str],
    ) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="relpath-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "RelPath Plugin"\n\n[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n\n[volumes]\ndata = "relative/path"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                captured = capsys.readouterr()
                assert "WARNING" in captured.err
                assert "non-absolute" in captured.err
            finally:
                os.unlink(f.name)

    def test_absolute_volume_path_no_warning(
        self, capsys: pytest.CaptureFixture[str],
    ) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="abspath-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "AbsPath Plugin"\n\n[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n\n[volumes]\ndata = "/home/user/.data"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                captured = capsys.readouterr()
                assert "WARNING" not in captured.err
            finally:
                os.unlink(f.name)

    def test_plugin_with_apt_packages(
        self, capsys: pytest.CaptureFixture[str],
    ) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="apt-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "Apt Plugin"\n\n'
                '[apt]\npackages = ["libssl-dev", "build-essential"]\n\n'
                '[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "A:PLUGIN_APT_PACKAGES=libssl-dev" in output
                assert "build-essential" in output
            finally:
                os.unlink(f.name)

    def test_plugin_without_apt_packages(
        self, capsys: pytest.CaptureFixture[str],
    ) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="noapt-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "NoApt Plugin"\n\n'
                '[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n'
            )
            f.flush()
            try:
                PluginCommand().execute(f.name)
                output = capsys.readouterr().out
                assert "A:PLUGIN_APT_PACKAGES=" in output
            finally:
                os.unlink(f.name)

    def test_backward_compat_wrapper(self, capsys: pytest.CaptureFixture[str]) -> None:
        """cmd_plugin() should delegate to PluginCommand."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="compat-plugin-",
        ) as f:
            f.write(
                '[metadata]\nname = "Compat"\n\n'
                '[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo compat"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                output = capsys.readouterr().out
                assert "S:PLUGIN_NAME=Compat" in output
            finally:
                os.unlink(f.name)


class TestCLI:
    """Test CLI invocation via subprocess."""

    def test_workspace_cli(self) -> None:
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write('[container]\nservice_name = "cli-test"\n')
            f.flush()
            try:
                result = subprocess.run(
                    [sys.executable, str(LIB_DIR / "toml_parser.py"), "workspace", f.name],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                assert "S:WS_SERVICE_NAME=cli-test" in result.stdout
            finally:
                os.unlink(f.name)

    def test_unknown_command(self) -> None:
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "toml_parser.py"), "bad-cmd", "/dev/null"],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode != 0

    def test_missing_args(self) -> None:
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "toml_parser.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode != 0

    def test_error_handling_file_not_found(self) -> None:
        """FileNotFoundError should produce user-friendly message, not stack trace."""
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "toml_parser.py"), "workspace", "/nonexistent.toml"],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode != 0
        assert "ERROR" in result.stderr
        assert "Traceback" not in result.stderr

    def test_check_flag(self) -> None:
        """--check should exit 0 without output."""
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "toml_parser.py"), "--check"],
            capture_output=True,
            text=True,
            check=True,
        )
        assert result.returncode == 0
