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
        testWidgets('MDM browser $language $size confirmed=$apply, Save only', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const profile = Profile(
            id: 'profile',
            applicationId: 'app',
            name: 'MDM',
            arguments: ['--custom', 'العربية with spaces'],
            environment: {'CUSTOM': 'unchanged', 'MDM_DATA_DIR': '/custom/old'},
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
          final use = find.text(l.useMisterDownloadManagerBrowser);
          for (var i = 0; i < 2; i++) {
            await tester.ensureVisible(use);
            await tester.tap(use);
            await tester.pumpAndSettle();
            expect(
              find.text(l.misterDownloadManagerBrowserConfirm),
              findsOneWidget,
            );
            expect(saved, isNull);
            final action = find.text(apply ? l.next : l.cancel).last;
            await tester.ensureVisible(action);
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(saved, isNull);
          }
          await tester.tap(find.text(l.save));
          await tester.pumpAndSettle();
          expect(saved?.environment, {
            ...profile.environment,
            if (apply) 'MDM_DATA_DIR': '{hostData}/misterdownloadmanager',
          });
          expect(saved?.arguments, profile.arguments);
          expect(saved?.paths, containsPair('data', '/custom/data'));
          expect(saved?.workingDirectory, profile.workingDirectory);
          expect(saved?.trustedFingerprint, 'approved');
          expect(saved?.id, profile.id);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'MDM helper rejects invalid environment JSON without changing it',
    (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return const Scaffold(
                body: ProfileEditor(
                  applicationId: 'app',
                  saveProfile: ignoreProfile,
                ),
              );
            },
          ),
        ),
      );
      final env = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == l.environment,
      );
      for (final invalid in ['not JSON', '[]', '{"CUSTOM":1}']) {
        await tester.ensureVisible(env);
        await tester.enterText(env, invalid);
        await tester.ensureVisible(
          find.text(l.useMisterDownloadManagerBrowser),
        );
        await tester.tap(find.text(l.useMisterDownloadManagerBrowser));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.next));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(env).controller!.text, invalid);
        expect(find.text(l.invalidInput), findsOneWidget);
      }
    },
  );
}

Future<void> ignoreProfile(Profile _) async {}
