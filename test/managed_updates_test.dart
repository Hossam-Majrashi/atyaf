import 'dart:io';

import 'package:atyaf/features/applications/services/application_service.dart';
import 'package:atyaf/features/updates/services/update_service.dart';
import 'package:atyaf/shared/services/managed_storage_service.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingRepository extends LinuxRepository {
  FailingRepository(super.path);
  bool failSave = false;
  @override
  void saveApplication(Application application) {
    if (failSave) {
      throw StateError('Injected database write failure');
    }
    super.saveApplication(application);
  }
}

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late FailingRepository repository;
  late LinuxProcesses processes;
  late LinuxArchives archives;
  late LinuxManagedStorage storage;
  late ApplicationService applications;
  late UpdateService updates;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-update العربية ');
    runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/data',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    repository = FailingRepository('${runtime.root}/library.sqlite');
    processes = LinuxProcesses(runtime, repository);
    archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    storage = LinuxManagedStorage(runtime, archives);
    applications = ApplicationService(repository, runtime, storage);
    updates = UpdateService(repository, runtime, processes, storage);
  });
  tearDown(() async {
    for (final profile in repository.profiles) {
      if (processes.isRunning(profile.id)) {
        await processes.stop(profile.id, force: true);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    repository.close();
    await temporary.delete(recursive: true);
  });

  Future<Directory> folder(
    String name,
    String version, {
    String executable = 'bin/studio',
    bool multiple = false,
  }) async {
    final directory = Directory('${temporary.path}/$name');
    final binary = File('${directory.path}/$executable');
    await binary.parent.create(recursive: true);
    await binary.writeAsString('#!/bin/sh\nprintf "$version"\n');
    await Process.run('chmod', ['755', '--', binary.path]);
    await File('${directory.path}/resource.txt')
        .writeAsString('resource-$version');
    if (multiple) {
      final other = File('${directory.path}/helper');
      await other.writeAsString('#!/bin/sh\nexit 0\n');
      await Process.run('chmod', ['755', '--', other.path]);
    }
    return directory;
  }

  Future<String> tar(Directory directory, String name, String format) async {
    final archive = '${temporary.path}/$name.tar.$format';
    final flag = {'gz': '-czf', 'xz': '-cJf', 'zst': '--zstd'}[format]!;
    final result = await Process.run(
      'tar',
      format == 'zst'
          ? [flag, '-cf', archive, '-C', directory.path, '.']
          : [flag, archive, '-C', directory.path, '.'],
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return archive;
  }

  Future<Application> initial() async {
    final input = await folder('initial', 'old');
    final staged = await storage.stage(input.path, archive: false);
    try {
      return await applications.addManaged('Studio', staged, 'bin/studio');
    } finally {
      await storage.discard(staged);
    }
  }

  Future<void> expectVersion(Application app, String version) async {
    final result = await Process.run(app.executable, []);
    expect(result.exitCode, 0);
    expect(result.stdout, version);
  }

  test('Full folder import stores relative executable and runs after source deletion', () async {
    final input = await folder('source', 'managed');
    await Link('${input.path}/shortcut').create('bin/studio');
    final staged = await storage.stage(input.path, archive: false);
    expect(staged.executables, containsAll(['bin/studio', 'shortcut']));
    final app = await applications.addManaged('Studio', staged, 'bin/studio');
    await storage.discard(staged);
    await input.delete(recursive: true);
    expect(app.executableRelative, 'bin/studio');
    expect(Application.fromJson(app.toJson()).executableRelative, 'bin/studio');
    expect(app.portableRoot, '${runtime.root}/applications/${app.id}/current');
    expect(
      await File('${app.portableRoot}/resource.txt').readAsString(),
      'resource-managed',
    );
    await expectVersion(app, 'managed');
    expect(await Directory(staged.root).exists(), isFalse);
  });

  for (final format in ['gz', 'xz', 'zst']) {
    test(
      'tar.$format managed import has no dependency on archive or source folder',
      () async {
        final input = await folder('archive-source', format);
        final archive = await tar(input, 'import', format);
        final staged = await storage.stage(archive, archive: true);
        final app = await applications.addManaged(
          'Archive',
          staged,
          'bin/studio',
        );
        await storage.discard(staged);
        await input.delete(recursive: true);
        await File(archive).delete();
        await expectVersion(app, format);
        expect(app.executableRelative, 'bin/studio');
      },
    );
  }

  test('Multiple executables require an explicit discovered selection, never first-file guessing', () async {
    final input = await folder('multiple', 'version', multiple: true);
    final staged = await storage.stage(input.path, archive: false);
    expect(staged.executables, ['bin/studio', 'helper']);
    expect(repository.applications, isEmpty);
    await expectLater(
      applications.addManaged('Invalid', staged, ''),
      throwsArgumentError,
    );
    await expectLater(
      applications.addManaged('Invalid', staged, '../bin/studio'),
      throwsArgumentError,
    );
    final app = await applications.addManaged('Chosen', staged, 'helper');
    expect(app.executableRelative, 'helper');
    await storage.discard(staged);
  });

  for (final kind in ['folder', 'gz', 'xz', 'zst']) {
    test(
      'Manual $kind update preserves all profiles, settings, data and desktop shortcuts',
      () async {
        final app = await initial();
        final entries = LinuxDesktopEntries(
          runtime,
          await File('assets/icon/icon.png').readAsBytes(),
          executable: '/usr/bin/true',
        );
        final snapshots = <String, Map<String, dynamic>>{};
        final shortcuts = <String, String>{};
        for (final id in ['work', 'personal']) {
          final profile = Profile(
            id: id,
            applicationId: app.id,
            name: '$id العربية',
            arguments: ['--profile={config}', 'argument with spaces'],
            environment: {'CUSTOM': '{data}', 'LITERAL': r'$(false)'},
            workingDirectory: temporary.path,
            paths: {
              'config': '${temporary.path}/custom-$id',
              'cache': '${temporary.path}/cache-$id',
            },
            trustedFingerprint: 'old-fingerprint',
          );
          repository.saveProfile(profile);
          await runtime.prepare(profile);
          await File('${runtime.resolvedPaths(profile)['data']}/value')
              .writeAsString(id);
          await entries.create(app, profile);
          snapshots[id] = profile.toJson();
          shortcuts[id] = await File(entries.filePath(id)).readAsString();
        }
        final input = await folder('replacement', 'new');
        final source = kind == 'folder'
            ? input.path
            : await tar(input, 'update', kind);
        final staged = await storage.stage(source, archive: kind != 'folder');
        // Preparing a manually chosen source must not change current files.
        await expectVersion(app, 'old');
        expect(updates.preferredExecutable(app, staged), 'bin/studio');
        final updated = await updates.update(app, staged, 'bin/studio');
        await storage.discard(staged);
        await input.delete(recursive: true);
        if (kind != 'folder') {
          await File(source).delete();
        }
        await expectVersion(updated, 'new');
        expect(updated.id, app.id);
        expect(updated.name, app.name);
        expect(repository.profiles.length, 2);
        for (final profile in repository.profiles) {
          expect(profile.toJson(), snapshots[profile.id]);
          expect(
            await File('${runtime.resolvedPaths(profile)['data']}/value')
                .readAsString(),
            profile.id,
          );
          expect(
            await File(entries.filePath(profile.id)).readAsString(),
            shortcuts[profile.id],
          );
        }
        expect(
          await Directory('${runtime.root}/staging').list().toList(),
          isEmpty,
        );
      },
    );
  }

  test('Changed executable prompts selection and preserves stable profile identity', () async {
    final app = await initial();
    final input = await folder(
      'renamed',
      'renamed',
      executable: 'new/main',
      multiple: true,
    );
    final staged = await storage.stage(input.path, archive: false);
    expect(updates.preferredExecutable(app, staged), isNull);
    await expectLater(
      updates.update(app, staged, 'bin/studio'),
      throwsArgumentError,
    );
    await expectVersion(app, 'old');
    final updated = await updates.update(app, staged, 'new/main');
    expect(updated.executableRelative, 'new/main');
    await expectVersion(updated, 'renamed');
    expect(await File('${updated.portableRoot}/bin/studio').exists(), isFalse);
    await storage.discard(staged);
  });

  test('Database failure after directory swap rolls back old files and application record', () async {
    final app = await initial();
    final input = await folder('failed-replacement', 'new');
    final staged = await storage.stage(input.path, archive: false);
    repository.failSave = true;
    await expectLater(
      updates.update(app, staged, 'bin/studio'),
      throwsStateError,
    );
    repository.failSave = false;
    expect(repository.applications.single.toJson(), app.toJson());
    await expectVersion(app, 'old');
    expect(
      await File('${app.portableRoot}/resource.txt').readAsString(),
      'resource-old',
    );
    await storage.discard(staged);
    expect(await Directory('${runtime.root}/staging').list().toList(), isEmpty);
  });

  test('Validation failure leaves current version intact and failed staging is cleaned', () async {
    final app = await initial();
    final empty = await Directory('${temporary.path}/empty').create();
    await File('${empty.path}/readme').writeAsString('No executable');
    await expectLater(
      storage.stage(empty.path, archive: false),
      throwsStateError,
    );
    await expectVersion(app, 'old');
    final input = await folder('tampered', 'new');
    final staged = await storage.stage(input.path, archive: false);
    await File('${staged.root}/bin/studio').delete();
    await expectLater(
      updates.update(app, staged, 'bin/studio'),
      throwsA(isA<FileSystemException>()),
    );
    await expectVersion(app, 'old');
    await storage.discard(staged);
    expect(await Directory('${runtime.root}/staging').list().toList(), isEmpty);
  });

  test('Running profiles block replacement under the launch lock without implicit force kill', () async {
    final app = await initial();
    final binary = File(app.executable);
    await binary.writeAsString('#!/bin/sh\nsleep 30\n');
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'running',
      applicationId: app.id,
      name: 'Running',
      trustedFingerprint: review.fingerprint,
    );
    repository.saveProfile(profile);
    await processes.launch(app, profile);
    final input = await folder('running-update', 'new');
    final staged = await storage.stage(input.path, archive: false);
    expect(updates.isRunning(app), isTrue);
    await expectLater(
      updates.update(app, staged, 'bin/studio'),
      throwsA(isA<ApplicationRunning>()),
    );
    expect(processes.isRunning(profile.id), isTrue);
    expect(await binary.readAsString(), contains('sleep 30'));
    await processes.stop(profile.id);
    final updated = await updates.update(app, staged, 'bin/studio');
    await expectVersion(updated, 'new');
    await storage.discard(staged);
  });

  test('Legacy portable roots reuse derived relative paths without relocating profile settings', () async {
    final input = await folder('legacy', 'old');
    final archive = await tar(input, 'legacy', 'gz');
    final root = await archives.extractPortable(archive);
    final app = await applications.add(
      'Legacy',
      '$root/bin/studio',
      portableRoot: root,
    );
    final staged = await storage.stage(
      (await folder('legacy-new', 'new')).path,
      archive: false,
    );
    expect(updates.preferredExecutable(app, staged), 'bin/studio');
    final updated = await updates.update(app, staged, 'bin/studio');
    expect(updated.portableRoot, root);
    expect(updated.executableRelative, 'bin/studio');
    await expectVersion(updated, 'new');
    await storage.discard(staged);
  });

  test('External reference update creates managed files without modifying external executable', () async {
    final input = await folder('external', 'old');
    final app = await applications.add('External', '${input.path}/bin/studio');
    final staged = await storage.stage(
      (await folder('external-new', 'new')).path,
      archive: false,
    );
    expect(updates.preferredExecutable(app, staged), isNull);
    final updated = await updates.update(app, staged, 'bin/studio');
    await expectVersion(updated, 'new');
    await expectVersion(app, 'old');
    expect(updated.portableRoot, isNotNull);
    await storage.discard(staged);
  });

  test('Profile data inside replaceable files blocks update instead of deleting persistent data', () async {
    final app = await initial();
    final profile = Profile(
      id: 'unsafe',
      applicationId: app.id,
      name: 'Unsafe',
      paths: {'data': '${app.portableRoot}/persistent'},
    );
    repository.saveProfile(profile);
    await runtime.prepare(profile);
    await File('${runtime.resolvedPaths(profile)['data']}/value')
        .writeAsString('keep');
    final staged = await storage.stage(
      (await folder('unsafe-new', 'new')).path,
      archive: false,
    );
    await expectLater(
      updates.update(app, staged, 'bin/studio'),
      throwsStateError,
    );
    expect(
      await File('${runtime.resolvedPaths(profile)['data']}/value')
          .readAsString(),
      'keep',
    );
    await expectVersion(app, 'old');
    await storage.discard(staged);
  });

  test('Canonical profile storage aliases inside application files also prevent replacement', () async {
    final app = await initial();
    await Directory('${app.portableRoot}/persistent').create();
    final alias = '${temporary.path}/data-alias';
    await Link(alias).create('${app.portableRoot}/persistent');
    repository.saveProfile(
      Profile(
        id: 'alias',
        applicationId: app.id,
        name: 'Alias',
        paths: {'data': '$alias/not-created-yet'},
      ),
    );
    final staged = await storage.stage(
      (await folder('alias-new', 'new')).path,
      archive: false,
    );
    await expectLater(
      updates.update(app, staged, 'bin/studio'),
      throwsStateError,
    );
    await expectVersion(app, 'old');
    await storage.discard(staged);
  });

  test('Folder importer rejects escaping links and special files, cleans canceled stages', () async {
    final input = await folder('links', 'old');
    await Link('${input.path}/escape').create('/etc/passwd');
    await expectLater(
      storage.stage(input.path, archive: false),
      throwsStateError,
    );
    await Link('${input.path}/escape').delete();
    final mkfifo = await Process.run('mkfifo', ['${input.path}/fifo']);
    expect(mkfifo.exitCode, 0);
    await expectLater(
      storage.stage(input.path, archive: false),
      throwsStateError,
    );
    await File('${input.path}/fifo').delete();
    final staged = await storage.stage(input.path, archive: false);
    await storage.discard(staged);
    expect(await Directory('${runtime.root}/staging').list().toList(), isEmpty);
    expect(repository.applications, isEmpty);
  });

  test('Chosen archive icon survives discarded staging, application replacement and backup restore', () async {
    final input = await folder('icon-source', 'old');
    final logo = File('${input.path}/images/nested/logo.png');
    await logo.parent.create(recursive: true);
    await File('assets/icon/icon.png').copy(logo.path);
    final archive = await tar(input, 'icons', 'gz');
    final source = await storage.stage(archive, archive: true);
    final entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
    );
    expect(await entries.scanImages(source.root), ['images/nested/logo.png']);
    final encoded = (await entries.previewImages(source.root, [
      'images/nested/logo.png',
    ], size: 512)).single!;
    final app = await applications.addManaged(
      'Chosen',
      source,
      'bin/studio',
      iconPng: encoded,
    );
    await storage.discard(source);
    await input.delete(recursive: true);
    await File(archive).delete();
    final next = await storage.stage(
      (await folder('icon-update', 'new')).path,
      archive: false,
    );
    final updated = await updates.update(app, next, 'bin/studio');
    await storage.discard(next);
    expect(updated.iconPng, encoded);
    expect(
      await File('${updated.portableRoot}/images/nested/logo.png').exists(),
      isFalse,
    );
    final backup = LinuxBackup(runtime, repository, archives, processes);
    final destination = '${temporary.path}/with-icon.tar.gz';
    await backup.export(destination);
    repository.saveApplication(
      Application.fromJson({...updated.toJson(), 'iconPng': null}),
    );
    await backup.restore(destination);
    expect(repository.applications.single.iconPng, encoded);
    const profile = Profile(id: 'chosen', applicationId: 'app', name: 'Chosen');
    await entries.create(repository.applications.single, profile);
    expect(await File(entries.iconPath(profile.id)).exists(), isTrue);
  });

  test('Managed applications are included in backup/restore, not just legacy portable roots', () async {
    final app = await initial();
    final backup = LinuxBackup(runtime, repository, archives, processes);
    final destination = '${temporary.path}/backup.tar.gz';
    await backup.export(destination);
    await File(app.executable).writeAsString('changed');
    await backup.restore(destination);
    expect(repository.applications.single.executableRelative, 'bin/studio');
    await expectVersion(repository.applications.single, 'old');
  });

  test('Replacement refuses non-staged sources and aliased managed destinations before moving files', () async {
    final input = await folder('outside-staging', 'old');
    final forged = ManagedSource(input.path, input.path, ['bin/studio']);
    await expectLater(
      applications.addManaged('Forged', forged, 'bin/studio'),
      throwsArgumentError,
    );
    expect(await File('${input.path}/bin/studio').exists(), isTrue);
    final staged = await storage.stage(input.path, archive: false);
    final outside = await Directory('${temporary.path}/outside-destination')
        .create();
    final collection = Directory('${runtime.root}/applications');
    if (await collection.exists()) {
      await collection.delete(recursive: true);
    }
    await Link(collection.path).create(outside.path);
    await expectLater(
      applications.addManaged('Aliased', staged, 'bin/studio'),
      throwsArgumentError,
    );
    expect(await outside.list().toList(), isEmpty);
    await Link(collection.path).delete();
    await storage.discard(staged);
    expect(repository.applications, isEmpty);
  });

  test('Updates are exclusively user-source driven with no remote checker or background service', () async {
    final app = await initial();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await expectVersion(app, 'old');
    for (final path in [
      'lib/features/updates/services/update_service.dart',
      'lib/platform/linux/linux_managed_storage.dart',
    ]) {
      final code = await File(path).readAsString();
      expect(
        code,
        isNot(
          matches(
            r'HttpClient|https?://|package:http|Timer|GitHub|apt-get|dnf',
          ),
        ),
      );
    }
    expect(repository.applications.single.toJson(), app.toJson());
  });
}
