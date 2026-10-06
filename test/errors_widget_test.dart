import 'dart:io';

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

  for (final language in ['en', 'ar']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
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
