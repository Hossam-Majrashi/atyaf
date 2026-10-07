import 'dart:io';

import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/screens/desktop/logs_screen.dart';
import 'package:atyaf/screens/desktop/errors_screen.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextReportPicker extends FilePicker {
  TextReportPicker(this.destination);
  final String destination;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => destination;
}

void main() {
  late Directory temporary;
  late LinuxRepository repository;
  late LibraryController library;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-error-widgets-');
    final runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/data',
      },
    );
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
      processes: processes,
      archives: archives,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(runtime, repository, archives, processes),
      entries: LinuxDesktopEntries(
        runtime,
        await File('assets/icon/icon.png').readAsBytes(),
      ),
    );
    repository.saveApplication(
      const Application(
        id: 'app',
        name: 'Antigravity',
        executable: '/usr/bin/true',
      ),
    );
    repository.saveProfile(
      const Profile(
        id: 'profile',
        applicationId: 'app',
        name: 'Profile العربية',
      ),
    );
    final directory = Directory('${runtime.profileRoot('profile')}/logs');
    await directory.create(recursive: true);
    await File('${directory.path}/stdout').writeAsString('stdout complete');
    await File('${directory.path}/stderr')
        .writeAsString('${'e' * (300 * 1024)}\nSocket path too long\nالنهاية');
    repository.recordLaunch({
      'id': 'failed',
      'profileId': 'profile',
      'pid': 632621,
      'start': '2026-10-05T23:21:56',
      'stop': '2026-10-05T23:21:58',
      'exitCode': -5,
      'crashed': true,
      'stdout': '${directory.path}/stdout',
      'stderr': '${directory.path}/stderr',
    });
    library.reportError(
      StateError('Atyaf operation failed'),
      StackTrace.fromString('Complete stack trace'),
    );
  });
  tearDown(() async {
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  });

  testWidgets(
    'Failed diagnostic deletion reports the error and preserves previous diagnostics',
    (tester) async {
      repository.db.execute(
        "CREATE TRIGGER reject_dismissal BEFORE UPDATE ON launches BEGIN SELECT RAISE(ABORT, 'Deletion rejected'); END",
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ErrorsScreen(library: library),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear errors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear errors').last);
      for (
        var attempt = 0;
        attempt < 150 && repository.errors.length == 1;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(repository.errors.length, 2);
      expect(
        repository.errors.any(
          (record) =>
              record['detail'].toString().contains('Atyaf operation failed'),
        ),
        isTrue,
      );
      expect(
        repository.errors.any(
          (record) => record['detail'].toString().contains('Deletion rejected'),
        ),
        isTrue,
      );
      expect(
        repository.history('profile').single['diagnosticsDismissed'],
        isNull,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Logs $language explain TLS, wallet, desktop handler and lost exit status',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        repository.updateLaunch('failed', {
          'interrupted': true,
          'exitCode': null,
          'crashed': false,
        });
        await tester.runAsync(
          () => File('${library.runtime.profileRoot('profile')}/logs/stderr')
              .writeAsString(
                'net_error -202\nError contacting kwalletd6\n/usr/bin/xdg-open: test: : integer expected',
              ),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LogsScreen(
              library: library,
              profile: repository.profiles.single,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        for (
          var attempt = 0;
          attempt < 100 && find.text(l.certificateAdvice).evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        for (final advice in [
          l.lostExitAdvice,
          l.certificateAdvice,
          l.walletAdvice,
          l.desktopHandlerAdvice,
        ]) {
          expect(find.text(advice), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets(
        'Clear diagnostics $language $size confirms, cancels, and preserves errors arriving during confirmation',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = lookupAppLocalizations(Locale(language));
          final originalErrors = repository.errors;
          final originalHistory = repository.history('profile');
          final originalApp = repository.applications.single.toJson();
          final originalProfile = repository.profiles.single.toJson();
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ErrorsScreen(library: library),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> waitFor(bool Function() ready) async {
            for (var attempt = 0; attempt < 150; attempt++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 15)),
              );
              await tester.pump(const Duration(milliseconds: 20));
              if (ready()) {
                await tester.pumpAndSettle();
                return;
              }
            }
            fail('Diagnostic deletion did not complete');
          }

          await tester.tap(find.text(l.clearErrors));
          await tester.pumpAndSettle();
          expect(find.text(l.clearErrorsConfirm), findsOneWidget);
          await tester.tap(find.text(l.cancel));
          await tester.pumpAndSettle();
          expect(repository.errors, originalErrors);
          expect(repository.history('profile'), originalHistory);
          await tester.tap(find.text(l.clearErrors));
          await tester.pumpAndSettle();
          library.reportError(
            StateError('New diagnostic during confirmation'),
            StackTrace.current,
          );
          repository.recordLaunch({
            ...originalHistory.single,
            'id': 'new-failure',
            'pid': 632622,
          });
          library.refresh();
          await tester.pump();
          await tester.tap(find.text(l.clearErrors).last);
          await waitFor(
            () =>
                repository.errors.length == 1 &&
                find.text(l.errorsCleared).evaluate().isNotEmpty &&
                repository
                        .history('profile')
                        .firstWhere(
                          (record) => record['id'] == 'failed',
                        )['diagnosticsDismissed'] ==
                    true,
          );
          expect(
            repository.errors.single['detail'],
            contains('New diagnostic during confirmation'),
          );
          expect(library.failedDiagnostics.single.$2['id'], 'new-failure');
          expect(repository.history('profile').length, 2);
          await tester.tap(find.text(l.clearErrors));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.clearErrors).last);
          await waitFor(
            () =>
                repository.errors.isEmpty &&
                library.failedDiagnostics.isEmpty &&
                find.text(l.noErrors).evaluate().isNotEmpty,
          );
          expect(find.text(l.noErrors), findsOneWidget);
          final button = find
              .ancestor(
                of: find.text(l.clearErrors),
                matching: find.byWidgetPredicate(
                  (widget) => widget is TextButton,
                ),
              )
              .first;
          expect(tester.widget<TextButton>(button).onPressed, isNull);
          expect(repository.history('profile').length, 2);
          expect(
            repository
                .history('profile')
                .every(
                  (record) =>
                      record['crashed'] == true && record['exitCode'] == -5,
                ),
            isTrue,
          );
          expect(repository.applications.single.toJson(), originalApp);
          expect(repository.profiles.single.toJson(), originalProfile);
          await tester.runAsync(() async {
            expect(
              await File(originalHistory.single['stdout'] as String)
                  .readAsString(),
              'stdout complete',
            );
            expect(
              await File(originalHistory.single['stderr'] as String)
                  .readAsString(),
              endsWith('النهاية'),
            );
          });
          library.reportError(
            StateError('Fresh error after reset'),
            StackTrace.current,
          );
          library.refresh();
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Fresh error after reset'),
            findsOneWidget,
          );
          expect(find.text(l.noErrors), findsNothing);
          expect(tester.widget<TextButton>(button).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Errors $language $size: full clipboard/TXT reports and responsive failed-launch details',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'onboarding_done': true,
            'language': language,
          });
          String? copied;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              if (call.method == 'Clipboard.getData') {
                return {'text': copied ?? ''};
              }
              if (call.method == 'Clipboard.hasStrings') {
                return {'value': copied != null};
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          FilePickerLinux.registerWith();
          final originalPicker = FilePicker.platform;
          FilePicker.platform = TextReportPicker('${temporary.path}/report');
          addTearDown(() => FilePicker.platform = originalPicker);
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
          await tester.tap(find.byIcon(Icons.bug_report_outlined));
          await tester.pumpAndSettle();
          expect(
            find.text(
              language == 'en' ? 'Errors and diagnostics' : 'الأخطاء والتشخيص',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          Future<void> waitFor(bool Function() ready) async {
            for (var i = 0; i < 200; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump(const Duration(milliseconds: 20));
              if (ready()) return;
            }
            fail('Diagnostic action did not complete');
          }

          await tester.tap(
            find
                .text(
                  language == 'en'
                      ? 'Copy complete report'
                      : 'نسخ التقرير كاملًا',
                )
                .first,
          );
          await waitFor(() => copied != null);
          expect(copied, contains('Socket path too long'));
          expect(copied, contains('النهاية'));
          expect(copied, contains('Complete stack trace'));
          expect(copied, contains('stdout complete'));
          expect(copied!.length, greaterThan(300 * 1024));
          await tester.tap(
            find.text(language == 'en' ? 'Export TXT' : 'تصدير TXT').first,
          );
          final exported = File('${temporary.path}/report.txt');
          await waitFor(() => exported.existsSync());
          await tester.runAsync(
            () async => expect(await exported.readAsString(), copied),
          );
          // Expanding the failed launch exposes complete-report actions plus bounded previews.
          final title = find.textContaining('632621').first;
          await tester.ensureVisible(title);
          await tester.tap(title);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
