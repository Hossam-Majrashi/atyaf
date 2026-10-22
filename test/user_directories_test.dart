import 'dart:convert';
import 'dart:io';

import 'package:atyaf/core/l10n/app_localizations_ar.dart';
import 'package:atyaf/core/l10n/app_localizations_en.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/platform/linux/linux_user_directories.dart';
import 'package:atyaf/screens/desktop/diagnostic_reports.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  final prepared = <String>{};
  const profile = Profile(id: 'one', applicationId: 'app', name: 'xrevive');
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-user-dirs-');
    runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': '${temporary.path}/home عربية',
        'XDG_CONFIG_HOME': '${temporary.path}/host-config',
        'XDG_DATA_HOME': '${temporary.path}/host-data عربية',
        'GSETTINGS_BACKEND': 'memory',
      },
    );
    prepared.clear();
  });
  tearDown(() async {
    for (final id in prepared) {
      await runtime.cleanupTemporary(id);
    }
    await temporary.delete(recursive: true);
  });
  Future<void> prepare(Profile p) async {
    prepared.add(p.id);
    await runtime.prepare(p);
  }

  File config([String id = 'one']) =>
      File('${runtime.profileRoot(id)}/config/user-dirs.dirs');

  Future<List<String>> specialFolders(Profile p) async {
    final result = await Process.run(
      '/usr/bin/python3',
      [
        '-c',
        'import ctypes,json\n'
            'g=ctypes.CDLL("libglib-2.0.so.0")\n'
            'g.g_get_user_special_dir.restype=ctypes.c_char_p\n'
            'print(json.dumps([g.g_get_user_special_dir(i).decode() for i in range(8)]))\n',
      ],
      environment: runtime.environmentFor(p),
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return List<String>.from(jsonDecode(result.stdout as String) as List);
  }

  test('Default preparation supplies all GLib special folders, privately and independently without copying host files or changing records', () async {
    final hostConfig = File('${runtime.configHome}/user-dirs.dirs');
    await hostConfig.parent.create(recursive: true);
    await hostConfig.writeAsString(
      'XDG_DOCUMENTS_DIR="/private/host/documents"\n',
    );
    final home = Directory(runtime.host['HOME']!);
    await home.create(recursive: true);
    await File('${home.path}/secret').writeAsString('never copy me');
    final original = profile.toJson();
    final host = Map.of(runtime.host);
    await prepare(profile);
    final raw = await config().readAsString();
    expect(raw, isNot(contains('/private/host/documents')));
    expect((await config().stat()).mode & 0x1ff, 0x180);
    final folders = await specialFolders(profile);
    expect(folders, hasLength(8));
    for (final path in folders) {
      expect(
        path,
        startsWith('${runtime.profileRoot('one')}/data/user-directories/'),
      );
      final dir = Directory(path);
      expect(await dir.exists(), isTrue);
      expect((await dir.stat()).mode & 0x1ff, 0x1c0);
      expect(await dir.list().toList(), isEmpty);
    }
    final stat = await config().stat();
    await prepare(profile);
    expect((await config().stat()).modified, stat.modified);
    const second = Profile(id: 'two', applicationId: 'app', name: 'Two');
    await prepare(second);
    expect(
      (await specialFolders(second)).toSet().intersection(folders.toSet()),
      isEmpty,
    );
    expect(runtime.host, host);
    expect(profile.toJson(), original);
    expect(runtime.environmentFor(profile)['HOME'], runtime.host['HOME']);
    expect(
      await hostConfig.readAsString(),
      'XDG_DOCUMENTS_DIR="/private/host/documents"\n',
    );
    expect(await File('${home.path}/secret').readAsString(), 'never copy me');
  });

  test(
    'Existing, empty and edited user files remain byte-for-byte unchanged',
    () async {
      await config().parent.create(recursive: true);
      for (final raw in ['', 'XDG_DOCUMENTS_DIR="/chosen/documents"\n']) {
        await config().writeAsString(raw);
        await prepare(profile);
        expect(await config().readAsString(), raw);
        expect(
          await Directory('${runtime.profileRoot('one')}/data/user-directories')
              .exists(),
          isFalse,
        );
      }
      await config().delete();
      await prepare(profile);
      final edited = '${await config().readAsString()}# user edit\n';
      await config().writeAsString(edited);
      await prepare(profile);
      expect(await config().readAsString(), edited);
    },
  );

  test(
    'Explicit config/data paths and environment overrides are not seeded',
    () async {
      var index = 0;
      for (final key in [
        'config',
        'data',
        'XDG_CONFIG_HOME',
        'XDG_DATA_HOME',
      ]) {
        final p = Profile(
          id: 'custom-${index++}',
          applicationId: 'app',
          name: key,
          paths: key.startsWith('XDG_')
              ? const {}
              : {key: '${temporary.path}/custom-$key'},
          environment: key.startsWith('XDG_')
              ? {key: '${temporary.path}/custom-$key'}
              : const {},
        );
        await prepare(p);
        final env = runtime.environmentFor(p);
        expect(
          await File('${env['XDG_CONFIG_HOME']}/user-dirs.dirs').exists(),
          isFalse,
        );
        expect(
          await Directory('${env['XDG_DATA_HOME']}/user-directories').exists(),
          isFalse,
        );
      }
    },
  );

  test(
    'A restored generated file is relocated, but modified files are not',
    () async {
      await prepare(profile);
      final original = await config().readAsString();
      final moved = Directory('${temporary.path}/relocated');
      await Directory(runtime.root).rename(moved.path);
      await Directory(runtime.root).create(recursive: true);
      final newProfile = '${moved.path}/profiles/one';
      await LinuxUserDirectories.prepare(moved.path, newProfile);
      final relocated = File('$newProfile/config/user-dirs.dirs');
      final raw = await relocated.readAsString();
      expect(raw, isNot(original));
      expect(raw, contains('$newProfile/data/user-directories/Documents'));
      expect(raw, isNot(contains('${runtime.root}/profiles/one/')));
      final edited = '$raw# user edit\n';
      await relocated.writeAsString(edited);
      await LinuxUserDirectories.prepare(moved.path, newProfile);
      expect(await relocated.readAsString(), edited);
    },
  );

  test('Symlink, hardlink, FIFO, oversized configuration and data aliases are refused without changing external files', () async {
    await config().parent.create(recursive: true);
    final external = File('${temporary.path}/external');
    await external.writeAsString('preserve');
    await Link(config().path).create(external.path);
    await expectLater(prepare(profile), throwsA(isA<FileSystemException>()));
    await Link(config().path).delete();
    await Process.run('/usr/bin/ln', [external.path, config().path]);
    await expectLater(prepare(profile), throwsA(isA<FileSystemException>()));
    await config().delete();
    await Process.run('/usr/bin/mkfifo', [config().path]);
    await expectLater(
      prepare(profile).timeout(const Duration(seconds: 10)),
      throwsA(isA<FileSystemException>()),
    );
    await File(config().path).delete();
    await config().writeAsString('x' * 65537);
    await expectLater(prepare(profile), throwsA(isA<FileSystemException>()));
    await config().delete();
    final data = Directory('${runtime.profileRoot('one')}/data');
    await data.delete();
    await Link(data.path).create(temporary.path);
    await expectLater(prepare(profile), throwsA(isA<FileSystemException>()));
    expect(await external.readAsString(), 'preserve');
    expect(
      await Directory('${temporary.path}/user-directories').exists(),
      isFalse,
    );
  });

  test('Unsafe folder permissions and profile aliases are refused', () async {
    await prepare(profile);
    final documents = Directory(
      '${runtime.profileRoot('one')}/data/user-directories/Documents',
    );
    await Process.run('/usr/bin/chmod', ['777', documents.path]);
    await expectLater(prepare(profile), throwsA(isA<FileSystemException>()));
    final other = await Directory('${temporary.path}/outside').create();
    await Link('${runtime.root}/profiles/alias').create(other.path);
    await expectLater(
      LinuxUserDirectories.prepare(
        runtime.root,
        '${runtime.root}/profiles/alias',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await other.list().toList(), isEmpty);
  });

  test('Tauri advice is localized and narrow, never a generic panic diagnosis', () {
    const signature =
        'Failed to setup app: error encountered during setup hook: unknown path';
    for (final l in [AppLocalizationsEn(), AppLocalizationsAr()]) {
      expect(logAdvice(l, "thread 'main' panicked\n$signature\r\n"), [
        l.tauriUnknownPathAdvice,
      ]);
      for (final output in [
        'unknown path',
        'Failed to setup app: another error',
        '$signature suffix',
        'prefix $signature',
      ]) {
        expect(logAdvice(l, output), isEmpty);
      }
    }
  });
}
