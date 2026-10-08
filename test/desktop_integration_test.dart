import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atyaf/core/l10n/app_localizations_ar.dart';
import 'package:atyaf/core/l10n/app_localizations_en.dart';
import 'package:atyaf/features/home/services/library_controller.dart';
import 'package:atyaf/screens/desktop/diagnostic_reports.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/screens/desktop/shortcut_launch.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

class RacingProcesses extends LinuxProcesses {
  RacingProcesses(super.runtime, super.repository);
  bool raceNextLaunch = false;

  @override
  Future<void> launch(Application application, Profile profile) async {
    if (raceNextLaunch) {
      raceNextLaunch = false;
      // Simulate a competing launch winning after the shortcut's early check.
      await super.launch(application, profile);
    }
    await super.launch(application, profile);
  }
}

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxRepository repository;
  late LibraryController library;
  late LinuxDesktopEntries entries;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf desktop العربية ');
    runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_CONFIG_HOME': '${temporary.path}/system-config',
        'XDG_DATA_HOME': '${temporary.path}/system-data',
        'XDG_DATA_DIRS': '${temporary.path}/system-share',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    final processes = RacingProcesses(runtime, repository);
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
    );
    library = LibraryController(
      repository: repository,
      runtime: runtime,
      archives: archives,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(runtime, repository, archives, processes),
      entries: entries,
      processes: processes,
    );
  });
  tearDown(() async {
    for (final profile in repository.profiles) {
      if (library.processes.isRunning(profile.id)) {
        await library.processes.stop(profile.id, force: true);
      }
      await runtime.cleanupTemporary(profile.id);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  });

  test('Project gallery scans nested images, confines links, and normalizes previews without executing files', () async {
    final root = Directory('${temporary.path}/project العربية');
    final nested = Directory('${root.path}/assets/deep');
    await nested.create(recursive: true);
    await File('assets/icon/icon.png').copy('${nested.path}/logo.PNG');
    await File('${root.path}/broken.png').writeAsString('not an image');
    await File('${root.path}/other.svg').writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="16"><rect width="32" height="16" fill="red"/></svg>',
    );
    await File('${root.path}/readme.txt').writeAsString('not an image');
    await Link('${root.path}/outside.png')
        .create(File('assets/icon/icon.png').absolute.path);
    await Link('${root.path}/loop').create(root.path);
    await Link('${root.path}/internal.png').create('assets/deep/logo.PNG');
    final paths = await entries.scanImages(root.path);
    expect(paths, [
      'assets/deep/logo.PNG',
      'broken.png',
      'internal.png',
      'other.svg',
    ]);
    final previews = await entries.previewImages(root.path, paths);
    expect(previews[1], isNull);
    for (final index in [0, 2, 3]) {
      final bytes = base64Decode(previews[index]!);
      expect(ByteData.sublistView(bytes).getUint32(16), lessThanOrEqualTo(96));
    }
    final chosen = (await entries.previewImages(root.path, [
      'other.svg',
    ], size: 512)).single!;
    final bytes = base64Decode(chosen);
    expect(ByteData.sublistView(bytes).getUint32(16), 512);
    expect(ByteData.sublistView(bytes).getUint32(20), 256);
    await expectLater(
      entries.previewImages(root.path, ['../escape.png']),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      entries.previewImages(root.path, ['outside.png']),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      entries.scanImages('${root.path}/missing'),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      await entries.scanImages(
        (await Directory('${root.path}/empty').create()).path,
      ),
      isEmpty,
    );
  });

  test('Installed image extensions are shared by gallery discovery and include non-PNG codecs', () async {
    final formats = await entries.imageExtensions();
    expect(formats, containsAll(['png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg']));
    expect(formats.toSet().length, formats.length);
    final root = await Directory('${temporary.path}/format aliases').create();
    for (final extension in formats) {
      await File('${root.path}/sample.${extension.toUpperCase()}')
          .writeAsString('not an image');
    }
    expect((await entries.scanImages(root.path)).length, formats.length);
  });

  test('JPEG, GIF, BMP, SVG and PNG sources decode into independent static PNG copies', () async {
    final root = await Directory('${temporary.path}/multiple formats').create();
    await File('assets/icon/icon-64.png').copy('${root.path}/logo.png');
    await File('${root.path}/logo.svg').writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32"><rect width="64" height="32" fill="blue"/></svg>',
    );
    await File('${root.path}/logo.gif').writeAsBytes(
      base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'),
    );
    // Tiny fixed JPEG and BMP fixtures; no external image converter required.
    await File('${root.path}/logo.JPEG').writeAsBytes(
      base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAACAAIDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAVAQEBAAAAAAAAAAAAAAAAAAAHCf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/ADoDFU3/2Q==',
      ),
    );
    final bmp = ByteData(58)
      ..setUint8(0, 66)
      ..setUint8(1, 77)
      ..setUint32(2, 58, Endian.little)
      ..setUint32(10, 54, Endian.little)
      ..setUint32(14, 40, Endian.little)
      ..setInt32(18, 1, Endian.little)
      ..setInt32(22, 1, Endian.little)
      ..setUint16(26, 1, Endian.little)
      ..setUint16(28, 24, Endian.little)
      ..setUint32(34, 4, Endian.little)
      ..setUint8(56, 255);
    await File('${root.path}/logo.bmp').writeAsBytes(bmp.buffer.asUint8List());
    for (final name in [
      'logo.JPEG',
      'logo.gif',
      'logo.bmp',
      'logo.svg',
      'logo.png',
    ]) {
      final source = File('${root.path}/$name');
      final original = await source.readAsBytes();
      final encoded = await entries.readImage(source.path);
      expect(encoded, isNotNull, reason: name);
      final bytes = base64Decode(encoded!);
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(ByteData.sublistView(bytes).getUint32(16), lessThanOrEqualTo(512));
      expect(ByteData.sublistView(bytes).getUint32(20), lessThanOrEqualTo(512));
      expect(await source.readAsBytes(), original);
      final app = Application(
        id: 'app',
        name: name,
        executable: '/usr/bin/true',
        iconPng: encoded,
      );
      repository.saveApplication(app);
      await source.delete();
      expect(repository.applications.single.iconPng, encoded);
    }
  });

  test('Direct PNG file choice normalizes and persists independently of its original path without changing profiles', () async {
    final root = await Directory('${temporary.path}/personal pictures')
        .create();
    final source = await File('assets/icon/icon.png')
        .copy('${root.path}/photo "quoted"% صورة.PNG');
    final originalBytes = await source.readAsBytes();
    final encoded = (await entries.readImage(source.path))!;
    final bytes = base64Decode(encoded);
    expect(ByteData.sublistView(bytes).getUint32(16), 512);
    expect(ByteData.sublistView(bytes).getUint32(20), 512);
    expect(bytes.length, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(await source.readAsBytes(), originalBytes);
    const profile = Profile(
      id: 'direct',
      applicationId: 'app',
      name: 'Direct',
      arguments: ['unchanged'],
      environment: {'KEEP': 'unchanged'},
    );
    repository.saveProfile(profile);
    repository.saveApplication(
      Application(
        id: 'app',
        name: 'App',
        executable: '/usr/bin/true',
        iconPng: encoded,
      ),
    );
    await source.delete();
    final reopened = LinuxRepository(repository.path);
    try {
      final saved = reopened.applications.single;
      expect(saved.iconPng, encoded);
      await entries.create(saved, profile);
      expect(await File(entries.iconPath(profile.id)).readAsBytes(), bytes);
      expect(reopened.profiles.single.toJson(), profile.toJson());
    } finally {
      reopened.close();
    }
  });

  test('Direct image decoding enforces source limits, does not execute files, and rejects escaping links and relative paths', () async {
    final root = await Directory('${temporary.path}/selected files').create();
    final marker = File('${root.path}/must-not-run');
    final invalid = File('${root.path}/broken.png');
    await invalid.writeAsString('#!/bin/sh\ntouch "${marker.path}"\n');
    expect(await entries.readImage(invalid.path), isNull);
    expect(await marker.exists(), isFalse);
    expect(await entries.readImage('${root.path}/missing.png'), isNull);
    expect(await entries.readImage(root.path), isNull);
    final large = File('${root.path}/oversized.png');
    final handle = await large.open(mode: FileMode.write);
    try {
      await handle.truncate(16 * 1024 * 1024 + 1);
    } finally {
      await handle.close();
    }
    expect(await entries.readImage(large.path), isNull);
    final dimensions = File('${root.path}/dimensions.svg');
    await dimensions.writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" width="9000" height="32"><rect width="9000" height="32" fill="green"/></svg>',
    );
    expect(await entries.readImage(dimensions.path), isNull);
    final link = Link('${root.path}/outside.png');
    await link.create(File('assets/icon/icon.png').absolute.path);
    await expectLater(
      entries.readImage(link.path),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(entries.readImage('relative.png'), throwsArgumentError);
    await expectLater(
      entries.readImage('${root.path}/bad\x00.png'),
      throwsArgumentError,
    );
  });

  test('Selected icon persists independently and refreshes existing shortcuts only', () async {
    final root = await Directory('${temporary.path}/logos').create();
    final selected = File('${root.path}/chosen.svg');
    await selected.writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="red"/></svg>',
    );
    final encoded = (await entries.previewImages(root.path, [
      'chosen.svg',
    ], size: 512)).single!;
    final app = Application(
      id: 'app',
      name: 'App',
      executable: '/usr/bin/true',
      iconPng: encoded,
    );
    repository.saveApplication(app);
    expect(repository.applications.single.iconPng, encoded);
    expect(
      Application.fromJson({...app.toJson(), 'iconPng': null}).iconPng,
      isNull,
    );
    expect(
      () => Application.fromJson({...app.toJson(), 'iconPng': 'bad'}),
      throwsFormatException,
    );
    const present = Profile(
      id: 'present',
      applicationId: 'app',
      name: 'Present',
    );
    const absent = Profile(id: 'absent', applicationId: 'app', name: 'Absent');
    await entries.create(app, present);
    await selected.delete();
    await entries.refreshIcons(app, [present, absent]);
    expect(
      await File(entries.iconPath(present.id)).readAsBytes(),
      base64Decode(encoded),
    );
    expect(await File(entries.filePath(absent.id)).exists(), isFalse);
    expect(await File(entries.iconPath(absent.id)).exists(), isFalse);
  });

  test('Launch reports explain certificate, wallet, handler and interrupted status without altering original output', () async {
    const profile = Profile(id: 'advice', applicationId: 'app', name: 'Advice');
    repository.saveProfile(profile);
    final out = File('${runtime.profileRoot(profile.id)}/logs/out');
    final err = File('${runtime.profileRoot(profile.id)}/logs/err');
    await out.parent.create(recursive: true);
    await out.writeAsString('original output');
    final stderr =
        'net_error -202\nError contacting kwalletd6 (isEnabled)\n/usr/bin/xdg-open: line 554: test: : integer expected\n${'x' * (300 * 1024)}\ncomplete ending';
    await err.writeAsString(stderr);
    final record = <String, dynamic>{
      'pid': 123,
      'start': '2026-10-06T06:11:12',
      'stop': '2026-10-06T06:12:35',
      'exitCode': null,
      'interrupted': true,
      'stdout': out.path,
      'stderr': err.path,
    };
    for (final l in [AppLocalizationsEn(), AppLocalizationsAr()]) {
      final complete = await library.logs.completeReport(
        await launchReport(l, library, profile, record),
      );
      for (final advice in [
        l.lostExitAdvice,
        l.certificateAdvice,
        l.walletAdvice,
        l.desktopHandlerAdvice,
      ]) {
        expect(complete, contains(advice));
      }
      expect(complete, contains(stderr));
      expect(complete, contains('original output'));
      expect(logAdvice(l, 'net_error -2020'), isEmpty);
      expect(logAdvice(l, 'handshake failed; net_error -201'), isEmpty);
      expect(logAdvice(l, 'normal output'), isEmpty);
    }
  });

  test(
    'Menu entry has only account name and original installed application icon',
    () async {
      final desktop = File('${runtime.dataHome}/applications/original.desktop');
      await desktop.parent.create(recursive: true);
      await desktop.writeAsString(
        '[Desktop Entry]\nType=Application\nName=Original\nExec=/usr/bin/true %U\nIcon=original-icon\n',
      );
      final original = File(
        '${runtime.dataHome}/icons/hicolor/256x256/apps/original-icon.png',
      );
      await original.parent.create(recursive: true);
      await File('assets/icon/icon.png').copy(original.path);
      const app = Application(
        id: 'app',
        name: 'Original',
        executable: '/usr/bin/true',
      );
      const profile = Profile(
        id: 'account',
        applicationId: 'app',
        name: 'حساب العمل\nExec=bad',
      );
      await entries.create(app, profile);
      var text = await File(entries.filePath(profile.id)).readAsString();
      expect(text, contains(r'Name=حساب العمل\nExec=bad'));
      expect(await entries.findApplicationIcon(app), original.path);
      expect(text, contains('Icon=${entries.iconPath(profile.id)}\n'));
      expect(text, contains('--launch-profile "account"'));
      expect(text, isNot(contains('Original —')));
      expect(text, isNot(contains('\nExec=bad')));
      final check = await Process.run('desktop-file-validate', [
        entries.filePath(profile.id),
      ]);
      expect(check.exitCode, 0, reason: check.stderr.toString());
      await desktop.delete();
      await entries.create(app, profile);
      text = await File(entries.filePath(profile.id)).readAsString();
      expect(text, contains('Icon=${entries.iconPath(profile.id)}\n'));
      expect(await File(entries.iconPath(profile.id)).exists(), isTrue);
      await entries.remove(profile.id);
      expect(await File(entries.filePath(profile.id)).exists(), isFalse);
    },
  );

  test(
    'Managed Electron icon is discovered without executing candidates',
    () async {
      final root = Directory('${runtime.root}/applications/app/current');
      final icon = File(
        '${root.path}/resources/app/resources/linux/antigravity.png',
      );
      await icon.parent.create(recursive: true);
      await File('assets/icon/icon.png').copy(icon.path);
      final app = Application(
        id: 'app',
        name: 'Antigravity',
        executable: '${root.path}/antigravity',
        portableRoot: root.path,
      );
      expect(await entries.findApplicationIcon(app), icon.path);
    },
  );

  test('Nested Antigravity code.png becomes a decoded 512px absolute shortcut icon', () async {
    final root = Directory('${runtime.root}/applications/app/current');
    final program = '${root.path}/Antigravity IDE/antigravity-ide';
    final logo = File(
      '${File(program).parent.path}/resources/app/resources/linux/code.png',
    );
    await logo.parent.create(recursive: true);
    await File('assets/icon/icon.png').copy(logo.path);
    final app = Application(
      id: 'app',
      name: 'Antigravity',
      executable: program,
      portableRoot: root.path,
    );
    const profile = Profile(id: 'nested', applicationId: 'app', name: 'Work');
    expect(await entries.findApplicationIcon(app), logo.path);
    await entries.create(app, profile);
    final installed = File(entries.iconPath(profile.id));
    final bytes = await installed.readAsBytes();
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(16), 512);
    expect(header.getUint32(20), 512);
    expect(installed.path, contains('/512x512/apps/'));
    expect((await installed.stat()).mode & 0x1ff, 0x1a4);
    expect(
      await File(entries.filePath(profile.id)).readAsString(),
      contains('Icon=${installed.path}\n'),
    );
    expect(await logo.exists(), isTrue);
  });

  test(
    'Malformed PNG and missing themed icons are rejected; SVG is normalized',
    () async {
      final root = Directory('${runtime.root}/applications/app/current');
      final resources = Directory('${root.path}/resources/app/resources/linux');
      await resources.create(recursive: true);
      await File('${resources.path}/code.png').writeAsBytes([1, 2, 3]);
      final svg = File('${resources.path}/code.svg');
      await svg.writeAsString(
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#9064d4"/></svg>',
      );
      final app = Application(
        id: 'app',
        name: 'IDE',
        executable: '${root.path}/studio',
        portableRoot: root.path,
      );
      const profile = Profile(id: 'svg', applicationId: 'app', name: 'SVG');
      expect(await entries.findApplicationIcon(app), svg.path);
      await entries.create(app, profile);
      expect(
        (await File(entries.iconPath(profile.id)).readAsBytes()).sublist(1, 4),
        [80, 78, 71],
      );
      await svg.delete();
      expect(await entries.findApplicationIcon(app), isNull);
      final desktop = File('${runtime.dataHome}/applications/broken.desktop');
      await desktop.writeAsString(
        '[Desktop Entry]\nType=Application\nExec=/usr/bin/true\nIcon=atyaf-icon-that-does-not-exist\n',
      );
      expect(
        await entries.findApplicationIcon(
          const Application(
            id: 'missing',
            name: 'Missing',
            executable: '/usr/bin/true',
          ),
        ),
        isNull,
      );
      await entries.create(app, profile);
      final fallback = await File(entries.iconPath(profile.id)).readAsBytes();
      expect(ByteData.sublistView(fallback).getUint32(16), 512);
    },
  );

  test('Refreshing shortcuts migrates unsupported legacy icons and removes owned images only', () async {
    const app = Application(
      id: 'app',
      name: 'True',
      executable: '/usr/bin/true',
    );
    const profile = Profile(id: 'legacy', applicationId: 'app', name: 'Legacy');
    final legacy = File(entries.iconPath(profile.id, legacy: true));
    await legacy.parent.create(recursive: true);
    await File('assets/icon/icon.png').copy(legacy.path);
    await entries.create(app, profile);
    expect(await legacy.exists(), isFalse);
    final installed = File(entries.iconPath(profile.id));
    expect(await installed.exists(), isTrue);
    await entries.remove(profile.id);
    expect(await installed.exists(), isFalse);
    expect(await File(entries.filePath(profile.id)).exists(), isFalse);
    expect(await File('assets/icon/icon.png').exists(), isTrue);
  });

  test('xdg-open restores host desktop environment and preserves exact OAuth URL', () async {
    final bin = Directory('${temporary.path}/host bin');
    await bin.create();
    final handler = File('${bin.path}/xdg-open');
    await handler.writeAsString('''#!/usr/bin/python3
import json,os,sys
print(json.dumps([sys.argv[1:],dict(os.environ)],ensure_ascii=False))
''');
    await Process.run('chmod', ['700', handler.path]);
    runtime.host['PATH'] = '${bin.path}:/usr/bin:/bin';
    runtime.host['BROWSER'] = 'system-browser';
    runtime.host['KDE_SESSION_VERSION'] = '6';
    runtime.host['KDE_SESSION_UID'] = '1000';
    runtime.host['UNRELATED_HOST_SECRET'] = 'not-for-browser';
    const profile = Profile(
      id: 'links',
      applicationId: 'app',
      name: 'Links',
      environment: {'PROFILE_SECRET': 'private'},
    );
    repository.saveProfile(profile);
    await runtime.prepare(profile);
    final environment = runtime.environmentFor(profile);
    expect(
      environment['XDG_CONFIG_HOME'],
      isNot(runtime.host['XDG_CONFIG_HOME']),
    );
    expect(environment['BROWSER'], 'xdg-open');
    const url =
        r'https://example.org/oauth?code=a%20b&state=العربية;$(touch injected)#part';
    final opened = await Process.run(
      '/usr/bin/python3',
      [
        '-c',
        'import subprocess,sys; subprocess.run(["xdg-open",sys.argv[1]],check=True)',
        url,
      ],
      environment: environment,
      includeParentEnvironment: false,
    );
    expect(opened.exitCode, 0, reason: opened.stderr.toString());
    final output = jsonDecode(opened.stdout.toString()) as List;
    expect(output[0], [url]);
    expect(output[1]['XDG_CONFIG_HOME'], runtime.host['XDG_CONFIG_HOME']);
    expect(output[1]['XDG_DATA_HOME'], runtime.host['XDG_DATA_HOME']);
    expect(output[1]['HOME'], temporary.path);
    expect(output[1]['BROWSER'], 'system-browser');
    expect(output[1]['KDE_SESSION_VERSION'], '6');
    expect(output[1]['KDE_SESSION_UID'], '1000');
    expect((output[1] as Map).containsKey('PROFILE_SECRET'), isFalse);
    expect((output[1] as Map).containsKey('UNRELATED_HOST_SECRET'), isFalse);
    expect(
      await File(
        '${runtime.desktopHandlers(profile).directory}/environment.json',
      ).readAsString(),
      isNot(contains('not-for-browser')),
    );
    final custom = runtime.environmentFor(
      const Profile(
        id: 'custom',
        applicationId: 'app',
        name: 'Custom',
        environment: {'PATH': '/usr/bin', 'BROWSER': 'chosen-browser'},
      ),
    );
    expect(custom['PATH'], '/usr/bin');
    expect(custom['BROWSER'], 'chosen-browser');
    final wrapper = runtime.desktopHandlers(profile).opener;
    expect((await File(wrapper).stat()).mode & 0x1ff, 0x1c0);
    expect(
      (await File(
            '${File(wrapper).parent.path}/environment.json',
          ).stat()).mode &
          0x1ff,
      0x180,
    );
  });

  test('Real xdg-open selects KDE 6 handler instead of legacy integer-warning fallback', () async {
    final bin = await Directory('${temporary.path}/KDE handlers').create();
    final handler = File('${bin.path}/kde-open');
    await handler.writeAsString('''#!/usr/bin/python3
import json,os,sys
print(json.dumps([sys.argv[1:],os.environ.get('KDE_SESSION_VERSION'),os.environ.get('XDG_CONFIG_HOME')]))
''');
    final legacy = File('${bin.path}/kfmclient');
    await legacy.writeAsString(
      '#!/bin/sh\necho legacy-path-was-used >&2\nexit 1\n',
    );
    for (final file in [handler, legacy]) {
      await Process.run('chmod', ['700', file.path]);
    }
    runtime.host['PATH'] = '${bin.path}:/usr/bin:/bin';
    runtime.host['XDG_CURRENT_DESKTOP'] = 'KDE';
    runtime.host['KDE_SESSION_VERSION'] = '6';
    const profile = Profile(id: 'kde', applicationId: 'app', name: 'KDE');
    repository.saveProfile(profile);
    await runtime.prepare(profile);
    const url = 'https://example.org/oauth?state=exact%20url&code=abc';
    final result = await Process.run(
      runtime.desktopHandlers(profile).opener,
      [url],
      environment: runtime.environmentFor(profile),
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stderr, isEmpty);
    expect(jsonDecode(result.stdout.toString()), [
      [url],
      '6',
      runtime.host['XDG_CONFIG_HOME'],
    ]);
  });

  test(
    'Real host xdg-open uses host default HTTPS browser, not profile defaults',
    () async {
      final browser = File('${temporary.path}/atyaf-test-browser');
      await browser.writeAsString('''#!/usr/bin/python3
import json,os,sys
print(json.dumps([sys.argv[1:],os.environ['XDG_CONFIG_HOME']]))
''');
      await Process.run('chmod', ['700', browser.path]);
      final desktop = File(
        '${runtime.dataHome}/applications/test-browser.desktop',
      );
      await desktop.parent.create(recursive: true);
      await desktop.writeAsString(
        '[Desktop Entry]\nType=Application\nName=Test Browser\nExec=atyaf-test-browser %u\n',
      );
      final defaults = File('${runtime.configHome}/mimeapps.list');
      await defaults.parent.create(recursive: true);
      await defaults.writeAsString(
        '[Default Applications]\nx-scheme-handler/https=test-browser.desktop\n',
      );
      runtime.host['XDG_CURRENT_DESKTOP'] = 'X-Generic';
      runtime.host['DE'] = 'generic';
      runtime.host['PATH'] = '${temporary.path}:/usr/bin:/bin';
      runtime.host['BROWSER'] = '/usr/bin/false';
      const profile = Profile(
        id: 'default-browser',
        applicationId: 'app',
        name: 'Default Browser',
      );
      repository.saveProfile(profile);
      await runtime.prepare(profile);
      await File('${runtime.resolvedPaths(profile)['config']}/mimeapps.list')
          .writeAsString(
            '[Default Applications]\nx-scheme-handler/https=missing-browser.desktop\n',
          );
      const url =
          'https://example.org/documentation?state=account%20one&code=exact';
      final result = await Process.run(
        runtime.desktopHandlers(profile).opener,
        [url],
        environment: runtime.environmentFor(profile),
        includeParentEnvironment: false,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(jsonDecode(result.stdout.toString()), [
        [url],
        runtime.configHome,
      ]);
    },
  );

  test('Shortcut launch requires approval then supervises full logs without desktop UI', () async {
    const app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    const profile = Profile(
      id: 'launch',
      applicationId: 'app',
      name: 'Work',
      arguments: ['-c', 'print("account launched")'],
    );
    repository.saveApplication(app);
    repository.saveProfile(profile);
    expect(await launchDesktopShortcut(library, profile.id), isFalse);
    expect(repository.history(profile.id), isEmpty);
    final review = await runtime.inspect(app.executable);
    repository.saveProfile(profile.trusted(review.fingerprint));
    expect(await launchDesktopShortcut(library, profile.id), isTrue);
    final record = repository.history(profile.id).single;
    expect(record['exitCode'], 0);
    expect(
      await File(record['stdout'] as String).readAsString(),
      'account launched\n',
    );
    repository.saveProfile(profile.trusted('changed-executable'));
    expect(await launchDesktopShortcut(library, profile.id), isFalse);
    expect(repository.history(profile.id).length, 1);
  });

  test('Shortcut supervision outlives the drain deadline and cross-instance reconciliation', () async {
    const app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'inherited-pipes',
      applicationId: app.id,
      name: 'Inherited pipes',
      trustedFingerprint: review.fingerprint,
      arguments: [
        '-c',
        '''
import os, time, sys
if os.fork() == 0:
    print("helper ready", flush=True)
    time.sleep(6.5)
    print("late stdout", flush=True)
    print("late stderr", file=sys.stderr, flush=True)
    os._exit(0)
os._exit(0)
''',
      ],
    );
    repository.saveApplication(app);
    repository.saveProfile(profile);
    var completed = false;
    final shortcut = launchDesktopShortcut(library, profile.id).then((result) {
      completed = true;
      return result;
    });
    try {
      // Wait for the actual parent exit, while its helper retains both pipes.
      for (var attempt = 0; attempt < 200; attempt++) {
        if (repository.history(profile.id).isNotEmpty &&
            !library.processes.isRunning(profile.id)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(repository.history(profile.id), hasLength(1));
      expect(library.processes.isRunning(profile.id), isFalse);
      LinuxProcesses(runtime, repository).reconcile();
      expect(repository.history(profile.id).single['interrupted'], isTrue);
      await Future<void>.delayed(const Duration(seconds: 5, milliseconds: 200));
      expect(completed, isFalse);
      expect(await shortcut.timeout(const Duration(seconds: 5)), isTrue);
      final record = repository.history(profile.id).single;
      expect(record['exitCode'], 0);
      expect(record['interrupted'], isFalse);
      expect(
        await File(record['stdout'] as String).readAsString(),
        'helper ready\nlate stdout\n',
      );
      expect(
        await File(record['stderr'] as String).readAsString(),
        'late stderr\n',
      );
      expect(repository.errors, isEmpty);
    } finally {
      await shortcut;
    }
  });

  test('A shortcut launch race is treated as already supervised, not a UI fallback', () async {
    const app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'race',
      applicationId: app.id,
      name: 'Race',
      trustedFingerprint: review.fingerprint,
      arguments: ['-c', 'import time; time.sleep(30)'],
    );
    repository.saveApplication(app);
    repository.saveProfile(profile);
    (library.processes as RacingProcesses).raceNextLaunch = true;
    expect(await launchDesktopShortcut(library, profile.id), isTrue);
    expect(repository.history(profile.id), hasLength(1));
    expect(library.processes.isRunning(profile.id), isTrue);
    expect(repository.errors, isEmpty);
  });

  test(
    'Reopening a running shortcut does not duplicate or stop its account',
    () async {
      const app = Application(
        id: 'app',
        name: 'Python',
        executable: '/usr/bin/python3',
      );
      final review = await runtime.inspect(app.executable);
      final profile = Profile(
        id: 'running',
        applicationId: 'app',
        name: 'Work',
        trustedFingerprint: review.fingerprint,
        arguments: ['-c', 'import time; time.sleep(30)'],
      );
      repository.saveApplication(app);
      repository.saveProfile(profile);
      await library.processes.launch(app, profile);
      final pid = library.processes.pidFor(profile.id);
      expect(await launchDesktopShortcut(library, profile.id), isTrue);
      expect(library.processes.pidFor(profile.id), pid);
      expect(repository.history(profile.id).length, 1);
      expect(library.processes.isRunning(profile.id), isTrue);
    },
  );
}
