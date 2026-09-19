#!/usr/bin/env python3

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import tomllib
import unittest

REPO = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), REPO / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dots = load("coder-dots")
client_config = load("coder-client-config")
core = load("coder-core")


def resolved(**env):
    return dots.resolve(REPO, env)


def dot_names(config):
    return {d["name"] for g in config["groups"] for d in g.get("dots", [])}


class DotsResolverTest(unittest.TestCase):
    def test_empty_is_minimal_and_isolated(self):
        config = resolved()
        self.assertEqual(dot_names(config), set(dots.CORE_DOTS))
        self.assertEqual(set(config["hosts"]), {"coder-components"})
        self.assertNotIn("tools", config)
        self.assertNotIn("$include", config)
        self.assertFalse(config["settings"]["dots_git"]["auto_commit"])
        self.assertEqual(config["host_settings"]["coder-components"]["dots_repo"], str(REPO))

    def test_legacy_host_profiles_are_absent(self):
        for name in ["setup-coder.sh", "setup-hermes.sh", "setup-workspace.sh",
                     "scripts/setup-coder-linux.sh", "scripts/setup-workspace-linux.sh"]:
            self.assertFalse((REPO / name).exists(), name)
        settings = json.loads((REPO / "dotfiles/omni/.config/omni/settings.json").read_text())
        legacy = {"coder", "hermes", "auto-code"}
        self.assertFalse(legacy & settings["hosts"].keys())
        self.assertFalse(legacy & settings["host_settings"].keys())
        self.assertIn("topaz", settings["hosts"])
        for filename in ["groups.json", "dots.json"]:
            data = json.loads((REPO / "dotfiles/omni/.config/omni/settings.d" / filename).read_text())
            self.assertFalse(legacy & {group["name"] for group in data["groups"]})
            for group in data["groups"]:
                for dot in group.get("dots", []):
                    self.assertFalse(legacy & dot.get("hosts", {}).keys())
        config = resolved()
        tmux = next(dot for group in config["groups"] for dot in group.get("dots", []) if dot["name"] == "tmux")
        self.assertEqual(tmux["hosts"]["coder-components"]["package"], "tmux@coder")

    def test_source_and_print_config_do_not_mutate_home(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for client, filename in [("claude", "CLAUDE.md"), ("codex", "AGENTS.md"), ("openhands", "settings.json")]:
                path = home / ("." + client) / filename
                path.parent.mkdir()
                path.write_text("preserve existing " + client)
            before = {str(path.relative_to(home)): path.read_bytes() for path in home.rglob("*") if path.is_file()}
            env = {k: v for k, v in os.environ.items() if not k.startswith(("CODER_", "OMNI_"))}
            env["HOME"] = str(home)
            result = subprocess.run(["bash", "-c", 'source "$1/setup-coder-dots.sh"; install_coder_workspace_notes; coder_dots_main --print-config', "test", str(REPO)], env=env, capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(result.stdout), resolved())
            after = {str(path.relative_to(home)): path.read_bytes() for path in home.rglob("*") if path.is_file()}
            self.assertEqual(after, before)
            self.assertEqual({path.name for path in home.iterdir()}, {".claude", ".codex", ".openhands"})

    def test_client_and_core_matrix(self):
        for clients in ["", "claude", "codex", "claude,codex"]:
            config = resolved(CODER_AGENT_CLIENTS=clients)
            self.assertEqual("claude" in dot_names(config), "claude" in clients)
            self.assertEqual("codex" in dot_names(config), "codex" in clients)
            self.assertIn("nvim", dot_names(config))
            self.assertIn("zsh", dot_names(config))
            for group in config["groups"]:
                for dot in group.get("dots", []):
                    package = dot.get("hosts", {}).get("coder-components", {}).get("package", dot["name"])
                    self.assertTrue((REPO / "dotfiles" / package).exists() or (REPO / package).exists(), package)

    def test_validation(self):
        for key, value in [("CODER_AGENT_CLIENTS", "openhands"), ("CODER_MCP_URL", "cluster/mcp"), ("CODER_MCP_URL", "https://good/\nbad")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                resolved(**{key: value})

    def test_print_config_is_offline_and_matches_resolver(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("CODER_")}
        env["CODER_AGENT_CLIENTS"] = "codex"
        result = subprocess.run(["bash", str(REPO / "setup-coder-dots.sh"), "--print-config"], env=env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), resolved(CODER_AGENT_CLIENTS="codex"))

    def test_templates_are_plugin_free_and_parseable(self):
        codex = tomllib.loads((REPO / "dotfiles/codex@coder-components/.codex/config.toml").read_text())
        claude = json.loads((REPO / "dotfiles/claude@coder-components/.claude/settings.json").read_text())
        self.assertNotIn("hooks", claude)
        self.assertNotIn("enabledPlugins", claude)
        self.assertNotIn("plugins", codex)
        self.assertNotIn("mcp_servers", codex)
        self.assertEqual(codex["cli_auth_credentials_store"], "file")


class ClientFilesTest(unittest.TestCase):
    def test_notes_replace_duplicates_without_mutating_source(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            source = home / "source.md"
            block = "<!-- coder-workspace:start -->\nold\n<!-- coder-workspace:end -->\n"
            original = "before\n" + block + "between\n" + block + "after\n"
            source.write_text(original)
            target = home / "notes.md"
            target.symlink_to(source)
            args = ["bash", "-c", 'source "$1/setup-coder-dots.sh"; install_coder_workspace_notes "$2"', "test", str(REPO), str(target)]
            env = dict(os.environ, HOME=str(home), CODER_ENABLE_DIND="0")
            subprocess.run(args, env=env, check=True, capture_output=True)
            result = target.read_text()
            self.assertEqual(source.read_text(), original)
            self.assertEqual(result.count("<!-- coder-workspace:start -->"), 1)
            self.assertTrue(result.startswith("before\n"))
            self.assertTrue(result.endswith("between\nafter\n"))
            subprocess.run(args, env=env, check=True, capture_output=True)
            self.assertEqual(target.read_text(), result)
            target.write_text("before\n<!-- coder-workspace:start -->\nunterminated\n")
            before = target.read_bytes()
            self.assertNotEqual(subprocess.run(args, env=env, capture_output=True).returncode, 0)
            self.assertEqual(target.read_bytes(), before)

    def test_selected_client_prepare_preserves_opencode(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            target = home / ".config/opencode/config.json"
            target.parent.mkdir(parents=True)
            target.write_text("keep me")
            subprocess.run(["bash", "-c", 'bash "$1/scripts/volatile-dots.sh" prepare claude', "test", str(REPO)], env=dict(os.environ, HOME=str(home)), check=True)
            self.assertEqual(target.read_text(), "keep me")

    def test_mcp_opt_in_preserves_other_servers_and_source(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / ".codex").mkdir()
            source = home / "source.toml"
            original = '[mcp_servers.other]\nurl = "https://unrelated/mcp"\n\n[mcp_servers.litellm-tools]\nurl = "https://public/mcp"\n'
            source.write_text(original)
            (home / ".codex/config.toml").symlink_to(source)
            claude = home / ".claude.json"
            claude.write_text('{"marker": 42, "mcpServers": {"other": {"url": "https://unrelated/mcp"}}}')
            before = claude.read_bytes()
            client_config.mcp_override(home, "", ["claude", "codex"])
            self.assertEqual(claude.read_bytes(), before)
            self.assertTrue((home / ".codex/config.toml").is_symlink())
            url = 'https://example.test/mcp/?x=a&y=b|c'
            client_config.mcp_override(home, url, ["claude", "codex"])
            first = (home / ".codex/config.toml").read_bytes()
            client_config.mcp_override(home, url, ["claude", "codex"])
            self.assertEqual((home / ".codex/config.toml").read_bytes(), first)
            self.assertEqual(source.read_text(), original)
            data = tomllib.loads(first.decode())
            self.assertEqual(data["mcp_servers"]["litellm-tools"]["url"], url)
            self.assertEqual(data["mcp_servers"]["other"]["url"], "https://unrelated/mcp")
            self.assertEqual(json.loads(claude.read_text())["marker"], 42)
            self.assertEqual(json.loads(claude.read_text())["mcpServers"]["litellm-tools"]["url"], url)

    def test_unselected_clients_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            client_config.mcp_override(home, "https://example.test/mcp", [])
            self.assertEqual(list(home.iterdir()), [])
            client_config.mcp_override(home, "https://example.test/mcp", ["claude"])
            self.assertFalse((home / ".codex").exists())

    def test_scoped_volatile_operations_preserve_live_config(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for client, name in [("claude", "settings.json"), ("codex", "config.toml")]:
                (home / ("." + client)).mkdir()
                (home / ("." + client) / name).write_text("live " + client)
            env = dict(os.environ, HOME=str(home))
            subprocess.run(["bash", str(REPO / "scripts/volatile-dots.sh"), "prepare", "claude"], env=env, check=True)
            self.assertEqual((home / ".codex/config.toml").read_text(), "live codex")
            self.assertFalse((home / ".claude/settings.json").exists())
            (home / ".claude/settings.json").symlink_to(REPO / "dotfiles/claude@coder-components/.claude/settings.json")
            subprocess.run(["bash", str(REPO / "scripts/volatile-dots.sh"), "detach", "claude"], env=env, check=True)
            self.assertEqual((home / ".claude/settings.json").read_text(), "live claude")
            self.assertFalse((home / ".claude/settings.json").is_symlink())


@unittest.skipUnless(os.environ.get("CODER_TEST_OMNI_BINARY"), "set CODER_TEST_OMNI_BINARY for native Omni dots checks")
class NativeOmniTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("stow"), "native dot sync requires existing stow; never auto-install it in tests")
    def test_client_dots(self):
        binary = str(Path(os.environ["CODER_TEST_OMNI_BINARY"]).resolve())
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"), XDG_CACHE_HOME=str(home / ".cache"), XDG_STATE_HOME=str(home / ".state"), OMNI_HOSTNAME="coder-components", OTEL_SDK_DISABLED="true")
            config_path = home / "settings.json"
            config_path.write_text(json.dumps(resolved(CODER_AGENT_CLIENTS="claude,codex")))
            for client, filename in [("claude", "settings.json"), ("codex", "config.toml")]:
                (home / ("." + client)).mkdir()
                subprocess.run([binary, "--config", str(config_path), "--yes", "dots", "sync", "--use-repo", client], env=env, text=True, capture_output=True, check=True)
                target = home / ("." + client) / filename
                self.assertTrue(target.exists())
                source = REPO / f"dotfiles/{client}@coder-components/.{client}" / filename
                self.assertEqual(target.read_bytes(), source.read_bytes())
                subprocess.run(["bash", str(REPO / "scripts/volatile-dots.sh"), "detach", client], env=env, check=True)
                self.assertFalse(target.is_symlink())
            self.assertFalse((home / ".config/opencode").exists())
            self.assertFalse((home / ".zshrc").exists())


class CoreTest(unittest.TestCase):
    def test_real_core_configs_and_conflict_preservation(self):
        config = resolved()
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            core.check_dots(config, home)
            with self.assertRaises(ValueError):
                core.check_dots(config, home, True)
            group = next(g for g in config["groups"] if g["name"] == "component-core-dots")
            for dot in group["dots"]:
                package = dot.get("hosts", {}).get("coder-components", {}).get("package", dot["name"])
                root = REPO / "dotfiles" / package
                if not root.exists():
                    root = REPO / package
                target = home / dot["path"][2:]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(root / dot["path"][2:])
            core.check_dots(config, home, True)
            target = home / ".zshrc"
            target.unlink()
            target.write_text("local settings preserved")
            with self.assertRaisesRegex(ValueError, "conflict"):
                core.check_dots(config, home)
            self.assertEqual(target.read_text(), "local settings preserved")
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            state = home / ".config/lazygit/state.yml"
            state.parent.mkdir(parents=True)
            state.write_text("local state")
            core.check_dots(config, home)
            self.assertEqual(state.read_text(), "local state")
            (state.parent / "unknown.yml").write_text("preserve")
            with self.assertRaisesRegex(ValueError, "unmanaged"):
                core.check_dots(config, home)

    def test_repo_markers_without_mocked_hook_install(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for value in ["../outside", "/outside", "."]:
                with self.assertRaises(ValueError):
                    core.repo_paths(home, value)
            repos = core.repo_paths(home, "repo, repo")
            self.assertEqual(len(repos), 1)
            with self.assertRaisesRegex(ValueError, "marker"):
                core.install_hooks(repos, timeout=0)
            subprocess.run(["git", "init", "-q", str(repos[0])], check=True)
            core.install_hooks(repos, timeout=0)


if __name__ == "__main__":
    unittest.main()
