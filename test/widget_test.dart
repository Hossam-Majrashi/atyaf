import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:atyaf/features/home/services/library_controller.dart';
import 'package:atyaf/features/settings/services/preferences_service.dart';
import 'package:atyaf/main.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DirectoryPicker extends FilePicker {
  DirectoryPicker(this.path);
  final String path;
  int calls = 0;
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    calls++;
    return path;
  }
}

void main() {
  late Directory temporary;
  late LinuxRepository repository;
  late LibraryController library;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-widgets-');
    final runtime = LinuxRuntime(environment: {'HOME': temporary.path});
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    final processes = LinuxProcesses(runtime, repository);
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    library = LibraryController(
      repository: repository,
      runtime: runtime,
      archives: archives,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(runtime, repository, archives, processes),
      entries: LinuxDesktopEntries(
        runtime,
        await File('assets/icon/icon.png').readAsBytes(),
      ),
      processes: processes,
    );
  });
  tearDown(() async {
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'Folder import icon gallery ${cancel ? 'cancels and cleans staging' : 'saves an icon and editing refreshes existing shortcuts'}',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'onboarding_done': true,
          'language': 'en',
        });
        final source = Directory('${temporary.path}/project');
        await tester.runAsync(() async {
          await Directory('${source.path}/images/nested')
              .create(recursive: true);
          final executable = File('${source.path}/main');
          await executable.writeAsString('#!/bin/sh\nexit 0\n');
          await Process.run('chmod', ['755', executable.path]);
          await File('assets/icon/icon.png')
              .copy('${source.path}/images/nested/logo.png');
          await File('${source.path}/images/other.svg').writeAsString(
            '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="red"/></svg>',
          );
        });
        FilePickerLinux.registerWith();
        final previousPicker = FilePicker.platform;
        FilePicker.platform = DirectoryPicker(source.path);
        addTearDown(() => FilePicker.platform = previousPicker);
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
        Future<void> waitFor(bool Function() ready) async {
          for (var attempt = 0; attempt < 200; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 15)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (ready()) {
              await tester.pump(const Duration(milliseconds: 400));
              return;
            }
          }
          fail('Icon import/edit operation did not complete');
        }

        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Application folder'));
        await waitFor(
          () => find.text('Choose an executable').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('main'));
        await waitFor(
          () =>
              find.byType(CustomScrollView).evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().length == 1,
        );
        if (cancel) {
          await tester.tap(find.text('Cancel'));
          await waitFor(
            () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          expect(repository.applications, isEmpty);
          await tester.runAsync(() async {
            expect(
              await Directory('${library.runtime.root}/staging')
                  .list()
                  .toList(),
              isEmpty,
            );
          });
        } else {
          await tester.scrollUntilVisible(
            find.text('images/nested/logo.png'),
            250,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await waitFor(
            () => find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Image &&
                      widget.semanticLabel == 'images/nested/logo.png',
                )
                .evaluate()
                .isNotEmpty,
          );
          await tester.tap(find.text('images/nested/logo.png'));
          await waitFor(() => find.text('Name').evaluate().isNotEmpty);
          await tester.tap(find.text('Save'));
          await waitFor(
            () =>
                repository.applications.isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          final app = repository.applications.single;
          expect(app.iconPng, isNotNull);
          final entries = library.entries as LinuxDesktopEntries;
          final profile = Profile(
            id: 'existing',
            applicationId: app.id,
            name: 'Existing',
          );
          await tester.runAsync(() async {
            await source.delete(recursive: true);
            repository.saveProfile(profile);
            await entries.create(app, profile);
            expect(
              await File(entries.iconPath(profile.id)).readAsBytes(),
              base64Decode(app.iconPng!),
            );
          });
          library.refresh();
          await tester.pumpAndSettle();
          await tester.tap(find.byType(PopupMenuButton<String>).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final choose = find.text('Choose an application icon');
          await tester.ensureVisible(choose);
          await tester.tap(choose);
          await waitFor(
            () =>
                find.byType(CustomScrollView).evaluate().isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().length == 1,
          );
          await tester.scrollUntilVisible(
            find.text('images/other.svg'),
            250,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await waitFor(
            () => find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Image &&
                      widget.semanticLabel == 'images/other.svg',
                )
                .evaluate()
                .isNotEmpty,
          );
          await tester.tap(find.text('images/other.svg'));
          await waitFor(
            () =>
                find.text('Choose an application icon').evaluate().length ==
                    1 &&
                find.byType(Image).evaluate().length > 1,
          );
          await tester.tap(find.text('Save'));
          await waitFor(
            () =>
                repository.applications.single.iconPng != app.iconPng &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await tester.runAsync(() async {
            expect(
              await File(entries.iconPath(profile.id)).readAsBytes(),
              base64Decode(repository.applications.single.iconPng!),
            );
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Accepting onboarding defaults persists language, theme and completion',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      final preferences = PreferencesService(store);
      await tester.pumpWidget(
        AtyafApp(
          preferences: preferences,
          library: library,
          manageWindow: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open library'));
      await tester.pumpAndSettle();
      expect(store.getString('language'), 'en');
      expect(store.getString('theme'), 'system');
      expect(store.getBool('onboarding_done'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Onboarding order, immediate language and theme, persistence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService(
      await SharedPreferences.getInstance(),
    );
    await tester.pumpWidget(
      AtyafApp(preferences: preferences, library: library, manageWindow: false),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('One application. Many independent identities.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    expect(preferences.language, 'ar');
    expect(
      Directionality.of(tester.element(find.text('متابعة'))),
      TextDirection.rtl,
    );
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('داكن').last);
    await tester.pumpAndSettle();
    expect(preferences.theme, ThemeMode.dark);
    await tester.tap(find.text('فتح المكتبة'));
    await tester.pumpAndSettle();
    expect(preferences.onboardingDone, isTrue);
    expect(find.text('مكتبتك تبدأ هنا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual update UI requires source and executable selection, summarizes source, then swaps files',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'language': 'en',
      });
      final source = Directory('${temporary.path}/new version العربية');
      await tester.runAsync(() async {
        await source.create();
        for (final name in ['main', 'helper']) {
          final file = File('${source.path}/$name');
          await file.writeAsString('#!/bin/sh\nprintf new\n');
          await Process.run('chmod', ['755', '--', file.path]);
        }
      });
      FilePickerLinux.registerWith();
      final previousPicker = FilePicker.platform;
      final picker = DirectoryPicker(source.path);
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = previousPicker);
      repository.saveApplication(
        const Application(
          id: 'app',
          name: 'Studio',
          executable: '/usr/bin/true',
        ),
      );
      const profile = Profile(
        id: 'work',
        applicationId: 'app',
        name: 'Work',
        arguments: ['a b'],
        environment: {'KEY': 'value'},
      );
      repository.saveProfile(profile);
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
      expect(picker.calls, 0);
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(picker.calls, 0);
      await tester.tap(find.text('Application folder'));
      Future<void> waitFor(Finder finder) async {
        for (var attempt = 0; attempt < 150; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (finder.evaluate().isNotEmpty) {
            return;
          }
        }
        fail('UI did not reach $finder');
      }

      await waitFor(find.text('Choose an executable'));
      expect(picker.calls, 1);
      expect(find.text('main'), findsOneWidget);
      expect(find.text('helper'), findsOneWidget);
      expect(repository.applications.single.executable, '/usr/bin/true');
      await tester.tap(find.text('main'));
      await waitFor(find.text('Replace the application with this source?'));
      expect(find.text(source.path), findsOneWidget);
      expect(find.text('new version العربية'), findsOneWidget);
      expect(find.text('main'), findsOneWidget);
      expect(repository.applications.single.executable, '/usr/bin/true');
      await tester.tap(find.text('Update'));
      await waitFor(
        find.text(
          'Application updated. Profiles and their settings were preserved.',
        ),
      );
      expect(repository.applications.single.executableRelative, 'main');
      expect(repository.profiles.single.toJson(), profile.toJson());
      await tester.runAsync(() async {
        await source.delete(recursive: true);
        final result = await Process.run(
          repository.applications.single.executable,
          [],
        );
        expect(result.stdout, 'new');
      });
      await waitFor(
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuButton<String> && widget.enabled,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    },
  );

  for (final language in ['en', 'ar']) {
    for (final size in [const Size(1100, 760), const Size(1600, 900)]) {
      testWidgets(
        'Saved icons $language $size retain providers and frames across real timer refreshes and SQLite reloads',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'onboarding_done': true,
            'language': language,
          });
          // Create this controller inside the widget test's fake clock so each
          // one-second pump exercises the production reconciliation timer.
          library.dispose();
          library = LibraryController(
            repository: repository,
            runtime: library.runtime,
            archives: library.archives,
            storage: library.storage,
            backup: library.backup,
            entries: library.entries,
            processes: library.processes,
          );
          try {
            late String firstPng, secondPng;
            const profile = Profile(
              id: 'profile',
              applicationId: 'a',
              name: 'Work',
              environment: {'KEEP': 'unchanged'},
            );
            final entries = library.entries as LinuxDesktopEntries;
            await tester.runAsync(() async {
              final source = File('${temporary.path}/chosen.svg');
              await source.writeAsString(
                '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="green"/></svg>',
              );
              firstPng = (await entries.previewImages(
                Directory('assets/icon').absolute.path,
                ['icon.png'],
                size: 512,
              )).single!;
              secondPng = (await entries.previewImages(temporary.path, [
                'chosen.svg',
              ], size: 512)).single!;
              repository.saveApplication(
                Application(
                  id: 'a',
                  name: 'Studio A',
                  executable: '/usr/bin/true',
                  iconPng: firstPng,
                ),
              );
              repository.saveApplication(
                Application(
                  id: 'b',
                  name: 'Studio B',
                  executable: '/usr/bin/true',
                  iconPng: secondPng,
                ),
              );
              repository.saveProfile(profile);
              await entries.create(repository.applications.first, profile);
              await source.delete();
            });
            final labels = {'a': 'Studio A', 'b': 'Studio B'};
            Finder icon(String id) => find.descendant(
              of: find.widgetWithText(ListTile, labels[id]!),
              matching: find.byType(Image),
            );
            ImageProvider provider(String id) =>
                tester.widget<Image>(icon(id)).image;
            ui.Image? frame(String id) => tester
                .widget<RawImage>(
                  find.descendant(
                    of: icon(id),
                    matching: find.byType(RawImage),
                  ),
                )
                .image;
            Future<void> waitForFrames() async {
              for (var attempt = 0; attempt < 100; attempt++) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)),
                );
                await tester.pump(const Duration(milliseconds: 10));
                if (frame('a') != null && frame('b') != null) return;
              }
              fail('Saved icon frames did not load');
            }

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
            await waitForFrames();
            final firstProvider = provider('a'), secondProvider = provider('b');
            final firstFrame = frame('a'), secondFrame = frame('b');
            expect(
              identical(
                repository.applications.first,
                repository.applications.first,
              ),
              isFalse,
            );
            for (var tick = 0; tick < 6; tick++) {
              final previousTick = library.timer.tick;
              await tester.pump(const Duration(seconds: 1));
              expect(library.timer.tick, greaterThan(previousTick));
              // Check immediately, not after decoding settles: there must be no
              // blank frame between periodic library refreshes.
              expect(frame('a'), same(firstFrame));
              expect(frame('b'), same(secondFrame));
              expect(provider('a'), same(firstProvider));
              expect(provider('b'), same(secondProvider));
            }
            final renamed = Application.fromJson({
              ...repository.applications.first.toJson(),
              'name': 'Renamed A',
            });
            labels['a'] = renamed.name;
            repository.saveApplication(renamed);
            // Simulate a restored/reordered library with new model instances.
            repository.removeApplication('a');
            repository.saveApplication(renamed);
            library.refresh();
            await tester.pump();
            expect(provider('a'), same(firstProvider));
            expect(provider('b'), same(secondProvider));
            expect(frame('a'), same(firstFrame));
            library.select('b');
            await tester.pump();
            expect(provider('a'), same(firstProvider));
            expect(provider('b'), same(secondProvider));
            repository.saveApplication(
              Application.fromJson({...renamed.toJson(), 'iconPng': secondPng}),
            );
            library.refresh();
            await tester.pump();
            expect(provider('a'), isNot(same(firstProvider)));
            expect(
              (provider('a') as MemoryImage).bytes,
              base64Decode(secondPng),
            );
            await waitForFrames();
            final replacement = provider('a'), replacementFrame = frame('a');
            expect(replacementFrame, isNot(same(firstFrame)));
            await tester.pump(const Duration(seconds: 1));
            expect(provider('a'), same(replacement));
            expect(frame('a'), same(replacementFrame));
            repository.saveApplication(
              Application.fromJson({...renamed.toJson(), 'iconPng': null}),
            );
            library.refresh();
            await tester.pump();
            expect(icon('a'), findsNothing);
            expect(provider('b'), same(secondProvider));
            expect(repository.profiles.single.toJson(), profile.toJson());
            await tester.runAsync(() async {
              // Rendering refreshes must not rewrite the Linux shortcut icon.
              expect(
                await File(entries.iconPath(profile.id)).readAsBytes(),
                base64Decode(firstPng),
              );
              expect(
                await File('${temporary.path}/chosen.svg').exists(),
                isFalse,
              );
            });
            expect(tester.takeException(), isNull);
          } finally {
            library.timer.cancel();
          }
        },
      );
    }
    testWidgets(
      'Saving and renaming $language accounts updates system shortcuts',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'onboarding_done': true,
          'language': language,
        });
        repository.saveApplication(
          const Application(
            id: 'app',
            name: 'Studio',
            executable: '/usr/bin/true',
          ),
        );
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
        await tester.tap(
          find.text(language == 'en' ? 'New profile' : 'ملف شخصي جديد'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(find.byType(TextField).first, 'حساب العمل');
        Future<void> saveAndWait() async {
          await tester.tap(find.text(language == 'en' ? 'Save' : 'حفظ'));
          for (var attempt = 0; attempt < 150; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(TextField).evaluate().isEmpty) {
              await tester.pumpAndSettle();
              return;
            }
          }
          fail('Profile dialog did not save');
        }

        await saveAndWait();
        final profile = repository.profiles.single;
        final entries = library.entries as LinuxDesktopEntries;
        final shortcut = File(entries.filePath(profile.id));
        await tester.runAsync(() async {
          expect(await shortcut.readAsString(), contains('Name=حساب العمل\n'));
        });
        await tester.ensureVisible(find.byType(PopupMenuButton<String>).last);
        await tester.tap(find.byType(PopupMenuButton<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(language == 'en' ? 'Edit' : 'تعديل'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(find.byType(TextField).first, 'حساب شخصي');
        await saveAndWait();
        expect(repository.profiles.single.id, profile.id);
        await tester.runAsync(() async {
          expect(await shortcut.readAsString(), contains('Name=حساب شخصي\n'));
        });
        final shortcutButton = find.text(
          language == 'en'
              ? 'Add to applications menu'
              : 'إضافة إلى قائمة تطبيقات الجهاز',
        );
        await tester.ensureVisible(shortcutButton);
        await tester.tap(shortcutButton);
        final confirmation = find.text(
          language == 'en'
              ? 'The shortcut and its icon were updated in the system applications menu.'
              : 'تم تحديث الاختصار وأيقونته في قائمة تطبيقات الجهاز.',
        );
        for (
          var attempt = 0;
          attempt < 150 && confirmation.evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(confirmation, findsOneWidget);
        await tester.runAsync(() async {
          expect(
            await shortcut.readAsString(),
            contains('Icon=${entries.iconPath(profile.id)}\n'),
          );
          expect(await File(entries.iconPath(profile.id)).exists(), isTrue);
        });
        expect(tester.takeException(), isNull);
      },
    );
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets(
        'Desktop $language $size has no overflow including settings and profile editor',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'onboarding_done': true,
            'language': language,
          });
          repository.saveApplication(
            Application(
              id: 'app',
              name: 'برنامج للاختبار A long application name',
              executable: '/usr/bin/true',
            ),
          );
          repository.saveProfile(
            const Profile(
              id: 'profile',
              applicationId: 'app',
              name: 'Work العمل',
            ),
          );
          final preferences = PreferencesService(
            await SharedPreferences.getInstance(),
          );
          await tester.pumpWidget(
            AtyafApp(
              preferences: preferences,
              library: library,
              manageWindow: false,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(PopupMenuButton<String>).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text(language == 'en' ? 'Update' : 'تحديث'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.text(
              language == 'en'
                  ? 'Choose the new application source'
                  : 'اختر مصدر الإصدار الجديد',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              language == 'en' ? 'Application folder' : 'مجلد البرنامج',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              language == 'en' ? 'Portable archive' : 'أرشيف برنامج محمول',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(language == 'en' ? 'Cancel' : 'إلغاء'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(language == 'en' ? 'New profile' : 'ملف شخصي جديد'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(language == 'en' ? 'Cancel' : 'إلغاء'));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.settings_outlined));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('حسام حسن مجرشي'),
            300,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
