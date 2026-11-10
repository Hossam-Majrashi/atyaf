import '../../../shared/models/library_models.dart';

/// Explicit desktop-session startup; never discovers or executes app autostarts.
abstract interface class AutostartService {
  Future<bool> autostartEnabled(String profileId);
  Future<void> setAutostart(Profile profile, bool enabled);
  Future<void> removeAutostart(String profileId);
}
