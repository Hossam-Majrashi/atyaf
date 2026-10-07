import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../features/logs/services/log_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/desktop_content.dart';
import 'diagnostic_reports.dart';
import 'report_actions.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.library, required this.profile});
  final LibraryController library;
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.logs)),
      body: DesktopContent(
        child: ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            final records = library.repository.history(profile.id);
            if (records.isEmpty) return Center(child: Text(l.noLogs));
            return ListView(
              children: [
                Text(l.reportPrivacy),
                const SizedBox(height: 16),
                ReportActions(
                  library: library,
                  fileName: 'atyaf-${profile.id}-logs.txt',
                  buildReport: () async {
                    final sections = <ReportSection>[];
                    for (final record in library.repository.history(
                      profile.id,
                    )) {
                      sections.addAll(
                        await launchReport(l, library, profile, record),
                      );
                    }
                    return sections;
                  },
                ),
                const SizedBox(height: 16),
                for (final record in records)
                  LaunchLogCard(
                    key: ValueKey(record['id']),
                    library: library,
                    profile: profile,
                    record: record,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LaunchLogCard extends StatefulWidget {
  const LaunchLogCard({
    super.key,
    required this.library,
    required this.profile,
    required this.record,
  });
  final LibraryController library;
  final Profile profile;
  final Map<String, dynamic> record;
  @override
  State<LaunchLogCard> createState() => _LaunchLogCardState();
}

class _LaunchLogCardState extends State<LaunchLogCard> {
  Future<String>? core;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final record = widget.record;
    final status = record['interrupted'] == true
        ? l.interrupted
        : record['crashed'] == true
        ? l.crashed
        : null;
    final subtitle = [widget.profile.name, ?status].join(' · ');
    String date(dynamic value) => value == null
        ? l.unavailable
        : DateFormat.yMd(l.localeName)
              .add_Hms()
              .format(DateTime.parse(value as String).toLocal());
    return Card(
      child: ExpansionTile(
        title: Text(
          l.launchRecord(
            record['pid'] as int,
            date(record['start']),
            date(record['stop']),
            record['exitCode']?.toString() ?? l.unavailable,
          ),
        ),
        subtitle: Text(subtitle),
        children: [
          if (record['interrupted'] == true)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.lostExitAdvice),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ReportActions(
              library: widget.library,
              fileName: 'atyaf-${record['id']}.txt',
              buildReport: () =>
                  launchReport(l, widget.library, widget.profile, record),
            ),
          ),
          for (final channel in ['stdout', 'stderr'])
            if (record[channel] is String)
              _LogOutput(
                key: ValueKey('${record['id']}-$channel-${record['stop']}'),
                library: widget.library,
                profileId: widget.profile.id,
                path: record[channel] as String,
                title: channel == 'stdout' ? l.stdoutLabel : l.stderrLabel,
              ),
          if (record['crashed'] == true)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => core = widget.library.logs.coreInfo(
                        crashRecord(widget.library, widget.profile, record),
                      ),
                    ),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: Text(l.loadSystemCrash),
                  ),
                  if (core != null)
                    FutureBuilder<String>(
                      future: core,
                      builder: (context, snapshot) => SelectableText(
                        snapshot.hasError
                            ? l.error(snapshot.error.toString())
                            : snapshot.data == null
                            ? l.busy
                            : snapshot.data!.isEmpty
                            ? l.noSystemCrash
                            : LogService.previewText(snapshot.data!),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LogOutput extends StatefulWidget {
  const _LogOutput({
    super.key,
    required this.library,
    required this.profileId,
    required this.path,
    required this.title,
  });
  final LibraryController library;
  final String profileId, path, title;
  @override
  State<_LogOutput> createState() => _LogOutputState();
}

class _LogOutputState extends State<_LogOutput> {
  late Future<String> preview = widget.library.logs.read(
    widget.path,
    widget.profileId,
  );
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l.refreshLog,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(
                  () => preview = widget.library.logs.read(
                    widget.path,
                    widget.profileId,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.openFullLog,
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () async {
                  try {
                    final opened = await widget.library.logs.openComplete(
                      widget.path,
                      widget.profileId,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.openFailed)));
                    }
                  } catch (error, stack) {
                    widget.library.reportError(error, stack);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.error(error.toString()))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          ReportActions(
            library: widget.library,
            buildReport: () async => [
              ReportSection(
                widget.title,
                text: l.unavailable,
                logPath: widget.path,
                profileId: widget.profileId,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.logPreview, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: preview,
            builder: (context, snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.title == l.stderrLabel && snapshot.hasData)
                  for (final advice in logAdvice(l, snapshot.data!))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(advice),
                    ),
                SelectableText(
                  snapshot.hasError
                      ? l.error(snapshot.error.toString())
                      : snapshot.data ?? l.busy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
