import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/archives/services/archive_service.dart';
import '../../shared/services/managed_storage_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_archives.dart';
import 'linux_commands.dart';

class LinuxManagedStorage implements ManagedStorageService {
  LinuxManagedStorage(this.runtime, this.archives);
  final RuntimeService runtime;
  final ArchiveService archives;

  Future<Directory> stagingParent() async {
    final parent = Directory('${runtime.root}/staging');
    if (await FileSystemEntity.type(parent.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw ArgumentError('Staging directory cannot be a symlink');
    }
    await parent.create(recursive: true);
    final root = await Directory(runtime.root).resolveSymbolicLinks();
    if (!p.equals(
      await parent.resolveSymbolicLinks(),
      p.join(root, 'staging'),
    )) {
      throw ArgumentError('Staging directory escaped library');
    }
    return parent;
  }

  @override
  Future<ManagedSource> stage(String source, {required bool archive}) async {
    final parent = await stagingParent();
    final root = '${parent.path}/${const Uuid().v4()}';
    try {
      if (archive) {
        await archives.extractTo(source, root);
      } else {
        // The same host helper validates confined links, special files and limits.
        if (archives is! LinuxArchives) {
          throw StateError('Linux folder importer unavailable');
        }
        await (archives as LinuxArchives).invoke([
          'copy',
          LinuxCommands.hostPath(Directory(source).absolute.path),
          root,
        ]);
      }
      final candidates = await runtime.discover(root);
      final valid = <String>[];
      for (final candidate in candidates) {
        try {
          await runtime.inspect(candidate);
          valid.add(p.relative(candidate, from: root));
        } on FileSystemException {
          continue;
        }
      }
      if (valid.isEmpty) {
        throw StateError('No valid executables in source');
      }
      return ManagedSource(source, root, List.unmodifiable(valid));
    } catch (_) {
      await runtime.deleteManaged(root);
      rethrow;
    }
  }

  @override
  Future<ExecutableReview> review(ManagedSource source, String relative) async {
    final parent = await stagingParent();
    if (!p.equals(p.dirname(source.root), parent.path) ||
        await FileSystemEntity.type(source.root, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw ArgumentError('Source must be a private staged application');
    }
    if (!source.executables.contains(relative) ||
        p.isAbsolute(relative) ||
        !p.isWithin(source.root, p.join(source.root, relative))) {
      throw ArgumentError('Select a discovered executable');
    }
    final result = await runtime.inspect(p.join(source.root, relative));
    final root = await Directory(source.root).resolveSymbolicLinks();
    if (!p.isWithin(root, result.path)) {
      throw ArgumentError('Executable escaped staged application');
    }
    return result;
  }

  @override
  Future<void> discard(ManagedSource source) =>
      runtime.deleteManaged(source.root);

  @override
  Future<void> replace(
    ManagedSource source,
    String destination,
    String relative, {
    required void Function() commit,
    Iterable<String> protectedPaths = const [],
  }) async {
    await review(source, relative);
    final root = await Directory(runtime.root).resolveSymbolicLinks();
    final normalized = p.normalize(destination);
    if (!p.isWithin('${runtime.root}/applications', normalized) &&
        !p.isWithin('${runtime.root}/portable', normalized)) {
      throw ArgumentError('Invalid managed application destination');
    }
    final parts = p.split(p.relative(normalized, from: runtime.root));
    final validId = RegExp(r'^[a-zA-Z0-9-]+$');
    if (!((parts.length == 3 &&
            parts.first == 'applications' &&
            parts.last == 'current' &&
            validId.hasMatch(parts[1])) ||
        (parts.length == 2 &&
            parts.first == 'portable' &&
            validId.hasMatch(parts[1])))) {
      throw ArgumentError('Invalid application storage layout');
    }
    for (final directory in {
      p.join(runtime.root, parts.first),
      p.dirname(normalized),
    }) {
      if (await FileSystemEntity.type(directory, followLinks: false) ==
          FileSystemEntityType.link) {
        throw ArgumentError('Application storage parents cannot be symlinks');
      }
    }
    await Directory(p.dirname(normalized)).create(recursive: true);
    final parent = await Directory(p.dirname(normalized))
        .resolveSymbolicLinks();
    final collection = p.isWithin('${runtime.root}/applications', normalized)
        ? 'applications'
        : 'portable';
    final expectedParent = p.join(
      root,
      p.relative(p.dirname(normalized), from: runtime.root),
    );
    if (!p.equals(parent, expectedParent) ||
        (parent != p.join(root, collection) &&
            !p.isWithin(p.join(root, collection), parent))) {
      throw ArgumentError('Destination parent escaped application storage');
    }
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw ArgumentError('Invalid current application directory');
    }
    final actualDestination = p.join(parent, p.basename(normalized));
    for (final path in protectedPaths) {
      var ancestor = p.normalize(path);
      final suffix = <String>[];
      while (await FileSystemEntity.type(ancestor, followLinks: false) ==
          FileSystemEntityType.notFound) {
        suffix.insert(0, p.basename(ancestor));
        ancestor = p.dirname(ancestor);
      }
      final actualPath = p.joinAll([
        await File(ancestor).resolveSymbolicLinks(),
        ...suffix,
      ]);
      if (p.equals(actualDestination, actualPath) ||
          p.isWithin(actualDestination, actualPath)) {
        throw StateError(
          'Profile data resolves inside replaceable application files',
        );
      }
    }
    final rollback = '${runtime.root}/staging/old-${const Uuid().v4()}';
    bool oldMoved = false, installed = false, committed = false;
    try {
      if (type == FileSystemEntityType.directory) {
        await Directory(normalized).rename(rollback);
        oldMoved = true;
      }
      await Directory(source.root).rename(normalized);
      installed = true;
      final executable = await runtime.inspect(p.join(normalized, relative));
      final actual = await Directory(normalized).resolveSymbolicLinks();
      if (!p.isWithin(actual, executable.path)) {
        throw ArgumentError('Installed executable escaped application');
      }
      commit();
      committed = true;
    } catch (_) {
      if (installed) {
        await runtime.deleteManaged(normalized);
      }
      if (oldMoved) {
        await Directory(rollback).rename(normalized);
      }
      rethrow;
    } finally {
      // Never remove rollback data on a failed restoration.
      if (committed && oldMoved) {
        await runtime.deleteManaged(rollback);
      }
    }
  }
}
