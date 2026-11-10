#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'assets/linux'))
import profile_autostart as module


class AutostartBoundaries(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='atyaf-startup-boundary-')
        self.base = Path(self.temporary.name)
        self.root = self.base / 'library'
        self.root.mkdir(mode=0o700)
        self.config = self.base / 'config'
        self.request = dict(root=str(self.root), config=str(self.config), profile='account', operation='enable', content='[Desktop Entry]\nType=Application\nExec=/usr/bin/true\n')

    def tearDown(self):
        self.temporary.cleanup()

    def manage(self, operation='enable'):
        return module.manage(dict(self.request, operation=operation))

    def target(self):
        return next((self.config / 'autostart').glob('*.desktop'))

    def test_failed_registry_commit_rolls_back_new_entry(self):
        original = module.os.replace
        def replace(source, destination, **kwargs):
            if destination == 'autostart.json':
                raise OSError('simulated commit failure')
            return original(source, destination, **kwargs)
        with patch.object(module.os, 'replace', replace), self.assertRaises(OSError):
            self.manage()
        self.assertEqual(list((self.config / 'autostart').iterdir()), [])
        self.assertFalse((self.root / 'autostart.json').exists())

    def test_failed_registry_commit_restores_previous_entry(self):
        self.manage()
        previous = self.target().read_bytes()
        registry = (self.root / 'autostart.json').read_bytes()
        self.request['content'] += '# refreshed\n'
        original = module.os.replace
        def replace(source, destination, **kwargs):
            if destination == 'autostart.json':
                raise OSError('simulated commit failure')
            return original(source, destination, **kwargs)
        with patch.object(module.os, 'replace', replace), self.assertRaises(OSError):
            self.manage()
        self.assertEqual(self.target().read_bytes(), previous)
        self.assertEqual((self.root / 'autostart.json').read_bytes(), registry)
        with patch.object(module.os, 'replace', replace), self.assertRaises(OSError):
            self.manage('disable')
        self.assertEqual(self.target().read_bytes(), previous)

    def test_unsafe_modes_fifo_and_large_target(self):
        self.manage()
        target = self.target()
        os.chmod(target, 0o666)
        with self.assertRaises(module.Failure):
            self.manage('disable')
        target.unlink()
        os.mkfifo(target, 0o600)
        with self.assertRaises(module.Failure):
            self.manage('disable')
        target.unlink()
        target.write_bytes(b'x' * 65537)
        with self.assertRaises(module.Failure):
            self.manage('disable')

    def test_symlinked_parent_and_registry_preserved(self):
        outside = self.base / 'outside'
        outside.mkdir()
        self.config.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(module.Failure):
            self.manage()
        self.assertEqual(list(outside.iterdir()), [])
        self.config.unlink()
        original = self.base / 'original'
        original.write_text('{}')
        (self.root / 'autostart.json').symlink_to(original)
        with self.assertRaises(OSError):
            self.manage()
        self.assertEqual(original.read_text(), '{}')

    def test_invalid_ids_and_bounded_metadata(self):
        for profile in ['../outside', 'a' * 81, '', 'a\nExec=bad']:
            with self.subTest(profile=profile), self.assertRaises(module.Failure):
                module.manage(dict(self.request, profile=profile))
        (self.root / 'autostart.json').write_text(json.dumps({'account': 'invalid'}))
        with self.assertRaises(module.Failure):
            self.manage()
        self.assertFalse(self.config.exists())

    def test_unregistered_collision_never_overwritten(self):
        self.manage()
        target = self.target()
        (self.root / 'autostart.json').unlink()
        previous = target.read_bytes()
        for operation in ('status', 'enable', 'disable'):
            with self.assertRaises(module.Failure):
                self.manage(operation)
        self.assertEqual(target.read_bytes(), previous)


if __name__ == '__main__':
    unittest.main()
