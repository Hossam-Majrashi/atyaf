import '../../../shared/models/library_models.dart';
import '../../../shared/services/runtime_service.dart';
import '../../../shared/services/process_service.dart';
import '../../../shared/services/library_repository.dart';

class LauncherService {
  LauncherService(this.repository, this.runtime, this.processes);
  final LibraryRepository repository;
  final RuntimeService runtime;
  final ProcessService processes;
  Future<ExecutableReview?> approval(
    Profile profile,
    Application application,
  ) async {
    final review = await runtime.inspect(application.executable);
    return review.fingerprint == profile.trustedFingerprint ? null : review;
  }

  Future<void> launch(
    Profile profile,
    Application application, {
    ExecutableReview? approval,
    bool restart = false,
  }) async {
    final trusted = approval == null
        ? profile
        : profile.trusted(approval.fingerprint);
    repository.saveProfile(trusted);
    if (restart) {
      await processes.restart(application, trusted);
    } else {
      await processes.launch(application, trusted);
    }
  }
}
