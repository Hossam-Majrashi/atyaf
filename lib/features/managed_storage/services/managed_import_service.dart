import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../shared/models/library_models.dart';
import '../../../shared/services/library_repository.dart';
import '../../../shared/services/managed_storage_service.dart';
import '../../../shared/services/runtime_service.dart';

class ManagedImportService {
  ManagedImportService(this.repository, this.runtime, this.storage);
  final LibraryRepository repository;
  final RuntimeService runtime;
  final ManagedStorageService storage;

  Future<Application> add(
    String name,
    ManagedSource source,
    String relative, {
    String? iconPng,
  }) => repository.withExclusiveLock(() async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Name required');
    }
    final id = const Uuid().v4();
    final destination = p.join(runtime.root, 'applications', id, 'current');
    final app = Application(
      id: id,
      name: name.trim(),
      executable: p.join(destination, relative),
      executableRelative: relative,
      portableRoot: destination,
      iconPng: iconPng,
    );
    await storage.replace(
      source,
      destination,
      relative,
      commit: () => repository.saveApplication(app),
    );
    return app;
  });
}
