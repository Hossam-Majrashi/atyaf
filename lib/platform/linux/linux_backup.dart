import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/backup/services/backup_service.dart';
import '../../shared/services/process_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_archives.dart';
import 'linux_repository.dart';

class LinuxBackup implements BackupService {
  LinuxBackup(this.runtime, this.repository, this.archives, this.processes);
  final RuntimeService runtime;
  final LinuxRepository repository;
  final LinuxArchives archives;
  final ProcessService processes;
  void ensureStopped() {
    if (repository.profiles.any((v) => processes.isRunning(v.id))) {
      throw StateError('Stop all profiles before backup or restore');
    }
  }

  @override
  Future<void> export(String destination) =>
      repository.withExclusiveLock(() => _export(destination));
  Future<void> _export(String destination) async {
    ensureStopped();
    if (p.isWithin(runtime.root, destination)) {
      throw ArgumentError('Backup must be outside managed library');
    }
    final snapshot = '${runtime.root}/snapshot-${const Uuid().v4()}.sqlite';
    final output = '$destination.partial-${const Uuid().v4()}';
    try {
      repository.snapshot(snapshot);
      await archives.invoke(['backup', runtime.root, snapshot, output]);
      await File(output).rename(destination);
    } finally {
      if (await File(snapshot).exists()) {
        await File(snapshot).delete();
      }
      if (await File(output).exists()) {
        await File(output).delete();
      }
    }
  }

  @override
  Future<void> restore(String source) =>
      repository.withExclusiveLock(() => _restore(source));
  Future<void> _restore(String source) async {
    ensureStopped();
    final staging = '${runtime.root}/restore-${const Uuid().v4()}';
    final rollback = '${runtime.root}/rollback-${const Uuid().v4()}';
    final moved = <String>[];
    LinuxRepository? imported;
    try {
      await archives.extractTo(source, staging);
      for (final name in ['backup.json', 'library.sqlite']) {
        if (await FileSystemEntity.type('$staging/$name', followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('Invalid backup metadata');
        }
      }
      final metadata =
          jsonDecode(await File('$staging/backup.json').readAsString()) as Map;
      if (metadata['format'] != 1 ||
          !p.isAbsolute(metadata['root'] as String)) {
        throw StateError('Unsupported backup');
      }
      final oldRoot = metadata['root'] as String;
      String relocate(String path) => p.isWithin(oldRoot, path)
          ? p.join(runtime.root, p.relative(path, from: oldRoot))
          : path;
      imported = LinuxRepository('$staging/library.sqlite');
      final apps = imported.applications
          .map(
            (a) => Application.fromJson({
              ...a.toJson(),
              'executable': relocate(a.executable),
              'portableRoot': a.portableRoot == null
                  ? null
                  : relocate(a.portableRoot!),
            }),
          )
          .toList();
      final profiles = imported.profiles
          .map(
            (v) => Profile.fromJson({
              ...v.toJson(),
              'workingDirectory': relocate(v.workingDirectory),
              'paths': {
                for (final e in v.paths.entries) e.key: relocate(e.value),
              },
              'arguments': v.arguments.map(relocate).toList(),
              'environment': {
                for (final e in v.environment.entries) e.key: relocate(e.value),
              },
              'trustedFingerprint': '',
            }),
          )
          .toList();
      for (final app in apps) {
        runtime.profileRoot(app.id);
        if (!p.isAbsolute(app.executable) ||
            app.name.trim().isEmpty ||
            (app.portableRoot != null &&
                !p.isWithin('${runtime.root}/portable', app.portableRoot!) &&
                !p.isWithin(
                  '${runtime.root}/applications',
                  app.portableRoot!,
                ))) {
          throw StateError('Invalid application in backup');
        }
      }
      for (final profile in profiles) {
        runtime.profileRoot(profile.id);
        if (!apps.any((a) => a.id == profile.applicationId) ||
            profile.name.trim().isEmpty ||
            profile.paths.values.any((v) => v.isNotEmpty && !p.isAbsolute(v))) {
          throw StateError('Invalid profile in backup');
        }
        runtime.environmentFor(profile);
      }
      final records = <Map<String, dynamic>>[];
      for (final profile in profiles) {
        for (final r in imported.history(profile.id)) {
          records.add({
            ...r,
            'stdout': relocate(r['stdout'] as String),
            'stderr': relocate(r['stderr'] as String),
            'executable': r['executable'] == null
                ? null
                : relocate(r['executable'] as String),
            'stop': r['stop'] ?? DateTime.now().toIso8601String(),
            'interrupted': r['stop'] == null,
          });
        }
      }
      imported.close();
      imported = null;
      await Directory(rollback).create();
      repository.db.execute('BEGIN IMMEDIATE');
      try {
        ensureStopped();
        for (final name in ['profiles', 'portable', 'applications']) {
          if (await FileSystemEntity.type(
                '$staging/$name',
                followLinks: false,
              ) ==
              FileSystemEntityType.link) {
            throw StateError('Invalid backup directory');
          }
          if (await Directory('${runtime.root}/$name').exists()) {
            await Directory('${runtime.root}/$name').rename('$rollback/$name');
          }
          moved.add(name);
          if (await Directory('$staging/$name').exists()) {
            await Directory('$staging/$name').rename('${runtime.root}/$name');
          }
        }
        for (final table in ['applications', 'profiles', 'launches']) {
          repository.db.execute('DELETE FROM $table');
        }
        for (final app in apps) {
          repository.saveApplication(app);
        }
        for (final profile in profiles) {
          repository.saveProfile(profile);
        }
        for (final record in records) {
          repository.recordLaunch(record);
        }
        repository.db.execute('COMMIT');
      } catch (_) {
        repository.db.execute('ROLLBACK');
        for (final name in moved.reversed) {
          await runtime.deleteManaged('${runtime.root}/$name');
          if (await Directory('$rollback/$name').exists()) {
            await Directory('$rollback/$name').rename('${runtime.root}/$name');
          }
        }
        rethrow;
      }
    } finally {
      imported?.close();
      await runtime.deleteManaged(staging);
      await runtime.deleteManaged(rollback);
    }
  }
}
