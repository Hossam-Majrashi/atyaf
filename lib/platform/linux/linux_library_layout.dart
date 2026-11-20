import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/models/library_models.dart';
import 'linux_commands.dart';
import 'linux_repository.dart';
import 'linux_runtime.dart';

/// Change the directory name, not the Linux application/Flatpak identity.
final class LinuxLibraryLayout {
  static const helper = r'''
import fcntl,os,stat,sys
base=sys.argv[1]
old=os.path.join(base,'com.h.atyaf')
new=os.path.join(base,'atyaf')
os.makedirs(base,mode=0o700,exist_ok=True)
def owned_directory(path):
    info=os.lstat(path)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise ValueError('Unsafe library directory: '+path)
owned_directory(base)
lock=os.open(os.path.join(base,'.atyaf-layout.lock'),os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW,0o600)
try:
    info=os.fstat(lock)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise ValueError('Unsafe layout lock')
    fcntl.flock(lock,fcntl.LOCK_EX)
    def rename_library():
        # An intent marker permits recovery if interrupted between rename/link.
        marker=os.path.join(old,'.legacy-layout')
        fd=os.open(marker,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600) if not os.path.lexists(marker) else None
        if fd is not None: os.close(fd)
        os.rename(old,new)
        try: os.symlink('atyaf',old)
        except BaseException:
            os.rename(new,old)
            raise
    if os.path.lexists(new):
        owned_directory(new)
        if os.path.lexists(os.path.join(new,'.legacy-layout')) and not os.path.lexists(old):
            os.symlink('atyaf',old)
        print('atyaf')
    elif not os.path.lexists(old):
        os.mkdir(new,0o700)
        print('atyaf')
    else:
        owned_directory(old)
        # Do not rename SQLite/WAL files under a live old supervisor or GUI.
        # Retry automatically on a later start, after the old version closes.
        database=os.path.join(old,'library.sqlite')
        busy=False
        if os.path.lexists(database):
            db=os.stat(database,follow_symlinks=False)
            if not stat.S_ISREG(db.st_mode) or db.st_uid != os.getuid() or db.st_nlink != 1 or db.st_mode & 0o022:
                raise ValueError('Unsafe library database')
            reservation=os.open(database+'.lock',os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW,0o600)
            try:
                record=os.fstat(reservation)
                if not stat.S_ISREG(record.st_mode) or record.st_uid != os.getuid() or record.st_nlink != 1 or record.st_mode & 0o022:
                    raise ValueError('Unsafe library reservation')
                try: fcntl.lockf(reservation,fcntl.LOCK_EX|fcntl.LOCK_NB)
                except BlockingIOError: busy=True
                for process in os.scandir('/proc'):
                    if busy: break
                    if not process.name.isdigit(): continue
                    try:
                        if process.stat().st_uid != os.getuid(): continue
                        for fd in os.scandir(process.path+'/fd'):
                            try: opened=fd.stat()
                            except FileNotFoundError: continue
                            if (opened.st_dev,opened.st_ino) == (db.st_dev,db.st_ino):
                                busy=True
                                break
                    # Nondumpable unrelated host processes can hide their FDs.
                    # Ordinary Atyaf/SQLite supervisors expose theirs to the UID.
                    except (FileNotFoundError,ProcessLookupError,PermissionError): pass
                if not busy: rename_library()
            finally: os.close(reservation)
        else:
            rename_library()
        print('com.h.atyaf' if busy else 'atyaf')
finally: os.close(lock)
''';

  static Future<LinuxRuntime> prepare(Map<String, String>? environment) async {
    final runtime = LinuxRuntime(environment: environment);
    final result = await LinuxCommands.run('/usr/bin/python3', [
      '-c',
      helper,
      runtime.dataHome,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException(result.stderr.toString(), runtime.dataHome);
    }
    return result.stdout.toString().trim() == 'com.h.atyaf'
        ? LinuxRuntime(environment: environment, legacyStorage: true)
        : runtime;
  }

  static Future<void> finish(
    LinuxRuntime runtime,
    LinuxRepository repository,
  ) => repository.withExclusiveLock(() async {
    if (runtime.hasLegacyAlias) {
      final old = p.join(runtime.dataHome, 'com.h.atyaf');
      String relocate(String path) => p.equals(old, path)
          ? runtime.root
          : p.isWithin(old, path)
          ? p.join(runtime.root, p.relative(path, from: old))
          : path;
      // Relocate managed absolute paths only, never arbitrary string contents
      // or external paths. The link preserves references inside application data.
      repository.db.execute('BEGIN IMMEDIATE');
      try {
        for (final app in repository.applications) {
          final executable = relocate(app.executable);
          final portable = app.portableRoot == null
              ? null
              : relocate(app.portableRoot!);
          if (executable != app.executable || portable != app.portableRoot) {
            repository.saveApplication(
              Application.fromJson({
                ...app.toJson(),
                'executable': executable,
                'portableRoot': portable,
              }),
            );
          }
        }
        for (final profile in repository.profiles) {
          final relocatedProfile = Profile.fromJson({
            ...profile.toJson(),
            'workingDirectory': relocate(profile.workingDirectory),
            'paths': {
              for (final entry in profile.paths.entries)
                entry.key: relocate(entry.value),
            },
            'arguments': profile.arguments.map(relocate).toList(),
            'environment': {
              for (final entry in profile.environment.entries)
                entry.key: relocate(entry.value),
            },
          });
          if (jsonEncode(relocatedProfile.toJson()) !=
              jsonEncode(profile.toJson())) {
            repository.saveProfile(relocatedProfile);
          }
          for (final record in repository.history(profile.id)) {
            final changed = Map<String, dynamic>.of(record);
            for (final key in ['stdout', 'stderr', 'executable']) {
              if (record[key] is String) {
                changed[key] = relocate(record[key] as String);
              }
            }
            if ([
              'stdout',
              'stderr',
              'executable',
            ].any((key) => changed[key] != record[key])) {
              repository.recordLaunch(changed);
            }
          }
        }
        repository.db.execute('COMMIT');
      } catch (_) {
        repository.db.execute('ROLLBACK');
        rethrow;
      }
    }
    await runtime.cleanupEmptyApplicationDirectories();
  });
}
