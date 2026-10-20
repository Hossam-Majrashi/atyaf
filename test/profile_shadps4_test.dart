import 'dart:convert';

import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/screens/desktop/profile_editor.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      for (final apply in [false, true]) {
        testWidgets('shadPS4 $language $size confirmed=$apply, Save only', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const profile = Profile(
            id: 'profile',
            applicationId: 'app',
            name: 'Shadps4',
            arguments: [
              '--game',
              '/games/لعبة with spaces/eboot.bin',
              '-b',
              '--big-picture',
              '--',
              '-b',
            ],
            environment: {'CUSTOM': 'unchanged'},
            workingDirectory: '/custom/work',
            paths: {'data': '/custom/data'},
            trustedFingerprint: 'approved',
          );
          Profile? saved;
          late AppLocalizations l;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  l = AppLocalizations.of(context);
                  return Scaffold(
                    body: TextButton(
                      onPressed: () => showDialog<Profile>(
                        context: context,
                        builder: (_) => ProfileEditor(
                          applicationId: 'app',
                          profile: profile,
                          saveProfile: (result) async => saved = result,
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final use = find.text(l.useShadps4BigPicture);
          // Reapplying is idempotent, and nothing persists until Save.
          for (var i = 0; i < 2; i++) {
            await tester.ensureVisible(use);
            await tester.tap(use);
            await tester.pumpAndSettle();
            expect(find.text(l.shadps4BigPictureConfirm), findsOneWidget);
            expect(saved, isNull);
            await tester.tap(find.text(apply ? l.next : l.cancel).last);
            await tester.pumpAndSettle();
            expect(saved, isNull);
          }
          await tester.tap(find.text(l.save));
          await tester.pumpAndSettle();
          expect(
            saved?.arguments,
            apply
                ? [
                    '--game',
                    '/games/لعبة with spaces/eboot.bin',
                    '--big-picture',
                    '--',
                    '-b',
                  ]
                : profile.arguments,
          );
          expect(saved?.environment, profile.environment);
          expect(saved?.paths['data'], '/custom/data');
          expect(saved?.workingDirectory, profile.workingDirectory);
          expect(saved?.trustedFingerprint, 'approved');
          expect(saved?.id, profile.id);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('shadPS4 rejects invalid argument JSON and supports empty args', (
    tester,
  ) async {
    late AppLocalizations l;
    Profile? saved;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l = AppLocalizations.of(context);
            return Scaffold(
              body: TextButton(
                onPressed: () => showDialog<Profile>(
                  context: context,
                  builder: (_) => ProfileEditor(
                    applicationId: 'app',
                    profile: const Profile(
                      id: 'profile',
                      applicationId: 'app',
                      name: 'Shadps4',
                    ),
                    saveProfile: (p) async => saved = p,
                  ),
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final args = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == l.arguments,
    );
    for (final invalid in ['not JSON', '{}', '[1]']) {
      await tester.enterText(args, invalid);
      await tester.ensureVisible(find.text(l.useShadps4BigPicture));
      await tester.tap(find.text(l.useShadps4BigPicture));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.next));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(args).controller!.text, invalid);
      expect(find.text(l.invalidInput), findsOneWidget);
      expect(saved, isNull);
    }
    await tester.enterText(args, '[]');
    await tester.ensureVisible(find.text(l.useShadps4BigPicture));
    await tester.tap(find.text(l.useShadps4BigPicture));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.next));
    await tester.pumpAndSettle();
    expect(jsonDecode(tester.widget<TextField>(args).controller!.text), [
      '--big-picture',
    ]);
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(saved?.arguments, ['--big-picture']);
    expect(tester.takeException(), isNull);
  });
}
