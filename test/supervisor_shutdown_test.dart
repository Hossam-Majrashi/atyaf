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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeldExitProcesses extends LinuxProcesses {
  HeldExitProcesses(super.runtime, super.repository);
  final captured = Completer<void>(), release = Completer<void>();
  int streams = 0, stops = 0;
  @override
  Future<void> capture(Stream<List<int>> stream, String path) async {
    await super.capture(stream, path);
    if (++streams == 2) captured.complete();
    await release.future;
  }

  @override
  Future<void> stop(String profileId, {bool force = false}) async {
    stops++;
    await super.stop(profileId, force: force);
  }
}

class HeldPrepareRuntime extends LinuxRuntime {
  HeldPrepareRuntime({required super.environment});
  final preparing = Completer<void>(), release = Completer<void>();
  bool hold = false;
  @override
  Future<void> prepare(Profile profile) async {
    if (hold) {
      preparing.complete();
      await release.future;
    }
    await super.prepare(profile);
  }
}

class ShutdownFixture {
  late Directory temporary;
  late LinuxRepository repository;
  late LibraryController library;
  late HeldExitProcesses owner;
  late HeldPrepareRuntime runtime;
  late Profile profile;
  final calls = <String>[];
  bool failHide = false;
  static const app = Application(
    id: 'app',
    name: 'Python',
    executable: '/usr/bin/python3',
  );

  Future<void> initialize({bool external = false, bool running = false}) async {
    temporary = await Directory.systemTemp.createTemp('atyaf-shutdown-');
    runtime = HeldPrepareRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/data',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    owner = HeldExitProcesses(runtime, repository);
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    library = LibraryController(
      repository: repository,
      runtime: runtime,
      processes: external ? LinuxProcesses(runtime, repository) : owner,
      archives: archives,
      storage: LinuxManagedStorage(runtime, archives),
      backup: LinuxBackup(runtime, repository, archives, owner),
      entries: LinuxDesktopEntries(
        runtime,
        await File('assets/icon/icon.png').readAsBytes(),
      ),
    );
    final review = await runtime.inspect(app.executable);
    profile = Profile(
      id: 'drain',
      applicationId: app.id,
      name: 'Drain',
      trustedFingerprint: review.fingerprint,
      // A private marker keeps the real process alive until explicit release.
      arguments: running
          ? [
              '-c',
              'import os,time,sys; print("ready",flush=True); '
                  'exec("while not os.path.exists(sys.argv[1]): time.sleep(.02)"); '
                  'print("saved output"); print("saved error",file=sys.stderr)',
              '${temporary.path}/finish',
            ]
          : [
              '-c',
              'import sys; print("saved output"); print("saved error",file=sys.stderr)',
            ],
    );
    repository.saveApplication(app);
    repository.saveProfile(profile);
  }

  void mockWindow(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'hide' && failHide) throw StateError('hide failed');
        if (call.method == 'isMinimized') return false;
        if (call.method == 'destroy' && identical(library.processes, owner)) {
          expectSync(owner.pendingLaunches, isEmpty);
          expectSync(owner.exits, isEmpty);
          if (repository.history(profile.id).isNotEmpty) {
            expectSync(repository.history(profile.id).single['exitCode'], 0);
          }
        }
        return null;
      },
    );
  }

  Future<void> mount(WidgetTester tester, String language) async {
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
  }

  Future<void> finish() async {
    await File('${temporary.path}/finish').writeAsString('done');
    if (!runtime.release.isCompleted) runtime.release.complete();
    if (!owner.release.isCompleted) owner.release.complete();
  }

  Future<void> dispose() async {
    await finish();
    await owner.waitForPendingExits(timeout: null);
    await runtime.cleanupTemporary(profile.id);
    library.dispose();
    repository.close();
    await temporary.delete(recursive: true);
  }
}

Future<void> settleClose(WidgetTester tester, ShutdownFixture fixture) async {
  for (
    var attempt = 0;
    attempt < 200 && !fixture.calls.contains('destroy');
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(fixture.calls, contains('destroy'));
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final mode in ['local', 'external', 'draining', 'launching', 'idle']) {
      testWidgets('Closing $language $mode hides without stopping programs', (
        tester,
      ) async {
        final fixture = ShutdownFixture();
        await tester.runAsync(() async {
          await fixture.initialize(
            external: mode == 'external',
            running: mode == 'local' || mode == 'external',
          );
          if (mode != 'idle' && mode != 'launching') {
            await fixture.owner.launch(ShutdownFixture.app, fixture.profile);
            if (mode == 'draining') await fixture.owner.captured.future;
          }
        });
        fixture.mockWindow(tester);
        addTearDown(() async {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            null,
          );
          await tester.runAsync(fixture.dispose);
        });
        await fixture.mount(tester, language);
        Future<void>? launch;
        if (mode == 'launching') {
          fixture.runtime.hold = true;
          await tester.runAsync(() async {
            launch = fixture.owner.launch(ShutdownFixture.app, fixture.profile);
            await fixture.runtime.preparing.future;
          });
        }
        final dynamic state = tester.state(find.byType(AtyafApp));
        final closing = state.onWindowClose() as Future<void>;
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        expect(fixture.calls, contains('hide'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(fixture.owner.stops, 0);
        expect(fixture.repository.errors, isEmpty);
        if (mode == 'external' || mode == 'idle') {
          await closing;
          expect(fixture.calls, contains('destroy'));
          if (mode == 'external') {
            expect(fixture.owner.isRunning('drain'), isTrue);
          }
        } else {
          expect(fixture.calls, isNot(contains('destroy')));
          if (mode == 'local') expect(fixture.owner.isRunning('drain'), isTrue);
          // Repeated native close events cannot stop anything or create a second waiter.
          await state.onWindowClose();
          expect(fixture.calls.where((call) => call == 'hide'), hasLength(1));
        }
        await tester.runAsync(fixture.finish);
        await settleClose(tester, fixture);
        if (launch != null) await tester.runAsync(() => launch!);
        await tester.pump();
        await closing;
        if (mode != 'idle') {
          await tester.runAsync(() async {
            await fixture.owner.waitForPendingExits(timeout: null);
            final record = fixture.repository.history('drain').single;
            expect(record['exitCode'], 0);
            expect(record['interrupted'], isFalse);
            expect(
              await File(record['stdout'] as String).readAsString(),
              contains('saved output'),
            );
            expect(
              await File(record['stderr'] as String).readAsString(),
              contains('saved error'),
            );
          });
        }
        expect(fixture.owner.stops, 0);
        expect(fixture.repository.errors, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('A genuine hide failure restores the window and allows retry', (
    tester,
  ) async {
    final fixture = ShutdownFixture();
    await tester.runAsync(() => fixture.initialize());
    fixture.mockWindow(tester);
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
      await tester.runAsync(fixture.dispose);
    });
    await fixture.mount(tester, 'en');
    fixture.failHide = true;
    final dynamic state = tester.state(find.byType(AtyafApp));
    await state.onWindowClose();
    await tester.pump();
    expect(fixture.calls, containsAllInOrder(['hide', 'show', 'focus']));
    expect(fixture.calls, isNot(contains('destroy')));
    expect(fixture.repository.errors, hasLength(1));
    fixture.failHide = false;
    await state.onWindowClose();
    expect(fixture.calls, contains('destroy'));
  });
}
