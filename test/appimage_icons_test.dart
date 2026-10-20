import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/applications/services/application_service.dart';
import 'package:atyaf/features/updates/services/update_service.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/appimage_fixture.dart';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxRepository repository;
  late LinuxProcesses processes;
  late LinuxArchives archives;
  late LinuxManagedStorage storage;
  late LinuxDesktopEntries entries;
  late ApplicationService applications;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'atyaf embedded العربية ',
    );
    runtime = LinuxRuntime(environment: {'HOME': temporary.path});
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    processes = LinuxProcesses(runtime, repository);
    archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    storage = LinuxManagedStorage(runtime, archives);
    entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
    );
    applications = ApplicationService(repository, runtime, storage);
  });
  tearDown(() async {
    repository.close();
    await temporary.delete(recursive: true);
  });

  for (final iso in [false, true]) {
    test(
      'Embedded ${iso ? 'ISO' : 'SquashFS'} logo is decoded, browsable, automatic and backed up without AppRun',
      () async {
        final source = await appImageWithIcons(
          '${temporary.path}/logo "quote" %.AppImage',
          iso: iso,
        );
        final original = await source.readAsBytes();
        final staged = await storage.stageAppImage(source.path);
        expect(staged.appImageIconStatus, 'ready');
        expect(staged.defaultIconPng, isNotNull);
        final images = await entries.scanImages(staged.root);
        expect(images, contains('.DirIcon'));
        expect(
          images.where((p) => p.startsWith('.appimage-icons/')),
          isNotEmpty,
        );
        final preview = await entries.previewImages(staged.root, [
          '.DirIcon',
        ], size: 512);
        expect(preview.single, staged.defaultIconPng);
        expect(await source.readAsBytes(), original);
        final app = await applications.addManaged(
          'Embedded',
          staged,
          staged.executables.single,
        );
        expect(app.iconAutomatic, isTrue);
        expect(app.iconPng, staged.defaultIconPng);
        const id = 'work';
        final profile = Profile(id: id, applicationId: app.id, name: 'Work');
        repository.saveProfile(profile);
        await runtime.prepare(profile);
        await entries.create(app, profile);
        expect(
          await File(entries.iconPath(id)).readAsBytes(),
          base64Decode(app.iconPng!),
        );
        // The on-disk automatic icon also works for legacy/null icon overrides.
        final legacy = Application.fromJson({...app.toJson(), 'iconPng': null});
        expect(
          await entries.findApplicationIcon(legacy),
          '${app.portableRoot}/.DirIcon',
        );
        await storage.discard(staged);
        await source.delete();
        final backup = LinuxBackup(runtime, repository, archives, processes);
        final output = '${temporary.path}/backup.tar.gz';
        await backup.export(output);
        await File('${app.portableRoot}/.DirIcon').delete();
        await backup.restore(output);
        expect(repository.applications.single.iconPng, app.iconPng);
        expect(repository.applications.single.iconAutomatic, isTrue);
        expect(await File('${app.portableRoot}/.DirIcon').exists(), isTrue);
        expect(
          await File('${temporary.path}/atyaf-icon-executed').exists(),
          isFalse,
        );
        expect(repository.history(id), isEmpty);
      },
    );
  }

  test('Automatic logo follows updates, manual override is preserved, old records stay compatible', () async {
    final original = await appImageWithIcons('${temporary.path}/old.AppImage');
    final staged = await storage.stageAppImage(original.path);
    final app = await applications.addManaged(
      'Auto',
      staged,
      staged.executables.single,
    );
    final updates = UpdateService(repository, runtime, processes, storage);
    final replacement = await appImageWithIcons(
      '${temporary.path}/new.AppImage',
      iso: true,
    );
    final next = await storage.stageAppImage(replacement.path);
    final updated = await updates.update(app, next, next.executables.single);
    expect(updated.iconPng, isNot(app.iconPng));
    expect(updated.iconPng, next.defaultIconPng);
    expect(updated.iconAutomatic, isTrue);
    final manualIcon = await entries.readImage(
      File('assets/icon/icon.png').absolute.path,
    );
    final manual = Application.fromJson({
      ...updated.toJson(),
      'iconPng': manualIcon,
      'iconAutomatic': false,
    });
    repository.saveApplication(manual);
    final again = await storage.stageAppImage(original.path);
    final kept = await updates.update(manual, again, again.executables.single);
    expect(kept.iconPng, manualIcon);
    expect(kept.iconAutomatic, isFalse);
    final oldJson = {...kept.toJson()}..remove('iconAutomatic');
    expect(Application.fromJson(oldJson).iconAutomatic, isFalse);
    final unsupported = await appImageFixture(
      '${temporary.path}/no-icons.AppImage',
    );
    final noIcons = await storage.stageAppImage(unsupported.path);
    final auto = Application.fromJson({
      ...kept.toJson(),
      'iconAutomatic': true,
    });
    repository.saveApplication(auto);
    final fallback = await updates.update(
      auto,
      noIcons,
      noIcons.executables.single,
    );
    expect(
      fallback.iconPng,
      manualIcon,
    ); // Do not erase an icon on read failure.
    expect(
      await File('${temporary.path}/atyaf-icon-executed').exists(),
      isFalse,
    );
  });

  test('Missing 7-Zip has an explicit status and does not block manual image selection', () async {
    final root = await Directory('${temporary.path}/without-tool').create();
    final source = await appImageWithIcons('${root.path}/application.AppImage');
    final original = await source.readAsBytes();
    final result = await Process.run(
      '/usr/bin/python3',
      [File('assets/linux/appimage_icons.py').absolute.path, root.path],
      environment: {...Platform.environment, 'PATH': '${temporary.path}/empty'},
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(jsonDecode(result.stdout.toString()), {'status': 'missing_tool'});
    expect(await source.readAsBytes(), original);
    expect(await root.list().length, 1);
  });

  test('Reader rejects unsafe links/paths, bounds subprocess output/time and validates decodes', () async {
    final result = await Process.run(
      '/usr/bin/python3',
      ['test/appimage_icon_reader_test.py'],
      environment: {...Platform.environment, 'PYTHONDONTWRITEBYTECODE': '1'},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr.toString(), contains('Ran 11 tests'));
  });
}
