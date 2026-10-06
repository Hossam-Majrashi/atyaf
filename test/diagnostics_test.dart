import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/logs/services/log_service.dart';
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
