import 'dart:convert';

import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/screens/desktop/profile_editor.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = Profile(
    id: 'profile',
    applicationId: 'app',
    name: 'Work',
    arguments: ['--password-store=gnome-libsecret', '--keep'],
    environment: {'GDK_BACKEND': 'wayland', 'KEEP': 'unchanged'},
    paths: {'data': '/custom/data', 'config': '/custom/config'},
    workingDirectory: '/custom/work',
    trustedFingerprint: 'approval',
  );
  for (final language in ['en', 'ar']) {
    for (final confirmed in [false, true]) {
      testWidgets(
        'GTK X11 helper $language ${confirmed ? 'confirmation' : 'cancellation'} changes only the explicit backend and requires Save',
        (tester) async {
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = lookupAppLocalizations(Locale(language));
          Profile? saved;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ProfileEditor(
                applicationId: 'app',
                profile: original,
                hasX11Display: true,
                saveProfile: (profile) async {
                  saved = profile;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l.windowControlsHelp), findsOneWidget);
          await tester.ensureVisible(find.text(l.useX11WindowControls));
          await tester.tap(find.text(l.useX11WindowControls));
          await tester.pumpAndSettle();
          expect(find.text(l.x11WindowControlsConfirm), findsOneWidget);
          await tester.tap(find.text(confirmed ? l.next : l.cancel).last);
          await tester.pumpAndSettle();
          expect(saved, isNull);
          await tester.tap(find.text(l.save));
          await tester.pumpAndSettle();
          expect(saved?.environment, {
            ...original.environment,
            'GDK_BACKEND': confirmed ? 'x11' : 'wayland',
          });
          final expected = original.toJson();
          expected['paths'] = {
            ...original.paths,
            'cache': '',
            'state': '',
            'temp': '',
            'home': '',
          };
          expected['environment'] = {
            ...original.environment,
            'GDK_BACKEND': confirmed ? 'x11' : 'wayland',
          };
          expect(saved?.toJson(), expected);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'GTK X11 helper is disabled without a host display and invalid environment JSON is never overwritten',
    (tester) async {
      Future<void> show(bool available) => tester.pumpWidget(
        MaterialApp(
          key: ValueKey(available),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileEditor(
            applicationId: 'app',
            profile: original,
            hasX11Display: available,
            saveProfile: (_) async {},
          ),
        ),
      );
      await show(false);
      await tester.pumpAndSettle();
      final label = find.text('GTK: try X11 window controls');
      final button = find
          .ancestor(
            of: label,
            matching: find.byWidgetPredicate(
              (widget) => widget is OutlinedButton,
            ),
          )
          .first;
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        find.byTooltip(
          'This option requires a host DISPLAY for an X11 or XWayland session.',
        ),
        findsOneWidget,
      );
      await show(true);
      await tester.pumpAndSettle();
      // Locate the environment editor by its original data, not label wording.
      final environment = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == jsonEncode(original.environment),
      );
      expect(environment, findsOneWidget);
      await tester.enterText(environment, 'invalid JSON');
      await tester.ensureVisible(label);
      await tester.tap(label);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.controller?.text == 'invalid JSON',
              ),
            )
            .controller!
            .text,
        'invalid JSON',
      );
      expect(
        find.textContaining('Enter a name and valid JSON'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
