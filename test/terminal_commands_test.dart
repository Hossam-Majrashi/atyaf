import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/desktop_entries/services/terminal_command_service.dart';
import 'package:atyaf/features/home/services/library_controller.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/platform/linux/linux_terminal_commands.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxTerminalCommands commands;
  late File launcher, output;
  String getBin() => '${temporary.path}/.local/bin';
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'atyaf commands العربية " % ',
    );
    runtime = LinuxRuntime(
      environment: {
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/library data',
        'PATH': '${getBin()}:/usr/bin:/bin',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    output = File('${temporary.path}/invocation.json');
    launcher = File('${temporary.path}/launcher " dollar\$ percent%.py');
    await launcher.writeAsString(
      '#!/usr/bin/python3\nimport sys,json,os\n'
      'open(${jsonEncode(output.path)},"w").write(json.dumps({"args":sys.argv[1:],"home":os.environ["HOME"],"data":os.environ["XDG_DATA_HOME"]}))\n',
    );
    await Process.run('chmod', ['700', launcher.path]);
    commands = LinuxTerminalCommands(runtime, launcher.path);
  });
  tearDown(() async => temporary.delete(recursive: true));
  Future<TerminalCommand> create(String id, String name) =>
      commands.createTerminalCommand(
        id,
        name,
        argumentsWarning: 'Use saved profile arguments العربية.',
      );
  Matcher failure(String code) => throwsA(
    isA<TerminalCommandFailure>().having((e) => e.code, 'code', code),
  );

  test('Terminal name invokes exact Atyaf profile ID with quoted paths and pinned library, not an external application', () async {
    final command = await create('profile-work', 'rpcs3');
    expect(command.name, 'rpcs3');
    expect(command.path, '${getBin()}/rpcs3');
    expect(command.inPath, isTrue);
    expect((await File(command.path).stat()).mode & 0x1ff, 0x1c0);
    final result = await Process.run(
      '/usr/bin/env',
      ['rpcs3'],
      environment: {
        ...Platform.environment,
        'PATH': '${getBin()}:/usr/bin:/bin',
        'HOME': '/wrong/home',
        'XDG_DATA_HOME': '/wrong/library',
      },
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(jsonDecode(await output.readAsString()), {
      'args': ['--launch-profile', 'profile-work'],
      'home': temporary.path,
      'data': runtime.dataHome,
    });
    expect(
      await File('${runtime.root}/terminal-commands.json')
          .stat()
          .then((s) => s.mode & 0x1ff),
      0x180,
    );
  });

  test('Extra CLI arguments are explicitly refused without invoking Atyaf or overriding profiles', () async {
    final command = await create('one', 'rpcs3');
    final result = await Process.run(command.path, [
      '--launch-profile',
      'other',
    ]);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Use saved profile arguments العربية.'));
    expect(await output.exists(), isFalse);
  });

  test('Separate accounts get separate commands; refresh and removal preserve unrelated aliases and files', () async {
    await create('work', 'rpcs3-work');
    await create('personal', 'rpcs3');
    await create('work', 'ps3-work');
    await create('work', 'rpcs3-work');
    expect((await commands.terminalCommands('work')).map((c) => c.name), [
      'ps3-work',
      'rpcs3-work',
    ]);
    await expectLater(create('personal', 'rpcs3-work'), failure('conflict'));
    final unrelated = await File('${getBin()}/external').writeAsString('keep');
    expect(await commands.removeTerminalCommands('work'), isEmpty);
    expect(await File('${getBin()}/rpcs3-work').exists(), isFalse);
    expect(await File('${getBin()}/ps3-work').exists(), isFalse);
    expect(await File('${getBin()}/rpcs3').exists(), isTrue);
    expect(await unrelated.readAsString(), 'keep');
    expect((await commands.terminalCommands('personal')).single.name, 'rpcs3');
  });

  test('Existing local files, links and all PATH matches are preserved, never overwritten or shadowed', () async {
    await Directory(getBin()).create(recursive: true);
    final external = await File('${getBin()}/rpcs3').writeAsString('external');
    await expectLater(create('one', 'rpcs3'), failure('conflict'));
    expect(await external.readAsString(), 'external');
    await external.delete();
    await Link(external.path).create(launcher.path);
    await expectLater(create('one', 'rpcs3'), failure('conflict'));
    expect(await Link(external.path).target(), launcher.path);
    await expectLater(create('one', 'python3'), failure('conflict'));
    expect(await File('${getBin()}/python3').exists(), isFalse);
  });

  test('Invalid names, built-ins and shell injection are rejected before writing launchers', () async {
    for (final name in [
      '',
      '../rpcs3',
      '/tmp/rpcs3',
      '3rpcs',
      'a b',
      'a;touch',
      'UPPER',
      'أمر',
      'cd',
      'exit',
      'atyaf',
      'a' * 65,
    ]) {
      await expectLater(create('one', name), failure('invalid'));
    }
    expect(await Directory(getBin()).exists(), isFalse);
  });

  test('Modified wrappers are not overwritten or deleted; removal forgets ownership', () async {
    final command = await create('one', 'rpcs3');
    await File(command.path).writeAsString('user changed this file');
    await expectLater(create('one', 'rpcs3'), failure('conflict'));
    expect(await commands.removeTerminalCommands('one'), ['rpcs3']);
    expect(await File(command.path).readAsString(), 'user changed this file');
    expect(await commands.terminalCommands('one'), isEmpty);
    await expectLater(create('one', 'rpcs3'), failure('conflict'));
  });

  test('Symlinked bin parents and registries are refused without touching outside files', () async {
    final outside = await Directory('${temporary.path}/outside').create();
    await Directory('${temporary.path}/.local').create();
    await Link(getBin()).create(outside.path);
    await expectLater(create('one', 'rpcs3'), failure('unsafe'));
    expect(await outside.list().toList(), isEmpty);
    await Link(getBin()).delete();
    final registry = File('${runtime.root}/terminal-commands.json');
    final target = await File('${outside.path}/data.json').writeAsString('{}');
    await Link(registry.path).create(target.path);
    await expectLater(create('one', 'rpcs3'), failure('unsafe'));
    expect(await target.readAsString(), '{}');
  });

  test(
    'Missing PATH is reported; no shell configuration is created or modified',
    () async {
      final noPath = LinuxRuntime(
        environment: {
          'HOME': temporary.path,
          'XDG_DATA_HOME': runtime.dataHome,
          'PATH': '/usr/bin:/bin',
        },
      );
      final service = LinuxTerminalCommands(noPath, launcher.path);
      final command = await service.createTerminalCommand(
        'one',
        'rpcs3',
        argumentsWarning: 'configured arguments only',
      );
      expect(command.inPath, isFalse);
      for (final name in ['.bashrc', '.zshrc', '.profile']) {
        expect(await File('${temporary.path}/$name').exists(), isFalse);
      }
    },
  );

  test('Concurrent competing profiles can claim a command only once', () async {
    final result = await Future.wait([
      for (final id in ['one', 'two'])
        create(
          id,
          'rpcs3',
        ).then<Object>((value) => value, onError: (Object error) => error),
    ]);
    expect(result.whereType<TerminalCommand>().length, 1);
    expect(result.whereType<TerminalCommandFailure>().single.code, 'conflict');
  });

  test('Deleting profiles and restoring backups remove commands, not profile settings on creation', () async {
    final repository = LinuxRepository('${runtime.root}/library.sqlite');
    final processes = LinuxProcesses(runtime, repository);
    final archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    final entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: launcher.path,
    );
    final backup = LinuxBackup(
      runtime,
      repository,
      archives,
      processes,
      terminalCommands: entries,
    );
    final library = LibraryController(
      repository: repository,
      runtime: runtime,
      processes: processes,
      archives: archives,
      entries: entries,
      backup: backup,
      storage: LinuxManagedStorage(runtime, archives),
    );
    try {
      const app = Application(
        id: 'app',
        name: 'RPCS3',
        executable: '/usr/bin/true',
      );
      const profile = Profile(
        id: 'one',
        applicationId: 'app',
        name: 'RPCS3',
        arguments: ['a b'],
        environment: {'KEEP': 'unchanged'},
      );
      repository.saveApplication(app);
      repository.saveProfile(profile);
      await runtime.prepare(profile);
      await create('one', 'rpcs3');
      expect(repository.profiles.single.toJson(), profile.toJson());
      final destination = '${temporary.path}/backup.tar.gz';
      await backup.export(destination);
      await backup.restore(destination);
      expect(await File('${getBin()}/rpcs3').exists(), isFalse);
      expect(await commands.terminalCommands('one'), isEmpty);
      await create('one', 'rpcs3');
      await library.deleteProfile(repository.profiles.single);
      expect(await File('${getBin()}/rpcs3').exists(), isFalse);
      expect(repository.profiles, isEmpty);
      expect(repository.applications.single.toJson(), app.toJson());
    } finally {
      library.dispose();
      repository.close();
    }
  });
}
