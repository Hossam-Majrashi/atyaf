import '../../../shared/models/library_models.dart';

abstract interface class DesktopEntryService {
  Future<void> create(Application application, Profile profile);
  Future<void> remove(String profileId);
}
