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
import 'package:atyaf/shared/models/library_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/appimage_fixture.dart';

class AppImagePicker extends FilePicker {
  String? path;
  final requests = <(FileType, List<String>?, bool, bool)>[];

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    requests.add((type, allowedExtensions, allowMultiple, withData));
    return path == null
        ? null
        : FilePickerResult([
            PlatformFile(name: path!.split('/').last, path: path, size: 1),
          ]);
  }
}

void main() {
  late Directory temporary;
  late LinuxRepository repository;
  late LibraryController library;
  late LinuxDesktopEntries entries;
  late AppImagePicker picker;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-appimage-ui-');
    final runtime = LinuxRuntime(environment: {'HOME': temporary.path});
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
      processes: processes,
      archives: archives,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(runtime, repository, archives, processes),
      entries: entries,
    );
    FilePickerLinux.registerWith();
    final previous = FilePicker.platform;
    picker = AppImagePicker();
    FilePicker.platform = picker;
    addTearDown(() => FilePicker.platform = previous);
  });
  tearDown(() async {
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 250; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (ready()) {
        await tester.pump(const Duration(milliseconds: 400));
        return;
      }
    }
    fail('AppImage desktop operation did not complete');
  }

  Future<AppLocalizations> open(
    WidgetTester tester,
    String language,
    Size size,
  ) async {
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
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        library: library,
        manageWindow: false,
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  for (final language in ['ar', 'en']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets('Executable copy and format labels $language $size', (
        tester,
      ) async {
        late File source;
        await tester.runAsync(() async {
          source = File('${temporary.path}/rusty-psn');
          await source.writeAsString('#!/bin/sh\nprintf independent\n');
          await Process.run('chmod', ['755', '--', source.path]);
        });
        picker.path = source.path;
        final l = await open(tester, language, size);
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        for (final label in [
          l.executableFormats,
          l.folderFormats,
          l.archiveFormats,
          l.appImageFormats,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text(l.executable));
        await waitFor(
          tester,
          () => find.text(l.chooseExecutable).evaluate().isNotEmpty,
        );
        expect(find.text(l.executableImportHelp), findsOneWidget);
        expect(picker.requests.single.$1, FileType.any);
        expect(picker.requests.single.$3, isFalse);
        expect(picker.requests.single.$4, isFalse);
        await tap(tester, find.text('rusty-psn'));
        await waitFor(
          tester,
          () =>
              find
                  .widgetWithText(TextButton, l.automaticIcon)
                  .evaluate()
                  .isNotEmpty &&
              tester
                      .widget<TextButton>(
                        find.widgetWithText(TextButton, l.automaticIcon),
                      )
                      .onPressed !=
                  null,
        );
        await tester.tap(find.text(l.automaticIcon));
        await waitFor(tester, () => find.text(l.name).evaluate().isNotEmpty);
        await tester.tap(find.text(l.save));
        await waitFor(
          tester,
          () =>
              repository.applications.isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        final app = repository.applications.single;
        expect(app.name, 'rusty-psn');
        expect(app.executableRelative, 'rusty-psn');
        expect(
          app.portableRoot,
          startsWith('${library.runtime.root}/applications/'),
        );
        await tester.runAsync(() async {
          expect(
            await source.readAsBytes(),
            await File(app.executable).readAsBytes(),
          );
          await source.delete();
          final result = await Process.run(app.executable, []);
          expect(result.exitCode, 0);
          expect(result.stdout, 'independent');
        });
        await tester.runAsync(() async {
          await source.writeAsString('#!/bin/sh\nprintf updated\n');
          await Process.run('chmod', ['755', '--', source.path]);
        });
        await tester.tap(find.byType(PopupMenuButton<String>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.update));
        await waitFor(
          tester,
          () => find.text(l.updateSource).evaluate().isNotEmpty,
        );
        await tap(tester, find.text(l.executable));
        await waitFor(
          tester,
          () => find.text(l.updateSummary).evaluate().isNotEmpty,
        );
        expect(find.text(l.executableImportHelp), findsOneWidget);
        await tester.runAsync(() async {
          expect(
            await File(app.executable).readAsString(),
            contains('independent'),
          );
        });
        await tester.tap(find.text(l.update));
        await waitFor(
          tester,
          () => find.text(l.updateSuccess).evaluate().isNotEmpty,
        );
        expect(repository.applications.single.id, app.id);
        await tester.runAsync(() async {
          await source.delete();
          final result = await Process.run(
            repository.applications.single.executable,
            [],
          );
          expect(result.stdout, 'updated');
        });
        expect(repository.history('unused'), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'AppImage import, rename, icon and manual update $language $size',
        (tester) async {
          late File original, next;
          await tester.runAsync(() async {
            original = await appImageWithIcons(
              '${temporary.path}/Studio-v1.AppImage',
            );
            next = await appImageWithIcons(
              '${temporary.path}/Studio-v2.appimage',
              iso: true,
            );
          });
          picker.path = original.path;
          final l = await open(tester, language, size);
          await tester.tap(find.byType(PopupMenuButton<String>).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.appImage));
          await waitFor(
            tester,
            () => find.text(l.chooseExecutable).evaluate().isNotEmpty,
          );
          expect(find.text(l.appImageHelp), findsOneWidget);
          expect(picker.requests.single.$1, FileType.custom);
          expect(picker.requests.single.$2, [
            'AppImage',
            'appimage',
            'APPIMAGE',
          ]);
          expect(
            (picker.requests.single.$3, picker.requests.single.$4),
            (false, false),
          );
          await tap(tester, find.text('application.AppImage'));
          await waitFor(
            tester,
            () =>
                find
                    .widgetWithText(TextButton, l.automaticIcon)
                    .evaluate()
                    .isNotEmpty &&
                tester
                        .widget<TextButton>(
                          find.widgetWithText(TextButton, l.automaticIcon),
                        )
                        .onPressed !=
                    null,
          );
          await tester.scrollUntilVisible(
            find.text('.DirIcon'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('.DirIcon'), findsOneWidget);
          await waitFor(
            tester,
            () => find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Image && widget.semanticLabel == '.DirIcon',
                )
                .evaluate()
                .isNotEmpty,
          );
          expect(find.text(l.noProjectImages), findsNothing);
          await tester.tap(find.text(l.automaticIcon));
          await waitFor(tester, () => find.text(l.name).evaluate().isNotEmpty);
          expect(find.text('Studio-v1'), findsOneWidget);
          await tester.enterText(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(TextField),
                )
                .first,
            'Studio العربية',
          );
          await tester.tap(find.text(l.save));
          await waitFor(
            tester,
            () =>
                repository.applications.isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          final app = repository.applications.single;
          expect(app.name, 'Studio العربية');
          expect(app.iconPng, isNotNull);
          expect(app.iconAutomatic, isTrue);
          expect(find.byType(Image), findsWidgets);
          final snapshots = <String, Map<String, dynamic>>{};
          await tester.runAsync(() async {
            for (final id in ['work', 'personal']) {
              final profile = Profile(
                id: id,
                applicationId: app.id,
                name: id,
                environment: {'KEEP': id},
              );
              repository.saveProfile(profile);
              snapshots[id] = profile.toJson();
              await entries.create(app, profile);
            }
          });
          library.refresh();
          await tester.pumpAndSettle();
          // Existing editor and image-file picker must work for a one-file import.
          await tester.tap(find.byType(PopupMenuButton<String>).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.edit));
          await waitFor(
            tester,
            () => find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(TextField),
                )
                .evaluate()
                .isNotEmpty,
          );
          await tester.enterText(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(TextField),
                )
                .first,
            'Renamed AppImage',
          );
          expect(
            tester
                .widget<TextField>(
                  find
                      .descendant(
                        of: find.byType(Dialog),
                        matching: find.byType(TextField),
                      )
                      .at(1),
                )
                .readOnly,
            isTrue,
          );
          await tap(tester, find.text(l.chooseApplicationIcon));
          await waitFor(
            tester,
            () =>
                find
                    .widgetWithText(OutlinedButton, l.chooseImageFile)
                    .evaluate()
                    .isNotEmpty &&
                tester
                        .widget<OutlinedButton>(
                          find.widgetWithText(
                            OutlinedButton,
                            l.chooseImageFile,
                          ),
                        )
                        .onPressed !=
                    null,
          );
          picker.path = File('assets/icon/icon.png').absolute.path;
          await tester.tap(find.text(l.chooseImageFile));
          await waitFor(
            tester,
            () => find.text(l.chooseImageFile).evaluate().isEmpty,
          );
          await tester.tap(find.text(l.save));
          await waitFor(
            tester,
            () =>
                repository.applications.single.iconPng != null &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          final edited = repository.applications.single;
          expect(edited.name, 'Renamed AppImage');
          expect(edited.iconAutomatic, isFalse);
          await tester.runAsync(() async {
            for (final id in snapshots.keys) {
              expect(
                await File(entries.iconPath(id)).readAsBytes(),
                base64Decode(edited.iconPng!),
              );
            }
          });
          picker.path = next.path;
          await tester.tap(find.byType(PopupMenuButton<String>).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.update));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tap(tester, find.text(l.appImage));
          await waitFor(
            tester,
            () => find.text(l.updateSummary).evaluate().isNotEmpty,
          );
          expect(find.text(next.path), findsOneWidget);
          expect(picker.requests.last.$1, FileType.custom);
          expect(picker.requests.last.$2, ['AppImage', 'appimage', 'APPIMAGE']);
          expect(
            (picker.requests.last.$3, picker.requests.last.$4),
            (false, false),
          );
          // The old executable remains untouched until explicit confirmation.
          await tester.runAsync(() async {
            expect(
              await File(edited.executable).readAsBytes(),
              await original.readAsBytes(),
            );
          });
          await tester.tap(find.text(l.update));
          await waitFor(
            tester,
            () => find.text(l.updateSuccess).evaluate().isNotEmpty,
          );
          final updated = repository.applications.single;
          expect(updated.name, edited.name);
          expect(updated.iconPng, edited.iconPng);
          expect(updated.iconAutomatic, isFalse);
          expect(updated.executable, edited.executable);
          expect(repository.profiles.map((p) => p.toJson()), snapshots.values);
          await tester.runAsync(() async {
            expect(
              await File(updated.executable).readAsBytes(),
              await next.readAsBytes(),
            );
            expect(
              await Directory('${library.runtime.root}/staging')
                  .list()
                  .toList(),
              isEmpty,
            );
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final language in ['ar', 'en']) {
    testWidgets('Executable cancellation discards copy $language', (
      tester,
    ) async {
      late File source;
      await tester.runAsync(() async {
        source = File('${temporary.path}/cancel.sh');
        await source.writeAsString('#!/bin/sh\nexit 0\n');
        await Process.run('chmod', ['755', '--', source.path]);
      });
      picker.path = source.path;
      final l = await open(tester, language, const Size(800, 600));
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.executable));
      await waitFor(
        tester,
        () => find.text(l.chooseExecutable).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(l.cancel));
      await waitFor(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(repository.applications, isEmpty);
      await tester.runAsync(() async {
        expect(await source.exists(), isTrue);
        expect(
          await Directory('${library.runtime.root}/staging').list().toList(),
          isEmpty,
        );
      });
      expect(tester.takeException(), isNull);
    });
  }

  for (final cancelAt in ['picker', 'executable', 'icon', 'invalid']) {
    testWidgets(
      'AppImage $cancelAt creates no application and leaves source intact',
      (tester) async {
        late File source;
        await tester.runAsync(() async {
          source = await appImageFixture('${temporary.path}/Cancel.AppImage');
          if (cancelAt == 'invalid') {
            await source.writeAsString('not an AppImage');
          }
        });
        picker.path = cancelAt == 'picker' ? null : source.path;
        final l = await open(tester, 'en', const Size(800, 600));
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.appImage));
        if (cancelAt == 'executable' || cancelAt == 'icon') {
          await waitFor(
            tester,
            () => find.text(l.chooseExecutable).evaluate().isNotEmpty,
          );
          if (cancelAt == 'icon') {
            await tap(tester, find.text('application.AppImage'));
            await waitFor(
              tester,
              () => find.text(l.automaticIcon).evaluate().isNotEmpty,
            );
            await tester.scrollUntilVisible(
              find.text(l.applicationIconHelp),
              -200,
              scrollable: find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    [
                      l.appImageIconUnsupported,
                      l.appImageIconUnavailable,
                    ].contains(widget.data),
              ),
              findsOneWidget,
            );
          }
          await tester.tap(find.text(l.cancel));
        }
        await waitFor(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        expect(repository.applications, isEmpty);
        await tester.runAsync(() async {
          expect(await source.exists(), isTrue);
          final staging = Directory('${library.runtime.root}/staging');
          if (await staging.exists()) {
            expect(await staging.list().toList(), isEmpty);
          }
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
