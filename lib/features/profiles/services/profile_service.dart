import 'package:path/path.dart' as p;

import '../../../shared/models/library_models.dart';
import '../../../shared/services/library_repository.dart';
import '../../../shared/services/runtime_service.dart';

class ProfileService {
  ProfileService(this.repository, this.runtime);
  final LibraryRepository repository;
  final RuntimeService runtime;
  Future<void> save(Profile profile) async {
    if (profile.name.trim().isEmpty ||
        profile.arguments.any((v) => v.contains('\x00')) ||
        (profile.workingDirectory.isNotEmpty &&
            !p.isAbsolute(profile.workingDirectory)) ||
        profile.paths.values.any((v) => v.isNotEmpty && !p.isAbsolute(v))) {
      throw ArgumentError('Invalid profile');
    }
    runtime.environmentFor(profile);
    repository.saveProfile(profile);
  }
}
