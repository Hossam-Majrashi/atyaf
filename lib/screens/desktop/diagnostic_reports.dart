import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../features/logs/services/log_service.dart';
import '../../shared/models/library_models.dart';

List<ReportSection> applicationErrorReport(
  AppLocalizations l,
  Map<String, dynamic> error,
) => [
  ReportSection(
    l.applicationErrors,
    text: error['time'] as String? ?? l.unavailable,
  ),
  ReportSection(
    l.diagnosticDetails,
    text: error['detail'] as String? ?? l.unavailable,
  ),
  ReportSection(l.stackTrace, text: error['stack'] as String? ?? l.unavailable),
];

Map<String, dynamic> crashRecord(
  LibraryController library,
  Profile profile,
  Map<String, dynamic> record,
) {
  final app = library.repository.applications
      .where((item) => item.id == profile.applicationId)
      .firstOrNull;
  return {...record, 'executable': record['executable'] ?? app?.executable};
}

List<String> logAdvice(AppLocalizations l, String stderr) => [
  if (RegExp(r'net_error\s*[=:]?\s*-202\b').hasMatch(stderr))
    l.certificateAdvice,
  if (RegExp(
    r'Error contacting kwallet|org\.kde\.KWallet|Error contacting klauncher',
    caseSensitive: false,
  ).hasMatch(stderr))
    l.walletAdvice,
  if (stderr.contains('xdg-open:') && stderr.contains('integer expected'))
    l.desktopHandlerAdvice,
];

Future<List<ReportSection>> launchReport(
  AppLocalizations l,
  LibraryController library,
  Profile profile,
  Map<String, dynamic> record,
) async {
  final app = library.repository.applications
      .where((item) => item.id == profile.applicationId)
      .firstOrNull;
  final core = await library.logs.coreInfo(
    crashRecord(library, profile, record),
  );
  final advice = [
    if (record['interrupted'] == true) l.lostExitAdvice,
    if (record['stderr'] is String)
      ...logAdvice(
        l,
        await library.logs.read(record['stderr'] as String, profile.id),
      ),
  ];
  return [
    ReportSection(
      l.logs,
      text: l.reportMetadata(
        profile.name,
        record['executable'] as String? ?? app?.executable ?? l.unavailable,
        record['pid']?.toString() ?? l.unavailable,
        record['start'] as String? ?? l.unavailable,
        record['stop'] as String? ?? l.unavailable,
        record['exitCode']?.toString() ?? l.unavailable,
      ),
    ),
    if (advice.isNotEmpty)
      ReportSection(l.launchAdvice, text: advice.join('\n\n')),
    for (final channel in ['stdout', 'stderr'])
      ReportSection(
        channel == 'stdout' ? l.stdoutLabel : l.stderrLabel,
        text: l.unavailable,
        logPath: record[channel] as String?,
        profileId: profile.id,
      ),
    if (record['crashed'] == true)
      ReportSection(l.systemCrash, text: core.isEmpty ? l.noSystemCrash : core),
  ];
}
