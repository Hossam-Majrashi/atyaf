/// Optional desktop integration; activation never starts another executable.
abstract interface class ProfileWindowService {
  Future<void> activateWindow(String profileId);
}
