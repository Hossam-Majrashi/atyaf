import '../models/library_models.dart';

abstract interface class ProcessService {
  bool isRunning(String profileId);
  int? pidFor(String profileId);
  Future<void> launch(Application application, Profile profile);
  Future<void> stop(String profileId, {bool force = false});
  Future<void> restart(Application application, Profile profile);
  void reconcile();
}
