import 'dart:convert';

class Application {
  const Application({
    required this.id,
    required this.name,
    required this.executable,
    this.portableRoot,
    this.executableRelative,
    this.wmClass = '',
  });
  final String id, name, executable, wmClass;
  final String? portableRoot, executableRelative;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'executable': executable,
    'portableRoot': portableRoot,
    'executableRelative': executableRelative,
    'wmClass': wmClass,
  };
  factory Application.fromJson(Map<String, dynamic> j) => Application(
    id: j['id'] as String,
    name: j['name'] as String,
    executable: j['executable'] as String,
    portableRoot: j['portableRoot'] as String?,
    executableRelative: j['executableRelative'] as String?,
    wmClass: j['wmClass'] as String? ?? '',
  );
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
