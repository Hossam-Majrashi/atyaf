enum ArchiveFormat {
  tar(['tar']),
  gzip(['tar.gz', 'tgz']),
  xz(['tar.xz', 'txz']),
  bzip2(['tar.bz2', 'tbz2', 'tbz']),
  zstd(['tar.zst', 'tzst']),
  zip(['zip']);

  const ArchiveFormat(this.extensions);
  final List<String> extensions;

  static ArchiveFormat? forPath(String path) {
    final lower = path.toLowerCase();
    for (final format in values) {
      if (format.extensions.any((ext) => lower.endsWith('.$ext'))) {
        return format;
      }
    }
    return null;
  }

  // The Linux portal uses globs. Match mixed-case suffixes as well.
  static List<String> get pickerExtensions => [
    for (final format in values)
      for (final ext in format.extensions)
        ext.replaceAllMapped(RegExp('[a-z]'), (m) {
          final c = m[0]!;
          return '[$c${c.toUpperCase()}]';
        }),
  ];
}

final class UnsupportedArchiveFormat implements Exception {
  const UnsupportedArchiveFormat();

  @override
  String toString() => 'Unsupported archive format';
}

abstract interface class ArchiveService {
  Future<String> extractPortable(String source);
  Future<void> extractTo(String source, String destination);
}
