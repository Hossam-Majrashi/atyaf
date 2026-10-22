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
  String get searchApplications => 'Search applications';

  @override
  String get noMatchingApplications => 'No matching applications.';

  @override
  String get addApplication => 'Add application';

  @override
  String get executable => 'Executable';

  @override
  String get executableFormats => 'Linux ELF / scripts (.sh or no extension)';

  @override
  String get folderFormats => 'Complete directory with program files';

  @override
  String get archiveFormats => '.tar.gz · .tar.xz · .tar.zst';

  @override
  String get appImageFormats => '.AppImage';

  @override
  String get executableImportHelp =>
      'An independent copy of this file is saved in the Atyaf library, so deleting the download will not remove it. For programs needing neighboring resources or libraries, import the complete application folder instead. Importing never runs the file.';

  @override
  String get wmClass => 'Window class (optional)';

  @override
  String get wmClassHelp =>
      'KDE detects window classes after launch. Generic AppRun is skipped to avoid mixed taskbar icons; use an application-specific class.';

  @override
  String get folder => 'Application folder';

  @override
  String get archive => 'Portable archive';

  @override
  String get appImage => 'AppImage file';

  @override
  String get appImageHelp =>
      'An independent AppImage copy is stored without running it. Embedded application icons are read safely and shown in the gallery; automatic selection uses the detected logo. You can choose a different image. Profiles use XDG paths; applications that ignore them need their own flags. FUSE/runtime dependencies may be required. Adjacent .home/.config directories are not imported.';

  @override
  String get appImageIconToolMissing =>
      'Reading embedded AppImage icons needs 7-Zip (7zz or 7z) on the host. Install the 7zip package using your package manager, then import again. You can still choose an image manually.';

  @override
  String get appImageIconUnsupported =>
      'This AppImage filesystem is not supported by the installed icon reader (for example DwarFS). No application was run. Choose an image manually or use the fallback icon.';

  @override
  String get appImageIconUnavailable =>
      'No readable embedded application icon was found, or icon reading failed or exceeded its limits. Choose an image manually or use the fallback icon. No application was run.';

  @override
  String get chooseExecutable => 'Choose an executable';

  @override
  String get managedLinksHelp =>
      'Internal symbolic links are kept portable within the imported application. Links to files outside it, missing targets and link loops are rejected. Importing does not launch any executable.';

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
  String get serviceConnectionAdvice =>
      'Telemetry ConnectionFailed or Social Overlay STOMP 4004 (Inactive timeout) indicates a connection problem in those services, not proof that the application crashed. If the problem persists, check network access and the service status. These messages alone do not establish the cause or exit status; Atyaf does not change network, TLS or account settings.';

  @override
  String get recoveredUiAdvice =>
      'The log reports a recovered React #424 rendering error. Recovery was reported, but this does not guarantee that every interface feature works or explain a later exit. Check the actual exit status and subsequent output; no rendering or sandbox flags are added automatically.';

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
  String get shadps4CliAdvice =>
      'This is shadPS4 CLI usage output, not a system crash report. Versions with Big Picture mode need --big-picture (or -b) to open their interface; launching without arguments can exit with code 255. In the profile editor, use the shadPS4 Big Picture option, then Save and restart. Alternatively, import the separate shadPS4 Qt Launcher for the desktop GUI, or supply a game using --game. Flags depend on the imported version; Atyaf does not add them automatically.';

  @override
  String get useShadps4BigPicture => 'shadPS4: use Big Picture';

  @override
  String get shadps4BigPictureConfirm =>
      'Add --big-picture to this profile’s arguments? Use only with a shadPS4 CLI version that lists this option in its help. This opens Big Picture mode, not the separate Qt Launcher. Other arguments and profile data are kept; no data migration or automatic launch occurs. Save and restart the profile to apply.';

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
  String get outputStreamsPending =>
      'Logs are still being saved. Try launching again after the application and its background helpers have finished. You can close the Atyaf window; logging will continue in the background. No output has been discarded.';

  @override
  String get profileAlreadyRunning =>
      'This profile is already running. No second copy was started.';

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
      'Add an executable, application folder, portable archive or AppImage to create independent profiles.';

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
  String get terminalCommand => 'Terminal command';

  @override
  String get createTerminalCommand => 'Create command';

  @override
  String get terminalCommandName => 'Command name (for example rpcs3)';

  @override
  String get terminalCommandHelp =>
      'Create a command in ~/.local/bin to launch this specific profile through Atyaf. It keeps profile settings, approval and logs. Use different command names for different accounts. Existing commands are never overwritten. Renaming a profile does not rename its commands.';

  @override
  String get terminalCommandInvalid =>
      'Use 1–64 lowercase English letters, digits, dots, underscores or hyphens, starting with a letter. Shell built-in names are reserved.';

  @override
  String get terminalArgumentsHelp =>
      'This command accepts no extra arguments. Configure application arguments in the Atyaf profile editor.';

  @override
  String terminalCommandCreated(String name) {
    return 'Type $name in your terminal to launch this profile. First launches and changed executables still require approval in Atyaf.';
  }

  @override
  String terminalCommandConflict(String detail) {
    return 'This name is already used by another profile or command: $detail. Choose a different name; nothing was replaced.';
  }

  @override
  String terminalCommandUnsafe(String detail) {
    return 'The command could not be managed safely. Existing files were preserved. Details: $detail';
  }

  @override
  String get terminalPathMissing =>
      '~/.local/bin is not in the host PATH. For a Bash/Zsh session, run the line below before using the command. Add it to your shell configuration yourself if you want it to persist; Atyaf does not edit shell files. Shell aliases/functions may take precedence over this command.';

  @override
  String get terminalPathCommand => 'export PATH=\"\$HOME/.local/bin:\$PATH\"';

  @override
  String get existingTerminalCommands => 'Commands for this profile';

  @override
  String get removeTerminalCommands => 'Remove terminal commands';

  @override
  String get removeTerminalCommandsConfirm =>
      'Remove this profile’s unchanged Atyaf terminal commands? The application, profile data, desktop shortcuts and running processes stay unchanged. Modified files are left untouched.';

  @override
  String get terminalCommandsRemoved =>
      'Terminal commands removed. The profile and its data were preserved.';

  @override
  String terminalCommandsPreserved(String names) {
    return 'Managed commands removed. Modified files were left untouched and are no longer managed: $names';
  }

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
  String get tauriUnknownPathAdvice =>
      'Tauri could not resolve a path during startup. Missing XDG special-folder definitions can cause this (reproduced with xrevive 0.1.22). Atyaf now supplies private Documents, Downloads and other standard folders for default managed config/data paths. Restart with the updated Atyaf; existing user-dirs.dirs files and custom config/data settings are preserved and may require manual review. This message alone does not identify every unknown-path failure.';

  @override
  String get profileHelp =>
      'XDG paths are isolated by default; HOME is not changed. Default managed profiles receive private standard user folders without copying personal files; custom config/data paths and existing user-dirs.dirs files are preserved. Use application-specific flags for apps that ignore XDG. Arguments and environment values can use {config}, {data}, {cache}, {state}, {temp}, {home} and {profile}. This is not a security sandbox.';

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
      'Updates are manual. Select a standalone executable, complete folder, tar.gz, tar.xz or tar.zst archive, or a new AppImage. Only application files will be replaced; names, chosen icons, profiles, data and shortcuts remain unchanged. AppImages run as files, without automatic extraction or dependency installation.';

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
