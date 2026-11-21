import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/screens/desktop/profile_editor.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets('NVIDIA PRIME is opt-in and save-only $language $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const original = Profile(
          id: 'pcsx2',
          applicationId: 'app',
          name: 'PCSX2',
          arguments: ['--example'],
          environment: {
            'CUSTOM': r'العربية $value',
            '__NV_PRIME_RENDER_OFFLOAD': '0',
            'DRI_PRIME': 'pci-0000_01_00_0',
          },
          paths: {'data': '/custom/data'},
          trustedFingerprint: 'approved',
        );
        Profile? saved;
        final l = lookupAppLocalizations(Locale(language));
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
                      profile: original,
                      saveProfile: (profile) async => saved = profile,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final env = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == l.environment,
        );
        String environmentText() =>
            tester.widget<TextField>(env).controller!.text;
        final initial = environmentText();
        final button = find.widgetWithText(OutlinedButton, l.useNvidiaPrime);
        Future<void> choose(String action) async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(
            find.descendant(
              of: dialog,
              matching: find.text(l.nvidiaPrimeConfirm),
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.descendant(of: dialog, matching: find.text(action)),
          );
          await tester.pumpAndSettle();
          expect(saved, isNull);
        }

        await choose(l.cancel);
        expect(environmentText(), initial);
        await tester.ensureVisible(env);
        await tester.enterText(env, '{"CUSTOM":7}');
        await choose(l.next);
        expect(environmentText(), '{"CUSTOM":7}');
        expect(find.text(l.invalidInput), findsOneWidget);
        await tester.ensureVisible(env);
        await tester.enterText(env, initial);
        await choose(l.next);
        final applied = environmentText();
        await choose(l.next);
        expect(environmentText(), applied);
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(saved?.environment, {
          ...original.environment,
          '__NV_PRIME_RENDER_OFFLOAD': '1',
          '__GLX_VENDOR_LIBRARY_NAME': 'nvidia',
        });
        expect(saved?.arguments, original.arguments);
        expect(saved?.paths, containsPair('data', '/custom/data'));
        expect(saved?.trustedFingerprint, original.trustedFingerprint);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
