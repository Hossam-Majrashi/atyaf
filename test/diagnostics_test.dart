import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/logs/services/log_service.dart';
import 'package:atyaf/features/process_manager/services/process_journal.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:atyaf/platform/linux/linux_crash_diagnostics.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxRepository repository;
  late LogService logs;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-diagnostics-');
    runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/data',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    logs = LogService(runtime);
  });
  tearDown(() async {
    repository.close();
    await temporary.delete(recursive: true);
  });
  Future<String> logFile(String id, String channel, String content) async {
    final file = File('${runtime.profileRoot(id)}/logs/launch.$channel.log');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file.path;
  }

  test('Full copy and streaming TXT export retain Unicode and content beyond the preview limit', () async {
    final text = '${'x' * (400 * 1024)}\nالنهاية complete error\n';
    final path = await logFile('report', 'stderr', text);
    final sections = [
      ReportSection('stderr', logPath: path, profileId: 'report'),
    ];
    expect((await logs.read(path, 'report')).length, 256 * 1024);
    final complete = await logs.completeReport(sections);
    expect(complete, 'stderr\n$text\n\n');
    final destination = '${temporary.path}/report.txt';
    await logs.exportReport(sections, destination);
    expect(await File(destination).readAsString(), complete);
    expect((await File(destination).stat()).mode & 0x1ff, 0x180);
    expect(
      await temporary
          .list()
          .where((entry) => entry.path.contains('/.atyaf-report-'))
          .toList(),
      isEmpty,
    );
  });

  test('Clipboard limit refuses rather than truncates; TXT export remains complete', () async {
    final path = await logFile('large', 'stderr', 'z' * 10000);
    final sections = [
      ReportSection('stderr', logPath: path, profileId: 'large'),
    ];
    await expectLater(
      logs.completeReport(sections, clipboardLimit: 1024),
      throwsA(isA<ReportTooLarge>()),
    );
    final destination = '${temporary.path}/large.txt';
    await logs.exportReport(sections, destination);
    expect(await File(destination).length(), greaterThan(10000));
  });

  test('Export rejects log escapes and managed destinations, preserves previous export on failure', () async {
    final destination = File('${temporary.path}/keep.txt');
    await destination.writeAsString('previous');
    final external = File('${temporary.path}/secret');
    await external.writeAsString('not a profile log');
    final path = '${runtime.profileRoot('safe')}/logs/escape';
    await Directory(File(path).parent.path).create(recursive: true);
    await Link(path).create(external.path);
    final sections = [
      ReportSection('stderr', logPath: path, profileId: 'safe'),
    ];
    await expectLater(
      logs.exportReport(sections, destination.path),
      throwsArgumentError,
    );
    expect(await destination.readAsString(), 'previous');
    await expectLater(
      logs.exportReport([], '${runtime.root}/library.sqlite'),
      throwsArgumentError,
    );
    await Link('${temporary.path}/library-alias').create(runtime.root);
    await expectLater(
      logs.exportReport([], '${temporary.path}/library-alias/report.txt'),
      throwsArgumentError,
    );
    expect(
      await temporary
          .list()
          .where((entry) => entry.path.contains('/.atyaf-report-'))
          .toList(),
      isEmpty,
    );
  });

  test('Missing logs are explicitly represented, never confused with empty available logs', () async {
    final sections = [
      ReportSection(
        'stderr',
        text: 'unavailable',
        logPath: '${runtime.profileRoot('gone')}/logs/missing',
        profileId: 'gone',
      ),
    ];
    expect(await logs.completeReport(sections), contains('unavailable'));
  });

  test('Clearing captured diagnostics persists, preserves history/files/profiles, and keeps new or changed failures', () async {
    const app = Application(
      id: 'app',
      name: 'App',
      executable: '/usr/bin/true',
    );
    const profile = Profile(
      id: 'profile',
      applicationId: 'app',
      name: 'Profile',
      arguments: ['unchanged'],
    );
    repository.saveApplication(app);
    repository.saveProfile(profile);
    final path = await logFile(
      profile.id,
      'stderr',
      'complete preserved output',
    );
    const oldId = "old' OR 1=1 --";
    repository.recordError({'id': oldId, 'detail': 'old error'});
    final old = <String, dynamic>{
      'id': 'old',
      'profileId': profile.id,
      'start': '2026-10-06T12:00:00',
      'stop': '2026-10-06T12:01:00',
      'crashed': true,
      'exitCode': 7,
      'stderr': path,
    };
    repository.recordLaunch(old);
    repository.recordLaunch({
      ...old,
      'id': 'interrupted',
      'crashed': false,
      'interrupted': true,
      'exitCode': null,
    });
    repository.recordLaunch({...old, 'id': 'changed'});
    repository.recordLaunch({...old, 'id': 'running', 'stop': null});
    repository.recordLaunch({
      ...old,
      'id': 'healthy',
      'crashed': false,
      'exitCode': 0,
    });
    final snapshot = repository.history(profile.id);
    repository.recordError({
      'id': 'new',
      'detail': 'arrived during confirmation',
    });
    repository.recordLaunch({...old, 'id': 'new'});
    repository.updateLaunch('changed', {'exitCode': 8});
    await repository.withExclusiveLock(() async {
      repository.clearDiagnostics(errorIds: [oldId], failedLaunches: snapshot);
    });
    expect(repository.errors.single['id'], 'new');
    final history = {
      for (final record in repository.history(profile.id)) record['id']: record,
    };
    expect(history.length, 6);
    for (final id in ['old', 'interrupted']) {
      expect(history[id]?['diagnosticsDismissed'], isTrue);
    }
    for (final id in ['new', 'changed', 'running', 'healthy']) {
      expect(history[id]?['diagnosticsDismissed'], isNot(true));
    }
    expect(history['changed']?['exitCode'], 8);
    expect(history['running']?['stop'], isNull);
    expect(history['old']?['crashed'], isTrue);
    expect(history['old']?['exitCode'], 7);
    expect(repository.applications.single.toJson(), app.toJson());
    expect(repository.profiles.single.toJson(), profile.toJson());
    expect(await File(path).readAsString(), 'complete preserved output');
    final reopened = LinuxRepository(repository.path);
    try {
      expect(reopened.errors.single['id'], 'new');
      expect(
        reopened
            .history(profile.id)
            .firstWhere(
              (record) => record['id'] == 'old',
            )['diagnosticsDismissed'],
        isTrue,
      );
    } finally {
      reopened.close();
    }
    // A real final failure arriving later must become visible again.
    ProcessJournal(repository).finish('interrupted', 9);
    final completed = repository
        .history(profile.id)
        .firstWhere((record) => record['id'] == 'interrupted');
    expect(completed['diagnosticsDismissed'], isFalse);
    expect(completed['crashed'], isTrue);
    expect(completed['exitCode'], 9);
    repository.clearDiagnostics(errorIds: [], failedLaunches: []);
    expect(repository.errors.single['id'], 'new');
  });

  test('Diagnostic clearing rolls back both error deletion and failure dismissal on database failure', () {
    repository.recordError({'id': 'keep', 'detail': 'must survive'});
    repository.recordLaunch({
      'id': 'failed',
      'profileId': 'profile',
      'crashed': true,
      'stop': 'ended',
    });
    final captured = repository.history('profile');
    repository.db.execute(
      "CREATE TRIGGER reject_dismissal BEFORE UPDATE ON launches BEGIN SELECT RAISE(ABORT, 'Injected diagnostic failure'); END",
    );
    expect(
      () => repository.clearDiagnostics(
        errorIds: ['keep'],
        failedLaunches: captured,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(repository.errors.single['id'], 'keep');
    expect(
      repository.history('profile').single['diagnosticsDismissed'],
      isNull,
    );
    expect(repository.history('profile').single['crashed'], isTrue);
  });

  test('SQLite error journal survives reopening and keeps complete multiline errors and stack traces', () {
    final detail = 'خطأ\n${'detail ' * 500}';
    repository.recordError({
      'id': 'error-1',
      'time': '2026-10-05T12:00:00',
      'detail': detail,
      'stack': 'trace\nsecond line',
    });
    final other = LinuxRepository(repository.path);
    expect(other.errors.single['detail'], detail);
    expect(other.errors.single['stack'], 'trace\nsecond line');
    other.close();
  });

  test('Short private TMPDIR fixes Electron-style Unix socket paths even with long XDG roots', () async {
    final longRuntime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/${'long' * 40}',
      },
    );
    const profile = Profile(
      id: '4d919887-689e-4c00-9a20-e494e22f3d32',
      applicationId: 'app',
      name: 'Electron',
    );
    await longRuntime.prepare(profile);
    final temp = longRuntime.environmentFor(profile)['TMPDIR']!;
    expect(
      utf8.encode('$temp/scoped_dirXXXXXXXXXX/SingletonSocket').length,
      lessThan(108),
    );
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      'import socket,tempfile,os,sys; d=tempfile.mkdtemp(prefix="scoped_dir",dir=sys.argv[1]); s=socket.socket(socket.AF_UNIX); s.bind(d+"/SingletonSocket"); print("bound"); s.close(); os.unlink(d+"/SingletonSocket"); os.rmdir(d)',
      temp,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), 'bound');
    expect((await Directory(temp).stat()).mode & 0x1ff, 0x1c0);
    const other = Profile(id: 'other', applicationId: 'app', name: 'Other');
    expect(temp, isNot(longRuntime.environmentFor(other)['TMPDIR']));
    await longRuntime.cleanupTemporary(profile.id);
    expect(await Directory(temp).exists(), isFalse);
  });

  test('Explicit temporary paths and environment overrides are preserved; cleanup never removes custom data', () async {
    final path = '${temporary.path}/custom-temp';
    final profile = Profile(
      id: 'custom',
      applicationId: 'app',
      name: 'Custom',
      paths: {'temp': path},
    );
    await runtime.prepare(profile);
    expect(runtime.environmentFor(profile)['TMPDIR'], path);
    expect(runtime.resolvedPaths(profile)['temp'], path);
    final override = Profile(
      id: 'override',
      applicationId: 'app',
      name: 'Override',
      environment: {'TMPDIR': '${temporary.path}/override-temp'},
    );
    await runtime.prepare(override);
    expect(
      runtime.environmentFor(override)['TMPDIR'],
      '${temporary.path}/override-temp',
    );
    await runtime.cleanupTemporary(profile.id);
    expect(await Directory(path).exists(), isTrue);
  });

  test('Private temporary storage rejects a replaced child symlink without touching its target', () async {
    const profile = Profile(
      id: 'symlink',
      applicationId: 'app',
      name: 'Symlink',
    );
    final path = runtime.shortTemporary(profile.id);
    await runtime.prepare(profile);
    await runtime.cleanupTemporary(profile.id);
    final outside = await Directory('${temporary.path}/outside').create();
    await File('${outside.path}/keep').writeAsString('safe');
    await Link(path).create(outside.path);
    await expectLater(
      runtime.prepare(profile),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      runtime.cleanupTemporary(profile.id),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File('${outside.path}/keep').readAsString(), 'safe');
    await Link(path).delete();
  });

  test('coredumpctl is optional and scoped to PID, boot, time and executable without a shell', () async {
    final calls = <List<String>>[];
    final diagnostics = LinuxCrashDiagnostics(
      run: (executable, args) async {
        calls.add([executable, ...args]);
        return ProcessResult(
          1,
          0,
          executable.endsWith('coredumpctl')
              ? 'Signal: 5 (TRAP)\nStack trace'
              : executable.endsWith('/id')
              ? '1000\n'
              : '',
          '',
        );
      },
    );
    final record = {
      'pid': 632621,
      'crashed': true,
      'identity': '191194d8-4cb3-471f-be73-655fea86e021:123',
      'start': '2026-10-05T23:21:56',
      'stop': '2026-10-05T23:21:58',
      'executable': '/path/Antigravity ; literal',
    };
    expect(await diagnostics.info(record), contains('Signal: 5'));
    expect(
      calls.last,
      containsAll([
        'COREDUMP_PID=632621',
        'COREDUMP_UID=1000',
        '_BOOT_ID=191194d84cb3471fbe73655fea86e021',
        'COREDUMP_EXE=/path/Antigravity ; literal',
      ]),
    );
    expect(
      calls.last.where((value) => value.startsWith('--since=')),
      isNotEmpty,
    );
    calls.clear();
    expect(await diagnostics.info({...record, 'identity': 'bad'}), '');
    expect(calls, isEmpty);
    final unavailable = LinuxCrashDiagnostics(
      run: (executable, args) async => ProcessResult(1, 1, '', ''),
    );
    expect(await unavailable.info(record), '');
  });
}
