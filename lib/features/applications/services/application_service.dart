import 'package:uuid/uuid.dart';

import '../../../shared/models/library_models.dart';
import '../../../shared/services/library_repository.dart';
import '../../../shared/services/runtime_service.dart';
import '../../../shared/services/managed_storage_service.dart';
import '../../managed_storage/services/managed_import_service.dart';

class ApplicationService {
  ApplicationService(this.repository, this.runtime, this.storage);
  final LibraryRepository repository;
  final RuntimeService runtime;
  final ManagedStorageService storage;

  Future<Application> addManaged(
    String name,
    ManagedSource source,
    String relative,
  ) => ManagedImportService(
    repository,
    runtime,
    storage,
  ).add(name, source, relative);
  Future<Application> add(
    String name,
    String executable, {
    String? portableRoot,
  }) async {
    final review = await runtime.inspect(executable);
    final app = Application(
      id: const Uuid().v4(),
      name: name.trim(),
      executable: review.path,
      portableRoot: portableRoot,
    );
    if (app.name.isEmpty) {
      throw ArgumentError('Name required');
    }
    repository.saveApplication(app);
    return app;
  }
}
