import '../../../shared/models/library_models.dart';
import '../../../shared/services/runtime_service.dart';
import '../../../shared/services/process_service.dart';
import '../../../shared/services/library_repository.dart';
import '../../desktop_entries/services/login_arguments.dart';

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
    List<String> loginArguments = const [],
  }) async {
    final trusted = approval == null
        ? profile
        : profile.trusted(approval.fingerprint);
    repository.saveProfile(trusted);
    if (restart) {
      await processes.restart(application, trusted);
    } else {
      final launchProfile = loginArguments.isEmpty
          ? trusted
          : Profile.fromJson({
              ...trusted.toJson(),
              'arguments': LoginArguments.combine(
                trusted.arguments,
                loginArguments,
              ),
            });
      await processes.launch(application, launchProfile);
    }
  }
}
