// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Atyaf';

  @override
  String get intro => 'One application. Many independent identities.';

  @override
  String get introDetail =>
      'Keep work, personal and testing profiles separate. Manage executables and portable applications locally on Linux.';

  @override
  String get next => 'Continue';

  @override
  String get finish => 'Open library';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get theme => 'Appearance';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get system => 'Follow system';

  @override
  String get settings => 'Settings';

  @override
  String get library => 'Applications';

  @override
  String get addApplication => 'Add application';

  @override
  String get executable => 'Executable';

  @override
  String get wmClass => 'Window class (optional)';

  @override
  String get wmClassHelp =>
      'Set StartupWMClass only when the application requires it to match its windows to the desktop shortcut.';

  @override
  String get folder => 'Application folder';

  @override
  String get archive => 'Portable archive';

  @override
  String get chooseExecutable => 'Choose an executable';

  @override
  String get name => 'Name';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get closeConfirm =>
      'Running profiles must be stopped before closing Atyaf so their output and exit codes can be recorded. Stop them now?';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConfirm =>
      'Remove this item and its managed data? External files and custom paths are never deleted.';

  @override
  String get emptyLibrary => 'Your library starts here';

  @override
  String get emptyLibraryDetail =>
      'Add an executable, application folder or portable archive to create independent profiles.';

  @override
  String get selectApplication => 'Select an application to see its profiles';

  @override
  String get profiles => 'Profiles';

  @override
  String get newProfile => 'New profile';

  @override
  String get emptyProfiles => 'Create your first identity for this application';

  @override
  String get launch => 'Launch';

  @override
  String get stop => 'Stop gracefully';

  @override
  String get forceKill => 'Force kill';

  @override
  String get forceConfirm =>
      'Force termination can lose unsaved work. Terminate this process now?';

  @override
  String get restart => 'Restart';

  @override
  String get running => 'Running';

  @override
  String get stopped => 'Stopped';

  @override
  String get shortcut => 'Add to applications menu';

  @override
  String get shortcutUpdated =>
      'The shortcut and its icon were updated in the system applications menu.';

  @override
  String get desktopIntegrationHelp =>
      'Saving a profile adds it to the system applications menu under its own name, using the applications icon when available. Approved shortcuts launch without the Atyaf window; first launches and changed executables require review. Links opened through xdg-open use the devices default browser. Explicit PATH/BROWSER overrides are preserved.';

  @override
  String get removeShortcut => 'Remove desktop shortcut';

  @override
  String get logs => 'Launch history and logs';

  @override
  String get noLogs => 'No launches recorded';

  @override
  String get arguments => 'Arguments (JSON string array)';

  @override
  String get environment => 'Environment (JSON object of strings)';

  @override
  String get workingDirectory =>
      'Working directory (empty uses executable folder)';

  @override
  String get configPath => 'Configuration path';

  @override
  String get dataPath => 'Data path';

  @override
  String get cachePath => 'Cache path';

  @override
  String get statePath => 'State path';

  @override
  String get tempPath => 'Temporary path';

  @override
  String get homePath => 'HOME path (empty keeps real HOME)';

  @override
  String get profileHelp =>
      'XDG paths are isolated by default; HOME is not changed. Use application-specific flags for apps that ignore XDG. Arguments and environment values can use {config}, {data}, {cache}, {state}, {temp}, {home} and {profile}. This is not a security sandbox.';

  @override
  String get invalidInput =>
      'Enter a name and valid JSON. Paths must be absolute. Environment keys must be valid identifiers.';

  @override
  String error(String detail) {
    return 'The operation could not be completed. Technical details: $detail';
  }

  @override
  String get done => 'Operation completed';

  @override
  String get openFailed => 'Could not open this link';

  @override
  String get developer => 'Developer';

  @override
  String get email => 'Email';

  @override
  String get website => 'Website';

  @override
  String get backup => 'Backup and restore';

  @override
  String get exportBackup => 'Export managed library';

  @override
  String get importBackup => 'Restore managed library';

  @override
  String get backupHelp =>
      'Backups include managed profiles, portable applications and library settings, not external application files or custom paths. Restore requires no running profiles and replaces the managed library. Preferences remain unchanged.';

  @override
  String get restoreConfirm => 'Replace the managed library with this backup?';

  @override
  String get securityTitle => 'Review executable before launch';

  @override
  String get securityWarning =>
      'Only launch programs you trust. Isolation separates settings; it does not restrict access to your files. The executable has been resolved and inspected.';

  @override
  String fileReview(String path, String owner, int size, String mode) {
    return 'Path: $path\nOwner UID: $owner\nSize: $size bytes\nPermissions: $mode';
  }

  @override
  String get trustLaunch => 'Trust and launch';

  @override
  String launchRecord(int pid, String start, String stop, String code) {
    return 'PID $pid · started $start · stopped $stop · exit $code';
  }

  @override
  String get crashed => 'Unexpected exit';

  @override
  String get interrupted => 'Supervisor interrupted; exit code unavailable';

  @override
  String get openFullLog => 'Open complete log';

  @override
  String get logPreview =>
      'Preview (first 256 KiB). Copy the complete report or export TXT to include all content.';

  @override
  String get refreshLog => 'Refresh preview';

  @override
  String get stdoutLabel => 'Standard output';

  @override
  String get stderrLabel => 'Standard error';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get isolationNotice => 'Independent paths, not a security sandbox';

  @override
  String get busy => 'Working';

  @override
  String get noExecutables => 'No executable files found in this folder';

  @override
  String get errors => 'Errors and diagnostics';

  @override
  String get noErrors => 'No application errors or failed launches recorded';

  @override
  String get applicationErrors => 'Atyaf errors';

  @override
  String get failedLaunches => 'Failed launches';

  @override
  String get copyAll => 'Copy complete report';

  @override
  String get exportTxt => 'Export TXT';

  @override
  String get copied => 'Complete report copied';

  @override
  String get reportPrivacy =>
      'Reports may contain private paths, secrets printed by programs, and system crash details. Review them before sharing. Previews are limited; copy and export use the complete logs.';

  @override
  String get copyTooLarge =>
      'This report exceeds the 64 MiB clipboard limit. Export TXT to save the complete report without truncation.';

  @override
  String get diagnosticDetails => 'Technical details';

  @override
  String get stackTrace => 'Stack trace';

  @override
  String get systemCrash => 'System crash details';

  @override
  String get loadSystemCrash => 'Show system crash details';

  @override
  String get noSystemCrash =>
      'No system crash details available. coredumpctl may be unavailable, access restricted, or the dump already removed.';

  @override
  String reportMetadata(
    String profile,
    String executable,
    String pid,
    String start,
    String stop,
    String code,
  ) {
    return 'Profile: $profile\nExecutable: $executable\nPID: $pid\nStarted: $start\nStopped: $stop\nExit code: $code';
  }

  @override
  String get tempHelp =>
      'The default temporary path is a short private per-profile Linux directory, avoiding Unix socket path limits in Electron/Chromium applications. Explicit temporary paths and TMPDIR overrides are preserved.';

  @override
  String get update => 'Update';

  @override
  String get updateSource => 'Choose the new application source';

  @override
  String get updateHelp =>
      'Updates are manual. Select a complete folder or tar.gz, tar.xz or tar.zst archive. Only application files will be replaced; profiles, data and shortcuts remain unchanged.';

  @override
  String get updateRunning =>
      'This application has running profiles. Stop them gracefully before updating. Force kill is never automatic.';

  @override
  String get updateSummary => 'Replace the application with this source?';

  @override
  String get source => 'Source';

  @override
  String get updateSuccess =>
      'Application updated. Profiles and their settings were preserved.';

  @override
  String get managedApplication =>
      'Managed application — independent of the original source';

  @override
  String get externalApplication =>
      'External reference — updating imports a managed copy; external files are never changed';

  @override
  String executableCandidate(String path, int size, String mode) {
    return '$path · $size bytes · $mode';
  }
}
