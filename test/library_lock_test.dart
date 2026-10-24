import 'dart:async';
import 'dart:io';

import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/shared/services/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/library_lock_holder.dart';

void main() {
  late Directory temporary;
  late LinuxRepository repository;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-lock العربية-');
    repository = LinuxRepository('${temporary.path}/library.sqlite');
  });
  tearDown(() async {
    repository.close();
    await temporary.delete(recursive: true);
  });

  test(
    'external EAGAIN waits asynchronously and executes only once after release',
    () async {
      final holder = await holdLock('${repository.path}.lock');
      var calls = 0;
      final pending = repository.withExclusiveLock(() async => ++calls);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(calls, 0);
      } finally {
        await releaseLock(holder);
      }
      expect(await pending, 1);
      expect(calls, 1);
      expect(repository.locked, isFalse);
      expect(await File('${repository.path}.lock').exists(), isTrue);
    },
  );

  test(
    'bounded contention does not execute and is reusable after timeout',
    () async {
      final bounded = LinuxRepository(
        repository.path,
        lockTimeout: const Duration(milliseconds: 100),
      );
      final holder = await holdLock('${repository.path}.lock');
      var calls = 0;
      final elapsed = Stopwatch()..start();
      try {
        await expectLater(
          bounded.withExclusiveLock(() async => ++calls),
          throwsA(isA<LibraryBusy>()),
        );
        expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
        expect(calls, 0);
        expect(bounded.locked, isFalse);
      } finally {
        await releaseLock(holder);
      }
      try {
        expect(await bounded.withExclusiveLock(() async => ++calls), 1);
      } finally {
        bounded.close();
      }
    },
  );

  test(
    'connections and directory aliases serialize within one process',
    () async {
      final alias = Link('${temporary.path}/alias');
      await alias.create(temporary.path);
      final other = LinuxRepository('${alias.path}/library.sqlite');
      final entered = Completer<void>();
      final release = Completer<void>();
      final order = <String>[];
      final first = repository.withExclusiveLock(() async {
        order.add('first');
        entered.complete();
        await release.future;
        order.add('released');
      });
      await entered.future;
      final second = other.withExclusiveLock(() async => order.add('second'));
      try {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(order, ['first']);
      } finally {
        release.complete();
        await first;
        await second;
        other.close();
      }
      expect(order, ['first', 'released', 'second']);
    },
  );

  test(
    'reentry fails without deadlock; operation errors are never retried',
    () async {
      var calls = 0;
      await expectLater(
        repository.withExclusiveLock(() async {
          calls++;
          await repository.withExclusiveLock(
            () async => fail('nested operation'),
          );
        }),
        throwsA(isA<LibraryBusy>()),
      );
      expect(calls, 1);
      final failure = FileSystemException(
        'operation, not acquisition',
        '',
        const OSError('busy', 11),
      );
      await expectLater(
        repository.withExclusiveLock(() async {
          calls++;
          throw failure;
        }),
        throwsA(same(failure)),
      );
      expect(calls, 2);
      expect(
        await repository.withExclusiveLock(() async => 'reusable'),
        'reusable',
      );
    },
  );

  test(
    'non-contention filesystem errors propagate and leave the gate reusable',
    () async {
      await Directory('${repository.path}.lock').create();
      var calls = 0;
      await expectLater(
        repository.withExclusiveLock(() async => ++calls),
        throwsA(isA<FileSystemException>()),
      );
      expect(calls, 0);
      await Directory('${repository.path}.lock').delete();
      expect(await repository.withExclusiveLock(() async => ++calls), 1);
    },
  );
}
