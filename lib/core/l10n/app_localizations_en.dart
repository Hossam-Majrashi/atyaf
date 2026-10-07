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
  String get applicationIcon => 'Application icon';

  @override
  String get chooseApplicationIcon => 'Choose an application icon';

  @override
  String get applicationIconHelp =>
      'Choose PNG, JPG, SVG or other supported images. A PNG copy is saved (still frame for animations). The folder button accepts folders only.';

  @override
  String supportedImageFormats(String formats) {
    return 'Image formats available on this device: $formats';
  }

  @override
  String get chooseImageFolder => 'Choose project / image folder';

  @override
  String get chooseImageFile => 'Choose image from device';

  @override
  String get automaticIcon => 'Use automatic icon';

  @override
  String get searchImages => 'Search image paths (press Enter)';

  @override
  String get noProjectImages =>
      'No matching images found. Choose an image directly from your device or another image folder, or use the automatic icon.';

  @override
  String get imageUnavailable =>
      'This image is damaged, unsupported, or exceeds the size limit (16 MiB / 8192 pixels).';

  @override
  String get retry => 'Retry';

  @override
  String imageCount(int count) {
    return '$count images · scroll to browse';
  }

  @override
  String get launchAdvice => 'Launch diagnostics and suggestions';

  @override
  String get lostExitAdvice =>
      'The supervisor was interrupted before recording the exit status. An unavailable exit code does not prove that the application crashed. Old missing codes cannot be recovered from these logs.';

  @override
  String get certificateAdvice =>
      'Chromium error -202 means the certificate authority is not trusted. Check the failing site’s certificate chain, system trust store and any HTTPS-inspecting proxy. This log does not identify the site. Do not disable certificate verification or import an unverified certificate.';

  @override
  String get walletAdvice =>
      'The KDE wallet could not be contacted. Check whether KWallet is enabled and available on the host. If you intentionally use an active Secret Service instead, Electron/Chromium profiles can explicitly select it in the profile editor. Changing stores may require signing in again; plaintext storage is not recommended.';

  @override
  String get desktopHandlerAdvice =>
      'The integer warning comes from xdg-open’s old KDE fallback. Updated Atyaf preserves the host KDE session version. Restart the profile with the updated build to regenerate its desktop handler.';

  @override
  String get useSecretService => 'Electron/Chromium: use Secret Service';

  @override
  String get secretServiceConfirm =>
      'Add --password-store=gnome-libsecret to this profile’s arguments? Use only with a compatible Electron/Chromium application and an active host Secret Service (such as GNOME Keyring). This changes the encryption backend and may require signing in again. Existing credentials are not migrated or deleted. Save and restart the profile to apply; KWallet and system settings are not changed.';

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
  String get windowControlsHelp =>
      'Default profiles inherit system window buttons for GTK/Electron apps such as VS Code and Antigravity without leaving Wayland or changing data and explicit preferences. Custom paths and GSettings setups stay untouched. X11 below is an optional GTK alternative, not the primary fix for Electron editors.';

  @override
  String get useX11WindowControls => 'GTK: try X11 window controls';

  @override
  String get x11Unavailable =>
      'This option requires a host DISPLAY for an X11 or XWayland session.';

  @override
  String get x11WindowControlsConfirm =>
      'Set GDK_BACKEND=x11 for this profile only? Use with GTK applications compatible with X11/XWayland; scaling or Wayland integration may differ. X11 provides weaker window isolation than Wayland. Buttons are not guaranteed for non-resizable dialogs or custom title bars. Other environment values, arguments and profile data remain unchanged. Save and restart the profile to apply. To undo, remove GDK_BACKEND from the environment or change it to wayland.';

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
  String get noErrors => 'No new application errors or failed launches';

  @override
  String get clearErrors => 'Clear errors';

  @override
  String get clearErrorsConfirm =>
      'Delete the displayed Atyaf errors and remove the current failed launches from diagnostics? Applications and profiles are unchanged; launch history and output files remain in profile history. Export reports first if you need them. Errors arriving after this confirmation opens are not cleared.';

  @override
  String get errorsCleared =>
      'Previous diagnostics cleared. New errors will appear automatically.';

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
