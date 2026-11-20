import 'dart:io';

import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/features/home/services/library_controller.dart';
import 'package:atyaf/features/settings/services/preferences_service.dart';
import 'package:atyaf/main.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_library_layout.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutFailingRepository extends LinuxRepository {
  LayoutFailingRepository(super.path);
  bool failProfile = true;
  @override
  void saveProfile(Profile profile) {
    if (failProfile) throw StateError('Injected relocation failure');
    super.saveProfile(profile);
  }
}

void main() {
  late Directory temporary;
  late Map<String, String> environment;
  late LinuxRuntime runtime;
  LinuxRepository? repository;
  LibraryController? library;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-layout بيانات ');
    environment = {
      ...Platform.environment,
      'HOME': temporary.path,
      'XDG_DATA_HOME': '${temporary.path}/data',
      'XDG_CONFIG_HOME': '${temporary.path}/config',
      'PATH': '/usr/bin:/bin',
    };
    runtime = LinuxRuntime(environment: environment);
  });

  tearDown(() async {
    library?.dispose();
    library = null;
    repository?.close();
    repository = null;
    await runtime.cleanupTemporary('account');
    await temporary.delete(recursive: true);
  });

  Future<LibraryController> controller() async {
    await Directory(runtime.root).create(recursive: true);
    final repo = repository = LinuxRepository('${runtime.root}/library.sqlite');
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    final processes = LinuxProcesses(runtime, repo);
    final entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: '/usr/bin/true',
    );
    return library = LibraryController(
      repository: repo,
      runtime: runtime,
      archives: archives,
      processes: processes,
      entries: entries,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(runtime, repo, archives, processes),
    );
  }

  Future<Application> application(LibraryController c) async {
    final input = File('${temporary.path}/source');
    await input.writeAsString('#!/bin/sh\nprintf complete\n');
    await Process.run('/usr/bin/chmod', ['700', input.path]);
    final staged = await c.storage.stageExecutable(input.path);
    final app = await c.applicationsService.addManaged(
      'Managed fixture',
      staged,
      'source',
    );
    await c.storage.discard(staged);
    return app;
  }

  test(
    'Default and invalid XDG fallback use atyaf, not the application ID',
    () async {
      runtime = await LinuxLibraryLayout.prepare(environment);
      expect(runtime.root, '${temporary.path}/data/atyaf');
      expect(await Directory(runtime.root).exists(), isTrue);
      expect(
        await FileSystemEntity.type(
          '${runtime.dataHome}/com.h.atyaf',
          followLinks: false,
        ),
        FileSystemEntityType.notFound,
      );
      expect(
        LinuxRuntime(environment: {...environment, 'XDG_DATA_HOME': 'relative'})
            .root,
        '${temporary.path}/.local/share/atyaf',
      );
    },
  );

  test('Rename preserves records, credentials, history, startup and terminal registrations; is idempotent', () async {
    runtime = LinuxRuntime(environment: environment, legacyStorage: true);
    final c = await controller();
    final app = await application(c);
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'account',
      applicationId: app.id,
      name: 'حساب',
      paths: {'data': '${runtime.profileRoot('account')}/data'},
      arguments: [
        '${runtime.profileRoot('account')}/data',
        'literal --unchanged',
      ],
      environment: {'EXTERNAL': temporary.path},
      trustedFingerprint: review.fingerprint,
      workingDirectory: runtime.root,
    );
    repository!.saveProfile(profile);
    await runtime.prepare(profile);
    final credential = File(
      '${runtime.profileRoot(profile.id)}/data/credentials',
    );
    await credential.writeAsString('private fixture');
    final log = File('${runtime.profileRoot(profile.id)}/logs/output');
    await log.parent.create();
    await log.writeAsString('complete historical output');
    repository!.recordLaunch({
      'id': 'history',
      'profileId': profile.id,
      'stdout': log.path,
      'stderr': log.path,
      'executable': app.executable,
      'exitCode': 7,
      'stop': 'past',
    });
    final entries = c.entries as LinuxDesktopEntries;
    await entries.setAutostart(profile, true);
    await entries.createTerminalCommand(
      profile.id,
      'layout-fixture',
      argumentsWarning: 'no args',
    );
    await entries.create(app, profile);
    final command = File('${temporary.path}/.local/bin/layout-fixture');
    final commandBytes = await command.readAsBytes();
    final startup = (await Directory(
      '${runtime.configHome}/autostart',
    ).list().toList()).single;
    final startupBytes = await File(startup.path).readAsBytes();
    final oldRoot = runtime.root;
    c.dispose();
    library = null;
    repository!.close();
    repository = null;
    runtime = await LinuxLibraryLayout.prepare(environment);
    expect(runtime.root, '${runtime.dataHome}/atyaf');
    expect(await Directory(oldRoot).resolveSymbolicLinks(), runtime.root);
    expect(await credential.readAsString(), 'private fixture');
    final repo = repository = LinuxRepository('${runtime.root}/library.sqlite');
    await LinuxLibraryLayout.finish(runtime, repo);
    expect(
      repo.applications.single.executable,
      startsWith('${runtime.root}/applications/'),
    );
    expect(repo.profiles.single.trustedFingerprint, review.fingerprint);
    expect(repo.profiles.single.workingDirectory, runtime.root);
    expect(
      repo.profiles.single.paths['data'],
      '${runtime.profileRoot('account')}/data',
    );
    expect(repo.profiles.single.environment, profile.environment);
    expect(repo.profiles.single.arguments.last, profile.arguments.last);
    expect(
      await File(repo.history('account').single['stdout'] as String)
          .readAsString(),
      'complete historical output',
    );
    expect(repo.history('account').single['exitCode'], 7);
    final relocated = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: '/usr/bin/true',
    );
    expect(await relocated.autostartEnabled(profile.id), isTrue);
    expect(await File(startup.path).readAsBytes(), startupBytes);
    expect(await command.readAsBytes(), commandBytes);
    expect(
      (await relocated.terminalCommands(profile.id)).single.name,
      'layout-fixture',
    );
    final changes = repo.db.select('SELECT total_changes() AS n').single['n'];
    await LinuxLibraryLayout.finish(runtime, repo);
    expect(repo.db.select('SELECT total_changes() AS n').single['n'], changes);
    // Backups after migration must restore without the original compatibility alias.
    final archive = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    final backup = LinuxBackup(
      runtime,
      repo,
      archive,
      LinuxProcesses(runtime, repo),
    );
    final output = '${temporary.path}/relocated.tar.gz';
    await backup.export(output);
    final restoredRuntime = LinuxRuntime(
      environment: {
        ...environment,
        'XDG_DATA_HOME': '${temporary.path}/restored',
      },
    );
    await Directory(restoredRuntime.root).create(recursive: true);
    final restoredRepository = LinuxRepository(
      '${restoredRuntime.root}/library.sqlite',
    );
    try {
      await LinuxBackup(
        restoredRuntime,
        restoredRepository,
        LinuxArchives(
          restoredRuntime,
          File('assets/linux/archive_helper.py').absolute.path,
        ),
        LinuxProcesses(restoredRuntime, restoredRepository),
      ).restore(output);
      expect(
        restoredRepository.applications.single.executable,
        startsWith(restoredRuntime.root),
      );
      expect(
        restoredRepository.profiles.single.workingDirectory,
        restoredRuntime.root,
      );
      final data = restoredRepository.profiles.single.paths['data']!;
      expect(data, startsWith(restoredRuntime.root));
      expect(await File('$data/credentials').readAsString(), 'private fixture');
      expect(restoredRepository.profiles.single.trustedFingerprint, isEmpty);
    } finally {
      restoredRepository.close();
    }
    await relocated.removeAutostart(profile.id);
    await relocated.removeTerminalCommands(profile.id);
    expect(await File(startup.path).exists(), isFalse);
    expect(await command.exists(), isFalse);
    expect(await File(relocated.filePath(profile.id)).exists(), isTrue);
  });

  test(
    'An open old SQLite connection defers migration without hiding its library',
    () async {
      runtime = LinuxRuntime(environment: environment, legacyStorage: true);
      final c = await controller();
      final app = await application(c);
      final old = runtime.root;
      final deferred = await LinuxLibraryLayout.prepare(environment);
      expect(deferred.root, old);
      expect(await File(app.executable).exists(), isTrue);
      expect(await Directory('${runtime.dataHome}/atyaf').exists(), isFalse);
      c.dispose();
      library = null;
      repository!.close();
      repository = null;
      runtime = await LinuxLibraryLayout.prepare(environment);
      expect(runtime.hasLegacyAlias, isTrue);
    },
  );

  test('Concurrent preparations share one renamed library and record relocation rolls back on failure', () async {
    runtime = LinuxRuntime(environment: environment, legacyStorage: true);
    final c = await controller();
    final app = await application(c);
    final profile = Profile(
      id: 'account',
      applicationId: app.id,
      name: 'Account',
      paths: {'data': '${runtime.profileRoot('account')}/data'},
    );
    repository!.saveProfile(profile);
    c.dispose();
    library = null;
    repository!.close();
    repository = null;
    final results = await Future.wait([
      LinuxLibraryLayout.prepare(environment),
      LinuxLibraryLayout.prepare(environment),
    ]);
    expect(results.first.root, results.last.root);
    runtime = results.first;
    expect(runtime.hasLegacyAlias, isTrue);
    final failing = LayoutFailingRepository('${runtime.root}/library.sqlite');
    repository = failing;
    await expectLater(
      LinuxLibraryLayout.finish(runtime, failing),
      throwsStateError,
    );
    expect(failing.applications.single.toJson(), app.toJson());
    expect(failing.profiles.single.toJson(), profile.toJson());
    expect(await File(app.executable).exists(), isTrue);
    failing.failProfile = false;
    await LinuxLibraryLayout.finish(runtime, failing);
    expect(failing.applications.single.executable, startsWith(runtime.root));
    expect(failing.profiles.single.paths['data'], startsWith(runtime.root));
  });

  test('Interrupted rename repairs only its compatibility link; separate libraries are never merged', () async {
    final old = '${runtime.dataHome}/com.h.atyaf';
    await Directory(old).create(recursive: true);
    runtime = await LinuxLibraryLayout.prepare(environment);
    await Link(old).delete();
    runtime = await LinuxLibraryLayout.prepare(environment);
    expect(runtime.hasLegacyAlias, isTrue);
    await Link(old).delete();
    await Directory(old).create();
    await File('$old/keep').writeAsString('separate library');
    runtime = await LinuxLibraryLayout.prepare(environment);
    expect(runtime.hasLegacyAlias, isFalse);
    expect(await File('$old/keep').readAsString(), 'separate library');
  });

  test('Unsafe linked layout roots and layout locks are refused', () async {
    await Directory(runtime.dataHome).create(recursive: true);
    final outside = await Directory('${temporary.path}/outside').create();
    final alias = Link('${runtime.dataHome}/com.h.atyaf');
    await alias.create(outside.path);
    await expectLater(
      LinuxLibraryLayout.prepare(environment),
      throwsA(isA<FileSystemException>()),
    );
    await alias.delete();
    await Link(runtime.root).create(outside.path);
    await expectLater(
      LinuxLibraryLayout.prepare(environment),
      throwsA(isA<FileSystemException>()),
    );
    await Link(runtime.root).delete();
    await File('${runtime.dataHome}/.atyaf-layout.lock').delete();
    final keep = File('${temporary.path}/keep');
    await keep.writeAsString('keep');
    await Link('${runtime.dataHome}/.atyaf-layout.lock').create(keep.path);
    await expectLater(
      LinuxLibraryLayout.prepare(environment),
      throwsA(isA<FileSystemException>()),
    );
    expect(await keep.readAsString(), 'keep');
    await Link('${runtime.dataHome}/.atyaf-layout.lock').delete();
    await Directory(alias.path).create();
    await Link('${alias.path}/library.sqlite')
        .create('${temporary.path}/missing-target');
    await expectLater(
      LinuxLibraryLayout.prepare(environment),
      throwsA(isA<FileSystemException>()),
    );
    expect(await Directory(alias.path).exists(), isTrue);
  });

  test('Delete removes the complete application ID, profiles, history, temp, shortcuts and integrations', () async {
    final c = await controller();
    final app = await application(c);
    final peer = await application(c);
    final custom = await Directory('${temporary.path}/custom').create();
    await File('${custom.path}/keep').writeAsString('custom data');
    final profile = Profile(
      id: 'account',
      applicationId: app.id,
      name: 'Account',
      paths: {'cache': custom.path},
    );
    repository!.saveProfile(profile);
    await runtime.prepare(profile);
    await File('${runtime.shortTemporary('account')}/cache')
        .writeAsString('temp');
    final oldTemp = runtime
        .shortTemporary('account')
        .replaceFirst('/var/tmp/', '/tmp/');
    final prepared = await Process.run('/usr/bin/python3', [
      '-c',
      LinuxRuntime.temporaryHelper,
      Directory(oldTemp).parent.path,
      oldTemp.split('/').last,
      'prepare',
    ]);
    expect(prepared.exitCode, 0);
    await File('$oldTemp/partial').writeAsString('old extraction');
    final entries = c.entries as LinuxDesktopEntries;
    await entries.create(app, profile);
    await entries.setAutostart(profile, true);
    await entries.createTerminalCommand(
      profile.id,
      'delete-fixture',
      argumentsWarning: 'no args',
    );
    repository!.recordLaunch({
      'id': 'log',
      'profileId': profile.id,
      'stop': 'past',
    });
    await File('${Directory(app.portableRoot!).parent.path}/old-version')
        .writeAsString('owned residue');
    await c.deleteApplication(app);
    expect(
      await Directory(Directory(app.portableRoot!).parent.path).exists(),
      isFalse,
    );
    expect(await Directory(runtime.profileRoot(profile.id)).exists(), isFalse);
    expect(
      await Directory(runtime.shortTemporary(profile.id)).exists(),
      isFalse,
    );
    expect(await Directory(oldTemp).exists(), isFalse);
    expect(repository!.profiles, isEmpty);
    expect(repository!.history(profile.id), isEmpty);
    expect(repository!.applications.single.id, peer.id);
    expect(await File(peer.executable).exists(), isTrue);
    expect(await File(entries.filePath(profile.id)).exists(), isFalse);
    expect(await File(entries.iconPath(profile.id)).exists(), isFalse);
    expect(await entries.autostartEnabled(profile.id), isFalse);
    expect(
      await File('${temporary.path}/.local/bin/delete-fixture').exists(),
      isFalse,
    );
    expect(await File('${custom.path}/keep').readAsString(), 'custom data');
    expect(await File('${temporary.path}/source').exists(), isTrue);
  });

  test('Running profiles block all application deletion until supervision completes', () async {
    final c = await controller();
    final app = await application(c);
    await File(app.executable)
        .writeAsString('#!/bin/sh\nexec /usr/bin/sleep 30\n');
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'account',
      applicationId: app.id,
      name: 'Running',
      trustedFingerprint: review.fingerprint,
    );
    repository!.saveProfile(profile);
    await c.processes.launch(app, profile);
    try {
      await expectLater(c.deleteApplication(app), throwsStateError);
      expect(repository!.applications.single.id, app.id);
      expect(repository!.profiles.single.id, profile.id);
      expect(await File(app.executable).exists(), isTrue);
    } finally {
      await c.processes.stop(profile.id);
      await c.processes.waitForPendingExits();
    }
    await c.deleteApplication(app);
    expect(
      await Directory(Directory(app.portableRoot!).parent.path).exists(),
      isFalse,
    );
  });

  test(
    'Legacy portable and external deletion preserve neighboring/external files',
    () async {
      final c = await controller();
      final portable = await Directory('${runtime.root}/portable/legacy')
          .create(recursive: true);
      final neighbor = await Directory('${runtime.root}/portable/peer')
          .create();
      const external = Application(
        id: 'external',
        name: 'External',
        executable: '/usr/bin/true',
      );
      final legacy = Application(
        id: 'legacy',
        name: 'Legacy',
        executable: '${portable.path}/run',
        portableRoot: portable.path,
      );
      repository!.saveApplication(legacy);
      repository!.saveApplication(external);
      await c.deleteApplication(legacy);
      await c.deleteApplication(external);
      expect(await portable.exists(), isFalse);
      expect(await neighbor.exists(), isTrue);
      expect(await File('/usr/bin/true').exists(), isTrue);
    },
  );

  test('Empty UUID remnants are cleaned; nonempty, unrelated and linked folders are preserved', () async {
    await Directory('${runtime.root}/applications').create(recursive: true);
    const ids = [
      '0ba20ee4-4934-4689-ad88-506861043190',
      '01f3cde7-3899-48d8-8a7d-8b4d8811e068',
      '027629c1-17bb-4d84-b9c3-015ff86e629e',
    ];
    final empty = await Directory('${runtime.root}/applications/${ids[0]}')
        .create();
    final nonempty = await Directory('${runtime.root}/applications/${ids[1]}')
        .create();
    await File('${nonempty.path}/keep').writeAsString('unknown data');
    final unrelated = await Directory('${runtime.root}/applications/not-an-id')
        .create();
    final outside = await Directory('${temporary.path}/outside').create();
    final link = Link('${runtime.root}/applications/${ids[2]}');
    await link.create(outside.path);
    await runtime.cleanupEmptyApplicationDirectories();
    expect(await empty.exists(), isFalse);
    expect(await File('${nonempty.path}/keep').readAsString(), 'unknown data');
    expect(await unrelated.exists(), isTrue);
    expect(await link.exists(), isTrue);
    expect(await outside.exists(), isTrue);
  });

  test(
    'A symlink collection cannot redirect cleanup or application removal',
    () async {
      await Directory(runtime.root).create(recursive: true);
      final outside = await Directory('${temporary.path}/outside').create();
      await Directory('${outside.path}/id/current').create(recursive: true);
      final keep = File('${outside.path}/id/current/keep');
      await keep.writeAsString('keep');
      await Link('${runtime.root}/applications').create(outside.path);
      await runtime.cleanupEmptyApplicationDirectories();
      await expectLater(
        runtime.deleteApplicationFiles(
          Application(
            id: 'id',
            name: 'Unsafe',
            executable: keep.path,
            portableRoot: '${runtime.root}/applications/id/current',
          ),
        ),
        throwsArgumentError,
      );
      expect(await keep.readAsString(), 'keep');
    },
  );

  for (final language in ['ar', 'en']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets(
        'Full application deletion confirmation/cancel $language $size',
        (tester) async {
          final c = (await tester.runAsync(controller))!;
          final app = (await tester.runAsync(() => application(c)))!;
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
              library: c,
              manageWindow: false,
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(Scaffold).first),
          );
          Future<void> open() async {
            await tester.tap(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is PopupMenuButton<String> &&
                        widget.tooltip == l.edit,
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(l.delete));
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.text(l.deleteApplicationConfirm), findsOneWidget);
          }

          await open();
          await tester.tap(find.text(l.cancel));
          await tester.pumpAndSettle();
          expect(repository!.applications.single.id, app.id);
          await open();
          await tester.tap(find.widgetWithText(FilledButton, l.delete));
          for (var i = 0; i < 200 && repository!.applications.isNotEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(repository!.applications, isEmpty);
          await tester.runAsync(() async {
            expect(
              await Directory(Directory(app.portableRoot!).parent.path)
                  .exists(),
              isFalse,
            );
          });
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
