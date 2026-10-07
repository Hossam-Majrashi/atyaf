import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atyaf/core/l10n/app_localizations.dart';
import 'package:atyaf/features/desktop_entries/services/desktop_entry_service.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/screens/desktop/application_editor.dart';
import 'package:atyaf/screens/desktop/application_icon_picker.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class GalleryEntries implements DesktopEntryService {
  GalleryEntries(this.png) : selectedImage = png;
  final String png;
  bool fail = false;
  int? selectedSize;
  int count = 42;
  final List<List<String>> previewRequests = [];
  final List<String> scans = [], readRequests = [];
  String? selectedImage;
  @override
  Future<List<String>> imageExtensions() async => [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'svg',
    'tiff',
  ];
  @override
  Future<String?> readImage(String path) async {
    readRequests.add(path);
    return selectedImage;
  }

  @override
  Future<List<String>> scanImages(String root) async {
    scans.add(root);
    if (fail) {
      throw const FileSystemException('scan failure');
    }
    return List.generate(count, (index) => 'assets/$index.png');
  }

  @override
  Future<List<String?>> previewImages(
    String root,
    List<String> paths, {
    int size = 96,
  }) async {
    selectedSize = size;
    previewRequests.add(List.of(paths));
    return paths.map((path) => path == 'assets/1.png' ? null : png).toList();
  }

  @override
  Future<void> create(Application application, Profile profile) async {}
  @override
  Future<void> remove(String profileId) async {}
  @override
  Future<void> refreshIcons(
    Application application,
    List<Profile> profiles,
  ) async {}
}

class ImageFilePicker extends FilePicker {
  FilePickerResult? response;
  Completer<FilePickerResult?>? pending;
  Object? failure;
  int fileCalls = 0, folderCalls = 0;
  FileType? requestedType;
  List<String>? extensions;
  String? title;
  bool? multiple, data;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    fileCalls++;
    title = dialogTitle;
    requestedType = type;
    extensions = allowedExtensions;
    multiple = allowMultiple;
    data = withData;
    if (failure != null) throw failure!;
    return pending != null ? await pending!.future : response;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    folderCalls++;
    return '/chosen images';
  }

  static FilePickerResult image(String path) => FilePickerResult([
    PlatformFile(name: path.split('/').last, path: path, size: 42),
  ]);
}

Finder galleryScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  late String png, initialIcon;
  late ImageFilePicker picker;
  setUp(() {
    FilePickerLinux.registerWith();
    final previous = FilePicker.platform;
    picker = ImageFilePicker();
    FilePicker.platform = picker;
    addTearDown(() => FilePicker.platform = previous);
  });
  setUpAll(() async {
    initialIcon = base64Encode(
      await File('assets/icon/icon-64.png').readAsBytes(),
    );
    final entries = LinuxDesktopEntries(
      LinuxRuntime(),
      await File('assets/icon/icon.png').readAsBytes(),
    );
    png = (await entries.previewImages(Directory('assets/icon').absolute.path, [
      'icon.png',
    ], size: 512)).single!;
  });

  for (final language in ['en', 'ar']) {
    for (final size in [
      const Size(800, 600),
      const Size(1100, 760),
      const Size(1600, 900),
    ]) {
      testWidgets(
        'Direct image choice $language $size separates folders/files, handles cancellation/errors and saves a PNG copy',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = lookupAppLocalizations(Locale(language));
          final entries = GalleryEntries(png);
          Application? saved;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      saved = await showDialog<Application>(
                        context: context,
                        builder: (_) => ApplicationEditor(
                          application: Application(
                            id: 'app',
                            name: 'Project',
                            executable: '/project/bin/main',
                            portableRoot: '/project',
                            iconPng: initialIcon,
                          ),
                          entries: entries,
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final editorImage = find.descendant(
            of: find.byType(ApplicationEditor),
            matching: find.byType(Image),
          );
          final originalProvider = tester.widget<Image>(editorImage).image;
          await tester.ensureVisible(find.text(l.chooseApplicationIcon));
          await tester.tap(find.text(l.chooseApplicationIcon));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(l.chooseImageFolder));
          await tester.tap(find.text(l.chooseImageFolder));
          await tester.pumpAndSettle();
          expect(picker.folderCalls, 1);
          expect(picker.fileCalls, 0);
          expect(entries.scans.last, '/chosen images');
          await tester.ensureVisible(find.byType(TextField).last);
          await tester.enterText(find.byType(TextField).last, '41.png');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          Future<void> chooseFile() async {
            await tester.ensureVisible(find.text(l.chooseImageFile));
            await tester.pumpAndSettle();
            await tester.tap(find.text(l.chooseImageFile));
            await tester.pumpAndSettle();
          }

          picker.failure = const FileSystemException(
            'Native image picker failed',
          );
          await chooseFile();
          expect(
            find.textContaining('Native image picker failed'),
            findsOneWidget,
          );
          picker.failure = null;
          picker.response = null;
          await chooseFile();
          expect(find.byType(ApplicationIconPicker), findsOneWidget);
          expect(find.text('/chosen images'), findsOneWidget);
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).last)
                .controller
                .text,
            '41.png',
          );
          expect(entries.readRequests, isEmpty);
          expect(saved, isNull);
          expect(
            tester.widget<Image>(editorImage).image,
            same(originalProvider),
          );
          entries.selectedImage = null;
          picker.response = ImageFilePicker.image(
            '/home/test/Pictures/broken.png',
          );
          await chooseFile();
          expect(find.textContaining(l.imageUnavailable), findsOneWidget);
          expect(find.byType(ApplicationIconPicker), findsOneWidget);
          expect(
            tester.widget<Image>(editorImage).image,
            same(originalProvider),
          );
          const path = '/home/test/Pictures/صورتي.PNG';
          entries.selectedImage = png;
          picker.response = ImageFilePicker.image(path);
          await chooseFile();
          expect(find.byType(ApplicationIconPicker), findsNothing);
          expect(entries.readRequests.last, path);
          expect(picker.requestedType, FileType.custom);
          expect(
            picker.extensions,
            containsAll([
              'png',
              'PNG',
              'svg',
              'SVG',
              'jpg',
              'jpeg',
              'gif',
              'bmp',
              'tiff',
            ]),
          );
          expect(picker.multiple, isFalse);
          expect(picker.data, isFalse);
          expect(picker.title, l.chooseImageFile);
          expect(
            (tester.widget<Image>(editorImage).image as MemoryImage).bytes,
            base64Decode(png),
          );
          await tester.tap(find.text(l.save));
          await tester.pumpAndSettle();
          expect(saved?.iconPng, png);
          expect(saved?.iconPng, isNot(initialIcon));
          expect(saved?.portableRoot, '/project');
          expect(saved?.executable, '/project/bin/main');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Gallery and editor $language $size select, scroll, search, cancel and reset',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final entries = GalleryEntries(png);
          Application? saved;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      saved = await showDialog<Application>(
                        context: context,
                        builder: (_) => ApplicationEditor(
                          application: const Application(
                            id: 'app',
                            name: 'Project',
                            executable: '/project/bin/main',
                            portableRoot: '/project',
                          ),
                          entries: entries,
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final choose = find.text(
            language == 'en'
                ? 'Choose an application icon'
                : 'اختر أيقونة البرنامج',
          );
          await tester.ensureVisible(choose);
          await tester.tap(choose);
          await tester.pumpAndSettle();
          expect(find.text('assets/0.png'), findsOneWidget);
          expect(find.text('assets/41.png'), findsNothing);
          expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
          expect(
            find.text(language == 'en' ? 'Next images' : 'الصور التالية'),
            findsNothing,
          );
          await tester.scrollUntilVisible(
            find.text('assets/41.png'),
            350,
            scrollable: galleryScrollable(),
          );
          await tester.pumpAndSettle();
          expect(find.text('assets/41.png'), findsOneWidget);
          final galleryScroll = tester.state<ScrollableState>(
            galleryScrollable(),
          );
          galleryScroll.position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TextField).last);
          await tester.enterText(find.byType(TextField).last, '41.png');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.text('assets/40.png'), findsNothing);
          await tester.ensureVisible(find.text('assets/41.png'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('assets/41.png'));
          await tester.pumpAndSettle();
          expect(entries.selectedSize, 512);
          expect(find.byType(ApplicationIconPicker), findsNothing);
          expect(find.byType(Image), findsOneWidget);
          // Canceling another gallery leaves the current icon intact.
          await tester.ensureVisible(choose);
          await tester.tap(choose);
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(language == 'en' ? 'Cancel' : 'إلغاء').last,
          );
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsOneWidget);
          // Automatic discovery can be restored without selecting another file.
          final automatic = find.text(
            language == 'en'
                ? 'Use automatic icon'
                : 'استخدام الأيقونة التلقائية',
          );
          await tester.ensureVisible(automatic);
          await tester.tap(automatic);
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsNothing);
          await tester.ensureVisible(choose);
          await tester.tap(choose);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('assets/0.png'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('assets/0.png'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(language == 'en' ? 'Save' : 'حفظ'));
          await tester.pumpAndSettle();
          expect(saved?.iconPng, png);
          expect(saved?.portableRoot, '/project');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Closing the gallery during a pending native choice ignores the late file and prevents duplicate chooser requests',
    (tester) async {
      final entries = GalleryEntries(png);
      String? result;
      picker.pending = Completer<FilePickerResult?>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => ApplicationIconPicker(
                      root: '/project',
                      entries: entries,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final button = find.text('Choose image from device');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(picker.fileCalls, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      picker.pending!.complete(ImageFilePicker.image('/home/test/logo.png'));
      await tester.pumpAndSettle();
      expect(entries.readRequests, isEmpty);
      expect(find.byType(ApplicationIconPicker), findsNothing);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Continuous gallery virtualizes 2000 images and reaches the last image without paging',
    (tester) async {
      final entries = GalleryEntries(png)..count = 2000;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ApplicationIconPicker(root: '/project', entries: entries),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('assets/1999.png'), findsNothing);
      expect(entries.previewRequests.length, lessThanOrEqualTo(2));
      final state = tester.state<ScrollableState>(galleryScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('assets/1999.png'), findsOneWidget);
      expect(find.text('assets/0.png'), findsNothing);
      expect(find.byType(Image).evaluate().length, lessThan(60));
      expect(
        entries.previewRequests.every((request) => request.length <= 40),
        isTrue,
      );
      expect(entries.previewRequests.length, lessThan(8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Gallery reports scan failures and allows retry or automatic fallback',
    (tester) async {
      final entries = GalleryEntries(png)..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ApplicationIconPicker(root: '/project', entries: entries),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('scan failure'), findsOneWidget);
      entries.fail = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('assets/0.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
