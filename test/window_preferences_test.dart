import 'dart:io';

import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/platform/linux/linux_window_preferences.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

const schema = 'org.gnome.desktop.wm.preferences';
const layout = 'icon:minimize,maximize,close';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  final prepared = <String>{};
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-window-prefs-');
    runtime = LinuxRuntime(
      environment:
          {
              ...Platform.environment,
              'HOME': temporary.path,
              'XDG_CONFIG_HOME': '${temporary.path}/host-config',
              'XDG_DATA_HOME': '${temporary.path}/host-data',
              'GSETTINGS_BACKEND': 'keyfile',
            }
            ..remove('GSETTINGS_SCHEMA_DIR')
            ..remove('DCONF_PROFILE'),
    );
    await Directory(runtime.root).create(recursive: true);
    final result = await Process.run(
      '/usr/bin/gsettings',
      ['set', schema, 'button-layout', layout],
      environment: runtime.host,
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    prepared.clear();
  });
  tearDown(() async {
    for (final id in prepared) {
      await runtime.cleanupTemporary(id);
    }
    await temporary.delete(recursive: true);
  });
  Future<void> prepare(Profile profile) async {
    prepared.add(profile.id);
    await runtime.prepare(profile);
  }

  Future<String> get(Map<String, String> env, String key) async {
    final result = await Process.run(
      '/usr/bin/gsettings',
      ['get', schema, key],
      environment: env,
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return result.stdout.toString().trim();
  }

  Future<String> defaults(Map<String, String> env) async {
    final result = await Process.run(
      '/usr/bin/gsettings',
      ['list-recursively', schema],
      environment: {...env, 'GSETTINGS_BACKEND': 'memory'},
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return result.stdout
        .toString()
        .split('\n')
        .where((line) => !line.startsWith('$schema button-layout '))
        .join('\n');
  }

  test('Host button layout becomes a local default; all other schema keys, paths, Wayland, arguments and records are preserved', () async {
    const profile = Profile(
      id: 'editor',
      applicationId: 'app',
      name: 'Editor',
      arguments: ['--keep'],
      environment: {'TOKEN': 'untouched'},
    );
    final before = runtime.environmentFor(profile);
    final original = profile.toJson();
    final originalDefaults = await defaults(before);
    final host = Map.of(runtime.host);
    expect(await get(before, 'button-layout'), isNot("'$layout'"));
    await prepare(profile);
    final after = runtime.environmentFor(profile);
    expect(after, {
      ...before,
      'GSETTINGS_SCHEMA_DIR':
          '${runtime.profileRoot(profile.id)}/window-controls',
    });
    expect(await get(after, 'button-layout'), "'$layout'");
    expect(await defaults(after), originalDefaults);
    expect(
      await get(after, 'focus-mode'),
      "'click'",
    ); // Enum declarations survive.
    expect(profile.toJson(), original);
    expect(runtime.argumentsFor(profile), profile.arguments);
    expect(runtime.host, host);
    expect(await get(host, 'button-layout'), "'$layout'");
    final files = await Directory(after['GSETTINGS_SCHEMA_DIR']!)
        .list()
        .toList();
    expect(files.map((f) => f.path.split('/').last).toSet(), {
      'gschemas.compiled',
      'fingerprint',
    });
    for (final file in files) {
      expect((await file.stat()).mode & 0x1ff, 0x180);
    }
  });

  test('Compiled distribution overrides, not just shipped XML defaults, remain identical', () async {
    final data = '${temporary.path}/vendor-data';
    final directory = await Directory('$data/glib-2.0/schemas')
        .create(recursive: true);
    for (final name in ['$schema.gschema.xml', 'org.gnome.desktop.enums.xml']) {
      await File('/usr/share/glib-2.0/schemas/$name')
          .copy('${directory.path}/$name');
    }
    await File('${directory.path}/90-fixture.gschema.override').writeAsString(
      "[$schema]\ntitlebar-font='Fixture Bold 23'\nfocus-mode='sloppy'\n",
    );
    final compiled = await Process.run('/usr/bin/glib-compile-schemas', [
      '--strict',
      directory.path,
    ]);
    expect(compiled.exitCode, 0, reason: compiled.stderr.toString());
    runtime = LinuxRuntime(
      environment: {...runtime.host, 'XDG_DATA_DIRS': '$data:/usr/share'},
    );
    const profile = Profile(id: 'vendor', applicationId: 'app', name: 'Vendor');
    final before = await defaults(runtime.environmentFor(profile));
    expect(
      await get(runtime.environmentFor(profile), 'titlebar-font'),
      "'Fixture Bold 23'",
    );
    await prepare(profile);
    expect(await defaults(runtime.environmentFor(profile)), before);
    expect(
      await get(runtime.environmentFor(profile), 'button-layout'),
      "'$layout'",
    );
  });

  test('Explicit backend values and editor settings remain unchanged, without copying the host database or credentials', () async {
    const profile = Profile(
      id: 'existing',
      applicationId: 'app',
      name: 'Existing',
    );
    final config = runtime.resolvedPaths(profile)['config']!;
    final own = File('$config/Code/User/settings.json');
    await own.parent.create(recursive: true);
    const contents = '{"window.titleBarStyle":"custom","private":"keep"}';
    await own.writeAsString(contents);
    final set = await Process.run(
      '/usr/bin/gsettings',
      ['set', schema, 'button-layout', ':close'],
      environment: runtime.environmentFor(profile),
      includeParentEnvironment: false,
    );
    expect(set.exitCode, 0);
    final backend = File('$config/glib-2.0/settings/keyfile');
    final bytes = await backend.readAsBytes();
    await File('${runtime.configHome}/credential-sentinel')
        .writeAsString('not copied');
    await prepare(profile);
    expect(runtime.environmentFor(profile), contains('GSETTINGS_SCHEMA_DIR'));
    expect(
      await get(runtime.environmentFor(profile), 'button-layout'),
      "':close'",
    );
    expect(await backend.readAsBytes(), bytes);
    expect(await own.readAsString(), contents);
    expect(await File('$config/credential-sentinel').exists(), isFalse);
  });

  test('Cached schemas reuse unchanged bytes, repair corruption and follow host button changes on restart', () async {
    const profile = Profile(id: 'cache', applicationId: 'app', name: 'Cache');
    await prepare(profile);
    final file = File(
      '${runtime.profileRoot(profile.id)}/window-controls/gschemas.compiled',
    );
    final bytes = await file.readAsBytes();
    final modified = (await file.stat()).modified;
    await prepare(profile);
    expect((await file.stat()).modified, modified);
    expect(await file.readAsBytes(), bytes);
    await file.writeAsString('corrupt');
    await prepare(profile);
    expect(await file.readAsBytes(), bytes);
    final set = await Process.run(
      '/usr/bin/gsettings',
      ['set', schema, 'button-layout', 'close:minimize,maximize'],
      environment: runtime.host,
      includeParentEnvironment: false,
    );
    expect(set.exitCode, 0);
    await prepare(profile);
    expect(
      await get(runtime.environmentFor(profile), 'button-layout'),
      "'close:minimize,maximize'",
    );
  });

  test('Custom config/schema/backend choices and explicit GTK layout are not overridden; missing tools/schema data are optional', () async {
    final cases = [
      Profile(
        id: 'custom',
        applicationId: 'app',
        name: 'Custom',
        paths: {'config': '${temporary.path}/custom'},
      ),
      Profile(
        id: 'override',
        applicationId: 'app',
        name: 'Override',
        environment: {'XDG_CONFIG_HOME': '${temporary.path}/override'},
      ),
      const Profile(
        id: 'schema',
        applicationId: 'app',
        name: 'Schema',
        environment: {'GSETTINGS_SCHEMA_DIR': '/custom/schema'},
      ),
      const Profile(
        id: 'backend',
        applicationId: 'app',
        name: 'Backend',
        environment: {'GSETTINGS_BACKEND': 'memory'},
      ),
      const Profile(id: 'gtk', applicationId: 'app', name: 'Gtk'),
    ];
    final gtk = File(
      '${runtime.profileRoot('gtk')}/config/gtk-3.0/settings.ini',
    );
    await gtk.parent.create(recursive: true);
    const text = '[Settings]\ngtk-decoration-layout=:close\n';
    await gtk.writeAsString(text);
    for (final profile in cases) {
      final before = runtime.environmentFor(profile);
      await prepare(profile);
      expect(runtime.environmentFor(profile), before);
      expect(
        await Directory('${runtime.profileRoot(profile.id)}/window-controls')
            .exists(),
        isFalse,
      );
    }
    expect(await gtk.readAsString(), text);
    final absent = LinuxRuntime(
      environment: {
        ...runtime.host,
        'XDG_DATA_DIRS': '${temporary.path}/missing-schemas',
      },
    );
    const profile = Profile(
      id: 'missing',
      applicationId: 'app',
      name: 'Missing',
    );
    prepared.add(profile.id);
    await absent.prepare(profile);
    expect(
      absent.environmentFor(profile).containsKey('GSETTINGS_SCHEMA_DIR'),
      isFalse,
    );
  });

  test('Aliased profile/config/cache parents never write to or activate an outside schema directory', () async {
    final outside = await Directory('${temporary.path}/outside').create();
    final sentinel = File('${outside.path}/gschemas.compiled');
    await sentinel.writeAsString('keep');
    for (final id in ['config-link', 'cache-link', 'profile-link']) {
      final path = runtime.profileRoot(id);
      if (id == 'profile-link') {
        await Link(path).create(outside.path);
      } else {
        await Directory(path).create(recursive: true);
        if (id == 'config-link') {
          await Link('$path/config').create(outside.path);
        } else {
          await Directory('$path/config').create();
          await Link('$path/window-controls').create(outside.path);
        }
      }
      expect(
        await LinuxWindowPreferences.prepare(runtime.root, path, runtime.host),
        isFalse,
      );
    }
    expect(await sentinel.readAsString(), 'keep');
    expect((await outside.list().toList()).length, 1);
  });

  test('Native GTK3 on Wayland gains minimize/maximize without changing display backend', () async {
    const profile = Profile(
      id: 'wayland',
      applicationId: 'app',
      name: 'Wayland',
    );
    const probe = r'''
import ctypes
k=ctypes.CDLL('libgtk-3.so.0'); o=ctypes.CDLL('libgobject-2.0.so.0'); g=ctypes.CDLL('libglib-2.0.so.0')
k.gtk_init_check.restype=ctypes.c_int;k.gtk_settings_get_default.restype=ctypes.c_void_p
o.g_object_get.argtypes=[ctypes.c_void_p,ctypes.c_char_p];g.g_free.argtypes=[ctypes.c_void_p]
assert k.gtk_init_check(None,None)
v=ctypes.c_char_p();o.g_object_get(k.gtk_settings_get_default(),b'gtk-decoration-layout',ctypes.byref(v),None)
print(v.value.decode());g.g_free(ctypes.cast(v,ctypes.c_void_p))
''';
    Future<String> native() async {
      final result = await Process.run(
        '/usr/bin/python3',
        ['-c', probe],
        environment: {
          ...runtime.environmentFor(profile),
          'GDK_BACKEND': 'wayland',
        },
        includeParentEnvironment: false,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return result.stdout.toString().trim();
    }

    expect(await native(), isNot(contains('maximize')));
    await prepare(profile);
    expect(await native(), contains('minimize,maximize,close'));
    expect(
      runtime.environmentFor(profile)['WAYLAND_DISPLAY'],
      runtime.host['WAYLAND_DISPLAY'],
    );
    expect(
      runtime.environmentFor(profile)['GDK_BACKEND'],
      runtime.host['GDK_BACKEND'],
    );
  }, skip: Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty != true);
}
