import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../shared/services/process_service.dart';
import '../../features/process_manager/services/process_journal.dart';
import '../../shared/models/library_models.dart';
import '../../shared/services/library_repository.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_commands.dart';

class LinuxProcesses implements ProcessService {
  LinuxProcesses(this.runtime, this.repository)
    : journal = ProcessJournal(repository);
  final ProcessJournal journal;
  final RuntimeService runtime;
  final LibraryRepository repository;
  final Map<String, Process> children = {};
  final Map<String, Future<int>> exits = {};
  bool get flatpak => Platform.environment.containsKey('FLATPAK_ID');
  String statusPath(String id) =>
      '${runtime.profileRoot(id)}/host-process.json';
  Map<String, dynamic>? hostState(String id) {
    try {
      return jsonDecode(File(statusPath(id)).readAsStringSync())
          as Map<String, dynamic>;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  bool matches(String id, Map<String, dynamic> record) {
    if (!flatpak) {
      return identity(record['pid'] as int) == record['identity'] &&
          record['identity'] != null;
    }
    final state = hostState(id);
    return state?['running'] == true &&
        state?['pid'] == record['pid'] &&
        state?['identity'] == record['identity'] &&
        DateTime.now().millisecondsSinceEpoch / 1000 -
                (state?['heartbeat'] as num? ?? 0) <
            10;
  }

  static String? identity(int pid) {
    try {
      final stat = File('/proc/$pid/stat').readAsStringSync();
      final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
      if (fields.first == 'Z') {
        return null;
      }
      final boot = File('/proc/sys/kernel/random/boot_id')
          .readAsStringSync()
          .trim();
      return '$boot:${fields[19]}';
    } on FileSystemException {
      return null;
    }
  }

  Map<String, dynamic>? active(String id) {
    for (final record in repository.history(id)) {
      if (record['stop'] == null && matches(id, record)) {
        return record;
      }
    }
    return null;
  }

  @override
  bool isRunning(String profileId) => active(profileId) != null;
  @override
  int? pidFor(String profileId) => active(profileId)?['pid'] as int?;
  @override
  void reconcile() {
    for (final profile in repository.profiles) {
      for (final r in repository.history(profile.id)) {
        if (r['stop'] == null &&
            !children.containsKey(profile.id) &&
            !matches(profile.id, r)) {
          journal.interrupted(r['id'] as String);
        }
      }
    }
  }

  @override
  Future<void> launch(Application application, Profile profile) =>
      repository.withExclusiveLock(() => _launch(application, profile));
  Future<void> _launch(Application application, Profile profile) async {
    final review = await runtime.inspect(application.executable);
    if (profile.trustedFingerprint != review.fingerprint) {
      throw StateError('Executable approval required');
    }
    await runtime.prepare(profile);
    final lock = await File('${runtime.profileRoot(profile.id)}/launch.lock')
        .open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      if (isRunning(profile.id) || children.containsKey(profile.id)) {
        throw StateError('Profile already running');
      }
      final workingDirectory = profile.workingDirectory.isEmpty
          ? File(review.path).parent.path
          : profile.workingDirectory;
      final requestPath =
          '${runtime.profileRoot(profile.id)}/host-request.json';
      if (flatpak) {
        if (await File(statusPath(profile.id)).exists()) {
          await File(statusPath(profile.id)).delete();
        }
        await LinuxCommands.writePrivateFile(
          requestPath,
          jsonEncode({
            'executable': review.path,
            'arguments': runtime.argumentsFor(profile),
            'environment': runtime.environmentFor(profile),
            'workingDirectory': workingDirectory,
            'status': statusPath(profile.id),
          }),
        );
      }
      final process = flatpak
          ? await Process.start('/usr/bin/flatpak-spawn', [
              '--host',
              '/usr/bin/python3',
              '${runtime.root}/process_helper.py',
              'launch',
              requestPath,
            ])
          : await Process.start(
              review.path,
              runtime.argumentsFor(profile),
              environment: runtime.environmentFor(profile),
              includeParentEnvironment: false,
              workingDirectory: workingDirectory,
            );
      process.stdin.close();
      children[profile.id] = process;
      final id = const Uuid().v4();
      final directory = Directory('${runtime.profileRoot(profile.id)}/logs');
      await directory.create(recursive: true);
      final outPath = '${directory.path}/$id.stdout.log';
      final errPath = '${directory.path}/$id.stderr.log';
      final streams = [
        capture(process.stdout, outPath),
        capture(process.stderr, errPath),
      ];
      if (flatpak) {
        for (var i = 0; i < 100 && hostState(profile.id) == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (hostState(profile.id) == null) {
          process.kill();
          children.remove(profile.id);
          throw StateError(
            'Host bridge failed to launch; inspect logs in $directory',
          );
        }
      }
      final state = flatpak ? hostState(profile.id) : null;
      journal.start(
        id: id,
        profileId: profile.id,
        pid: state?['pid'] as int? ?? process.pid,
        identity: state?['identity'] as String? ?? identity(process.pid),
        stdoutPath: outPath,
        stderrPath: errPath,
        executable: review.path,
      );
      final completion = process.exitCode.then((code) async {
        await Future.wait(streams);
        journal.finish(
          id,
          flatpak ? (hostState(profile.id)?['exitCode'] as int? ?? code) : code,
        );
        children.remove(profile.id);
        exits.remove(profile.id);
        return code;
      });
      exits[profile.id] = completion;
      unawaited(completion);
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  Future<void> capture(Stream<List<int>> stream, String path) async {
    final sink = File(path).openWrite();
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        await sink.flush();
      }
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> stop(String profileId, {bool force = false}) async {
    final record = active(profileId);
    if (record == null) {
      return;
    }
    final pid = record['pid'] as int;
    if (!matches(profileId, record)) {
      throw StateError('Process identity changed');
    }
    if (flatpak) {
      final result = await Process.run('/usr/bin/flatpak-spawn', [
        '--host',
        '/usr/bin/python3',
        '${runtime.root}/process_helper.py',
        'signal',
        '$pid',
        record['identity'] as String,
        force ? 'force' : 'graceful',
      ]);
      if (result.exitCode != 0) {
        throw StateError(result.stderr.toString());
      }
    } else if (!Process.killPid(
      pid,
      force ? ProcessSignal.sigkill : ProcessSignal.sigterm,
    )) {
      throw StateError('Unable to signal process');
    }
    for (var i = 0; i < 50; i++) {
      if (!matches(profileId, record)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (force) {
      throw StateError('Process did not terminate');
    }
  }

  @override
  Future<void> restart(Application application, Profile profile) async {
    await stop(profile.id);
    if (isRunning(profile.id)) {
      throw StateError(
        'Graceful stop timed out; force kill is a separate action',
      );
    }
    if (exits[profile.id] != null) {
      await exits[profile.id];
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await launch(application, profile);
  }
}
