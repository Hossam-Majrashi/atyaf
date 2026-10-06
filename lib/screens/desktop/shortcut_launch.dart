import '../../features/home/services/library_controller.dart';

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
  await library.launcher.launch(profile, application);
  final launchId = library.repository.history(profile.id).first['id'];
  while (library.repository
      .history(profile.id)
      .any((record) => record['id'] == launchId && record['stop'] == null)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return true;
}
