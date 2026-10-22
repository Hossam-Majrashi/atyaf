"""No live compositor or user library is touched by these boundary tests."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'profile_windows', Path(__file__).parents[1] / 'assets/linux/profile_windows.py')
w = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(w)


class WindowsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='atyaf-windows-test-')
        self.addCleanup(self.temporary.cleanup)
        self.desktop = Path(self.temporary.name) / 'com.h.atyaf.profile-test.desktop'
        self.original = ('[Desktop Entry]\nName=RPCS3\n'
                         'Exec="/some path/atyaf" --launch-profile "test"\n'
                         'Icon=/keep/logo.png\nTerminal=false\n')
        self.desktop.write_text(self.original)
        self.build = patch.object(w.subprocess, 'run')
        self.build.start()
        self.addCleanup(self.build.stop)

    def request(self, **changes):
        return dict(pid=123, identity='boot:42', desktop=str(self.desktop),
                    activate=False, **changes)

    def test_real_identity_and_descendant_bounds(self):
        self.assertIsNotNone(w.identity(os.getpid()))
        self.assertIsNone(w.identity(2**30))
        self.assertIn(os.getpid(), w.descendants(os.getpid()))
        self.assertLessEqual(len(w.descendants(os.getpid())), 512)

    def test_only_integration_fields_change(self):
        self.desktop.chmod(0o640)
        w.refresh_shortcut(self.desktop, 'RPCS3')
        result = self.desktop.read_text()
        self.assertIn('StartupWMClass=RPCS3\n', result)
        self.assertIn('X-Atyaf-AutomaticWMClass=true\n', result)
        self.assertIn('StartupNotify=false\n', result)
        for line in self.original.splitlines():
            self.assertIn(line + '\n', result)
        self.assertEqual(self.desktop.stat().st_mode & 0o777, 0o640)
        before = self.desktop.stat()
        w.refresh_shortcut(self.desktop, 'RPCS3')
        self.assertEqual(before.st_ino, self.desktop.stat().st_ino)

    def test_explicit_classes_and_notify_are_preserved(self):
        self.desktop.write_text(self.original + 'StartupWMClass=Manual\nStartupNotify=true\n')
        original = self.desktop.read_bytes()
        w.refresh_shortcut(self.desktop, 'RPCS3')
        self.assertEqual(original, self.desktop.read_bytes())

    def test_unrelated_entries_and_modified_exec_are_preserved(self):
        self.desktop.write_text(self.original.replace('--launch-profile', '--other'))
        before = self.desktop.read_bytes()
        w.refresh_shortcut(self.desktop, 'RPCS3')
        self.assertEqual(before, self.desktop.read_bytes())

    def test_symlinks_hardlinks_and_unsafe_parents_are_not_written(self):
        target = self.desktop.with_name('target')
        self.desktop.rename(target)
        self.desktop.symlink_to(target)
        with self.assertRaises(OSError):
            w.refresh_shortcut(self.desktop, 'RPCS3')
        self.desktop.unlink()
        os.link(target, self.desktop)
        w.refresh_shortcut(self.desktop, 'RPCS3')
        self.assertEqual(target.read_text(), self.original)
        self.desktop.unlink()
        self.desktop.write_text(self.original)
        self.desktop.parent.chmod(0o777)
        w.refresh_shortcut(self.desktop, 'RPCS3')
        self.assertEqual(self.desktop.read_text(), self.original)
        self.desktop.parent.chmod(0o700)

    def test_stale_identity_does_not_contact_desktop(self):
        with patch.object(w, 'identity', return_value='different'), patch.object(w, 'call') as call:
            w.update(self.request())
            call.assert_not_called()
        self.assertEqual(self.desktop.read_text(), self.original)

    def test_actual_class_is_selected_by_pid_not_title(self):
        def call(destination, path, method, *args):
            if method.endswith('.Match'):
                return "([('0_{11111111-1111-1111-1111-111111111111}', 'RPCS3'), ('0_{22222222-2222-2222-2222-222222222222}', 'Other')],)"
            pid = 999 if args[0].startswith('{111') else 123
            return "({'pid': <" + str(pid) + ">, 'resourceClass': <'Actual.Class'>},)"
        with patch.object(w, 'call', side_effect=call):
            self.assertEqual(list(w.window_classes([123])), ['Actual.Class'])

    def test_binding_learns_once_without_running_activation_script(self):
        with patch.object(w, 'identity', return_value='boot:42'), \
                patch.object(w, 'descendants', return_value=[123]), \
                patch.object(w, 'window_classes', return_value=iter(['RPCS3'])), \
                patch.object(w, 'kwin') as kwin:
            w.update(self.request())
            kwin.assert_not_called()
        self.assertIn('StartupWMClass=RPCS3\n', self.desktop.read_text())

    def test_tauri_callback_requires_exact_process_owner(self):
        callbacks = []
        def call(destination, path, method, *args):
            if method.endswith('.ListNames'):
                return "(['com.other.SingleInstance', 'com.epicgames.eglv2.SingleInstance'],)"
            if method.endswith('.GetNameOwner'):
                return "(':1.1',)" if args[0] == 'com.other.SingleInstance' else "(':1.2',)"
            if method.endswith('.GetConnectionUnixProcessID'):
                return '(uint32 ' + ('999' if args[0] == ':1.1' else '123') + ',)'
            callbacks.append((destination, path, method, args))
            return '()'
        with patch.object(w, 'call', side_effect=call):
            w.notify_single_instance([123])
        self.assertEqual(len(callbacks), 1)
        self.assertEqual(callbacks[0][0], ':1.2')
        self.assertEqual(callbacks[0][1], '/com/epicgames/eglv2/SingleInstance')
        self.assertEqual(callbacks[0][3], ('[]', '/'))

    def test_activation_script_is_pid_scoped_and_avoids_readonly_properties(self):
        code = w.script([123, 124], True)
        self.assertIn('pids.has(window.pid)', code)
        self.assertIn('workspace.activeWindow = window', code)
        self.assertNotIn('window.desktopFileName =', code)
        self.assertNotIn('caption', code)
        self.assertNotIn('resourceClass', code)

    def test_script_is_unloaded_after_run_failure(self):
        actions = []
        def kwin(method, *args):
            actions.append(method)
            return '(int32 7,)'
        with patch.object(w, 'identity', return_value='boot:42'), \
                patch.object(w, 'descendants', return_value=[123]), \
                patch.object(w, 'notify_single_instance'), \
                patch.object(w, 'kwin', side_effect=kwin), \
                patch.object(w, 'call', side_effect=TimeoutError):
            with self.assertRaises(TimeoutError):
                request = self.request()
                request['activate'] = True
                w.update(request)
        self.assertEqual(actions, ['loadScript', 'unloadScript'])

    def test_generic_apprun_is_never_learned(self):
        w.refresh_shortcut(self.desktop, 'AppRun')
        self.assertNotIn('StartupWMClass=', self.desktop.read_text())
        self.assertNotIn('X-Atyaf-AutomaticWMClass=', self.desktop.read_text())

    def test_generic_automatic_peers_are_repaired_but_manual_classes_remain(self):
        automatic = self.original + 'StartupWMClass=AppRun\nX-Atyaf-AutomaticWMClass=true\n'
        self.desktop.write_text(automatic)
        peer = self.desktop.with_name('com.h.atyaf.profile-peer.desktop')
        peer.write_text(automatic.replace('"test"', '"peer"'))
        manual = self.desktop.with_name('com.h.atyaf.profile-manual.desktop')
        manual.write_text(automatic.replace('"test"', '"manual"').replace(
            'X-Atyaf-AutomaticWMClass=true\n', ''))
        before = manual.read_bytes()
        w.repair_generic_shortcuts(self.desktop.parent)
        for path in (self.desktop, peer):
            content = path.read_text()
            self.assertNotIn('StartupWMClass=', content)
            self.assertNotIn('X-Atyaf-AutomaticWMClass=', content)
            self.assertIn('Icon=/keep/logo.png\n', content)
            self.assertIn('StartupNotify=false\n', content)
        self.assertEqual(before, manual.read_bytes())
        w.refresh_shortcut(self.desktop, 'RPCS3')
        self.assertIn('StartupWMClass=RPCS3\n', self.desktop.read_text())

    def test_commands_are_argument_lists_with_deadlines(self):
        w.subprocess.run.return_value.stdout = '()'
        w.call('org.example.Test', '/test', 'org.example.Test.Method', 'a; not a shell')
        args, kwargs = w.subprocess.run.call_args
        self.assertEqual(args[0][-1], 'a; not a shell')
        self.assertEqual(kwargs['timeout'], 2)
        self.assertNotIn('shell', kwargs)


if __name__ == '__main__':
    unittest.main()
