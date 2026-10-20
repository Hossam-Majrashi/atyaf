"""Boundary tests for architecture checks and complete release asset sets."""
import hashlib
import importlib.util
import pathlib
import struct
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("release", pathlib.Path(__file__).resolve().parents[1] / "tool/verify_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def header(arch="x86_64"):
    value = bytearray(20)
    value[:6] = b"\x7fELF\x02\x01"
    value[8:11] = b"AI\x02"
    struct.pack_into("<H", value, 18, release.ARCHES[arch][0])
    return bytes(value)


def control(image, **changes):
    fields = {
        "zsync": "0.6.6", "Filename": image.name,
        "URL": "https://github.com/Hossam-Majrashi/atyaf/releases/download/v1.2.0/" + image.name,
        "Length": str(image.stat().st_size), "SHA-1": hashlib.sha1(image.read_bytes()).hexdigest(),
    }
    fields.update(changes)
    return ("\n".join(k + ": " + v for k, v in fields.items()) + "\n\n").encode() + b"binary block checksums"


class ReleaseValidation(unittest.TestCase):
    def test_both_real_elf_machine_values(self):
        for arch in release.ARCHES:
            release.elf_header(header(arch), arch, "fixture")

    def test_wrong_architecture_is_not_a_filename_alias(self):
        for arch, other in [("x86_64", "aarch64"), ("aarch64", "x86_64")]:
            with self.assertRaisesRegex(ValueError, "Wrong ELF architecture"):
                release.elf_header(header(other), arch, "renamed payload")

    def test_32_bit_and_unknown_targets_rejected(self):
        for arch in ("i686", "armv7", "armv7l"):
            with self.assertRaisesRegex(ValueError, "Unsupported Linux architecture"):
                release.elf_header(header(), arch, "fixture")
        value = bytearray(header()); value[4] = 1
        with self.assertRaisesRegex(ValueError, "ELF64"):
            release.elf_header(value, "x86_64", "ELF32")

    def test_short_corrupt_big_endian_headers_rejected(self):
        for value in (b"", b"\x7fELF", b"X" * 20, header().replace(b"\x02\x01", b"\x02\x02", 1)):
            with self.assertRaises(ValueError):
                release.elf_header(value, "x86_64", "bad fixture")

    def test_bundle_checks_all_plugins_and_engine(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle = pathlib.Path(temporary)
            (bundle / "lib").mkdir()
            for name in (*release.ELFS, "lib/plugin.so"):
                (bundle / name).write_bytes(header())
            release.verify_bundle(bundle, "x86_64")
            (bundle / "lib/plugin.so").write_bytes(header("aarch64"))
            with self.assertRaisesRegex(ValueError, "Wrong ELF architecture"):
                release.verify_bundle(bundle, "x86_64")

    def test_missing_engine_is_not_a_valid_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, "Missing bundle file"):
                release.verify_bundle(pathlib.Path(temporary), "x86_64")

    def test_zsync_matches_exact_image_content_and_name(self):
        with tempfile.TemporaryDirectory() as temporary:
            image = pathlib.Path(temporary) / "atyaf-1.2.0-linux-x86_64.AppImage"
            image.write_bytes(header())
            sync = image.with_suffix(".AppImage.zsync")
            sync.write_bytes(control(image))
            release.verify_zsync(image, sync)
            for changes in ({"Filename": "wrong.AppImage"}, {"Length": "999"}, {"SHA-1": "0" * 40}, {"URL": "https://example.invalid/wrong"}):
                sync.write_bytes(control(image, **changes))
                with self.assertRaises(ValueError):
                    release.verify_zsync(image, sync)
            sync.write_bytes(control(image)); image.write_bytes(header() + b"changed")
            with self.assertRaises(ValueError):
                release.verify_zsync(image, sync)

    def test_incomplete_zsync_header_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            image = pathlib.Path(temporary) / "image.AppImage"; image.write_bytes(header())
            sync = pathlib.Path(temporary) / "image.zsync"; sync.write_bytes(b"zsync: 0.6.6\n")
            with self.assertRaisesRegex(ValueError, "terminator"):
                release.verify_zsync(image, sync)

    def test_missing_assets_block_publication(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, "Missing/empty release asset"):
                release.verify_release(pathlib.Path(temporary), "1.2.0", ["x86_64", "aarch64"], True)
            self.assertFalse((pathlib.Path(temporary) / "SHA256SUMS").exists())

    def test_manifest_includes_exactly_fourteen_bound_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = pathlib.Path(temporary)
            for arch in release.ARCHES:
                for suffix in release.FORMATS:
                    path = directory / f"atyaf-1.2.0-linux-{arch}.{suffix}"
                    path.write_bytes(header(arch))
                image = directory / f"atyaf-1.2.0-linux-{arch}.AppImage"
                image.with_suffix(".AppImage.zsync").write_bytes(control(image))
            # Container parsing has separate real-package release checks. This
            # test isolates manifest coverage and actual zsync/hash binding.
            with mock.patch.object(release, "verify_deb"), mock.patch.object(release, "verify_archive"), mock.patch.object(release, "verify_flatpak"):
                files = release.verify_release(directory, "1.2.0", list(release.ARCHES), True)
            self.assertEqual(len(files), 14)
            lines = (directory / "SHA256SUMS").read_text().splitlines()
            self.assertEqual(len(lines), 14)
            for line in lines:
                checksum, name = line.split("  ")
                self.assertEqual(checksum, hashlib.sha256((directory / name).read_bytes()).hexdigest())
                self.assertNotIn("armv7", name); self.assertNotIn("i686", name)


if __name__ == "__main__":
    unittest.main()
