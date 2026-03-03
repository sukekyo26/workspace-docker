"""Tests for lib/generators.py."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

# Add lib/ to import path
LIB_DIR = Path(__file__).resolve().parent.parent.parent / "lib"
sys.path.insert(0, str(LIB_DIR))

from generators import (
    generate_compose,
    generate_devcontainer_compose,
    generate_devcontainer_json,
    get_plugin_volumes,
    load_toml,
)


@pytest.fixture()
def plugins_dir(tmp_path: Path) -> str:
    """Create a temporary plugins directory with test plugins."""
    plugins = tmp_path / "plugins"
    plugins.mkdir()

    # Plugin with volumes
    (plugins / "test-plugin.toml").write_text(
        '[metadata]\nname = "Test Plugin"\ndescription = "test"\ndefault = false\n\n'
        "[install]\nrequires_root = false\n"
        'dockerfile = "RUN echo test"\n\n'
        '[volumes]\ntest-data = "/home/${USERNAME}/.test"\n\n'
        "[version]\nstrategy = \"latest\"\n"
    )

    # Plugin without volumes
    (plugins / "no-vol.toml").write_text(
        '[metadata]\nname = "No Vol"\n\n[install]\nrequires_root = false\n'
        'dockerfile = "RUN echo novol"\n\n[version]\nstrategy = "latest"\n'
    )
    return str(plugins)


@pytest.fixture()
def workspace_data() -> dict[str, object]:
    """Minimal workspace data."""
    return {
        "container": {"service_name": "test-svc", "username": "testuser", "ubuntu_version": "24.04"},
        "plugins": {"enable": ["test-plugin"]},
        "ports": {"forward": [3000]},
        "volumes": {},
        "vscode": {"extensions": ["ms-python.python"]},
    }


class TestLoadToml:
    """Test load_toml function."""

    def test_load_valid(self, tmp_path: Path) -> None:
        f = tmp_path / "test.toml"
        f.write_text('[container]\nservice_name = "test"\n')
        data = load_toml(str(f))
        assert data["container"]["service_name"] == "test"  # type: ignore[index]

    def test_load_nonexistent(self) -> None:
        with pytest.raises(FileNotFoundError):
            load_toml("/nonexistent/path.toml")


class TestGetPluginVolumes:
    """Test get_plugin_volumes function."""

    def test_with_volumes(self, plugins_dir: str) -> None:
        vols = get_plugin_volumes(plugins_dir, ["test-plugin"])
        assert len(vols) == 1
        name, vol_name, vol_path = vols[0]
        assert name == "Test Plugin"
        assert vol_name == "test-data"
        assert "${USERNAME}" in vol_path

    def test_without_volumes(self, plugins_dir: str) -> None:
        vols = get_plugin_volumes(plugins_dir, ["no-vol"])
        assert len(vols) == 0

    def test_nonexistent_plugin(self, plugins_dir: str) -> None:
        vols = get_plugin_volumes(plugins_dir, ["does-not-exist"])
        assert len(vols) == 0


class TestGenerateCompose:
    """Test generate_compose function."""

    def test_basic_structure(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_compose(workspace_data, plugins_dir)
        assert "services:" in output
        assert "test-svc:" in output
        assert "volumes:" in output
        assert "UBUNTU_VERSION" in output

    def test_plugin_volumes_included(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_compose(workspace_data, plugins_dir)
        assert "test-data:" in output  # volume mount
        assert "CONTAINER_SERVICE_NAME}_test-data" in output  # volume definition

    def test_custom_volumes(self, plugins_dir: str) -> None:
        data: dict[str, object] = {
            "container": {"service_name": "cv-test", "username": "user"},
            "plugins": {"enable": []},
            "ports": {"forward": [8080]},
            "volumes": {"mydata": "/home/user/data"},
        }
        output = generate_compose(data, plugins_dir)
        assert "mydata:" in output

    def test_trailing_newline(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_compose(workspace_data, plugins_dir)
        assert output.endswith("\n")


class TestGenerateDevcontainerJson:
    """Test generate_devcontainer_json function."""

    def test_basic_structure(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_json(workspace_data, plugins_dir)
        assert '"name"' in output
        assert '"service"' in output
        assert '"test-svc"' in output
        assert '"forwardPorts"' in output

    def test_extensions(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_json(workspace_data, plugins_dir)
        assert '"ms-python.python"' in output

    def test_jsonc_with_comments(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_json(workspace_data, plugins_dir)
        assert "//" in output  # JSONC comments

    def test_json_valid_after_stripping_comments(
        self, workspace_data: dict[str, object], plugins_dir: str
    ) -> None:
        """JSONC should be valid JSON after stripping // comments."""
        import re

        output = generate_devcontainer_json(workspace_data, plugins_dir)
        stripped = re.sub(r"//.*", "", output)
        # Should not raise
        json.loads(stripped)

    def test_workspace_folder(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_json(workspace_data, plugins_dir)
        assert '"/home/testuser/workspace"' in output


class TestGenerateDevcontainerCompose:
    """Test generate_devcontainer_compose function."""

    def test_basic_structure(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_compose(workspace_data, plugins_dir)
        assert "services:" in output
        assert "test-svc:" in output
        assert "sleep infinity" in output

    def test_docker_socket_mount(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_compose(workspace_data, plugins_dir)
        assert "/var/run/docker.sock" in output

    def test_docker_gid(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = generate_devcontainer_compose(workspace_data, plugins_dir)
        assert "DOCKER_GID" in output


class TestCLI:
    """Test CLI invocation."""

    @pytest.fixture()
    def workspace_toml(self, tmp_path: Path, plugins_dir: str) -> str:
        f = tmp_path / "workspace.toml"
        f.write_text(
            '[container]\nservice_name = "cli-test"\nusername = "u"\n'
            'ubuntu_version = "24.04"\n\n[plugins]\nenable = []\n\n'
            "[ports]\nforward = [3000]\n"
        )
        return str(f)

    def test_compose_cli(self, workspace_toml: str, plugins_dir: str) -> None:
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "generators.py"), "compose", workspace_toml, plugins_dir],
            capture_output=True,
            text=True,
            check=True,
        )
        assert "services:" in result.stdout

    def test_devcontainer_json_cli(self, workspace_toml: str, plugins_dir: str) -> None:
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "generators.py"), "devcontainer-json", workspace_toml, plugins_dir],
            capture_output=True,
            text=True,
            check=True,
        )
        assert '"name"' in result.stdout

    def test_devcontainer_compose_cli(self, workspace_toml: str, plugins_dir: str) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(LIB_DIR / "generators.py"),
                "devcontainer-compose",
                workspace_toml,
                plugins_dir,
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        assert "services:" in result.stdout

    def test_unknown_command(self, workspace_toml: str, plugins_dir: str) -> None:
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "generators.py"), "bad", workspace_toml, plugins_dir],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode != 0

    def test_missing_args(self) -> None:
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "generators.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode != 0
