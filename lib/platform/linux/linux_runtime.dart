import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../shared/models/library_models.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_commands.dart';
import 'linux_desktop_handlers.dart';
import 'linux_window_preferences.dart';

class LinuxRuntime implements RuntimeService {
  LinuxRuntime({Map<String, String>? environment})
    : host = Map.of(environment ?? Platform.environment) {
    final home = host['HOME'];
    if (home == null || !p.isAbsolute(home)) {
      throw StateError('HOME must be absolute');
    }
    dataHome = xdg('XDG_DATA_HOME', p.join(home, '.local', 'share'));
    root = p.join(dataHome, 'com.h.atyaf');
  }
  final Map<String, String> host;
  final _windowPreferencesReady = <String>{};

  bool inheritsWindowPreferences(Profile profile) =>
      profile.paths['config']?.isNotEmpty != true &&
      !profile.environment.containsKey('XDG_CONFIG_HOME') &&
      !profile.environment.containsKey('XDG_DATA_DIRS') &&
      !profile.environment.containsKey('XDG_CURRENT_DESKTOP') &&
      !profile.environment.containsKey('GSETTINGS_BACKEND') &&
      !['GSETTINGS_SCHEMA_DIR', 'DCONF_PROFILE'].any(
        (key) =>
            profile.environment.containsKey(key) ||
            host[key]?.isNotEmpty == true,
      );
  @override
  late final String root, dataHome;
  String xdg(String key, String fallback) =>
      p.isAbsolute(host[key] ?? '') ? host[key]! : fallback;
  @override
  bool get hasX11Display => host['DISPLAY']?.trim().isNotEmpty == true;

  String get configHome =>
      xdg('XDG_CONFIG_HOME', p.join(host['HOME']!, '.config'));
  String get cacheHome =>
      xdg('XDG_CACHE_HOME', p.join(host['HOME']!, '.cache'));
  String get stateHome =>
      xdg('XDG_STATE_HOME', p.join(host['HOME']!, '.local', 'state'));
  @override
  String profileRoot(String id) {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid profile ID');
    }
    return p.join(root, 'profiles', id);
  }

  late final String uid = Process.runSync('/usr/bin/id', [
    '-u',
  ]).stdout.toString().trim();
  String shortTemporary(String id) {
    profileRoot(id);
    if (!RegExp(r'^\d+$').hasMatch(uid) || uid == '0') {
      throw StateError('Private temporary storage requires a non-root UID');
    }
    return '/tmp/atyaf-$uid/${const Uuid().v5(Namespace.url.value, '$root/$id')}';
  }

  static const temporaryHelper = r'''
import os,stat,sys,shutil
base,child,operation=sys.argv[1:]
uid=os.getuid()
if operation == 'prepare':
    try: os.mkdir(base,0o700)
    except FileExistsError: pass
elif not os.path.lexists(base):
    sys.exit(0)
fd=os.open(base,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
try:
    info=os.fstat(fd)
    if info.st_uid != uid or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('Unsafe temporary storage owner or permissions')
    if operation == 'prepare':
        try: os.mkdir(child,0o700,dir_fd=fd)
        except FileExistsError: pass
    elif not os.path.lexists(os.path.join(base,child)):
        sys.exit(0)
    info=os.stat(child,dir_fd=fd,follow_symlinks=False)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != uid or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('Unsafe profile temporary directory')
    if operation == 'remove':
        if not shutil.rmtree.avoids_symlink_attacks:
            raise ValueError('Secure directory removal is unavailable')
        shutil.rmtree('/proc/self/fd/'+str(fd)+'/'+child)
finally:
    os.close(fd)
''';

  Future<void> temporaryOperation(String id, String operation) async {
    final path = shortTemporary(id);
    final result = await LinuxCommands.run('/usr/bin/python3', [
      '-c',
      temporaryHelper,
      p.dirname(path),
      p.basename(path),
      operation,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException(result.stderr.toString().trim(), path);
    }
  }

  @override
  Future<void> cleanupTemporary(String id) => temporaryOperation(id, 'remove');

  @override
  Map<String, String> resolvedPaths(Profile profile) => {
    for (final key in ['config', 'data', 'cache', 'state', 'temp'])
      key: profile.paths[key]?.isNotEmpty == true
          ? profile.paths[key]!
          : key == 'temp'
          ? shortTemporary(profile.id)
          : p.join(profileRoot(profile.id), key),
    'home': profile.paths['home']?.isNotEmpty == true
        ? profile.paths['home']!
        : host['HOME']!,
    'profile': profileRoot(profile.id),
  };
  String expand(String value, Profile profile) {
    for (final e in resolvedPaths(profile).entries) {
      value = value.replaceAll('{${e.key}}', e.value);
    }
    return value;
  }

  @override
  List<String> argumentsFor(Profile profile) =>
      profile.arguments.map((v) => expand(v, profile)).toList();
  @override
  Map<String, String> environmentFor(Profile profile) {
    final paths = resolvedPaths(profile);
    final result = {
      ...host,
      'XDG_CONFIG_HOME': paths['config']!,
      'XDG_DATA_HOME': paths['data']!,
      'XDG_CACHE_HOME': paths['cache']!,
      'XDG_STATE_HOME': paths['state']!,
      'TMPDIR': paths['temp']!,
      'HOME': paths['home']!,
    };
    if (inheritsWindowPreferences(profile) &&
        _windowPreferencesReady.contains(profile.id)) {
      result['GSETTINGS_SCHEMA_DIR'] = p.join(
        profileRoot(profile.id),
        'window-controls',
      );
    }
    for (final e in profile.environment.entries) {
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(e.key) ||
          e.value.contains('\x00')) {
        throw ArgumentError('Invalid environment');
      }
      result[e.key] = expand(e.value, profile);
    }
    for (final key in [
      'HOME',
      'XDG_CONFIG_HOME',
      'XDG_DATA_HOME',
      'XDG_CACHE_HOME',
      'XDG_STATE_HOME',
      'TMPDIR',
    ]) {
      if (!p.isAbsolute(result[key]!)) {
        throw ArgumentError('Environment path must be absolute: $key');
      }
    }
    return desktopHandlers(profile).environment(result, profile.environment);
  }

  LinuxDesktopHandlers desktopHandlers(Profile profile) => LinuxDesktopHandlers(
    p.join(profileRoot(profile.id), 'desktop-handlers'),
    host,
  );

  @override
  Future<void> prepare(Profile profile) async {
    _windowPreferencesReady.remove(profile.id);
    final values = environmentFor(profile);
    final defaultTemp = shortTemporary(profile.id);
    if (values['TMPDIR'] == defaultTemp) {
      await temporaryOperation(profile.id, 'prepare');
    }
    for (final key in [
      'XDG_CONFIG_HOME',
      'XDG_DATA_HOME',
      'XDG_CACHE_HOME',
      'XDG_STATE_HOME',
      'TMPDIR',
    ]) {
      if (key == 'TMPDIR' && values[key] == defaultTemp) {
        continue;
      }
      final directory = Directory(values[key]!);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        await LinuxCommands.run('/usr/bin/chmod', [
          '700',
          '--',
          directory.path,
        ]);
      }
    }
    if (profile.paths['home']?.isNotEmpty == true) {
      await Directory(values['HOME']!).create(recursive: true);
    }
    await desktopHandlers(profile).prepare();
    if (inheritsWindowPreferences(profile) &&
        await LinuxWindowPreferences.prepare(root, profileRoot(profile.id), {
          ...host,
          'XDG_CONFIG_HOME': configHome,
        })) {
      _windowPreferencesReady.add(profile.id);
    }
  }

  @override
  Future<ExecutableReview> inspect(String path) async {
    if (!p.isAbsolute(path) || path.contains('\x00')) {
      throw ArgumentError('Executable path must be absolute');
    }
    final resolved = await LinuxCommands.run('/usr/bin/readlink', [
      '-f',
      '--',
      LinuxCommands.hostPath(path),
    ]);
    final canonical = resolved.stdout.toString().replaceFirst(
      RegExp(r'\n$'),
      '',
    );
    final stat = await LinuxCommands.run('/usr/bin/stat', [
      '-Lc',
      '%s:%a:%u:%A',
      '--',
      canonical,
    ]);
    final check = await LinuxCommands.run('/usr/bin/test', ['-x', canonical]);
    final regular = await LinuxCommands.run('/usr/bin/test', ['-f', canonical]);
    if (resolved.exitCode != 0 ||
        stat.exitCode != 0 ||
        check.exitCode != 0 ||
        regular.exitCode != 0) {
      throw FileSystemException('Executable inaccessible', canonical);
    }
    final fields = stat.stdout.toString().trim().split(':');
    final size = int.parse(fields[0]);
    final mode = int.parse(fields[1], radix: 8);
    if (size == 0 || mode & 0xC00 != 0) {
      throw FileSystemException(
        'Empty or setuid executable rejected',
        canonical,
      );
    }
    final uid = await LinuxCommands.run('/usr/bin/id', ['-u']);
    if (uid.stdout.toString().trim() == '0') {
      throw StateError('Launching as root is prohibited');
    }
    final hash = await LinuxCommands.run('/usr/bin/sha256sum', [
      '--',
      canonical,
    ]);
    if (hash.exitCode != 0) {
      throw FileSystemException('Cannot fingerprint executable', canonical);
    }
    final fingerprint =
        '${hash.stdout.toString().split(' ').first}:${fields[2]}:$mode';
    return ExecutableReview(canonical, fields[2], size, fields[3], fingerprint);
  }

  @override
  Future<List<String>> discover(String directory) async {
    final canonical = await Directory(directory).resolveSymbolicLinks();
    final results = <String>[];
    await for (final entity in Directory(
      canonical,
    ).list(recursive: true, followLinks: false)) {
      if (entity is File || entity is Link) {
        try {
          final target = await File(entity.path).resolveSymbolicLinks();
          if (!p.isWithin(canonical, target)) {
            continue;
          }
          final stat = await File(target).stat();
          if (stat.type == FileSystemEntityType.file &&
              stat.size > 0 &&
              stat.mode & 0x49 != 0) {
            results.add(entity.path);
          }
        } on FileSystemException {
          continue;
        }
      }
    }
    return results..sort();
  }

  @override
  Future<void> deleteManaged(String path) async {
    final normalized = p.normalize(p.absolute(path));
    final safeRoot = await Directory(root).resolveSymbolicLinks();
    if (!p.isWithin(root, normalized)) {
      throw ArgumentError('Deletion outside managed root');
    }
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    final parent = await Directory(p.dirname(normalized))
        .resolveSymbolicLinks();
    if (parent != safeRoot && !p.isWithin(safeRoot, parent)) {
      throw ArgumentError('Parent symlink escaped managed root');
    }
    if (type == FileSystemEntityType.link) {
      await Link(normalized).delete();
      return;
    }
    final actual = await File(normalized).resolveSymbolicLinks();
    if (!p.isWithin(safeRoot, actual)) {
      throw ArgumentError('Symlink escaped managed root');
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(normalized).delete(recursive: true);
    } else {
      await File(normalized).delete();
    }
  }
}
