import '../models/library_models.dart';

/// Expected launch contention, not a failure of the application being launched.
class ProfileAlreadyRunning extends StateError {
  ProfileAlreadyRunning() : super('Profile already running');
}

/// Logs are still owned by a live supervisor; they must not be discarded.
class OutputStreamsPending extends StateError {
  OutputStreamsPending() : super('Output streams are still draining');
}

abstract interface class ProcessService {
  /// Includes live supervision of inherited streams after the original PID
  /// exits. Such a profile stays reserved against launch/update/delete.
  bool isRunning(String profileId);

  /// Only a verified original process, never a dead PID or guessed relaunch.
  /// Null with isRunning=true means output supervision is still pending.
  int? pidFor(String profileId);
  Future<void> launch(Application application, Profile profile);
  Future<void> stop(String profileId, {bool force = false});
  Future<void> restart(Application application, Profile profile);

  /// Wait for in-flight local launches/restarts and all supervised exits to
  /// finish persisting both log streams. Other instances' profiles do not wait.
  /// A null timeout keeps hidden desktop/shortcut supervision alive until done.
  Future<void> waitForPendingExits({
    Duration? timeout = const Duration(seconds: 5),
  });
  void reconcile();
}
