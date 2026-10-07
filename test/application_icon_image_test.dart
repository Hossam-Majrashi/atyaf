import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:atyaf/screens/desktop/application_icon_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String first, second;
  setUpAll(() async {
    first = base64Encode(await File('assets/icon/icon-64.png').readAsBytes());
    second = base64Encode(await File('assets/icon/icon-128.png').readAsBytes());
  });

  ui.Image? frame(WidgetTester tester) =>
      tester.widget<RawImage>(find.byType(RawImage)).image;

  Future<void> waitForFrame(WidgetTester tester) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
      if (frame(tester) != null) return;
    }
    fail('Icon frame did not load');
  }

  testWidgets(
    'Unchanged PNG retains its provider and displayed frame across parent, theme, size and semantics rebuilds',
    (tester) async {
      Widget view(String encoded, int revision) => MaterialApp(
        theme: revision.isEven ? ThemeData.light() : ThemeData.dark(),
        home: Scaffold(
          body: ApplicationIconImage(
            encoded: encoded,
            width: revision.isEven ? 36 : 64,
            height: revision.isEven ? 36 : 64,
            semanticLabel: 'logo-$revision',
          ),
        ),
      );
      await tester.pumpWidget(view(first, 0));
      await waitForFrame(tester);
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final original = frame(tester);
      for (var revision = 1; revision <= 12; revision++) {
        // Equal content arriving in freshly decoded JSON is not a new icon.
        await tester.pumpWidget(
          view(utf8.decode(utf8.encode(first)), revision),
        );
        expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
        expect(frame(tester), same(original));
        expect(
          tester.widget<Image>(find.byType(Image)).semanticLabel,
          'logo-$revision',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Changed PNG replaces the provider; invalid content shows a bounded fallback instead of the old icon',
    (tester) async {
      Widget view(String encoded) => MaterialApp(
        home: Scaffold(
          body: ApplicationIconImage(encoded: encoded, width: 64, height: 64),
        ),
      );
      await tester.pumpWidget(view(first));
      await waitForFrame(tester);
      final originalProvider = tester.widget<Image>(find.byType(Image)).image;
      final originalFrame = frame(tester);
      await tester.pumpWidget(view(second));
      final replacement = tester.widget<Image>(find.byType(Image));
      expect(replacement.image, isNot(same(originalProvider)));
      expect((replacement.image as MemoryImage).bytes, base64Decode(second));
      expect(replacement.gaplessPlayback, isFalse);
      await waitForFrame(tester);
      expect(frame(tester), isNot(same(originalFrame)));
      await tester.pumpWidget(view('invalid base64!'));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(
        tester.getSize(find.byType(ApplicationIconImage)),
        const Size(64, 64),
      );
      await tester.pumpWidget(view(base64Encode(utf8.encode('not a PNG'))));
      for (
        var attempt = 0;
        attempt < 100 &&
            find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(
        tester.getSize(find.byType(ApplicationIconImage)),
        const Size(64, 64),
      );
      await tester.pumpWidget(view(first));
      await waitForFrame(tester);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
