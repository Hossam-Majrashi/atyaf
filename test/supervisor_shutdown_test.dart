import 'dart:async';
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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeldExitProcesses extends LinuxProcesses {
  HeldExitProcesses(super.runtime, super.repository);
  final captured = Completer<void>(), release = Completer<void>();
  int streams = 0;
  @override
  Future<void> capture(Stream<List<int>> stream, String path) async {
    await super.capture(stream, path);
    if (++streams == 2) captured.complete();
    await release.future;
  }
}

void main() {
  testWidgets(
    'Closing a window with an exited PID still waits for logs and exit commit',
    (tester) async {
      late Directory temporary;
      late LinuxRepository repository;
      late LibraryController library;
      late HeldExitProcesses processes;
      await tester.runAsync(() async {
        temporary = await Directory.systemTemp.createTemp('atyaf-shutdown-');
        final runtime = LinuxRuntime(
          environment: {
            ...Platform.environment,
            'HOME': temporary.path,
            'XDG_DATA_HOME': '${temporary.path}/data',
          },
        );
        await Directory(runtime.root).create(recursive: true);
        repository = LinuxRepository('${runtime.root}/library.sqlite');
        processes = HeldExitProcesses(runtime, repository);
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
        const app = Application(
          id: 'app',
          name: 'Python',
          executable: '/usr/bin/python3',
        );
        final review = await runtime.inspect(app.executable);
        final profile = Profile(
          id: 'drain',
          applicationId: app.id,
          name: 'Drain',
          trustedFingerprint: review.fingerprint,
          arguments: ['-c', 'print("saved output")'],
        );
        repository.saveApplication(app);
        repository.saveProfile(profile);
        await processes.launch(app, profile);
        await processes.captured.future.timeout(const Duration(seconds: 10));
      });
      var destroyed = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async {
          if (call.method == 'destroy') {
            expect(repository.history('drain').single['exitCode'], 0);
            destroyed = true;
          }
          return null;
        },
      );
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          null,
        );
        if (!processes.release.isCompleted) processes.release.complete();
        await tester.runAsync(() async {
          await processes.waitForPendingExits();
          await library.runtime.cleanupTemporary('drain');
          library.dispose();
          repository.close();
          await temporary.delete(recursive: true);
        });
      });
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'language': 'en',
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
      expect(processes.isRunning('drain'), isFalse);
      final dynamic state = tester.state(find.byType(AtyafApp));
      final closing = state.onWindowClose() as Future<void>;
      await tester.pump(const Duration(milliseconds: 400));
      expect(destroyed, isFalse);
      processes.release.complete();
      for (var attempt = 0; attempt < 100 && !destroyed; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await closing;
      expect(destroyed, isTrue);
      expect(repository.history('drain').single['interrupted'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
