import 'dart:convert';
import 'dart:typed_data';

class Application {
  const Application({
    required this.id,
    required this.name,
    required this.executable,
    this.portableRoot,
    this.executableRelative,
    this.wmClass = '',
    this.iconPng,
  });
  final String id, name, executable, wmClass;
  // A normalized PNG copy, independent of source paths and application updates.
  final String? iconPng;
  final String? portableRoot, executableRelative;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'executable': executable,
    'portableRoot': portableRoot,
    'executableRelative': executableRelative,
    'wmClass': wmClass,
    'iconPng': iconPng,
  };
  factory Application.fromJson(Map<String, dynamic> j) => Application(
    id: j['id'] as String,
    name: j['name'] as String,
    executable: j['executable'] as String,
    portableRoot: j['portableRoot'] as String?,
    executableRelative: j['executableRelative'] as String?,
    wmClass: j['wmClass'] as String? ?? '',
    iconPng: _validatedIcon(j['iconPng'] as String?),
  );
}

String? _validatedIcon(String? encoded) {
  if (encoded == null) {
    return null;
  }
  if (encoded.length > 2800000) {
    throw const FormatException('Application icon exceeds size limit');
  }
  final bytes = base64Decode(encoded);
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24 ||
      bytes.length > 2 * 1024 * 1024 ||
      !List.generate(
        8,
        (index) => bytes[index] == signature[index],
      ).every((value) => value)) {
    throw const FormatException('Invalid application PNG icon');
  }
  final header = ByteData.sublistView(bytes);
  final width = header.getUint32(16), height = header.getUint32(20);
  if (width < 1 || height < 1 || width > 512 || height > 512) {
    throw const FormatException('Invalid application icon dimensions');
  }
  return encoded;
}

class Profile {
  const Profile({
    required this.id,
    required this.applicationId,
    required this.name,
    this.arguments = const [],
    this.environment = const {},
    this.workingDirectory = '',
    this.paths = const {},
    this.trustedFingerprint = '',
  });
  final String id, applicationId, name, workingDirectory, trustedFingerprint;
  final List<String> arguments;
  final Map<String, String> environment, paths;
  Map<String, dynamic> toJson() => {
    'id': id,
    'applicationId': applicationId,
    'name': name,
    'arguments': arguments,
    'environment': environment,
    'workingDirectory': workingDirectory,
    'paths': paths,
    'trustedFingerprint': trustedFingerprint,
  };
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    applicationId: j['applicationId'] as String,
    name: j['name'] as String,
    arguments: List<String>.from(j['arguments'] as List),
    environment: Map<String, String>.from(j['environment'] as Map),
    workingDirectory: j['workingDirectory'] as String,
    paths: Map<String, String>.from(j['paths'] as Map),
    trustedFingerprint: j['trustedFingerprint'] as String? ?? '',
  );
  Profile trusted(String fingerprint) =>
      Profile.fromJson({...toJson(), 'trustedFingerprint': fingerprint});
}

Map<String, dynamic> decodeRecord(String json) =>
    Map<String, dynamic>.from(jsonDecode(json) as Map);

class ExecutableReview {
  const ExecutableReview(
    this.path,
    this.owner,
    this.size,
    this.mode,
    this.fingerprint,
  );
  final String path, owner, mode, fingerprint;
  final int size;
}
