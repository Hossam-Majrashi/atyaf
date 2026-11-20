import '../../../shared/models/library_models.dart';

/// Explicit desktop-session startup; never discovers or executes app autostarts.
abstract interface class AutostartService {
  Future<bool> autostartEnabled(String profileId);

  /// Null when disabled, empty for normal startup, or the minimized-mode flags.
  Future<List<String>?> autostartArguments(String profileId);
  Future<void> setAutostart(
    Profile profile,
    bool enabled, {
    List<String> loginArguments = const [],
  });
  Future<void> removeAutostart(String profileId);
}
