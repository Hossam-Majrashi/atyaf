import '../../../shared/models/library_models.dart';

abstract interface class DesktopEntryService {
  Future<void> create(Application application, Profile profile);
  Future<void> remove(String profileId);
  Future<void> refreshIcons(Application application, List<Profile> profiles);

  /// Image extensions exposed by the installed Linux image decoders.
  Future<List<String>> imageExtensions();

  /// Decode a single explicitly chosen file into a bounded 512px PNG copy.
  /// Returns null for damaged, unsupported or oversized images.
  Future<String?> readImage(String path);

  /// Relative image paths, recursively confined to the selected project root.
  Future<List<String>> scanImages(String root);

  /// Decoded, normalized PNG copies; invalid/unsupported images return null.
  Future<List<String?>> previewImages(
    String root,
    List<String> paths, {
    int size = 96,
  });
}
