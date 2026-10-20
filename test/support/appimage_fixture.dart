import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A host ELF with the AppImage identification bytes. Exercises safe copying,
/// approval and real process supervision without needing FUSE or executing an
/// untrusted downloaded image. This is not a complete AppImage filesystem.
Future<File> appImageFixture(
  String path, {
  int type = 2,
  String version = 'one',
}) async {
  final bytes = await File('/usr/bin/env').readAsBytes();
  bytes.setRange(8, 11, [65, 73, type]);
  final file = await File(path).writeAsBytes([...bytes, ...version.codeUnits]);
  await Process.run('chmod', ['600', '--', file.path]);
  return file;
}

/// Tiny real SquashFS/ISO image fixtures containing a desktop entry, SVG logo,
/// internal .DirIcon link and an AppRun which must never be executed. The ELF
/// identification header is synthetic; these fixtures are read, not launched.
Future<File> appImageWithIcons(String path, {bool iso = false}) async {
  final encoded = await File(
    'test/fixtures/appimage-icons.${iso ? 'iso' : 'squashfs'}.gz.b64',
  ).readAsString();
  final filesystem = gzip.decode(base64Decode(encoded.trim()));
  final header = ByteData(64)
    ..setUint8(0, 127)
    ..setUint8(1, 69)
    ..setUint8(2, 76)
    ..setUint8(3, 70)
    ..setUint8(4, 2)
    ..setUint8(5, 1)
    ..setUint8(6, 1)
    ..setUint8(8, 65)
    ..setUint8(9, 73)
    ..setUint8(10, iso ? 1 : 2)
    ..setUint16(16, 3, Endian.little)
    ..setUint16(18, 62, Endian.little);
  final bytes = header.buffer.asUint8List();
  return File(path).writeAsBytes(
    iso ? [...bytes, ...filesystem.skip(64)] : [...bytes, ...filesystem],
  );
}
