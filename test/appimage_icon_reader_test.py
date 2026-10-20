"""Reader boundary checks; all AppImage members are data, never programs."""
import base64
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path('assets/linux').resolve()))
import appimage_icons as icons


class ReaderTests(unittest.TestCase):
    def reader(self, members):
        reader = icons.ImageReader.__new__(icons.ImageReader)
        reader.command = ['7z']
        reader.image = '/private/application.AppImage'
        reader.deadline = time.monotonic() + 5
        reader.members = members
        reader.cache = {}
        reader.total = 0
        return reader

    def test_internal_and_absolute_internal_links_never_use_host_files(self):
        reader = self.reader({
            '.DirIcon': {'Mode': 'lrwx', 'Symbolic Link': '/usr/icons/logo.png'},
            'usr/icons/logo.png': {'Mode': '-rw', 'Size': '3'},
        })
        with patch.object(icons, 'capture', return_value=b'png') as capture:
            self.assertEqual(reader.read('.DirIcon'), b'png')
            self.assertEqual(capture.call_args.args[0][-1], 'usr/icons/logo.png')

    def test_broken_ci_link_falls_back_to_desktop_icon(self):
        reader = self.reader({
            '.DirIcon': {'Mode': 'lrwx', 'Symbolic Link': '/runner/build/icon.png'},
            'app.desktop': {'Mode': '-rw', 'Size': '60'},
            'usr/share/icons/hicolor/256x256/apps/logo.png': {'Mode': '-rw', 'Size': '3'},
        })
        with patch.object(icons, 'capture', return_value=b'[Desktop Entry]\nIcon=logo\nType=Application\n'):
            self.assertIsNone(reader.read('.DirIcon'))
            self.assertIn('usr/share/icons/hicolor/256x256/apps/logo.png', reader.candidates())

    def test_cycles_and_escape_links_are_rejected(self):
        for target in ['.DirIcon', '../../secret.png']:
            reader = self.reader({'.DirIcon': {'Mode': 'lrwx', 'Symbolic Link': target}})
            with self.assertRaises(ValueError):
                reader.read('.DirIcon')

    def test_oversized_images_and_special_members_are_not_read(self):
        reader = self.reader({
            'huge.png': {'Mode': '-rw', 'Size': str(icons.MAX_IMAGE + 1)},
            'pipe.png': {'Mode': 'prw', 'Size': '1'},
        })
        with patch.object(icons, 'capture') as capture:
            self.assertIsNone(reader.read('huge.png'))
            self.assertIsNone(reader.read('pipe.png'))
            capture.assert_not_called()

    def test_iso_empty_link_field_is_a_regular_file(self):
        reader = self.reader({'logo.png': {'Mode': '-rw', 'Size': '3', 'Symbolic Link': ''}})
        with patch.object(icons, 'capture', return_value=b'png'):
            self.assertEqual(reader.read('logo.png'), b'png')

    def test_member_paths_are_confined_and_listing_duplicates_fail(self):
        for name in ['/host.png', '../host.png', 'a/../../host.png', 'bad\nname.png', 'a\\b.png']:
            with self.assertRaises(ValueError):
                icons.member_name(name)
        listing = b'\nType = SquashFS\n\n----------\nPath = logo.png\nSize = 1\n\nPath = logo.png\nSize = 1\n'
        with patch.object(icons, 'capture', return_value=listing):
            with self.assertRaises(ValueError):
                icons.ImageReader('7z', '/image')

    def test_candidate_count_is_bounded(self):
        reader = self.reader({str(i) + '.png': {'Mode': '-rw', 'Size': '1'} for i in range(200)})
        self.assertEqual(len(reader.candidates()), icons.MAX_CANDIDATES)

    def test_capture_bounds_actual_stdout_and_timeout(self):
        with self.assertRaises(ValueError):
            icons.capture(['/usr/bin/python3', '-c', 'print("x"*20000)'], 64, time.monotonic() + 5)
        with self.assertRaises(ValueError):
            icons.capture(['/usr/bin/python3', '-c', 'import time;time.sleep(5)'], 64, time.monotonic() + 0.1)

    def test_unsupported_filesystems_are_explicit(self):
        with patch.object(icons, 'capture', return_value=b'\nType = ELF\n\n----------\n'):
            with self.assertRaises(NotImplementedError):
                icons.ImageReader('7z', '/image')

    def test_missing_tool_and_preexisting_output_links_do_not_write(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'application.AppImage').write_bytes(b'image')
            with patch.object(icons.shutil, 'which', return_value=None):
                self.assertEqual(icons.extract_icons(root)['status'], 'missing_tool')
            outside = root / 'outside'
            outside.mkdir()
            (root / '.appimage-icons').symlink_to(outside)
            with patch.object(icons.shutil, 'which', return_value='/usr/bin/7z'), patch.object(icons, 'ImageReader'):
                with self.assertRaises(ValueError):
                    icons.extract_icons(root)
            self.assertEqual(list(outside.iterdir()), [])

    def test_bad_images_are_not_published(self):
        reader = self.reader({'logo.png': {'Mode': '-rw', 'Size': '3'}})
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'application.AppImage').write_bytes(b'image')
            with patch.object(icons, 'ImageReader', return_value=reader), patch.object(icons, 'capture', return_value=b'bad'):
                self.assertEqual(icons.extract_icons(root)['status'], 'no_icon')
            self.assertEqual(sorted(p.name for p in root.iterdir()), ['application.AppImage'])


if __name__ == '__main__':
    unittest.main()
