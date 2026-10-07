import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/screens/desktop/profile_editor.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final apply in [false, true]) {
      testWidgets(
        'Secret Service $language is explicitly confirmed=$apply and preserves unrelated settings',
        (tester) async {
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const profile = Profile(
            id: 'profile',
            applicationId: 'app',
            name: 'Work',
            arguments: [
              '--user-data-dir={data}',
              '--password-store=kwallet6',
              '--password-store',
              'basic',
              '--',
              '--password-store=literal-file',
            ],
            environment: {'CUSTOM': 'unchanged'},
            paths: {'data': '/custom/data'},
            trustedFingerprint: 'approved',
          );
          Profile? saved;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<Profile>(
                      context: context,
                      builder: (_) => ProfileEditor(
                        applicationId: 'app',
                        profile: profile,
                        saveProfile: (result) async {
                          saved = result;
                        },
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final use = find.text(
            language == 'en'
                ? 'Electron/Chromium: use Secret Service'
                : 'Electron/Chromium: استخدام Secret Service',
          );
          await tester.ensureVisible(use);
          await tester.tap(use);
          await tester.pumpAndSettle();
          expect(saved, isNull);
          await tester.tap(
            find
                .text(
                  apply
                      ? (language == 'en' ? 'Continue' : 'متابعة')
                      : (language == 'en' ? 'Cancel' : 'إلغاء'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          expect(saved, isNull);
          await tester.tap(find.text(language == 'en' ? 'Save' : 'حفظ'));
          await tester.pumpAndSettle();
          expect(
            saved?.arguments,
            apply
                ? [
                    '--user-data-dir={data}',
                    '--password-store=gnome-libsecret',
                    '--',
                    '--password-store=literal-file',
                  ]
                : profile.arguments,
          );
          expect(saved?.environment, profile.environment);
          expect(saved?.paths['data'], '/custom/data');
          expect(saved?.trustedFingerprint, 'approved');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
