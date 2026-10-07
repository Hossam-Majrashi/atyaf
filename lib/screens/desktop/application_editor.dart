import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/models/library_models.dart';
import '../../features/desktop_entries/services/desktop_entry_service.dart';
import 'application_icon_picker.dart';
import 'application_icon_image.dart';
import '../../shared/widgets/desktop_content.dart';

class ApplicationEditor extends StatefulWidget {
  const ApplicationEditor({
    super.key,
    required this.application,
    required this.entries,
  });
  final Application application;
  final DesktopEntryService entries;
  @override
  State<ApplicationEditor> createState() => _ApplicationEditorState();
}

class _ApplicationEditorState extends State<ApplicationEditor> {
  late final name = TextEditingController(text: widget.application.name);
  late final executable = TextEditingController(
    text: widget.application.executable,
  );
  late final wmClass = TextEditingController(text: widget.application.wmClass);
  late String? iconPng = widget.application.iconPng;
  @override
  void dispose() {
    name.dispose();
    executable.dispose();
    wmClass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DesktopDialog(
      title: l.edit,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty || !executable.text.startsWith('/')) {
              return;
            }
            Navigator.pop(
              context,
              Application(
                id: widget.application.id,
                name: name.text.trim(),
                executable: executable.text,
                portableRoot: widget.application.portableRoot,
                executableRelative: widget.application.executableRelative,
                wmClass: wmClass.text.trim(),
                iconPng: iconPng,
              ),
            );
          },
          child: Text(l.save),
        ),
      ],
      children: [
        TextField(
          controller: name,
          decoration: InputDecoration(labelText: l.name),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: executable,
          readOnly: widget.application.portableRoot != null,
          decoration: InputDecoration(
            labelText: l.executable,
            suffixIcon: widget.application.portableRoot != null
                ? null
                : IconButton(
                    tooltip: l.chooseExecutable,
                    icon: const Icon(Icons.folder_open_rounded),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: l.chooseExecutable,
                      );
                      final path = result?.files.single.path;
                      if (path != null) {
                        executable.text = path;
                      }
                    },
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(l.applicationIcon, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (iconPng != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ApplicationIconImage(
              encoded: iconPng!,
              width: 64,
              height: 64,
            ),
          )
        else
          Text(l.automaticIcon),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.image_search_rounded),
              label: Text(l.chooseApplicationIcon),
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => ApplicationIconPicker(
                    root:
                        widget.application.portableRoot ??
                        p.dirname(executable.text),
                    entries: widget.entries,
                  ),
                );
                if (result != null && mounted) {
                  setState(() => iconPng = result.isEmpty ? null : result);
                }
              },
            ),
            if (iconPng != null)
              TextButton(
                onPressed: () => setState(() => iconPng = null),
                child: Text(l.automaticIcon),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: wmClass,
          decoration: InputDecoration(labelText: l.wmClass),
        ),
        const SizedBox(height: 12),
        Text(l.wmClassHelp),
      ],
    );
  }
}
