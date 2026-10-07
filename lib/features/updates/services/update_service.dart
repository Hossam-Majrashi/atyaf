import 'package:path/path.dart' as p;

import '../../../shared/models/library_models.dart';
import '../../../shared/services/library_repository.dart';
import '../../../shared/services/process_service.dart';
import '../../../shared/services/runtime_service.dart';
import '../../../shared/services/managed_storage_service.dart';

class ApplicationRunning implements Exception {}

class UpdateService {
  UpdateService(this.repository, this.runtime, this.processes, this.storage);
  final LibraryRepository repository;
  final RuntimeService runtime;
  final ProcessService processes;
  final ManagedStorageService storage;

  bool isRunning(Application app) => repository.profiles
      .where((profile) => profile.applicationId == app.id)
      .any((profile) => processes.isRunning(profile.id));

  String? preferredExecutable(Application app, ManagedSource source) {
    final relative =
        app.executableRelative ??
        (app.portableRoot == null
            ? null
            : p.relative(app.executable, from: app.portableRoot!));
    return source.executables.contains(relative) ? relative : null;
  }

  Future<Application> update(
    Application app,
    ManagedSource source,
    String relative,
  ) => repository.withExclusiveLock(() async {
    if (isRunning(app)) {
      throw ApplicationRunning();
    }
    final current = repository.applications
        .where((item) => item.id == app.id)
        .firstOrNull;
    if (current == null ||
        current.toJson().toString() != app.toJson().toString()) {
      throw StateError('Application changed while preparing update');
    }
    final destination =
        app.portableRoot ??
        p.join(runtime.root, 'applications', app.id, 'current');
    // Custom profile storage must never be removed with application files.
    final protectedPaths = <String>{};
    for (final profile in repository.profiles.where(
      (item) => item.applicationId == app.id,
    )) {
      final values = [
        ...runtime.resolvedPaths(profile).values,
        ...runtime
            .environmentFor(profile)
            .entries
            .where(
              (entry) => [
                'HOME',
                'XDG_CONFIG_HOME',
                'XDG_DATA_HOME',
                'XDG_CACHE_HOME',
                'XDG_STATE_HOME',
                'TMPDIR',
              ].contains(entry.key),
            )
            .map((entry) => entry.value),
      ];
      protectedPaths.addAll(values);
      if (values.any(
        (path) => p.equals(destination, path) || p.isWithin(destination, path),
      )) {
        throw StateError(
          'Profile data paths must be outside application files',
        );
      }
    }
    final updated = Application(
      id: app.id,
      name: app.name,
      executable: p.join(destination, relative),
      executableRelative: relative,
      portableRoot: destination,
      wmClass: app.wmClass,
      iconPng: app.iconPng,
    );
    // Shortcuts invoke the stable profile ID, not this executable path.
    await storage.replace(
      source,
      destination,
      relative,
      commit: () => repository.saveApplication(updated),
      protectedPaths: protectedPaths,
    );
    return updated;
  });
}
