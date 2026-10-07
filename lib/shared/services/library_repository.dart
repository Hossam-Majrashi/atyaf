import '../models/library_models.dart';

abstract interface class LibraryRepository {
  List<Application> get applications;
  List<Profile> get profiles;
  void saveApplication(Application application);
  void saveProfile(Profile profile);
  void removeApplication(String id);
  void removeProfile(String id);
  List<Map<String, dynamic>> history(String profileId);
  void recordLaunch(Map<String, dynamic> record);
  List<Map<String, dynamic>> get errors;
  void recordError(Map<String, dynamic> record);

  /// Delete the captured error IDs and dismiss unchanged completed failures
  /// from diagnostics without deleting launch history or its log files.
  void clearDiagnostics({
    required Iterable<String> errorIds,
    required Iterable<Map<String, dynamic>> failedLaunches,
  });
  void updateLaunch(String id, Map<String, dynamic> values);
  void snapshot(String destination);
  Future<T> withExclusiveLock<T>(Future<T> Function() operation);
  void close();
}
