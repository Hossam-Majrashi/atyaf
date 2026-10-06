import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../features/desktop_entries/services/desktop_entry_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_commands.dart';
import 'linux_runtime.dart';

class LinuxDesktopEntries implements DesktopEntryService {
  LinuxDesktopEntries(
    this.runtime,
    this.icon, {
    String? executable,
    String? iconHelper,
  }) : executable =
           executable ??
           Platform.environment['ATYAF_LAUNCHER'] ??
           Platform.resolvedExecutable,
       iconHelper =
           iconHelper ??
           File('assets/linux/desktop_icon_helper.py').absolute.path;
  final RuntimeService runtime;
  final Uint8List icon;
  final String executable, iconHelper;
  static String value(String input) => input
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
  static String quoteExec(String input) {
    if (input.contains('\n') ||
        input.contains('\r') ||
        input.contains('\x00')) {
      throw ArgumentError('Invalid Exec token');
    }
    var escaped = input.replaceAll('%', '%%');
    for (final char in ['\\', '"', '`', r'$']) {
      escaped = escaped.replaceAll(char, '\\$char');
    }
    return value('"$escaped"');
  }

  String filePath(String id) {
    runtime.profileRoot(id);
    return p.join(
      runtime.dataHome,
      'applications',
      'com.h.atyaf.profile-$id.desktop',
    );
  }

  String iconPath(String id, {bool legacy = false}) {
    runtime.profileRoot(id);
    return p.join(
      runtime.dataHome,
      'icons',
      'hicolor',
      legacy ? '1024x1024' : '512x512',
      'apps',
      'com.h.atyaf.profile-$id.png',
    );
  }

  String render(Application app, Profile profile, {String? applicationIcon}) {
    if (executable.contains('=')) {
      throw ArgumentError('Desktop executable cannot contain =');
    }
    final exec = Platform.environment.containsKey('FLATPAK_ID')
        ? 'flatpak run com.h.atyaf --launch-profile ${quoteExec(profile.id)}'
        : '${quoteExec(executable)} --launch-profile ${quoteExec(profile.id)}';
    // Absolute paths avoid unsupported theme sizes and stale theme-name caches.
    return '[Desktop Entry]\nVersion=1.0\nType=Application\nName=${value(profile.name)}\n'
        'Exec=$exec\nIcon=${value(applicationIcon ?? iconPath(profile.id))}\nTerminal=false\nCategories=Utility;\n'
        '${app.wmClass.isEmpty ? '' : 'StartupWMClass=${value(app.wmClass)}\n'}';
  }

  @override
  Future<void> create(Application application, Profile profile) async {
    final file = File(filePath(profile.id));
    await file.parent.create(recursive: true);
    final image = File(iconPath(profile.id));
    await image.parent.create(recursive: true);
    final staging = await image.parent.createTemp('.atyaf-icon-');
    try {
      final fallback = File(p.join(staging.path, 'fallback.png'));
      await fallback.writeAsBytes(icon, flush: true);
      final applicationIcon = await findApplicationIcon(application);
      final result = await LinuxCommands.run('/usr/bin/python3', [
        iconHelper,
        'install',
        image.path,
        ?applicationIcon,
        fallback.path,
      ]);
      if (result.exitCode != 0) {
        throw FileSystemException(result.stderr.toString().trim(), image.path);
      }
      await file.writeAsString(render(application, profile), flush: true);
      final old = File(iconPath(profile.id, legacy: true));
      if (await old.exists()) {
        await old.delete();
      }
    } finally {
      await staging.delete(recursive: true);
    }
    await refresh();
  }

  @override
  Future<void> remove(String profileId) async {
    final file = File(filePath(profileId));
    if (await file.exists()) {
      await file.delete();
    }
    for (final legacy in [false, true]) {
      final image = File(iconPath(profileId, legacy: legacy));
      if (await image.exists()) {
        await image.delete();
      }
    }
    await refresh();
  }

  Future<String?> findApplicationIcon(Application application) async {
    final host = runtime is LinuxRuntime
        ? (runtime as LinuxRuntime).host
        : Platform.environment;
    final result = await LinuxCommands.run('/usr/bin/python3', [
      iconHelper,
      'find',
      jsonEncode({
        'executable': application.executable,
        'wmClass': application.wmClass,
        'portableRoot': application.portableRoot,
        'dataHome': runtime.dataHome,
        'home': host['HOME'],
        'dataDirs': (host['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share')
            .split(':')
            .where(p.isAbsolute)
            .toList(),
        'path': host['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
      }),
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException(result.stderr.toString().trim(), iconHelper);
    }
    final name = result.stdout.toString().trim();
    return name.isNotEmpty ? name : null;
  }

  Future<void> refresh() async {
    try {
      await LinuxCommands.run('update-desktop-database', [
        p.join(runtime.dataHome, 'applications'),
      ]);
    } on ProcessException {
      /* Desktop environments can discover entries without this optional cache tool. */
    }
  }
}
