#!/usr/bin/env python3
"""Exercise global hook dispatch without running any real repository jobs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOOKS = ROOT / 'dotfiles/git@topaz/.config/git/hooks'
WRAPPERS = sorted(p for p in HOOKS.iterdir() if 'call_lefthook run' in p.read_text())


class GlobalHooks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.env = {**os.environ, 'GIT_CONFIG_GLOBAL': os.devnull,
                    'GIT_CONFIG_NOSYSTEM': '1', 'LEFTHOOK': '1'}
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'LEFTHOOK_CONFIG',
                    'LEFTHOOK_CONFIGS', 'LEFTHOOK_VERBOSE'):
            self.env.pop(key, None)
        subprocess.run(['git', 'init', '-q', str(self.repo)], env=self.env, check=True)
        (self.repo / 'lefthook.yml').write_text('pre-commit:\n  commands: {}\n')
        self.fake = self.repo / 'fake-lefthook'
        self.fake.write_text('''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1] == 'dump':
    print(os.environ.get('HOOK_DUMP', 'pre-commit: {}'))
    if os.environ.get('DUMP_ERROR'):
        print('invalid lefthook config', file=sys.stderr)
        sys.exit(23)
else:
    print(json.dumps({'args': sys.argv[1:], 'stdin': sys.stdin.read()}))
    sys.exit(int(os.environ.get('RUN_EXIT', '0')))
''')
        self.fake.chmod(0o755)
        self.env['LEFTHOOK_BIN'] = str(self.fake)

    def run_hook(self, hook, *args):
        return subprocess.run(['sh', str(hook), *args], cwd=self.repo, env=self.env,
                              input='old new refs/heads/main\n', text=True, capture_output=True)

    def test_absent_hooks_are_silent(self):
        self.env['HOOK_DUMP'] = '{}'
        for hook in WRAPPERS:
            with self.subTest(hook=hook.name):
                result = self.run_hook(hook, 'prepared')
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, '', ''))

    def test_configured_hooks_preserve_arguments_stdin_and_failure(self):
        for hook in WRAPPERS:
            with self.subTest(hook=hook.name):
                self.env['HOOK_DUMP'] = hook.name + ':\n  commands: {}'
                self.env['RUN_EXIT'] = '37'
                result = self.run_hook(hook, 'prepared', 'argument with spaces')
                self.assertEqual(result.returncode, 37)
                call = json.loads(result.stdout)
                self.assertEqual(call['args'], ['run', '--no-auto-install', hook.name,
                                                'prepared', 'argument with spaces'])
                self.assertEqual(call['stdin'], 'old new refs/heads/main\n')

    def test_invalid_configuration_fails_visibly(self):
        self.env['DUMP_ERROR'] = '1'
        for hook in WRAPPERS:
            with self.subTest(hook=hook.name):
                result = self.run_hook(hook)
                self.assertEqual(result.returncode, 23)
                self.assertIn('invalid lefthook config', result.stderr)
                self.assertEqual(result.stdout, '')

    def test_disabled_and_unconfigured_repositories_stay_silent(self):
        self.env['LEFTHOOK'] = '0'
        self.assertEqual(self.run_hook(HOOKS / 'pre-commit').stdout, '')
        self.env['LEFTHOOK'] = '1'
        (self.repo / 'lefthook.yml').unlink()
        self.assertEqual(self.run_hook(HOOKS / 'pre-commit').stdout, '')

    def test_real_lefthook_resolves_extends(self):
        binary = shutil.which('lefthook')
        if not binary:
            self.skipTest('lefthook not installed')
        self.env['LEFTHOOK_BIN'] = binary
        (self.repo / 'lefthook.yml').write_text('extends:\n  - shared.yml\n')
        (self.repo / 'shared.yml').write_text(
            "reference-transaction:\n  commands:\n    probe:\n      run: echo inherited > ran\n")
        result = self.run_hook(HOOKS / 'reference-transaction', 'prepared')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.repo / 'ran').read_text().strip(), 'inherited')
        self.assertFalse((self.repo / '.git/hooks/reference-transaction').exists())
        result = self.run_hook(HOOKS / 'post-rewrite')
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, '', ''))


if __name__ == '__main__':
    unittest.main()
