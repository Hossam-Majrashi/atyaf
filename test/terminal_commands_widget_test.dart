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
import 'package:atyaf/screens/desktop/terminal_command_dialog.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temporary;
  late LibraryController library;
  late LinuxRepository repository;
  const profile = Profile(
    id: 'rpcs3-account',
    applicationId: 'app',
    name: 'rpcs3',
    arguments: ['a b'],
    environment: {'KEEP': 'same'},
  );
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-terminal-widget-');
    final runtime = LinuxRuntime(
      environment: {'HOME': temporary.path, 'PATH': '/usr/bin:/bin'},
    );
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    repository.saveApplication(
      const Application(id: 'app', name: 'RPCS3', executable: '/usr/bin/true'),
    );
    repository.saveProfile(profile);
    final processes = LinuxProcesses(runtime, repository);
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    final entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: '/usr/bin/true',
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
        terminalCommands: entries,
      ),
    );
  });
  tearDown(() async {
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 180; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (ready()) {
        await tester.pump(const Duration(milliseconds: 400));
        return;
      }
    }
    fail('Terminal command UI did not complete');
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
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    final action = find.widgetWithText(OutlinedButton, l.terminalCommand);
    await tester.scrollUntilVisible(
      action,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(action);
    await waitFor(
      tester,
      () =>
          find
              .widgetWithText(FilledButton, l.createTerminalCommand)
              .evaluate()
              .isNotEmpty &&
          tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, l.createTerminalCommand),
                  )
                  .onPressed !=
              null,
    );
    return l;
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final language in ['ar', 'en']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets(
        'Create and confirm/cancel removal of terminal command $language $size',
        (tester) async {
          final l = await open(tester, language, size);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'rpcs3',
          );
          await tap(
            tester,
            find.widgetWithText(FilledButton, l.createTerminalCommand),
          );
          await waitFor(
            tester,
            () => find
                .text(l.terminalCommandCreated('rpcs3'))
                .evaluate()
                .isNotEmpty,
          );
          expect(find.text(l.terminalPathMissing), findsOneWidget);
          expect(find.text(l.terminalPathCommand), findsOneWidget);
          final command = File('${temporary.path}/.local/bin/rpcs3');
          await tester.runAsync(() async {
            expect(await command.exists(), isTrue);
          });
          await tap(
            tester,
            find.widgetWithText(TextButton, l.removeTerminalCommands),
          );
          expect(find.text(l.removeTerminalCommandsConfirm), findsOneWidget);
          await tap(tester, find.text(l.cancel));
          await tester.runAsync(() async {
            expect(await command.exists(), isTrue);
          });
          await tap(
            tester,
            find.widgetWithText(TextButton, l.removeTerminalCommands),
          );
          await tap(tester, find.text(l.delete));
          await waitFor(
            tester,
            () => find.text(l.terminalCommandsRemoved).evaluate().isNotEmpty,
          );
          await tester.runAsync(() async {
            expect(await command.exists(), isFalse);
          });
          expect(repository.profiles.single.toJson(), profile.toJson());
          expect(repository.history(profile.id), isEmpty);
          await tap(tester, find.text(l.close));
          await waitFor(
            tester,
            () => find.byType(TerminalCommandDialog).evaluate().isEmpty,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('Terminal command $language cancel never creates a launcher', (
      tester,
    ) async {
      final l = await open(tester, language, const Size(800, 600));
      await tap(tester, find.text(l.close));
      await waitFor(
        tester,
        () => find.byType(TerminalCommandDialog).evaluate().isEmpty,
      );
      await tester.runAsync(() async {
        expect(
          await Directory('${temporary.path}/.local/bin').exists(),
          isFalse,
        );
      });
      expect(repository.profiles.single.toJson(), profile.toJson());
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'Terminal command $language conflicts and invalid names are localized and retryable',
      (tester) async {
        final external = File('${temporary.path}/.local/bin/rpcs3');
        await tester.runAsync(() async {
          await external.parent.create(recursive: true);
          await external.writeAsString('external');
        });
        final l = await open(tester, language, const Size(800, 600));
        await tap(
          tester,
          find.widgetWithText(FilledButton, l.createTerminalCommand),
        );
        await waitFor(
          tester,
          () => find
              .text(l.terminalCommandConflict(external.path))
              .evaluate()
              .isNotEmpty,
        );
        await tester.runAsync(() async {
          expect(await external.readAsString(), 'external');
        });
        await tester.enterText(find.byType(TextField), '../bad');
        await tap(
          tester,
          find.widgetWithText(FilledButton, l.createTerminalCommand),
        );
        await waitFor(
          tester,
          () => find.text(l.terminalCommandInvalid).evaluate().length == 2,
        );
        await tester.enterText(find.byType(TextField), 'rpcs3-work');
        await tap(
          tester,
          find.widgetWithText(FilledButton, l.createTerminalCommand),
        );
        await waitFor(
          tester,
          () => find
              .text(l.terminalCommandCreated('rpcs3-work'))
              .evaluate()
              .isNotEmpty,
        );
        expect(repository.errors, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
