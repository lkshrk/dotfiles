#!/usr/bin/env python3
"""Verify native Lefthook installation stays isolated across repositories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'dotfiles/git@topaz/.config/git/config.local'


class RepositoryHooks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('GIT_', 'LEFTHOOK'))}
        self.env.update(GIT_CONFIG_GLOBAL=str(CONFIG), GIT_CONFIG_NOSYSTEM='1')

    def run_cmd(self, *args, cwd=None, check=True, input=None):
        return subprocess.run(args, cwd=cwd or self.root, env=self.env,
                              check=check, input=input, text=True, capture_output=True)

    def repo(self, name):
        path = self.root / name
        self.run_cmd('git', 'init', '-q', str(path))
        self.run_cmd('git', 'config', 'commit.gpgsign', 'false', cwd=path)
        return path

    def install(self, repo):
        binary = shutil.which('lefthook')
        if not binary:
            self.skipTest('lefthook not installed')
        self.run_cmd(binary, 'install', cwd=repo)

    def configure(self, repo, marker):
        (repo / 'lefthook.yml').write_text(
            'pre-commit:\n  commands:\n    probe:\n'
            f'      run: echo {marker} >> hook-runs\n')

    def commit(self, repo):
        (repo / 'staged').write_text('probe\n')
        self.run_cmd('git', 'add', 'staged', cwd=repo)
        return self.run_cmd('git', 'commit', '--allow-empty', '-qm', 'probe', cwd=repo)

    def test_no_shared_hooks_path(self):
        result = self.run_cmd('git', 'config', '--get', 'core.hooksPath', check=False)
        self.assertEqual(result.returncode, 1, result.stdout)

    def test_installs_and_reinstalls_are_isolated(self):
        first, second, unrelated = [self.repo(name) for name in ('first', 'second', 'unrelated')]
        for repo in (first, second):
            self.configure(repo, repo.name)
            self.install(repo)
        first_hook = first / '.git/hooks/pre-commit'
        before = first_hook.read_bytes()
        self.install(second)
        self.assertEqual(first_hook.read_bytes(), before)
        for repo in (first, second):
            self.commit(repo)
            self.assertEqual((repo / 'hook-runs').read_text(), repo.name + '\n')
            self.assertFalse((repo / '.git/hooks/reference-transaction').exists())
        self.commit(unrelated)
        self.assertFalse((unrelated / 'hook-runs').exists())
        self.assertFalse((unrelated / '.git/hooks/pre-commit').exists())

    def test_worktree_uses_common_hooks(self):
        repo = self.repo('main')
        self.commit(repo)
        worktree = self.root / 'worktree'
        self.run_cmd('git', 'worktree', 'add', '-qb', 'probe', str(worktree), cwd=repo)
        self.configure(worktree, 'worktree')
        self.install(worktree)
        self.assertTrue((repo / '.git/hooks/pre-commit').is_file())
        self.run_cmd('git', 'add', 'lefthook.yml', cwd=worktree)
        self.commit(worktree)
        self.assertEqual((worktree / 'hook-runs').read_text(), 'worktree\n')

    def test_extends_and_failure_are_preserved(self):
        repo = self.repo('inherited')
        (repo / 'lefthook.yml').write_text('extends:\n  - shared.yml\n')
        (repo / 'shared.yml').write_text(
            'pre-commit:\n  commands:\n    reject:\n      run: exit 1\n')
        self.install(repo)
        self.run_cmd('git', 'add', 'lefthook.yml', 'shared.yml', cwd=repo)
        result = self.run_cmd('git', 'commit', '--allow-empty', '-qm', 'reject',
                              cwd=repo, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(self.run_cmd('git', 'rev-parse', '--verify', 'HEAD',
                                        cwd=repo, check=False).returncode, 0)


if __name__ == '__main__':
    unittest.main()
