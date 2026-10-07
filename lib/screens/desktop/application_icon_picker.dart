import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../core/l10n/app_localizations.dart';
import '../../features/desktop_entries/services/desktop_entry_service.dart';
import '../../shared/widgets/desktop_content.dart';
import 'application_icon_image.dart';

/// null cancels; an empty string explicitly restores automatic icon discovery.
class ApplicationIconPicker extends StatefulWidget {
  const ApplicationIconPicker({
    super.key,
    required this.root,
    required this.entries,
  });
  final String root;
  final DesktopEntryService entries;
  @override
  State<ApplicationIconPicker> createState() => _ApplicationIconPickerState();
}

class _ApplicationIconPickerState extends State<ApplicationIconPicker> {
  late String root = widget.root;
  List<String> images = [], filtered = [], extensions = [];
  bool busy = true;
  String? error;
  String query = '';
  int generation = 0;
  final scroll = ScrollController();
  // All paths share one virtual grid; only nearby thumbnails are decoded.
  // Keep at most eight batches (320 images), never the entire project in memory.
  static const batchSize = 40;
  final batches = <int, Future<List<String?>>>{};
  Future<void> previewQueue = Future.value();

  @override
  void initState() {
    super.initState();
    scan();
  }

  @override
  void dispose() {
    generation++;
    scroll.dispose();
    super.dispose();
  }

  void filter(String value) {
    generation++;
    batches.clear();
    query = value;
    filtered = images
        .where((path) => path.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> run(Future<void> Function() operation) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() => run(scanRoot);

  Future<void> scanRoot() async {
    generation++;
    batches.clear();
    images = [];
    filtered = [];
    if (extensions.isEmpty) extensions = await widget.entries.imageExtensions();
    final found = await widget.entries.scanImages(root);
    if (!mounted) return;
    images = found;
    filter(query);
  }

  Future<void> chooseFolder() async {
    if (busy) return;
    await run(() async {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context).chooseImageFolder,
      );
      if (selected != null && mounted) {
        root = selected;
        await scanRoot();
      }
    });
  }

  Future<void> chooseFile() async {
    if (busy) return;
    await run(() async {
      final selected = await FilePicker.platform.pickFiles(
        dialogTitle: AppLocalizations.of(context).chooseImageFile,
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        // Linux portal glob filters are case-sensitive (photo.PNG is valid).
        allowedExtensions: extensions.isEmpty
            ? null
            : [
                for (final extension in extensions) ...[
                  extension,
                  extension.toUpperCase(),
                ],
              ],
        allowMultiple: false,
        withData: false,
      );
      if (!mounted || selected == null) return;
      final path = selected.files.single.path;
      finishSelection(
        path == null ? null : await widget.entries.readImage(path),
      );
    });
  }

  void finishSelection(String? image) {
    if (!mounted) return;
    if (image == null) {
      setState(() => error = AppLocalizations.of(context).imageUnavailable);
    } else {
      Navigator.pop(context, image);
    }
  }

  Future<List<String?>> batch(int index) {
    final number = index ~/ batchSize;
    final existing = batches.remove(number);
    if (existing != null) {
      batches[number] = existing;
      return existing;
    }
    final paths = filtered.skip(number * batchSize).take(batchSize).toList();
    final requestedRoot = root, requestedGeneration = generation;
    final result = previewQueue.then((_) async {
      if (!mounted || requestedGeneration != generation) {
        return List<String?>.filled(paths.length, null);
      }
      return widget.entries.previewImages(requestedRoot, paths);
    });
    // Serialize decoding, but one failed batch must not block later images.
    previewQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    batches[number] = result;
    if (batches.length > 8) batches.remove(batches.keys.first);
    return result;
  }

  Future<void> select(String path) => run(() async {
    final result = await widget.entries.previewImages(root, [path], size: 512);
    finishSelection(result.single);
  });

  Widget imageTile(int index, AppLocalizations l) {
    final path = filtered[index];
    return FutureBuilder<List<String?>>(
      key: ValueKey('$generation:$path'),
      future: batch(index),
      builder: (context, snapshot) {
        final image = snapshot.data?[index % batchSize];
        final ready = snapshot.connectionState == ConnectionState.done;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: !busy && image != null ? () => select(path) : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: !ready
                        ? Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: l.busy,
                            ),
                          )
                        : snapshot.hasError
                        ? Tooltip(
                            message: l.error(snapshot.error.toString()),
                            child: IconButton(
                              tooltip: l.retry,
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: () => setState(
                                () => batches.remove(index ~/ batchSize),
                              ),
                            ),
                          )
                        : image == null
                        ? Tooltip(
                            message: l.imageUnavailable,
                            child: const Icon(Icons.broken_image_outlined),
                          )
                        : ApplicationIconImage(
                            encoded: image,
                            semanticLabel: path,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Tooltip(
                    message: path,
                    child: Text(
                      path,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DesktopDialog(
      title: l.chooseApplicationIcon,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, ''),
          child: Text(l.automaticIcon),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 150).floor().clamp(1, 4);
          return Scrollbar(
            controller: scroll,
            thumbVisibility: true,
            child: CustomScrollView(
              controller: scroll,
              scrollCacheExtent: const ScrollCacheExtent.pixels(200),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.applicationIconHelp),
                      const SizedBox(height: 12),
                      SelectableText(root),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Tooltip(
                            message: l.supportedImageFormats(
                              extensions.isEmpty
                                  ? l.unavailable
                                  : extensions
                                        .map((item) => item.toUpperCase())
                                        .join(', '),
                            ),
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : chooseFile,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(l.chooseImageFile),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : chooseFolder,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(l.chooseImageFolder),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: l.searchImages,
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onSubmitted: (value) => setState(() => filter(value)),
                      ),
                      const SizedBox(height: 12),
                      if (busy) LinearProgressIndicator(semanticsLabel: l.busy),
                      if (error != null) ...[
                        Text(l.error(error!)),
                        TextButton(
                          onPressed: busy ? null : scan,
                          child: Text(l.retry),
                        ),
                      ] else if (!busy && filtered.isEmpty)
                        Text(l.noProjectImages),
                      if (filtered.isNotEmpty)
                        Text(l.imageCount(filtered.length)),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                SliverGrid.builder(
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 158,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, index) => imageTile(index, l),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
