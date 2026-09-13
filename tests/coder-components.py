#!/usr/bin/env python3

import importlib.util
import hashlib
import io
import tarfile
import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

REPO = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), REPO / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


components = load("coder-components")
client_config = load("coder-client-config")
core = load("coder-core")
neovim = load("coder-neovim")


def resolved(**env):
    return components.resolve(REPO, env)


def dot_names(config):
    return {d["name"] for g in config["groups"] for d in g.get("dots", [])}


class ComponentsTest(unittest.TestCase):
    def test_empty_is_minimal_and_isolated(self):
        config = resolved()
        self.assertEqual(set(config["tools"]), set(components.BASE))
        self.assertEqual(dot_names(config), set(components.CORE_DOTS))
        self.assertEqual(set(config["hosts"]), {"coder-components"})
        self.assertNotIn("$include", config)
        self.assertFalse(config["settings"]["dots_git"]["auto_commit"])
        self.assertEqual(config["host_settings"]["coder-components"]["dots_repo"], str(REPO))

    def test_legacy_entrypoints_and_host_profiles_are_absent(self):
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
        config = resolved(CODER_OMNI_STACKS="containers")
        self.assertIn("docker", config["tools"])
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
            result = subprocess.run(["bash", "-c", 'source "$1/setup-coder-components.sh"; install_coder_workspace_notes; coder_components_main --print-config', "test", str(REPO)], env=env, capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(result.stdout), resolved())
            after = {str(path.relative_to(home)): path.read_bytes() for path in home.rglob("*") if path.is_file()}
            self.assertEqual(after, before)
            self.assertEqual({path.name for path in home.iterdir()}, {".claude", ".codex", ".openhands"})

    def test_every_stack_readiness_and_linux_provider(self):
        expected = {
            "go": {"go", "gopls"}, "python": {"uv", "node"}, "ts": {"node", "pnpm", "tsc", "typescript-language-server"},
            "lua": {"lua", "luarocks"}, "rust": {"rustc", "cargo"},
            "k8s": {"kubectl", "helm", "kustomize"}, "gitops": {"flux", "helmfile"},
            "argo": {"argo"}, "talos": {"talosctl"}, "cilium": {"cilium"},
            "cnpg": {"kubectl", "kubectl-cnpg"}, "iac": {"tofu"},
            "containers": {"docker", "skopeo"}, "quality": {"actionlint", "gitleaks", "bats"},
            "terminal-recording": {"vhs", "ffmpeg", "ttyd"}, "media": {"ffmpeg"},
        }
        for stack, commands in expected.items():
            with self.subTest(stack=stack):
                config = resolved(CODER_OMNI_STACKS=stack)
                self.assertTrue(commands <= set(components.required_commands(config)))
                self.assertEqual(dot_names(config), set(components.CORE_DOTS))
                self.assertEqual("cargo" in config["tools"], stack == "rust")
                self.assertNotIn("ignore", config)
                for name, tool in config["tools"].items():
                    self.assertTrue(any(p["provider"] in {"script", "apt", "npm", "bun", "cargo", "uv"} for p in tool["providers"]), name)

    def test_shared_ts_group_supplies_native_editor_tools(self):
        groups = json.loads((REPO / "dotfiles/omni/.config/omni/settings.d/groups.json").read_text())["groups"]
        tools = next(group["tools"] for group in groups if group["name"] == "ts")
        self.assertTrue({"typescript", "typescript-language-server"} <= set(tools))

    def test_ts_uses_native_catalog_and_requires_compiler_and_server(self):
        catalog = json.loads((REPO / "dotfiles/omni/.config/omni/settings.d/tools.json").read_text())["tools"]
        for stacks in ["ts", "go,python,ts"]:
            config = resolved(CODER_OMNI_STACKS=stacks)
            for name in ["typescript", "typescript-language-server"]:
                self.assertIn(name, config["tools"])
                self.assertEqual(config["tools"][name], catalog[name])
                self.assertEqual(catalog[name]["providers"], [{"provider": "npm", "package": name}])
            self.assertTrue({"tsc", "typescript-language-server"} <= set(components.required_commands(config, "npm")))
            self.assertNotIn("typescript", components.required_commands(config))

    def test_unselected_ts_does_not_install_or_require_ts_tools(self):
        for stacks in ["", *[s for s in components.STACK_TOOLS if s != "ts"]]:
            for clients in ["", "codex", "claude"]:
                config = resolved(CODER_OMNI_STACKS=stacks, CODER_AGENT_CLIENTS=clients)
                self.assertFalse({"typescript", "typescript-language-server"} & config["tools"].keys())
                self.assertFalse({"tsc", "typescript-language-server"} & set(components.required_commands(config)))

    def test_pairs_deduplicate_and_preserve_dependencies(self):
        for first, second in itertools.combinations(components.STACK_TOOLS, 2):
            config = resolved(CODER_OMNI_STACKS=f"{first},{second},{first}")
            tools = [t for g in config["groups"] for t in g.get("tools", [])]
            self.assertEqual(len(tools), len(set(tools)))
            self.assertTrue(set(components.STACK_TOOLS[first] + components.STACK_TOOLS[second]) <= set(tools))

    def test_runtime_order_and_package_managers(self):
        config = resolved(CODER_OMNI_STACKS="python,go,ts,lua")
        groups = {g["name"]: i for i, g in enumerate(config["groups"])}
        for runtime in ["nvm", "uv", "go", "lua", "luarocks"]:
            self.assertLess(groups["runtime-" + runtime], groups["component-tools"])
        self.assertLess(groups["runtime-lua"], groups["runtime-luarocks"])
        self.assertNotIn("bun", config["tools"])
        self.assertNotIn("cargo", config["tools"])
        self.assertIn("pnpm", config["tools"])
        self.assertIn("python@3.14", config["tools"])

    def test_client_and_core_matrix(self):
        for clients, plugins in itertools.product(["", "claude", "codex", "claude,codex"], ["0", "1"]):
            env = dict(CODER_AGENT_CLIENTS=clients, CODER_AGENT_PLUGINS=plugins)
            if not clients and plugins == "1":
                with self.assertRaises(ValueError):
                    resolved(**env)
                continue
            config = resolved(**env)
            self.assertEqual("cargo" in config["tools"], plugins == "1")
            self.assertEqual("claude" in dot_names(config), "claude" in clients)
            self.assertEqual("codex" in dot_names(config), "codex" in clients)
            self.assertIn("nvim", dot_names(config))
            self.assertIn("zsh", dot_names(config))
            if "codex" in clients:
                self.assertTrue({"nvm", "bun", "@openai/codex"} <= config["tools"].keys())
            if clients == "claude" and plugins == "0":
                self.assertNotIn("nvm", config["tools"])
            for group in config["groups"]:
                for dot in group.get("dots", []):
                    package = dot.get("hosts", {}).get("coder-components", {}).get("package", dot["name"])
                    self.assertTrue((REPO / "dotfiles" / package).exists() or (REPO / package).exists(), package)

    def test_aliases_and_validation(self):
        alias = resolved(CODER_OMNI_STACKS=" infra, omni,infra ")
        explicit = resolved(CODER_OMNI_STACKS=",".join(components.ALIASES["infra"] + ["terminal-recording"]))
        self.assertEqual(alias, explicit)
        for key, value in [("CODER_OMNI_STACKS", "all"), ("CODER_AGENT_CLIENTS", "openhands"), ("CODER_AGENT_PLUGINS", "true"), ("CODER_ENABLE_DIND", "yes"), ("CODER_BACKEND", "podman"), ("CODER_MCP_URL", "cluster/mcp"), ("CODER_MCP_URL", "https://good/\nbad")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                resolved(**{key: value})
        for backend, dind in itertools.product(["docker", "kubernetes"], ["0", "1"]):
            self.assertEqual(resolved(CODER_BACKEND=backend, CODER_ENABLE_DIND=dind), resolved())

    def test_print_config_is_offline_and_matches_resolver(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("CODER_")}
        env.update(CODER_OMNI_STACKS="go,ts", CODER_AGENT_CLIENTS="codex")
        result = subprocess.run(["bash", str(REPO / "setup-coder-components.sh"), "--print-config"], env=env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), resolved(CODER_OMNI_STACKS="go,ts", CODER_AGENT_CLIENTS="codex"))

    def test_readiness_failure_is_fatal_without_installers(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "settings.json"
            config.write_text(json.dumps({"groups": [{"name": "component-tools", "tools": ["coder-components-deliberately-missing-binary"]}], "tools": {}}))
            result = subprocess.run(["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_check "$2"; printf unreachable', "test", str(REPO), str(config)], text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("required component binary missing", result.stderr)
            self.assertNotIn("unreachable", result.stdout)

    def test_required_npm_commands_only_follow_selection(self):
        self.assertEqual(components.required_commands(resolved(), "npm"), [])
        self.assertEqual(components.required_commands(resolved(CODER_OMNI_STACKS="ts"), "npm"), ["pnpm", "tsc", "typescript-language-server"])
        self.assertEqual(components.required_commands(resolved(CODER_OMNI_STACKS="python"), "npm"), ["pyright"])
        self.assertEqual(components.required_commands(resolved(CODER_AGENT_CLIENTS="codex"), "npm"), [])

    def test_pin_url_and_rejection_without_installing(self):
        for version, suffix in [("", "latest/download"), ("0.10.14", "download/v0.10.14"), ("v0.10.14", "download/v0.10.14")]:
            result = subprocess.run(["bash", "-c", 'source "$1/scripts/install-omni-latest.sh"; omni_release_base', "test", str(REPO)], env=dict(os.environ, OMNI_VERSION=version), text=True, capture_output=True, check=True)
            self.assertTrue(result.stdout.strip().endswith(suffix))
        result = subprocess.run(["bash", str(REPO / "setup-coder-components.sh"), "--print-config"], env=dict(os.environ, OMNI_VERSION="latest; invalid"), text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exact release version", result.stderr)

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
            args = ["bash", "-c", 'source "$1/setup-coder-components.sh"; install_coder_workspace_notes "$2"', "test", str(REPO), str(target)]
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

    def test_node_links_allow_absent_optional_corepack(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            node_bin = home / "node-bin"
            node_bin.mkdir()
            (node_bin / "node").symlink_to(shutil.which("python3"))
            subprocess.run(["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_node_commands "$2"', "test", str(REPO), str(node_bin)], env=dict(os.environ, HOME=str(home)), check=True)
            self.assertEqual((home / ".local/bin/node").resolve(), (node_bin / "node").resolve())
            self.assertFalse((home / ".local/bin/corepack").exists())

    def test_node_links_retarget_on_upgrade(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = dict(os.environ, HOME=str(home))
            for version in ["v24.0.0", "v24.1.0"]:
                node_bin = home / ".nvm/versions/node" / version / "bin"
                node_bin.mkdir(parents=True)
                for name in ["node", "npm", "npx", "corepack"]:
                    (node_bin / name).symlink_to(shutil.which("python3"))
                subprocess.run(["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_node_commands "$2"', "test", str(REPO), str(node_bin)], env=env, text=True, capture_output=True, check=True)
                for name in ["node", "npm", "npx", "corepack"]:
                    self.assertEqual((home / ".local/bin" / name).readlink(), node_bin / name)

    @unittest.skipUnless(shutil.which("node") and shutil.which("npm"), "requires existing node and npm")
    def test_selected_npm_links_run_without_nvm_or_personal_rc(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            prefix = home / "custom npm prefix"
            node_bin = home / ".nvm/versions/node/v24.0.0/bin"
            node_bin.mkdir(parents=True)
            (node_bin / "node").symlink_to(shutil.which("node"))
            (node_bin / "npm").symlink_to(shutil.which("npm"))
            package = prefix / "lib/node_modules/pyright"
            package.mkdir(parents=True)
            (prefix / "bin").mkdir()
            for name in ["pnpm", "pyright", "old-unselected-tool"]:
                executable = package / (name + ".js")
                executable.write_text('#!/usr/bin/env node\nconsole.log("' + name + ' executable");\n')
                executable.chmod(0o755)
                (prefix / "bin" / name).symlink_to(executable)
            for rc in [".bashrc", ".profile", ".zshrc"]:
                (home / rc).write_text("exit 91\n")
            config = home / "settings.json"
            config.write_text(json.dumps(resolved(CODER_OMNI_STACKS="python")))
            env = dict(os.environ, HOME=str(home), NVM_BIN=str(node_bin), NPM_CONFIG_PREFIX=str(prefix), PATH=str(node_bin) + ":" + os.environ["PATH"])
            args = ["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_node_commands "$2"; coder_components_link_npm_commands "$3"', "test", str(REPO), str(node_bin), str(config)]
            for _ in range(2):
                subprocess.run(args, env=env, text=True, capture_output=True, check=True)
            clean = {"HOME": str(home), "PATH": ":".join(str(home / p) for p in [".local/bin", ".bun/bin", ".cargo/bin", ".krew/bin", ".local/share/pnpm"]) + ":/bin"}
            for name in ["pyright"]:
                result = subprocess.run([name, "--version"], env=clean, text=True, capture_output=True, check=True)
                self.assertEqual(result.stdout.strip(), name + " executable")
                self.assertEqual((home / ".local/bin" / name).resolve(), (prefix / "bin" / name).resolve())
            self.assertFalse((home / ".local/bin/old-unselected-tool").exists())
            (package / "pyright.js").write_text("#!/usr/bin/env node\nprocess.exit(42);\n")
            result = subprocess.run(args, env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("required npm executable failed on stable PATH: pyright", result.stderr)
            target = home / ".local/bin/pyright"
            target.unlink()
            target.write_text("unrelated user file")
            result = subprocess.run(args, env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("refusing to replace", result.stderr)
            self.assertEqual(target.read_text(), "unrelated user file")
            (prefix / "bin/pyright").unlink()
            result = subprocess.run(args, env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("required npm executable missing", result.stderr)

    @unittest.skipUnless(os.environ.get("CODER_TEST_REAL_NPM") == "1", "set CODER_TEST_REAL_NPM=1 for real npm integration")
    def test_real_ts_npm_readiness_on_stable_path(self):
        with tempfile.TemporaryDirectory(dir=REPO) as directory:
            home = Path(directory)
            prefix = home / "npm-prefix"
            env = dict(os.environ, HOME=str(home), NPM_CONFIG_PREFIX=str(prefix),
                       NPM_CONFIG_CACHE=str(home / "npm-cache"), NODE_COMPILE_CACHE=str(home / "node-cache"))
            config = home / "settings.json"
            selected = resolved(CODER_OMNI_STACKS="ts")
            config.write_text(json.dumps(selected))
            packages = [provider["package"] for tool in selected["tools"].values()
                        for provider in tool["providers"] if provider["provider"] == "npm"]
            subprocess.run(["npm", "install", "--global", "--ignore-scripts", "--registry=https://registry.npmjs.org", *packages],
                           env=env, check=True, capture_output=True, text=True)
            node_bin = home / "node-bin"
            node_bin.mkdir()
            (node_bin / "node").symlink_to(shutil.which("node"))
            (node_bin / "npm").symlink_to(shutil.which("npm"))
            args = ["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_node_commands "$2"; coder_components_link_npm_commands "$3"',
                    "test", str(REPO), str(node_bin), str(config)]
            for _ in range(2):
                subprocess.run(args, env=env, check=True, capture_output=True, text=True)
            clean = {"HOME": str(home), "PATH": str(home / ".local/bin") + ":/bin"}
            for name in ["pnpm", "tsc", "typescript-language-server"]:
                subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c", '"$1" --version', "test", name], env=clean, check=True, capture_output=True, text=True)
                self.assertEqual((home / ".local/bin" / name).resolve(), (prefix / "bin" / name).resolve())
            source = home / "acceptance.ts"
            source.write_text("const value: string = 'ready';\n")
            subprocess.run(["tsc", "--noEmit", str(source)], env=clean, check=True, capture_output=True, text=True)
            for name in ["tsc", "typescript-language-server"]:
                executable = prefix / "bin" / name
                executable.chmod(0o644)
                result = subprocess.run(args, env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("required npm executable missing:", result.stderr)
                executable.chmod(0o755)

    def test_composable_node_link_conflicts_preserve_user_files(self):
        for kind in ["file", "directory", "symlink", "dangling"]:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                node_bin = home / "node-bin"
                node_bin.mkdir()
                (node_bin / "node").symlink_to(shutil.which("python3"))
                target = home / ".local/bin/node"
                target.parent.mkdir(parents=True)
                original = home / "original"
                original.write_text("untouched")
                if kind == "file":
                    target.write_text("untouched")
                elif kind == "directory":
                    target.mkdir()
                else:
                    target.symlink_to(original if kind == "symlink" else home / "missing")
                result = subprocess.run(["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_node_commands "$2"', "test", str(REPO), str(node_bin)], env=dict(os.environ, HOME=str(home)), capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("refusing to replace", result.stderr)
                self.assertEqual(original.read_text(), "untouched")
                if kind == "file":
                    self.assertEqual(target.read_text(), "untouched")
                elif kind == "directory":
                    self.assertEqual(list(target.iterdir()), [])
                else:
                    self.assertEqual(target.readlink(), original if kind == "symlink" else home / "missing")

    def test_composable_node_upgrade_tracks_managed_links(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            bins = [home / ".nvm/versions/node" / version / "bin" for version in ["v24.0.0", "v24.1.0"]]
            for node_bin in bins:
                node_bin.mkdir(parents=True)
                (node_bin / "node").symlink_to(shutil.which("python3"))
            args = ["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_node_commands "$2"', "test", str(REPO)]
            env = dict(os.environ, HOME=str(home))
            subprocess.run(args + [str(bins[0])], env=env, capture_output=True, check=True)
            target = home / ".local/bin/node"
            result = subprocess.run(args + [str(bins[1])], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.readlink(), bins[1] / "node")
            (bins[1] / "node").unlink()
            result = subprocess.run(args + [str(bins[0])], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.readlink(), bins[0] / "node")

    def test_managed_receipt_does_not_override_user_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            args = ["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_local_bin "$2" pyright', "test", str(REPO)]
            env = dict(os.environ, HOME=str(home))
            subprocess.run(args + [str(home / "old-runtime/pyright")], env=env, capture_output=True, check=True)
            target = home / ".local/bin/pyright"
            target.unlink()
            target.symlink_to(home / "user-runtime/pyright")
            result = subprocess.run(args + [str(home / "new-runtime/pyright")], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.readlink(), home / "user-runtime/pyright")

    def test_unrecorded_runtime_link_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            target = home / ".local/bin/node"
            target.parent.mkdir(parents=True)
            original = home / ".nvm/versions/node/v24.0.0/bin/node"
            target.symlink_to(original)
            result = subprocess.run(["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_link_local_bin "$HOME/.nvm/versions/node/v24.1.0/bin/node" node', "test", str(REPO)], env=dict(os.environ, HOME=str(home)), capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.readlink(), original)

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


@unittest.skipUnless(os.environ.get("CODER_TEST_OMNI_BINARY"), "set CODER_TEST_OMNI_BINARY for native Omni resolution/dots checks")
class NativeOmniTest(unittest.TestCase):
    def test_resolve_every_stack(self):
        binary = str(Path(os.environ["CODER_TEST_OMNI_BINARY"]).resolve())
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"), XDG_CACHE_HOME=str(home / ".cache"), XDG_STATE_HOME=str(home / ".state"), OMNI_HOSTNAME="coder-components", OTEL_SDK_DISABLED="true")
            config_path = home / "settings.json"
            for stack in ["", *components.STACK_TOOLS, ",".join(components.STACK_TOOLS)]:
                config = resolved(CODER_OMNI_STACKS=stack, CODER_AGENT_CLIENTS="claude,codex", CODER_AGENT_PLUGINS="1")
                config_path.write_text(json.dumps(config))
                result = subprocess.run([binary, "--config", str(config_path), "settings", "show", "--format", "json"], env=env, text=True, capture_output=True, check=True)
                self.assertEqual(json.loads(result.stdout)["dots_repo"], str(REPO))
                self.assertEqual(json.loads(result.stdout)["disabled_providers"], ["brew"])
            native_version = subprocess.run([binary, "--version"], text=True, capture_output=True, check=True).stdout.split()[2].lstrip("v")
            args = ["bash", "-c", 'source "$1/setup-coder-components.sh"; coder_components_omni_compatible "$2" "$3"', "test", str(REPO), str(config_path), binary]
            self.assertEqual(subprocess.run(args, env=dict(env, OMNI_VERSION=native_version)).returncode, 0)
            self.assertNotEqual(subprocess.run(args, env=dict(env, OMNI_VERSION="999.0.0")).returncode, 0)

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
    def test_core_providers_and_native_lsp_policy(self):
        config = resolved()
        self.assertFalse({"cargo", "bun", "nvm"} & config["tools"].keys())
        self.assertTrue({"nvim", "fd", "fdfind", "bat", "batcat", "rg", "lefthook", "lazygit", "tree-sitter", "cc", "make", "delta"} <= set(components.required_commands(config)))
        for name in ["neovim", "lefthook", "tree-sitter-cli", "git-delta"]:
            self.assertEqual([p["provider"] for p in config["tools"][name]["providers"]], ["script"])
        for options in components.linux_core_providers(REPO).values():
            for command in options["providers"][0].get("options", {}).values():
                subprocess.run(["bash", "-n"], input=command, text=True, check=True)
        text = (REPO / "dotfiles/nvim/.config/nvim/lua/plugins/lsp.lua").read_text()
        self.assertNotIn("client_supports_method", text)
        self.assertNotIn("nvim-0.11", text)
        self.assertNotIn("mason", text)
        self.assertNotIn("CODER_ENVIRONMENT_MODE", text)
        self.assertNotIn("require('lspconfig')", text)
        self.assertIn("vim.lsp.config(server_name, server)", text)
        self.assertIn("vim.lsp.enable(server_name)", text)
        self.assertIn("vim.fn.executable(executable) == 1", text)
        self.assertIn("gopls = 'gopls'", text)
        self.assertIn("pyright = 'pyright-langserver'", text)

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

    def archive(self, path, extra=None, content=b"fixture-binary"):
        with tarfile.open(path, "w:gz") as archive:
            entries = [("nvim-linux-x86_64/bin/nvim", content, 0o755),
                       ("nvim-linux-x86_64/share/nvim/runtime/doc/help.txt", b"runtime docs", 0o644)]
            if extra:
                entries.append(extra)
            for name, data, mode in entries:
                member = tarfile.TarInfo(name)
                member.size = len(data)
                member.mode = mode
                archive.addfile(member, io.BytesIO(data))
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def test_full_runtime_archive_atomic_update_and_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            archive = root / "nvim.tar.gz"
            digest = self.archive(archive)
            with self.assertRaisesRegex(ValueError, "SHA256"):
                neovim.install_archive(archive, home, "0" * 64)
            neovim.install_archive(archive, home, digest)
            neovim.install_archive(archive, home, digest)
            self.assertEqual((home / ".local/bin/nvim").read_bytes(), b"fixture-binary")
            self.assertEqual((home / ".local/share/coder-neovim/current/share/nvim/runtime/doc/help.txt").read_text(), "runtime docs")
            digest = self.archive(archive, content=b"updated")
            neovim.install_archive(archive, home, digest)
            self.assertEqual((home / ".local/bin/nvim").read_bytes(), b"updated")
            digest = self.archive(archive, ("../escaped", b"bad", 0o644))
            with self.assertRaisesRegex(ValueError, "unsafe"):
                neovim.install_archive(archive, home, digest)
            self.assertFalse((root / "escaped").exists())
            self.assertEqual((home / ".local/bin/nvim").read_bytes(), b"updated")

    def test_neovim_preserves_unmanaged_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            target = home / ".local/bin/nvim"
            target.parent.mkdir(parents=True)
            target.write_text("user executable")
            archive = home / "nvim.tar.gz"
            digest = self.archive(archive)
            with self.assertRaisesRegex(ValueError, "overwrite"):
                neovim.install_archive(archive, home, digest)
            self.assertEqual(target.read_text(), "user executable")


if __name__ == "__main__":
    unittest.main()
