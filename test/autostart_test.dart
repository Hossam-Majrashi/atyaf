import 'dart:convert';
import 'dart:io';

import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/features/home/services/library_controller.dart';
import 'package:atyaf/features/settings/services/preferences_service.dart';
import 'package:atyaf/main.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/screens/desktop/autostart_dialog.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxRepository repository;
  late LinuxDesktopEntries entries;
  late LibraryController library;
  const profile = Profile(
    id: 'account',
    applicationId: 'app',
    name: 'MDM حساب',
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-startup-');
    runtime = LinuxRuntime(
      environment: {
        'HOME': temporary.path,
        'XDG_CONFIG_HOME': '${temporary.path}/config space',
        'XDG_DATA_HOME': '${temporary.path}/data "quoted"% بيانات',
        'PATH': '/usr/bin:/bin',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    repository.saveApplication(
      const Application(id: 'app', name: 'MDM', executable: '/usr/bin/true'),
    );
    repository.saveProfile(profile);
    entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: '/usr/bin/true',
    );
    final processes = LinuxProcesses(runtime, repository);
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    library = LibraryController(
      repository: repository,
      runtime: runtime,
      processes: processes,
      archives: archives,
      entries: entries,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(
        runtime,
        repository,
        archives,
        processes,
        autostart: entries,
      ),
    );
  });

  tearDown(() async {
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  });

  Future<List<File>> startupFiles() async =>
      Directory('${runtime.configHome}/autostart')
          .list()
          .where((v) => v.path.endsWith('.desktop'))
          .cast<File>()
          .toList();

  test('Explicit host startup pins library and uses Atyaf, not the profile executable', () async {
    expect(await entries.autostartEnabled(profile.id), isFalse);
    expect(await startupFiles(), isEmpty);
    await entries.setAutostart(profile, true);
    final file = (await startupFiles()).single;
    final first = await file.readAsString();
    expect(first, contains('--launch-profile'));
    expect(first, contains('"/usr/bin/env"'));
    expect(first, contains('XDG_DATA_HOME='));
    expect(first, contains('%%'));
    expect(first, contains(r'\\"quoted\\"'));
    expect(first, isNot(contains('application.AppImage')));
    expect(first, contains('StartupNotify=false'));
    expect((await file.stat()).mode & 0x1ff, 0x180);
    await entries.setAutostart(profile, true);
    expect(await file.readAsString(), first);
    expect(await entries.autostartEnabled(profile.id), isTrue);
    expect(repository.profiles.single.toJson(), profile.toJson());
    expect(repository.history(profile.id), isEmpty);
    await entries.removeAutostart(profile.id);
    expect(await file.exists(), isFalse);
    expect(await entries.autostartEnabled(profile.id), isFalse);
  });

  test(
    'Preserve modified startup entries and unrelated application startup files',
    () async {
      await entries.setAutostart(profile, true);
      final file = (await startupFiles()).single;
      final foreign = File('${file.parent.path}/misterdownloadmanager.desktop');
      await foreign.writeAsString('external startup');
      await file.writeAsString('${await file.readAsString()}# custom edit\n');
      await expectLater(
        entries.setAutostart(profile, true),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        entries.removeAutostart(profile.id),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), endsWith('# custom edit\n'));
      expect(await foreign.readAsString(), 'external startup');
    },
  );

  test(
    'Reject symlink and hardlink autostart targets without changing originals',
    () async {
      await entries.setAutostart(profile, true);
      final file = (await startupFiles()).single;
      await file.delete();
      final original = File('${temporary.path}/original');
      await original.writeAsString('keep');
      await Link(file.path).create(original.path);
      await expectLater(
        entries.removeAutostart(profile.id),
        throwsA(isA<FileSystemException>()),
      );
      await Link(file.path).delete();
      expect(
        (await Process.run('/usr/bin/ln', [original.path, file.path])).exitCode,
        0,
      );
      await expectLater(
        entries.setAutostart(profile, true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await original.readAsString(), 'keep');
    },
  );

  test('Refuse linked startup directories and unsafe registry', () async {
    final config = Directory(runtime.configHome);
    await config.create();
    final outside = await Directory('${temporary.path}/outside').create();
    await Link('${config.path}/autostart').create(outside.path);
    await expectLater(
      entries.setAutostart(profile, true),
      throwsA(isA<FileSystemException>()),
    );
    expect(await outside.list().toList(), isEmpty);
    await Link('${config.path}/autostart').delete();
    await File('${runtime.root}/autostart.json')
        .writeAsString('{"account":"../../unsafe"}');
    await expectLater(
      entries.setAutostart(profile, true),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'Profile deletion and successful restore remove registered startup only',
    () async {
      final backup = '${temporary.path}/backup.tar.gz';
      await library.backup.export(backup);
      await entries.setAutostart(profile, true);
      await expectLater(
        library.backup.restore('${temporary.path}/absent'),
        throwsA(anything),
      );
      expect(await entries.autostartEnabled(profile.id), isTrue);
      await library.backup.restore(backup);
      expect(await entries.autostartEnabled(profile.id), isFalse);
      await entries.setAutostart(profile, true);
      await library.deleteProfile(profile);
      expect(await entries.autostartEnabled(profile.id), isFalse);
    },
  );

  test(
    'Different libraries and profiles have independent startup entries',
    () async {
      await entries.setAutostart(profile, true);
      final otherRuntime = LinuxRuntime(
        environment: {
          ...runtime.host,
          'XDG_DATA_HOME': '${temporary.path}/other library',
        },
      );
      await Directory(otherRuntime.root).create(recursive: true);
      final otherEntries = LinuxDesktopEntries(
        otherRuntime,
        await File('assets/icon/icon.png').readAsBytes(),
        executable: '/usr/bin/true',
      );
      await otherEntries.setAutostart(profile, true);
      expect(await startupFiles(), hasLength(2));
      await entries.removeAutostart(profile.id);
      expect(await otherEntries.autostartEnabled(profile.id), isTrue);
      expect(await startupFiles(), hasLength(1));
    },
  );

  test('Linux desktop executes startup with exact library and account through launcher', () async {
    final capture = File('${temporary.path}/captured.json');
    final launcher = File('${temporary.path}/launcher "quoted"% برنامج');
    await launcher.writeAsString(
      '#!/usr/bin/python3\nimport os,sys,json\n'
      'with open(${jsonEncode(capture.path)}, "w") as f: json.dump([sys.argv[1:], os.environ["HOME"], os.environ["XDG_DATA_HOME"]], f)\n',
    );
    await Process.run('/usr/bin/chmod', ['700', launcher.path]);
    final service = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: launcher.path,
    );
    await service.setAutostart(profile, true);
    final result = await Process.run('/usr/bin/gio', [
      'launch',
      (await startupFiles()).single.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
    for (var i = 0; i < 100 && !await capture.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(jsonDecode(await capture.readAsString()), [
      ['--launch-profile', profile.id],
      temporary.path,
      runtime.dataHome,
    ]);
    expect(repository.history(profile.id), isEmpty);
  });

  test('Helper rollback and unsafe input boundaries', () async {
    final result = await Process.run('/usr/bin/python3', [
      'test/profile_autostart_test.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  Future<void> wait(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 30));
      if (ready()) return;
    }
    fail('Startup dialog did not complete');
  }

  for (final language in ['ar', 'en']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets(
        'Explicit startup enable/disable and cancel $language $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'onboarding_done': true,
            'language': language,
          });
          await tester.pumpWidget(
            AtyafApp(
              preferences: PreferencesService(
                await SharedPreferences.getInstance(),
              ),
              library: library,
              manageWindow: false,
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(Scaffold).first),
          );
          Future<void> open() async {
            final action = find.widgetWithText(OutlinedButton, l.autostart);
            await tester.scrollUntilVisible(
              action,
              180,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(action);
            await wait(
              tester,
              () =>
                  find.text(l.autostartDisabled).evaluate().isNotEmpty ||
                  find.text(l.autostartEnabled).evaluate().isNotEmpty,
            );
            await tester.pump(const Duration(milliseconds: 400));
          }

          await open();
          await tester.tap(find.text(l.close));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.runAsync(() async {
            expect(await entries.autostartEnabled(profile.id), isFalse);
          });
          await open();
          await tester.tap(find.text(l.enableAutostart));
          await wait(
            tester,
            () => find.text(l.autostartEnabled).evaluate().isNotEmpty,
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(AutostartDialog), findsOneWidget);
          await tester.runAsync(() async {
            expect(await entries.autostartEnabled(profile.id), isTrue);
          });
          await tester.tap(find.text(l.disableAutostart));
          await wait(
            tester,
            () => find.text(l.autostartDisabled).evaluate().isNotEmpty,
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.runAsync(() async {
            expect(await entries.autostartEnabled(profile.id), isFalse);
          });
          expect(
            jsonEncode(repository.profiles.single.toJson()),
            jsonEncode(profile.toJson()),
          );
          expect(repository.history(profile.id), isEmpty);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l.close));
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    }
  }
}
