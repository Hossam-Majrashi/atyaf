import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atyaf/features/home/services/library_controller.dart';
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
    final processes = LinuxProcesses(runtime, repository);
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
