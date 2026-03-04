"""Tests for lib/toml_parser.py."""

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

from toml_parser import cmd_plugin, cmd_workspace, encode_value


class TestEncodeValue:
    """Test encode_value function."""

    def test_simple_string(self) -> None:
        result = encode_value("hello")
        assert result == "hello"

    def test_string_with_backslash(self) -> None:
        result = encode_value("path\\to")
        assert result == "path\\\\to"

    def test_string_with_newline(self) -> None:
        result = encode_value("line1\nline2")
        assert result == "line1\\nline2"

    def test_string_with_tab(self) -> None:
        result = encode_value("col1\tcol2")
        assert result == "col1\\tcol2"

    def test_string_with_carriage_return(self) -> None:
        result = encode_value("line1\rline2")
        assert result == "line1\\rline2"

    def test_boolean_true(self) -> None:
        assert encode_value(True) == "true"

    def test_boolean_false(self) -> None:
        assert encode_value(False) == "false"

    def test_integer(self) -> None:
        assert encode_value(42) == "42"

    def test_float(self) -> None:
        assert encode_value(3.14) == "3.14"

    def test_list(self) -> None:
        result = encode_value(["a", "b", "c"])
        assert result == "a\x1fb\x1fc"

    def test_empty_list(self) -> None:
        assert encode_value([]) == ""

    def test_empty_string(self) -> None:
        assert encode_value("") == ""

    def test_multiline_dockerfile(self) -> None:
        """Multi-line Dockerfile content must be single-line output."""
        content = "RUN apt-get update && \\\n    apt-get install -y curl"
        result = encode_value(content)
        assert "\n" not in result
        assert "\\n" in result


class TestCmdWorkspace:
    """Test cmd_workspace function (workspace.toml parsing)."""

    def test_basic_workspace(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write(
                '[container]\nservice_name = "test"\nusername = "dev"\n'
                'ubuntu_version = "24.04"\n\n[plugins]\nenable = ["proto"]\n\n'
                "[ports]\nforward = [3000]\n"
            )
            f.flush()
            try:
                cmd_workspace(f.name)
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
                cmd_workspace(f.name)
                output = capsys.readouterr().out
                assert "S:WS_SERVICE_NAME=dev" in output  # default service_name
                assert "S:WS_USERNAME=developer" in output  # default username
            finally:
                os.unlink(f.name)

    def test_workspace_with_volumes(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write(
                '[container]\nservice_name = "test"\n\n'
                "[volumes]\ndata = \"/home/dev/data\"\n"
            )
            f.flush()
            try:
                cmd_workspace(f.name)
                output = capsys.readouterr().out
                assert "A:WS_VOLUME_NAMES=" in output
                assert "A:WS_VOLUME_PATHS=" in output
            finally:
                os.unlink(f.name)


class TestCmdPlugin:
    """Test cmd_plugin function (plugin TOML parsing)."""

    def test_plugin_parsing(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="test-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "Test Plugin"\ndescription = "A test"\n'
                "default = true\n\n[install]\nrequires_root = false\n"
                'dockerfile = "RUN echo test"\n\n[version]\nstrategy = "latest"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                output = capsys.readouterr().out
                assert "S:PLUGIN_NAME=Test Plugin" in output
                assert "S:PLUGIN_REQUIRES_ROOT=false" in output
                assert "S:PLUGIN_DOCKERFILE=" in output
            finally:
                os.unlink(f.name)

    def test_plugin_with_volumes(self, capsys: pytest.CaptureFixture[str]) -> None:
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="vol-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "Vol Plugin"\n\n[install]\nrequires_root = false\n'
                'dockerfile = ""\n\n[volumes]\ndata = "/home/dev/.data"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                output = capsys.readouterr().out
                assert "A:PLUGIN_VOLUME_NAMES=data" in output
            finally:
                os.unlink(f.name)

    def test_requires_root_with_user_directive_warns(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """requires_root=true + manual USER directive should produce a warning."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="bad-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "Bad Plugin"\n\n[install]\nrequires_root = true\n'
                'dockerfile = "USER root\\nRUN echo test\\nUSER ${USERNAME}"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                captured = capsys.readouterr()
                assert "WARNING" in captured.err
                assert "USER" in captured.err
            finally:
                os.unlink(f.name)

    def test_requires_root_without_user_no_warning(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """requires_root=true without USER directive should NOT produce a warning."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="good-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "Good Plugin"\n\n[install]\nrequires_root = true\n'
                'dockerfile = "RUN apt-get install -y curl"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                captured = capsys.readouterr()
                assert "WARNING" not in captured.err
            finally:
                os.unlink(f.name)

    def test_non_absolute_volume_path_warns(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Non-absolute volume paths should produce a warning."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="relpath-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "RelPath Plugin"\n\n[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n\n[volumes]\ndata = "relative/path"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                captured = capsys.readouterr()
                assert "WARNING" in captured.err
                assert "non-absolute" in captured.err
            finally:
                os.unlink(f.name)

    def test_absolute_volume_path_no_warning(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Absolute volume paths should NOT produce a warning."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="abspath-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "AbsPath Plugin"\n\n[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n\n[volumes]\ndata = "/home/user/.data"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                captured = capsys.readouterr()
                assert "WARNING" not in captured.err
            finally:
                os.unlink(f.name)

    def test_plugin_with_apt_packages(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Plugin with [apt] packages should output PLUGIN_APT_PACKAGES."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="apt-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "Apt Plugin"\n\n'
                '[apt]\npackages = ["libssl-dev", "build-essential"]\n\n'
                '[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                output = capsys.readouterr().out
                assert "A:PLUGIN_APT_PACKAGES=libssl-dev" in output
                assert "build-essential" in output
            finally:
                os.unlink(f.name)

    def test_plugin_without_apt_packages(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Plugin without [apt] section should output empty PLUGIN_APT_PACKAGES."""
        with tempfile.NamedTemporaryFile(
            suffix=".toml", mode="w", delete=False, prefix="noapt-plugin-"
        ) as f:
            f.write(
                '[metadata]\nname = "NoApt Plugin"\n\n'
                '[install]\nrequires_root = false\n'
                'dockerfile = "RUN echo test"\n'
            )
            f.flush()
            try:
                cmd_plugin(f.name)
                output = capsys.readouterr().out
                assert "A:PLUGIN_APT_PACKAGES=" in output
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
