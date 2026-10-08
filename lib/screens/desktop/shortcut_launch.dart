import '../../features/home/services/library_controller.dart';
import '../../shared/services/process_service.dart';

/// Approved desktop shortcuts need no library window. Keep the supervisor alive
/// until output and exit status are persisted; approval still uses the normal UI.
Future<bool> launchDesktopShortcut(
  LibraryController library,
  String profileId,
) async {
  final profile = library.repository.profiles.firstWhere(
    (profile) => profile.id == profileId,
  );
  if (library.processes.isRunning(profile.id)) {
    return true;
  }
  final application = library.repository.applications.firstWhere(
    (application) => application.id == profile.applicationId,
  );
  if (await library.launcher.approval(profile, application) != null) {
    return false;
  }
  try {
    await library.launcher.launch(profile, application);
  } on ProfileAlreadyRunning {
    // Another supervisor won the launch race under the library lock.
    return true;
  } on OutputStreamsPending {
    // A local supervisor still owns output from the previous launch.
    await library.processes.waitForPendingExits(timeout: null);
    return true;
  }
  // Follow our actual completion, not SQLite's stop marker: another instance
  // can reconcile an exited PID before inherited output pipes reach EOF.
  // Hidden supervision has no shutdown deadline and must not retry the launch.
  await library.processes.waitForPendingExits(timeout: null);
  return true;
}
