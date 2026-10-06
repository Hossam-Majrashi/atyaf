import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../features/logs/services/log_service.dart';

class ReportActions extends StatefulWidget {
  const ReportActions({
    super.key,
    required this.library,
    required this.buildReport,
    this.fileName = 'atyaf-errors.txt',
  });
  final LibraryController library;
  final Future<List<ReportSection>> Function() buildReport;
  final String fileName;
  @override
  State<ReportActions> createState() => _ReportActionsState();
}

class _ReportActionsState extends State<ReportActions> {
  bool busy = false;
  Future<void> transfer(bool export) async {
    if (busy) return;
    final l = AppLocalizations.of(context);
    setState(() => busy = true);
    try {
      String? destination;
      if (export) {
        destination = await FilePicker.platform.saveFile(
          dialogTitle: l.exportTxt,
          fileName: widget.fileName,
          type: FileType.custom,
          allowedExtensions: ['txt'],
        );
        if (destination == null) return;
        if (!destination.toLowerCase().endsWith('.txt')) {
          destination = '$destination.txt';
        }
      }
      final sections = await widget.buildReport();
      if (destination != null) {
        await widget.library.logs.exportReport(sections, destination);
      } else {
        await Clipboard.setData(
          ClipboardData(
            text: await widget.library.logs.completeReport(sections),
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(export ? l.done : l.copied)));
      }
    } on ReportTooLarge {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.copyTooLarge)));
      }
    } catch (error, stack) {
      widget.library.reportError(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.error(error.toString()))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : () => transfer(false),
          icon: const Icon(Icons.copy_all_rounded),
          label: Text(l.copyAll),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => transfer(true),
          icon: const Icon(Icons.save_alt_rounded),
          label: Text(l.exportTxt),
        ),
        if (busy)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              semanticsLabel: l.busy,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}
