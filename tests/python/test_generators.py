"""Tests for lib/generators.py — class-based generator architecture."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

# Add lib/ to import path
LIB_DIR = Path(__file__).resolve().parent.parent.parent / "lib"
sys.path.insert(0, str(LIB_DIR))

from generators import (
    ComposeGenerator,
    DevcontainerComposeGenerator,
    DevcontainerJsonGenerator,
    DockerfileGenerator,
    Generator,
)
from toml_parser import load_toml


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

    # Plugin with apt packages
    (plugins / "apt-plugin.toml").write_text(
        '[metadata]\nname = "Apt Plugin"\n\n'
        '[apt]\npackages = ["libfoo-dev", "libbar-dev"]\n\n'
        '[install]\nrequires_root = false\n'
        'dockerfile = "RUN echo apt-plugin"\n\n'
        '[version]\nstrategy = "latest"\n'
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


class TestGeneratorBase:
    """Test Generator base class properties and methods."""

    def test_service_name(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        gen = ComposeGenerator(workspace_data, plugins_dir)
        assert gen.service_name == "test-svc"

    def test_username(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        gen = ComposeGenerator(workspace_data, plugins_dir)
        assert gen.username == "testuser"

    def test_enabled_plugins(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        gen = ComposeGenerator(workspace_data, plugins_dir)
        assert gen.enabled_plugins == ["test-plugin"]

    def test_defaults(self, plugins_dir: str) -> None:
        gen = ComposeGenerator({}, plugins_dir)
        assert gen.service_name == "dev"
        assert gen.username == "developer"
        assert gen.enabled_plugins == []


class TestYamlRepresenter:
    """Test ComposeGenerator YAML representer for correct quoting behavior (#67)."""

    def _dump(self, data: str) -> str:
        """Dump a string using the compose dumper and return the YAML output."""
        dumper = ComposeGenerator.make_dumper()
        return yaml.dump({"key": data}, Dumper=dumper, default_flow_style=False)

    def test_plain_string_no_quotes(self) -> None:
        """Simple strings without special chars should not be quoted."""
        result = self._dump("simple-value")
        assert result.strip() == "key: simple-value"

    def test_colon_gets_quoted(self) -> None:
        """Strings with colon should be double-quoted."""
        result = self._dump("host:port")
        assert '"host:port"' in result

    def test_hash_gets_quoted(self) -> None:
        """Strings with # should be double-quoted."""
        result = self._dump("value # comment")
        assert '"value # comment"' in result

    def test_curly_brace_gets_quoted(self) -> None:
        """Strings with {} should be double-quoted."""
        result = self._dump("${VAR}")
        assert '"${VAR}"' in result

    def test_square_bracket_gets_quoted(self) -> None:
        """Strings with [] should be double-quoted."""
        result = self._dump("[item]")
        assert '"[item]"' in result

    def test_ampersand_gets_quoted(self) -> None:
        """Strings with & should be double-quoted."""
        result = self._dump("a & b")
        assert '"a & b"' in result

    def test_asterisk_gets_quoted(self) -> None:
        """Strings with * should be double-quoted."""
        result = self._dump("*alias")
        assert '"*alias"' in result

    def test_pipe_gets_quoted(self) -> None:
        """Strings with | should be double-quoted."""
        result = self._dump("cmd | grep")
        assert '"cmd | grep"' in result

    def test_percent_gets_quoted(self) -> None:
        """Strings with % should be double-quoted."""
        result = self._dump("100%")
        assert '"100%"' in result

    def test_single_quote_gets_quoted(self) -> None:
        """Strings with ' should be double-quoted."""
        result = self._dump("it's")
        assert "\"it's\"" in result

    def test_double_quote_gets_quoted(self) -> None:
        """Strings with double quote should be double-quoted."""
        result = self._dump('say "hello"')
        # YAML escapes internal double quotes
        assert result.count('"') >= 2

    def test_backtick_gets_quoted(self) -> None:
        """Strings with backtick should be double-quoted."""
        result = self._dump("run `cmd`")
        assert '"run `cmd`"' in result

    def test_comma_gets_quoted(self) -> None:
        """Strings with comma should be double-quoted."""
        result = self._dump("a,b")
        assert '"a,b"' in result

    def test_question_mark_gets_quoted(self) -> None:
        """Strings with ? should be double-quoted."""
        result = self._dump("really?")
        assert '"really?"' in result

    def test_newline_gets_quoted(self) -> None:
        """Strings with newline should be double-quoted."""
        result = self._dump("line1\nline2")
        # YAML may use different representations for newlines
        assert '"' in result or "|-" in result

    def test_docker_compose_env_var(self) -> None:
        """Docker compose ${VAR} references should be double-quoted."""
        result = self._dump("${FORWARD_PORT:-3000}:${FORWARD_PORT:-3000}")
        assert '"${FORWARD_PORT:-3000}:${FORWARD_PORT:-3000}"' in result

    def test_docker_compose_volume_path(self) -> None:
        """Docker compose volume paths without special chars should be plain."""
        result = self._dump("..:/home/user/workspace")
        # Contains colon, so should be quoted
        assert '"..:/home/user/workspace"' in result

    def test_yaml_special_chars_coverage(self) -> None:
        """Every character in YAML_SPECIAL_CHARS should trigger quoting."""
        for char in ComposeGenerator.YAML_SPECIAL_CHARS:
            if char == "\n":
                continue  # newline handled differently by yaml
            data = f"test{char}value"
            result = self._dump(data)
            assert '"' in result, f"Character {char!r} should trigger quoting"

    def test_make_dumper_returns_custom_type(self) -> None:
        """make_dumper should return a new SafeDumper subclass."""
        dumper = ComposeGenerator.make_dumper()
        assert issubclass(dumper, yaml.SafeDumper)
        assert dumper is not yaml.SafeDumper


class TestGetPluginVolumes:
    """Test Generator.get_plugin_volumes static method."""

    def test_with_volumes(self, plugins_dir: str) -> None:
        vols = Generator.get_plugin_volumes(plugins_dir, ["test-plugin"])
        assert len(vols) == 1
        name, vol_name, vol_path = vols[0]
        assert name == "Test Plugin"
        assert vol_name == "test-data"
        assert "${USERNAME}" in vol_path

    def test_without_volumes(self, plugins_dir: str) -> None:
        vols = Generator.get_plugin_volumes(plugins_dir, ["no-vol"])
        assert len(vols) == 0

    def test_nonexistent_plugin(self, plugins_dir: str) -> None:
        vols = Generator.get_plugin_volumes(plugins_dir, ["does-not-exist"])
        assert len(vols) == 0


class TestComposeGenerator:
    """Test ComposeGenerator."""

    def test_basic_structure(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = ComposeGenerator(workspace_data, plugins_dir).generate()
        assert "services:" in output
        assert "test-svc:" in output
        assert "volumes:" in output
        assert "UBUNTU_VERSION" in output

    def test_plugin_volumes_included(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = ComposeGenerator(workspace_data, plugins_dir).generate()
        assert "test-data:" in output
        assert "CONTAINER_SERVICE_NAME}_test-data" in output
        assert "COMPOSE_PROJECT_NAME}" in output

    def test_custom_volumes(self, plugins_dir: str) -> None:
        data: dict[str, object] = {
            "container": {"service_name": "cv-test", "username": "user"},
            "plugins": {"enable": []},
            "ports": {"forward": [8080]},
            "volumes": {"mydata": "/home/user/data"},
        }
        output = ComposeGenerator(data, plugins_dir).generate()
        assert "mydata:" in output

    def test_trailing_newline(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = ComposeGenerator(workspace_data, plugins_dir).generate()
        assert output.endswith("\n")


class TestDevcontainerJsonGenerator:
    """Test DevcontainerJsonGenerator."""

    def test_basic_structure(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerJsonGenerator(workspace_data, plugins_dir).generate()
        assert '"name"' in output
        assert '"service"' in output
        assert '"test-svc"' in output
        assert '"forwardPorts"' in output

    def test_extensions(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerJsonGenerator(workspace_data, plugins_dir).generate()
        assert '"ms-python.python"' in output

    def test_header_comment(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerJsonGenerator(workspace_data, plugins_dir).generate()
        assert output.startswith("// Auto-generated from workspace.toml")

    def test_valid_json_after_stripping_header(
        self, workspace_data: dict[str, object], plugins_dir: str,
    ) -> None:
        """Output should be valid JSON after stripping the header comment."""
        import re

        output = DevcontainerJsonGenerator(workspace_data, plugins_dir).generate()
        stripped = re.sub(r"^\s*//.*$", "", output, flags=re.MULTILINE)
        json.loads(stripped)

    def test_workspace_folder(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerJsonGenerator(workspace_data, plugins_dir).generate()
        assert '"/home/testuser/workspace"' in output

    def test_empty_extensions(self, plugins_dir: str) -> None:
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "ports": {"forward": [3000]},
            "vscode": {"extensions": []},
        }
        output = DevcontainerJsonGenerator(data, plugins_dir).generate()
        assert '"extensions": []' in output

    def test_build_config_dict(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        """Verify _build_config returns a proper dict (not string concatenation)."""
        gen = DevcontainerJsonGenerator(workspace_data, plugins_dir)
        config = gen._build_config()
        assert isinstance(config, dict)
        assert config["service"] == "test-svc"
        assert config["forwardPorts"] == [3000]
        assert config["customizations"]["vscode"]["extensions"] == ["ms-python.python"]

    def test_forward_ports_multiple(self, plugins_dir: str) -> None:
        """All ports from ports.forward should be included, not just the first."""
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "ports": {"forward": [3000, 8080, 5432]},
            "vscode": {"extensions": []},
        }
        gen = DevcontainerJsonGenerator(data, plugins_dir)
        config = gen._build_config()
        assert config["forwardPorts"] == [3000, 8080, 5432]

    def test_devcontainer_section_adds_new_keys(self, plugins_dir: str) -> None:
        """[devcontainer] section adds new top-level properties."""
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "ports": {"forward": [3000]},
            "vscode": {"extensions": []},
            "devcontainer": {
                "postCreateCommand": "echo hello",
                "remoteUser": "devcontainer",
            },
        }
        config = DevcontainerJsonGenerator(data, plugins_dir)._build_config()
        assert config["postCreateCommand"] == "echo hello"
        assert config["remoteUser"] == "devcontainer"

    def test_devcontainer_section_overrides_existing(self, plugins_dir: str) -> None:
        """[devcontainer] can override base config values."""
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "ports": {"forward": [3000]},
            "vscode": {"extensions": []},
            "devcontainer": {"shutdownAction": "none"},
        }
        config = DevcontainerJsonGenerator(data, plugins_dir)._build_config()
        assert config["shutdownAction"] == "none"

    def test_devcontainer_deep_merge_preserves_extensions(self, plugins_dir: str) -> None:
        """Deep merge: vscode.settings coexists with vscode.extensions."""
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "ports": {"forward": [3000]},
            "vscode": {"extensions": ["ms-python.python"]},
            "devcontainer": {
                "customizations": {
                    "vscode": {
                        "settings": {"editor.fontSize": 14},
                    },
                },
            },
        }
        config = DevcontainerJsonGenerator(data, plugins_dir)._build_config()
        assert config["customizations"]["vscode"]["extensions"] == ["ms-python.python"]
        assert config["customizations"]["vscode"]["settings"] == {"editor.fontSize": 14}

    def test_no_devcontainer_section_unchanged(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        """Without [devcontainer], output is identical to base config."""
        config = DevcontainerJsonGenerator(workspace_data, plugins_dir)._build_config()
        assert "postCreateCommand" not in config
        assert "remoteUser" not in config

    def test_devcontainer_features(self, plugins_dir: str) -> None:
        """[devcontainer.features] adds features to the config."""
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "ports": {"forward": [3000]},
            "vscode": {"extensions": []},
            "devcontainer": {
                "features": {
                    "ghcr.io/devcontainers/features/node:1": {},
                },
            },
        }
        config = DevcontainerJsonGenerator(data, plugins_dir)._build_config()
        assert config["features"] == {"ghcr.io/devcontainers/features/node:1": {}}


class TestDevcontainerComposeGenerator:
    """Test DevcontainerComposeGenerator."""

    def test_basic_structure(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerComposeGenerator(workspace_data, plugins_dir).generate()
        assert "services:" in output
        assert "test-svc:" in output
        assert "sleep infinity" in output

    def test_docker_socket_mount(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerComposeGenerator(workspace_data, plugins_dir).generate()
        assert "/var/run/docker.sock" in output

    def test_docker_gid(self, workspace_data: dict[str, object], plugins_dir: str) -> None:
        output = DevcontainerComposeGenerator(workspace_data, plugins_dir).generate()
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

    def test_error_handling_file_not_found(self, plugins_dir: str) -> None:
        """FileNotFoundError should produce user-friendly message, not stack trace."""
        result = subprocess.run(
            [sys.executable, str(LIB_DIR / "generators.py"), "compose", "/nonexistent.toml", plugins_dir],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode != 0
        assert "ERROR" in result.stderr
        assert "Traceback" not in result.stderr


class TestDockerfileGenerator:
    """Test DockerfileGenerator."""

    @pytest.fixture()
    def workspace_root(self, tmp_path: Path, plugins_dir: str) -> str:
        """Create a minimal workspace structure for Dockerfile generation."""
        root = tmp_path / "workspace"
        root.mkdir()

        # Create config
        config = root / "config"
        config.mkdir()
        (config / "apt-base-packages.conf").write_text(
            "# Base packages\ncurl\nwget\n"
        )

        # Create empty certs dir
        (root / "certs").mkdir()

        # Copy plugins
        import shutil
        plugins = root / "plugins"
        shutil.copytree(plugins_dir, str(plugins))

        return str(root)

    def test_basic_generation(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u", "ubuntu_version": "24.04"},
            "plugins": {"enable": ["test-plugin"]},
            "ports": {"forward": [3000]},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert "FROM ubuntu:${UBUNTU_VERSION}" in output
        assert "curl" in output
        assert "RUN echo test" in output

    def test_no_plugins(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert "FROM ubuntu:${UBUNTU_VERSION}" in output
        assert "RUN echo test" not in output

    def test_apt_extra_packages(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
            "apt": {"packages": ["vim-nox", "tmux"]},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert "vim-nox" in output
        assert "tmux" in output

    def test_empty_placeholder_removed(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": []},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert "{{" not in output

    def test_plugin_validation_warns_on_user_with_root(
        self, workspace_root: str, capsys: pytest.CaptureFixture[str],
    ) -> None:
        """Plugin with requires_root=true and USER directive should warn."""
        plugins_dir = os.path.join(workspace_root, "plugins")
        bad_plugin = Path(plugins_dir) / "bad-test.toml"
        bad_plugin.write_text(
            '[metadata]\nname = "Bad"\n\n[install]\nrequires_root = true\n'
            'dockerfile = "USER root\\nRUN echo bad\\nUSER ${USERNAME}"\n\n'
            '[version]\nstrategy = "latest"\n'
        )
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": ["bad-test"]},
        }
        DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        captured = capsys.readouterr()
        assert "WARNING" in captured.err
        bad_plugin.unlink()


class TestCollectPluginAptPackages:
    """Test DockerfileGenerator.collect_plugin_apt_packages static method."""

    def test_collects_packages(self, plugins_dir: str) -> None:
        result = DockerfileGenerator.collect_plugin_apt_packages(plugins_dir, ["apt-plugin"], set())
        assert "libfoo-dev" in result
        assert "libbar-dev" in result

    def test_empty_when_no_apt_section(self, plugins_dir: str) -> None:
        result = DockerfileGenerator.collect_plugin_apt_packages(plugins_dir, ["test-plugin"], set())
        assert result == ""

    def test_deduplicates_with_base(self, plugins_dir: str) -> None:
        result = DockerfileGenerator.collect_plugin_apt_packages(
            plugins_dir, ["apt-plugin"], {"libfoo-dev"},
        )
        assert "libfoo-dev" not in result
        assert "libbar-dev" in result

    def test_deduplicates_across_plugins(self, tmp_path: Path) -> None:
        plugins = tmp_path / "plugins2"
        plugins.mkdir()
        (plugins / "a.toml").write_text(
            '[metadata]\nname = "A"\n\n[apt]\npackages = ["pkg1", "pkg2"]\n\n'
            '[install]\nrequires_root = false\ndockerfile = "RUN echo a"\n'
        )
        (plugins / "b.toml").write_text(
            '[metadata]\nname = "B"\n\n[apt]\npackages = ["pkg2", "pkg3"]\n\n'
            '[install]\nrequires_root = false\ndockerfile = "RUN echo b"\n'
        )
        result = DockerfileGenerator.collect_plugin_apt_packages(str(plugins), ["a", "b"], set())
        assert result.count("pkg2") == 1
        assert "pkg1" in result
        assert "pkg3" in result

    def test_nonexistent_plugin(self, plugins_dir: str) -> None:
        result = DockerfileGenerator.collect_plugin_apt_packages(plugins_dir, ["does-not-exist"], set())
        assert result == ""


class TestDockerfilePluginApt:
    """Test plugin apt packages in Dockerfile generation."""

    @pytest.fixture()
    def workspace_root(self, tmp_path: Path, plugins_dir: str) -> str:
        """Create a minimal workspace structure for Dockerfile generation."""
        root = tmp_path / "workspace"
        root.mkdir()
        config = root / "config"
        config.mkdir()
        (config / "apt-base-packages.conf").write_text("# Base\ncurl\nwget\n")
        (root / "certs").mkdir()
        import shutil
        plugins = root / "plugins"
        shutil.copytree(plugins_dir, str(plugins))
        return str(root)

    def test_plugin_apt_in_dockerfile(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": ["apt-plugin"]},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert "libfoo-dev" in output
        assert "libbar-dev" in output

    def test_no_plugin_apt_when_disabled(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": ["test-plugin"]},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert "libfoo-dev" not in output
        assert "libbar-dev" not in output

    def test_plugin_apt_dedup_with_base(self, workspace_root: str) -> None:
        plugins_dir = os.path.join(workspace_root, "plugins")
        data: dict[str, object] = {
            "container": {"service_name": "test", "username": "u"},
            "plugins": {"enable": ["apt-plugin"]},
        }
        output = DockerfileGenerator(data, plugins_dir, workspace_root).generate()
        assert output.count("libfoo-dev") == 1
        assert output.count("curl") == 1


class TestUserDirs:
    """Test user_dirs feature for plugin directory ownership."""

    def test_generate_user_dirs_block_empty(self) -> None:
        result = DockerfileGenerator._generate_user_dirs_block([])
        assert result == ""

    def test_generate_user_dirs_block_single(self) -> None:
        result = DockerfileGenerator._generate_user_dirs_block(
            ["/home/${USERNAME}/.config/gh"],
        )
        assert "USER root" in result
        assert "mkdir -p" in result
        assert "/home/${USERNAME}/.config " in result
        assert "/home/${USERNAME}/.config/gh" in result
        assert "chown ${USERNAME}:${USERNAME}" in result
        assert result.endswith("USER ${USERNAME}")

    def test_generate_user_dirs_block_multiple(self) -> None:
        result = DockerfileGenerator._generate_user_dirs_block(
            ["/home/${USERNAME}/.config/gh", "/home/${USERNAME}/.aws"],
        )
        assert "/home/${USERNAME}/.aws" in result
        assert "/home/${USERNAME}/.config" in result
        assert "/home/${USERNAME}/.config/gh" in result

    def test_generate_user_dirs_block_deduplicates_prefixes(self) -> None:
        result = DockerfileGenerator._generate_user_dirs_block(
            ["/home/${USERNAME}/.config/gh", "/home/${USERNAME}/.config/fish"],
        )
        # .config should appear only once in mkdir and chown
        assert result.count("/home/${USERNAME}/.config ") == 2  # once in mkdir, once in chown

    def test_plugin_with_user_dirs_in_dockerfile(self, tmp_path: Path) -> None:
        plugins = tmp_path / "plugins"
        plugins.mkdir()
        (plugins / "dir-plugin.toml").write_text(
            '[metadata]\nname = "Dir Plugin"\n\n'
            "[install]\nrequires_root = false\n"
            'user_dirs = ["/home/${USERNAME}/.mydir"]\n'
            'dockerfile = "RUN echo install"\n\n'
            '[version]\nstrategy = "latest"\n'
        )
        result = DockerfileGenerator.generate_plugin_installs(str(plugins), ["dir-plugin"])
        assert "Prepare plugin directories" in result
        assert "/home/${USERNAME}/.mydir" in result
        assert "RUN echo install" in result

    def test_no_user_dirs_no_block(self, tmp_path: Path) -> None:
        plugins = tmp_path / "plugins"
        plugins.mkdir()
        (plugins / "simple.toml").write_text(
            '[metadata]\nname = "Simple"\n\n'
            "[install]\nrequires_root = false\n"
            'dockerfile = "RUN echo simple"\n\n'
            '[version]\nstrategy = "latest"\n'
        )
        result = DockerfileGenerator.generate_plugin_installs(str(plugins), ["simple"])
        assert "Prepare plugin directories" not in result
        assert "RUN echo simple" in result
