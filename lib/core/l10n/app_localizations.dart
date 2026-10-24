import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Linux Desktop strings generated from the Arabic and English ARB sources.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Atyaf'**
  String get appName;

  /// No description provided for @intro.
  ///
  /// In en, this message translates to:
  /// **'One application. Many independent identities.'**
  String get intro;

  /// No description provided for @introDetail.
  ///
  /// In en, this message translates to:
  /// **'Keep work, personal and testing profiles separate. Manage executables and portable applications locally on Linux.'**
  String get introDetail;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Open library'**
  String get finish;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get theme;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get system;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get library;

  /// No description provided for @searchApplications.
  ///
  /// In en, this message translates to:
  /// **'Search applications'**
  String get searchApplications;

  /// No description provided for @noMatchingApplications.
  ///
  /// In en, this message translates to:
  /// **'No matching applications.'**
  String get noMatchingApplications;

  /// No description provided for @addApplication.
  ///
  /// In en, this message translates to:
  /// **'Add application'**
  String get addApplication;

  /// No description provided for @executable.
  ///
  /// In en, this message translates to:
  /// **'Executable'**
  String get executable;

  /// No description provided for @executableFormats.
  ///
  /// In en, this message translates to:
  /// **'Linux ELF / scripts (.sh or no extension)'**
  String get executableFormats;

  /// No description provided for @folderFormats.
  ///
  /// In en, this message translates to:
  /// **'Complete directory with program files'**
  String get folderFormats;

  /// No description provided for @archiveFormats.
  ///
  /// In en, this message translates to:
  /// **'.tar.gz · .tar.xz · .tar.zst'**
  String get archiveFormats;

  /// No description provided for @appImageFormats.
  ///
  /// In en, this message translates to:
  /// **'.AppImage'**
  String get appImageFormats;

  /// No description provided for @executableImportHelp.
  ///
  /// In en, this message translates to:
  /// **'An independent copy of this file is saved in the Atyaf library, so deleting the download will not remove it. For programs needing neighboring resources or libraries, import the complete application folder instead. Importing never runs the file.'**
  String get executableImportHelp;

  /// No description provided for @wmClass.
  ///
  /// In en, this message translates to:
  /// **'Window class (optional)'**
  String get wmClass;

  /// No description provided for @wmClassHelp.
  ///
  /// In en, this message translates to:
  /// **'KDE detects window classes after launch. Generic AppRun is skipped to avoid mixed taskbar icons; use an application-specific class.'**
  String get wmClassHelp;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Application folder'**
  String get folder;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Portable archive'**
  String get archive;

  /// No description provided for @appImage.
  ///
  /// In en, this message translates to:
  /// **'AppImage file'**
  String get appImage;

  /// No description provided for @appImageHelp.
  ///
  /// In en, this message translates to:
  /// **'An independent AppImage copy is stored without running it. Embedded application icons are read safely and shown in the gallery; automatic selection uses the detected logo. You can choose a different image. Profiles use XDG paths; applications that ignore them need their own flags. FUSE/runtime dependencies may be required. Adjacent .home/.config directories are not imported.'**
  String get appImageHelp;

  /// No description provided for @appImageIconToolMissing.
  ///
  /// In en, this message translates to:
  /// **'Reading embedded AppImage icons needs 7-Zip (7zz or 7z) on the host. Install the 7zip package using your package manager, then import again. You can still choose an image manually.'**
  String get appImageIconToolMissing;

  /// No description provided for @appImageIconUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This AppImage filesystem is not supported by the installed icon reader (for example DwarFS). No application was run. Choose an image manually or use the fallback icon.'**
  String get appImageIconUnsupported;

  /// No description provided for @appImageIconUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No readable embedded application icon was found, or icon reading failed or exceeded its limits. Choose an image manually or use the fallback icon. No application was run.'**
  String get appImageIconUnavailable;

  /// No description provided for @chooseExecutable.
  ///
  /// In en, this message translates to:
  /// **'Choose an executable'**
  String get chooseExecutable;

  /// No description provided for @managedLinksHelp.
  ///
  /// In en, this message translates to:
  /// **'Internal symbolic links are kept portable within the imported application. Links to files outside it, missing targets and link loops are rejected. Importing does not launch any executable.'**
  String get managedLinksHelp;

  /// No description provided for @applicationIcon.
  ///
  /// In en, this message translates to:
  /// **'Application icon'**
  String get applicationIcon;

  /// No description provided for @chooseApplicationIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an application icon'**
  String get chooseApplicationIcon;

  /// No description provided for @applicationIconHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose PNG, JPG, SVG or other supported images. A PNG copy is saved (still frame for animations). The folder button accepts folders only.'**
  String get applicationIconHelp;

  /// No description provided for @supportedImageFormats.
  ///
  /// In en, this message translates to:
  /// **'Image formats available on this device: {formats}'**
  String supportedImageFormats(String formats);

  /// No description provided for @chooseImageFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose project / image folder'**
  String get chooseImageFolder;

  /// No description provided for @chooseImageFile.
  ///
  /// In en, this message translates to:
  /// **'Choose image from device'**
  String get chooseImageFile;

  /// No description provided for @automaticIcon.
  ///
  /// In en, this message translates to:
  /// **'Use automatic icon'**
  String get automaticIcon;

  /// No description provided for @searchImages.
  ///
  /// In en, this message translates to:
  /// **'Search image paths (press Enter)'**
  String get searchImages;

  /// No description provided for @noProjectImages.
  ///
  /// In en, this message translates to:
  /// **'No matching images found. Choose an image directly from your device or another image folder, or use the automatic icon.'**
  String get noProjectImages;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This image is damaged, unsupported, or exceeds the size limit (16 MiB / 8192 pixels).'**
  String get imageUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @imageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images · scroll to browse'**
  String imageCount(int count);

  /// No description provided for @launchAdvice.
  ///
  /// In en, this message translates to:
  /// **'Launch diagnostics and suggestions'**
  String get launchAdvice;

  /// No description provided for @libraryBusyAdvice.
  ///
  /// In en, this message translates to:
  /// **'The library is busy in another operation or Atyaf instance. Atyaf waited briefly for its lock; no launch was retried automatically. Wait for the operation to finish, then try again. Do not delete the lock file or stop a running update.'**
  String get libraryBusyAdvice;

  /// No description provided for @selfUpdateAdvice.
  ///
  /// In en, this message translates to:
  /// **'The application reports a successful internal update. It may replace its executable and relaunch: the original PID or its exit status does not describe the final relaunched instance. Atyaf keeps inherited output streams open, but independently detached processes are not tracked. Review the changed executable on the next launch; approval is never renewed automatically. This message does not recover a missing exit status or establish the cause of a later failure.'**
  String get selfUpdateAdvice;

  /// No description provided for @heapCorruptionAdvice.
  ///
  /// In en, this message translates to:
  /// **'The native allocator reported corrupted double-linked list (heap corruption). This is distinct from a recovered React warning. The line alone does not identify the affected updater/helper/main process or prove the final instance crashed. Check subsequent output, the actual exit status and any matching system crash report; Atyaf does not patch the application or add unsafe launch flags.'**
  String get heapCorruptionAdvice;

  /// No description provided for @serviceConnectionAdvice.
  ///
  /// In en, this message translates to:
  /// **'Telemetry ConnectionFailed or Social Overlay STOMP 4004 (Inactive timeout) indicates a connection problem in those services, not proof that the application crashed. If the problem persists, check network access and the service status. These messages alone do not establish the cause or exit status; Atyaf does not change network, TLS or account settings.'**
  String get serviceConnectionAdvice;

  /// No description provided for @recoveredUiAdvice.
  ///
  /// In en, this message translates to:
  /// **'The log reports a recovered React #424 rendering error. Recovery was reported, but this does not guarantee that every interface feature works or explain a later exit. Check the actual exit status and subsequent output; no rendering or sandbox flags are added automatically.'**
  String get recoveredUiAdvice;

  /// No description provided for @lostExitAdvice.
  ///
  /// In en, this message translates to:
  /// **'The supervisor was interrupted before recording the exit status. An unavailable exit code does not prove that the application crashed. Old missing codes cannot be recovered from these logs.'**
  String get lostExitAdvice;

  /// No description provided for @certificateAdvice.
  ///
  /// In en, this message translates to:
  /// **'Chromium error -202 means the certificate authority is not trusted. Check the failing site’s certificate chain, system trust store and any HTTPS-inspecting proxy. This log does not identify the site. Do not disable certificate verification or import an unverified certificate.'**
  String get certificateAdvice;

  /// No description provided for @walletAdvice.
  ///
  /// In en, this message translates to:
  /// **'The KDE wallet could not be contacted. Check whether KWallet is enabled and available on the host. If you intentionally use an active Secret Service instead, Electron/Chromium profiles can explicitly select it in the profile editor. Changing stores may require signing in again; plaintext storage is not recommended.'**
  String get walletAdvice;

  /// No description provided for @desktopHandlerAdvice.
  ///
  /// In en, this message translates to:
  /// **'The integer warning comes from xdg-open’s old KDE fallback. Updated Atyaf preserves the host KDE session version. Restart the profile with the updated build to regenerate its desktop handler.'**
  String get desktopHandlerAdvice;

  /// No description provided for @shadps4CliAdvice.
  ///
  /// In en, this message translates to:
  /// **'This is shadPS4 CLI usage output, not a system crash report. Versions with Big Picture mode need --big-picture (or -b) to open their interface; launching without arguments can exit with code 255. In the profile editor, use the shadPS4 Big Picture option, then Save and restart. Alternatively, import the separate shadPS4 Qt Launcher for the desktop GUI, or supply a game using --game. Flags depend on the imported version; Atyaf does not add them automatically.'**
  String get shadps4CliAdvice;

  /// No description provided for @useShadps4BigPicture.
  ///
  /// In en, this message translates to:
  /// **'shadPS4: use Big Picture'**
  String get useShadps4BigPicture;

  /// No description provided for @shadps4BigPictureConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add --big-picture to this profile’s arguments? Use only with a shadPS4 CLI version that lists this option in its help. This opens Big Picture mode, not the separate Qt Launcher. Other arguments and profile data are kept; no data migration or automatic launch occurs. Save and restart the profile to apply.'**
  String get shadps4BigPictureConfirm;

  /// No description provided for @useSecretService.
  ///
  /// In en, this message translates to:
  /// **'Electron/Chromium: use Secret Service'**
  String get useSecretService;

  /// No description provided for @secretServiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add --password-store=gnome-libsecret to this profile’s arguments? Use only with a compatible Electron/Chromium application and an active host Secret Service (such as GNOME Keyring). This changes the encryption backend and may require signing in again. Existing credentials are not migrated or deleted. Save and restart the profile to apply; KWallet and system settings are not changed.'**
  String get secretServiceConfirm;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @supervisionPending.
  ///
  /// In en, this message translates to:
  /// **'Supervising output / relaunch — original process ended. Waiting for inherited streams; no verified PID to stop.'**
  String get supervisionPending;

  /// No description provided for @outputStreamsPending.
  ///
  /// In en, this message translates to:
  /// **'Logs are still being saved. Try launching again after the application and its background helpers have finished. You can close the Atyaf window; logging will continue in the background. No output has been discarded.'**
  String get outputStreamsPending;

  /// No description provided for @profileAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'This profile is already running. No second copy was started.'**
  String get profileAlreadyRunning;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this item and its managed data? External files and custom paths are never deleted.'**
  String get deleteConfirm;

  /// No description provided for @emptyLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library starts here'**
  String get emptyLibrary;

  /// No description provided for @emptyLibraryDetail.
  ///
  /// In en, this message translates to:
  /// **'Add an executable, application folder, portable archive or AppImage to create independent profiles.'**
  String get emptyLibraryDetail;

  /// No description provided for @selectApplication.
  ///
  /// In en, this message translates to:
  /// **'Select an application to see its profiles'**
  String get selectApplication;

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @newProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// No description provided for @emptyProfiles.
  ///
  /// In en, this message translates to:
  /// **'Create your first identity for this application'**
  String get emptyProfiles;

  /// No description provided for @launch.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop gracefully'**
  String get stop;

  /// No description provided for @forceKill.
  ///
  /// In en, this message translates to:
  /// **'Force kill'**
  String get forceKill;

  /// No description provided for @forceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Force termination can lose unsaved work. Terminate this process now?'**
  String get forceConfirm;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @shortcut.
  ///
  /// In en, this message translates to:
  /// **'Add to applications menu'**
  String get shortcut;

  /// No description provided for @shortcutUpdated.
  ///
  /// In en, this message translates to:
  /// **'The shortcut and its icon were updated in the system applications menu.'**
  String get shortcutUpdated;

  /// No description provided for @desktopIntegrationHelp.
  ///
  /// In en, this message translates to:
  /// **'Saving a profile adds it to the system applications menu under its own name, using the application\'s icon when available. Approved shortcuts launch without the Atyaf window; first launches and changed executables require review. Links opened through xdg-open use the device\'s default browser. Explicit PATH/BROWSER overrides are preserved.'**
  String get desktopIntegrationHelp;

  /// No description provided for @removeShortcut.
  ///
  /// In en, this message translates to:
  /// **'Remove desktop shortcut'**
  String get removeShortcut;

  /// No description provided for @terminalCommand.
  ///
  /// In en, this message translates to:
  /// **'Terminal command'**
  String get terminalCommand;

  /// No description provided for @createTerminalCommand.
  ///
  /// In en, this message translates to:
  /// **'Create command'**
  String get createTerminalCommand;

  /// No description provided for @terminalCommandName.
  ///
  /// In en, this message translates to:
  /// **'Command name (for example rpcs3)'**
  String get terminalCommandName;

  /// No description provided for @terminalCommandHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a command in ~/.local/bin to launch this specific profile through Atyaf. It keeps profile settings, approval and logs. Use different command names for different accounts. Existing commands are never overwritten. Renaming a profile does not rename its commands.'**
  String get terminalCommandHelp;

  /// No description provided for @terminalCommandInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 1–64 lowercase English letters, digits, dots, underscores or hyphens, starting with a letter. Shell built-in names are reserved.'**
  String get terminalCommandInvalid;

  /// No description provided for @terminalArgumentsHelp.
  ///
  /// In en, this message translates to:
  /// **'This command accepts no extra arguments. Configure application arguments in the Atyaf profile editor.'**
  String get terminalArgumentsHelp;

  /// No description provided for @terminalCommandCreated.
  ///
  /// In en, this message translates to:
  /// **'Type {name} in your terminal to launch this profile. First launches and changed executables still require approval in Atyaf.'**
  String terminalCommandCreated(String name);

  /// No description provided for @terminalCommandConflict.
  ///
  /// In en, this message translates to:
  /// **'This name is already used by another profile or command: {detail}. Choose a different name; nothing was replaced.'**
  String terminalCommandConflict(String detail);

  /// No description provided for @terminalCommandUnsafe.
  ///
  /// In en, this message translates to:
  /// **'The command could not be managed safely. Existing files were preserved. Details: {detail}'**
  String terminalCommandUnsafe(String detail);

  /// No description provided for @terminalPathMissing.
  ///
  /// In en, this message translates to:
  /// **'~/.local/bin is not in the host PATH. For a Bash/Zsh session, run the line below before using the command. Add it to your shell configuration yourself if you want it to persist; Atyaf does not edit shell files. Shell aliases/functions may take precedence over this command.'**
  String get terminalPathMissing;

  /// No description provided for @terminalPathCommand.
  ///
  /// In en, this message translates to:
  /// **'export PATH=\"\$HOME/.local/bin:\$PATH\"'**
  String get terminalPathCommand;

  /// No description provided for @existingTerminalCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands for this profile'**
  String get existingTerminalCommands;

  /// No description provided for @removeTerminalCommands.
  ///
  /// In en, this message translates to:
  /// **'Remove terminal commands'**
  String get removeTerminalCommands;

  /// No description provided for @removeTerminalCommandsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this profile’s unchanged Atyaf terminal commands? The application, profile data, desktop shortcuts and running processes stay unchanged. Modified files are left untouched.'**
  String get removeTerminalCommandsConfirm;

  /// No description provided for @terminalCommandsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Terminal commands removed. The profile and its data were preserved.'**
  String get terminalCommandsRemoved;

  /// No description provided for @terminalCommandsPreserved.
  ///
  /// In en, this message translates to:
  /// **'Managed commands removed. Modified files were left untouched and are no longer managed: {names}'**
  String terminalCommandsPreserved(String names);

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Launch history and logs'**
  String get logs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No launches recorded'**
  String get noLogs;

  /// No description provided for @arguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments (JSON string array)'**
  String get arguments;

  /// No description provided for @environment.
  ///
  /// In en, this message translates to:
  /// **'Environment (JSON object of strings)'**
  String get environment;

  /// No description provided for @workingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Working directory (empty uses executable folder)'**
  String get workingDirectory;

  /// No description provided for @configPath.
  ///
  /// In en, this message translates to:
  /// **'Configuration path'**
  String get configPath;

  /// No description provided for @dataPath.
  ///
  /// In en, this message translates to:
  /// **'Data path'**
  String get dataPath;

  /// No description provided for @cachePath.
  ///
  /// In en, this message translates to:
  /// **'Cache path'**
  String get cachePath;

  /// No description provided for @statePath.
  ///
  /// In en, this message translates to:
  /// **'State path'**
  String get statePath;

  /// No description provided for @tempPath.
  ///
  /// In en, this message translates to:
  /// **'Temporary path'**
  String get tempPath;

  /// No description provided for @homePath.
  ///
  /// In en, this message translates to:
  /// **'HOME path (empty keeps real HOME)'**
  String get homePath;

  /// No description provided for @tauriUnknownPathAdvice.
  ///
  /// In en, this message translates to:
  /// **'Tauri could not resolve a path during startup. Missing XDG special-folder definitions can cause this (reproduced with xrevive 0.1.22). Atyaf now supplies private Documents, Downloads and other standard folders for default managed config/data paths. Restart with the updated Atyaf; existing user-dirs.dirs files and custom config/data settings are preserved and may require manual review. This message alone does not identify every unknown-path failure.'**
  String get tauriUnknownPathAdvice;

  /// No description provided for @profileHelp.
  ///
  /// In en, this message translates to:
  /// **'XDG paths are isolated by default; HOME is not changed. Default managed profiles receive private standard user folders without copying personal files; custom config/data paths and existing user-dirs.dirs files are preserved. Use application-specific flags for apps that ignore XDG. Arguments and environment values can use \'{config}\', \'{data}\', \'{cache}\', \'{state}\', \'{temp}\', \'{home}\' and \'{profile}\'. This is not a security sandbox.'**
  String get profileHelp;

  /// No description provided for @windowControlsHelp.
  ///
  /// In en, this message translates to:
  /// **'Default profiles inherit system window buttons for GTK/Electron apps such as VS Code and Antigravity without leaving Wayland or changing data and explicit preferences. Custom paths and GSettings setups stay untouched. X11 below is an optional GTK alternative, not the primary fix for Electron editors.'**
  String get windowControlsHelp;

  /// No description provided for @useX11WindowControls.
  ///
  /// In en, this message translates to:
  /// **'GTK: try X11 window controls'**
  String get useX11WindowControls;

  /// No description provided for @x11Unavailable.
  ///
  /// In en, this message translates to:
  /// **'This option requires a host DISPLAY for an X11 or XWayland session.'**
  String get x11Unavailable;

  /// No description provided for @x11WindowControlsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Set GDK_BACKEND=x11 for this profile only? Use with GTK applications compatible with X11/XWayland; scaling or Wayland integration may differ. X11 provides weaker window isolation than Wayland. Buttons are not guaranteed for non-resizable dialogs or custom title bars. Other environment values, arguments and profile data remain unchanged. Save and restart the profile to apply. To undo, remove GDK_BACKEND from the environment or change it to wayland.'**
  String get x11WindowControlsConfirm;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and valid JSON. Paths must be absolute. Environment keys must be valid identifiers.'**
  String get invalidInput;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed. Technical details: {detail}'**
  String error(String detail);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Operation completed'**
  String get done;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this link'**
  String get openFailed;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backup;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export managed library'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore managed library'**
  String get importBackup;

  /// No description provided for @backupHelp.
  ///
  /// In en, this message translates to:
  /// **'Backups include managed profiles, portable applications and library settings, not external application files or custom paths. Restore requires no running profiles and replaces the managed library. Preferences remain unchanged.'**
  String get backupHelp;

  /// No description provided for @restoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace the managed library with this backup?'**
  String get restoreConfirm;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Review executable before launch'**
  String get securityTitle;

  /// No description provided for @securityWarning.
  ///
  /// In en, this message translates to:
  /// **'Only launch programs you trust. Isolation separates settings; it does not restrict access to your files. The executable has been resolved and inspected.'**
  String get securityWarning;

  /// No description provided for @fileReview.
  ///
  /// In en, this message translates to:
  /// **'Path: {path}\nOwner UID: {owner}\nSize: {size} bytes\nPermissions: {mode}'**
  String fileReview(String path, String owner, int size, String mode);

  /// No description provided for @trustLaunch.
  ///
  /// In en, this message translates to:
  /// **'Trust and launch'**
  String get trustLaunch;

  /// No description provided for @launchRecord.
  ///
  /// In en, this message translates to:
  /// **'PID {pid} · started {start} · stopped {stop} · exit {code}'**
  String launchRecord(int pid, String start, String stop, String code);

  /// No description provided for @crashed.
  ///
  /// In en, this message translates to:
  /// **'Unexpected exit'**
  String get crashed;

  /// No description provided for @interrupted.
  ///
  /// In en, this message translates to:
  /// **'Supervisor interrupted; exit code unavailable'**
  String get interrupted;

  /// No description provided for @openFullLog.
  ///
  /// In en, this message translates to:
  /// **'Open complete log'**
  String get openFullLog;

  /// No description provided for @logPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview (first 256 KiB). Copy the complete report or export TXT to include all content.'**
  String get logPreview;

  /// No description provided for @refreshLog.
  ///
  /// In en, this message translates to:
  /// **'Refresh preview'**
  String get refreshLog;

  /// No description provided for @stdoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard output'**
  String get stdoutLabel;

  /// No description provided for @stderrLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard error'**
  String get stderrLabel;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @isolationNotice.
  ///
  /// In en, this message translates to:
  /// **'Independent paths, not a security sandbox'**
  String get isolationNotice;

  /// No description provided for @busy.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get busy;

  /// No description provided for @noExecutables.
  ///
  /// In en, this message translates to:
  /// **'No executable files found in this folder'**
  String get noExecutables;

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors and diagnostics'**
  String get errors;

  /// No description provided for @noErrors.
  ///
  /// In en, this message translates to:
  /// **'No new application errors or failed launches'**
  String get noErrors;

  /// No description provided for @clearErrors.
  ///
  /// In en, this message translates to:
  /// **'Clear errors'**
  String get clearErrors;

  /// No description provided for @clearErrorsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the displayed Atyaf errors and remove the current failed launches from diagnostics? Applications and profiles are unchanged; launch history and output files remain in profile history. Export reports first if you need them. Errors arriving after this confirmation opens are not cleared.'**
  String get clearErrorsConfirm;

  /// No description provided for @errorsCleared.
  ///
  /// In en, this message translates to:
  /// **'Previous diagnostics cleared. New errors will appear automatically.'**
  String get errorsCleared;

  /// No description provided for @applicationErrors.
  ///
  /// In en, this message translates to:
  /// **'Atyaf errors'**
  String get applicationErrors;

  /// No description provided for @failedLaunches.
  ///
  /// In en, this message translates to:
  /// **'Failed launches'**
  String get failedLaunches;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy complete report'**
  String get copyAll;

  /// No description provided for @exportTxt.
  ///
  /// In en, this message translates to:
  /// **'Export TXT'**
  String get exportTxt;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Complete report copied'**
  String get copied;

  /// No description provided for @reportPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Reports may contain private paths, secrets printed by programs, and system crash details. Review them before sharing. Previews are limited; copy and export use the complete logs.'**
  String get reportPrivacy;

  /// No description provided for @copyTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This report exceeds the 64 MiB clipboard limit. Export TXT to save the complete report without truncation.'**
  String get copyTooLarge;

  /// No description provided for @diagnosticDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get diagnosticDetails;

  /// No description provided for @stackTrace.
  ///
  /// In en, this message translates to:
  /// **'Stack trace'**
  String get stackTrace;

  /// No description provided for @systemCrash.
  ///
  /// In en, this message translates to:
  /// **'System crash details'**
  String get systemCrash;

  /// No description provided for @loadSystemCrash.
  ///
  /// In en, this message translates to:
  /// **'Show system crash details'**
  String get loadSystemCrash;

  /// No description provided for @noSystemCrash.
  ///
  /// In en, this message translates to:
  /// **'No system crash details available. coredumpctl may be unavailable, access restricted, or the dump already removed.'**
  String get noSystemCrash;

  /// No description provided for @reportMetadata.
  ///
  /// In en, this message translates to:
  /// **'Profile: {profile}\nExecutable: {executable}\nPID: {pid}\nStarted: {start}\nStopped: {stop}\nExit code: {code}'**
  String reportMetadata(
    String profile,
    String executable,
    String pid,
    String start,
    String stop,
    String code,
  );

  /// No description provided for @tempHelp.
  ///
  /// In en, this message translates to:
  /// **'The default temporary path is a short private per-profile Linux directory, avoiding Unix socket path limits in Electron/Chromium applications. Explicit temporary paths and TMPDIR overrides are preserved.'**
  String get tempHelp;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateSource.
  ///
  /// In en, this message translates to:
  /// **'Choose the new application source'**
  String get updateSource;

  /// No description provided for @updateHelp.
  ///
  /// In en, this message translates to:
  /// **'Updates are manual. Select a standalone executable, complete folder, tar.gz, tar.xz or tar.zst archive, or a new AppImage. Only application files will be replaced; names, chosen icons, profiles, data and shortcuts remain unchanged. AppImages run as files, without automatic extraction or dependency installation.'**
  String get updateHelp;

  /// No description provided for @updateRunning.
  ///
  /// In en, this message translates to:
  /// **'This application has running profiles. Stop them gracefully before updating. Force kill is never automatic.'**
  String get updateRunning;

  /// No description provided for @updateSummary.
  ///
  /// In en, this message translates to:
  /// **'Replace the application with this source?'**
  String get updateSummary;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @updateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Application updated. Profiles and their settings were preserved.'**
  String get updateSuccess;

  /// No description provided for @managedApplication.
  ///
  /// In en, this message translates to:
  /// **'Managed application — independent of the original source'**
  String get managedApplication;

  /// No description provided for @externalApplication.
  ///
  /// In en, this message translates to:
  /// **'External reference — updating imports a managed copy; external files are never changed'**
  String get externalApplication;

  /// No description provided for @executableCandidate.
  ///
  /// In en, this message translates to:
  /// **'{path} · {size} bytes · {mode}'**
  String executableCandidate(String path, int size, String mode);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
