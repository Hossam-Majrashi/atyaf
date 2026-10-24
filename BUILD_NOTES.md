# Linux builds and distribution

Application ID: `com.h.atyaf`. Version is read from `pubspec.yaml` by both distribution scripts. `/dist` in the project contract means the repository-root `dist/` output directory, not a privileged directory at the filesystem root. Scripts run as an ordinary user and do not elevate privileges.

## Build requirements

Flutter stable with Linux Desktop enabled (verified using Flutter 3.47.7 / Dart 3.13.5), Git, Clang, CMake, Ninja, pkg-config, GTK3 development headers, GLib/GIO headers and the standard C++ toolchain. Linux runtime requirements: GTK3, GLib/GIO, libc, libstdc++, libgcc, X11 libraries, SQLite's `libsqlite3.so.0`, coreutils, Python 3, zstd, xdg-utils and a running XDG Desktop Portal with a file-chooser backend. Native package dependencies include the portal and a compatible backend; AppImage requires a functioning portal on the host. The executable, owner, mode, size and checksum are inspected using coreutils. `update-desktop-database` is optional; profile shortcuts remain valid without it.

After `flutter gen-l10n`, `python3 tool/normalize_l10n.py` removes the generator's unrelated platform documentation without changing localization code. `tool/generate_l10n.sh` combines these commands; distribution scripts normalize automatically.

The release bundle includes the Flutter engine, AOT library, plugins and all Flutter assets. It is dynamically linked against system libraries. Native packages and AppImage require the documented GTK3/SQLite runtime libraries; AppImage is relocatable but does not promise to replace libc or every system graphics library. RPM generates ELF dependency capabilities automatically so dnf/yum/zypper resolve the correct libraries. The verified x64 bundle requires GLIBC 2.34 or later. Build on the oldest supported Linux distribution/toolchain when expanding compatibility; inspect `ldd` and ELF version requirements rather than copying host system libc into a bundle.

Packaging tools: a **real** `dpkg-deb`, `rpmbuild`, `bsdtar`, `zstd`, `tar`, `gzip`, `appimagetool`, `zsyncmake`, `desktop-file-validate`, `appstreamcli`, Curl, Python 3, POSIX awk and coreutils. No FPM dependency is required. AppImage generation uses the architecture-matching appimagetool/runtime and its `--appimage-extract-and-run` mode, so FUSE is not necessary on the build host. Curl fetches the runtime with bounded connection/transfer timeouts, then caches it in `build/appimage-runtime-x86_64` or `build/appimage-runtime-aarch64`; `APPIMAGE_RUNTIME_FILE` can supply a matching offline runtime. The script validates the ELF architecture and passes `--runtime-file` explicitly, avoiding the tool's unbounded automatic download. `tool/generate_icons.sh` additionally requires Inkscape and ImageMagick and invokes icons_launcher exactly 3.1.0 for Linux only.

This host originally had a contents-only dpkg-deb compatibility wrapper and no appimagetool or flatpak-builder. Real dpkg-deb and flatpak-builder binaries were extracted from the official Arch packages into `/tmp/atyaf-tools`, and the official appimagetool x86-64 release was downloaded there. Builds were executed with that directory prepended to PATH. GNOME 50 Platform and SDK were installed user-wide from Flathub. These environment tools are not project dependencies or bundled executables. The full dpkg-deb and appimagetool were subsequently installed persistently in `~/.local/bin` (the previous dpkg-deb script was backed up under `~/.local/share/atyaf-build-tools/backups/`), so the native script now works on this host's ordinary PATH without sudo. Flatpak-builder remains available in `/tmp/atyaf-tools` for the verified Flatpak build.

## Building after cleanup

`build_linux.sh` creates both `dist/` and `build/` before allocating its private packaging workspace, so it can run directly after `flutter clean` or from a fresh checkout. No preliminary manual `mkdir` or Flutter build is required. The EXIT trap removes only that invocation's temporary packaging directory, preserving other build outputs.

## x86-64 (x64)

Run on a native x86-64 Linux machine:

```bash
flutter pub get
flutter gen-l10n
python3 tool/normalize_l10n.py
flutter analyze
flutter test
python3 tool/verify_contract.py
flutter build linux --release --target-platform linux-x64
./build_linux.sh x64
./flatpak_linux.sh x64
```

Release bundle: `build/linux/x64/release/bundle/`. Distribution outputs for pubspec version 1.2.0 (the scripts derive future versions automatically):

- `dist/atyaf-1.2.0-linux-x86_64.deb`
- `dist/atyaf-1.2.0-linux-x86_64.rpm`
- `dist/atyaf-1.2.0-linux-x86_64.pkg.tar.zst`
- `dist/atyaf-1.2.0-linux-x86_64.tar.gz`
- `dist/atyaf-1.2.0-linux-x86_64.AppImage`
- `dist/atyaf-1.2.0-linux-x86_64.AppImage.zsync`
- `dist/atyaf-1.2.0-linux-x86_64.flatpak`

The general tarball contains the complete `opt/atyaf` release bundle and the `usr` desktop/icon/license/metadata install tree. It can be run without installation using the extracted `opt/atyaf/atyaf` executable; its bundled relative library/assets layout must remain intact. The absolute `/usr/bin/atyaf` symlink in the install tree is for installed packages, not for running a tarball in place. AppImage profile shortcuts keep the AppImage file's persistent path.

## AArch64 (ARM64)

Use a native AArch64 Linux machine or a complete AArch64 Linux virtual machine with the matching Flutter Linux ARM64 SDK, GTK3 development libraries, toolchain, packaging tools, AArch64 appimagetool/runtime, and GNOME 50 AArch64 Flatpak Platform/SDK:

```bash
flutter pub get
flutter gen-l10n
python3 tool/normalize_l10n.py
flutter analyze
flutter test
python3 tool/verify_contract.py
flutter build linux --release --target-platform linux-arm64
./build_linux.sh arm64
./flatpak_linux.sh arm64
```

The bundle is `build/linux/arm64/release/bundle/`. All seven output files use the `linux-aarch64` filename suffix; Debian architecture is `arm64`, RPM/Arch/Flatpak/AppImage architecture is `aarch64`. The scripts reject architecture mismatches instead of relabeling x64 binaries as ARM64.

**Verified environment constraint:** this machine is x86-64 and has no native AArch64 build environment. The actual command `flutter build linux --release --target-platform linux-arm64` returned: `Cross-build from Linux x64 host to Linux arm64 target is not currently supported.` The ARM64 package script also rejected the host explicitly. This remains a local-host constraint, not a reason to relabel binaries. The GitHub release workflow now provides a native `ubuntu-24.04-arm` runner; an ARM64 artifact is publishable only after its real build and data-level architecture validation pass.

## Flatpak

GNOME 50 provides the GTK3/Flutter runtime and versioned SQLite runtime library. Flatpak building also requires `elfutils` (`eu-strip`), explicitly checked by the script and installed on CI; minimal package installation must not rely on flatpak-builder's optional recommendations. Before distribution, user-wide runtime/SDK installation is:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//50 org.gnome.Sdk//50
./flatpak_linux.sh x64
```

The architecture-native script reads `flatpak/com.h.atyaf.json`, `.metainfo.xml` and `.desktop`, creates a versioned metadata input from pubspec, builds the release bundle and exports a single-file bundle. Source manifests retain real source paths, not substitution markers. Icon exports use sizes at most 512 as required by Flatpak, including the 256 icon generated by icons_launcher. GTK/Flutter and SQLite work inside the runtime, while host program launch, executable inspection and archives use `flatpak-spawn --host` and the private Python helpers. Host filesystem access and the Flatpak host-spawn permission are intentional product requirements, not a security sandbox claim.

## Verification performed

`flutter analyze` passed without issues; all 66 Flutter tests passed, covering onboarding, locale/theme persistence, RTL/LTR, resizing at 800×600, 1100×760 and 1600×900, path boundaries, executable inspection, Unicode/spaces/shell metacharacters, argument/environment handling, independent profile paths, real process lifecycle/logging, desktop entry escaping, all three archive formats, malicious archives and backup restoration. Source-contract verification checks actual ARB parity, Linux-only structure, exact palette, required files, icon dimensions and prohibited fixed UI text/colors.

The x64 release and all five native formats were built with the scripts, and a Flatpak bundle was built, installed and smoke-launched successfully. Native, AppImage and Flatpak smoke launches remained running until controlled termination, without Dart runtime failures. The installed Flatpak host bridge also executed exact Unicode arguments/environment and persisted the real exit status. GNOME's local cursor-theme warning does not block the application. Flatpak export initially rejected oversized 1024 icon exports and its runtime exposed SQLite only as `.so.0`; both were investigated, fixed in real project files and rebuilt. Metadata and desktop entries were validated. Generated archives/packages contain the complete executable bundle, desktop entry and icons.

## Update 1 verification

The manual-update implementation passed `flutter analyze`, all 51 Flutter tests, `python3 tool/verify_contract.py`, and shell syntax checks. Added tests exercise full folder import and source deletion, all three managed archive formats, multiple candidate selection, saved relative paths, folder/archive replacement, preservation of profile records/data/arguments/environment/custom paths and shortcut contents, changed executable paths, injected database failure after directory swap and rollback, validation failure, running-process refusal followed by graceful stop, legacy portable updates, external-to-managed updates, canonical profile-data aliases, unsafe folder links/special files, backup restoration of managed applications, and absence of remote/background update code. A widget test completes the real folder-update UI through a deterministic file picker, executable choice, summary and success; Arabic/English update source dialogs are checked at all three desktop sizes.

Both Linux distribution scripts were rerun with `PATH=/tmp/atyaf-tools:$PATH`, producing updated x64 DEB, RPM, Arch, general tarball, AppImage and Flatpak artifacts in `dist/`. The previously documented native AArch64 requirement still applies; no ARM64 build is claimed on this x86-64 host.

## Diagnostics release 1.1.0

`flutter analyze`, all 66 Flutter tests and the source-contract checker pass. New service tests cover complete logs beyond 256 KiB, UTF-8 TXT and mode 0600, explicit clipboard-limit refusal with unlimited streaming export, canonical destination/log boundary checks, preservation of previous files on failed exports, durable SQLite error records, real Unix socket binding below 108 bytes with very long XDG roots, custom temporary-path preservation, symlink rejection and optional scoped coredump queries. Six widget tests exercise errors navigation, complete clipboard/TXT content, and expanded failed-launch details in Arabic/English at all three window sizes.

The real reported Antigravity executable was smoke-started with isolated test userdata and the new default TMPDIR. It remained running for eight seconds and exited normally after graceful termination (code 0). No `--no-sandbox` was used. The old stderr's `Socket path too long` failure is addressed; unrelated IDE functionality is not claimed as verified.

All six x64 distribution formats were rebuilt for version 1.1.0. Older 1.0.0 artifacts may remain alongside them; use the explicit 1.1.0 filename when installing. Native Arch and Flatpak installations are independent. A per-user native `com.h.atyaf.desktop` override on this host now points to `/usr/bin/atyaf`, preventing the old user Flatpak export from shadowing the native installation. Installation of a new native package requires the user's package-manager authorization; building does not use sudo. The existing AArch64 limitation remains unchanged.

## Account shortcuts and host-browser verification

The shortcut/browser changes pass `flutter analyze`, all 74 Flutter tests and `python3 tool/verify_contract.py`. `flutter build linux --release` produced the updated native x64 bundle in `build/linux/x64/release/bundle/`. A separate temporary SQLite library was used to smoke-launch an approved profile through that release executable: no Atyaf X11 window was mapped, complete stdout was persisted and exit code 0 was recorded. Tests also run the actual system `xdg-open` against temporary host MIME defaults and a deterministic browser handler, with a conflicting profile default. No complete Antigravity OAuth flow or updated Flatpak runtime smoke is claimed. Existing installed applications and `dist/` package artifacts were not replaced; run the distribution scripts above to package these changes.

## White-square shortcut icon repair

All 77 Flutter tests, `flutter analyze`, source-contract checks, Python helper compilation and the native x64 release build pass. The new asset `desktop_icon_helper.py` uses Python's standard-library ctypes to call existing host GdkPixbuf/GObject/GLib libraries from the GTK3 runtime. It validates and normalizes discovered application logos or the bundled fallback to 512px PNG files. No Pillow/ImageMagick runtime dependency is added. Desktop Icon fields use absolute paths, independent of theme-name cache discovery.

The reported Antigravity logo was found at the nested `resources/app/resources/linux/code.png` path. The host hicolor theme did not index the former 1024-only fallback directory. Both existing shortcuts were repaired without changing account data or launch commands, with desktop-file backups in `build/shortcut-icon-backups/`; the real GTK icon lookup API successfully loaded both images at 64×64. Updated executable: `build/linux/x64/release/bundle/atyaf`. Existing installed executables and `dist/` packages were not replaced; Flatpak host-side support is implemented but a new Flatpak smoke/build is not claimed.

## Project-image icon gallery verification

All 89 Flutter tests, `flutter analyze`, `python3 tool/verify_contract.py`, Python helper compilation and `flutter build linux --release` pass. Twelve new tests cover the paginated gallery/application editor in Arabic/English at 800×600, 1100×760 and 1600×900, retry/cancel/automatic selection, real folder-import cancellation and cleanup, import/edit-driven existing-shortcut refresh, nested project scanning with symlink confinement, decoding/normalization, archive selection and icon preservation through application replacement and backup restoration.

Selected images are saved as bounded, normalized PNG copies in the application's SQLite JSON record. No imaging dependency was added; decoding still uses the host GTK3 GdkPixbuf runtime. The x64 bundle is available at `build/linux/x64/release/bundle/atyaf`; keep its `lib` and `data` siblings intact. Existing installed binaries and `dist/` packages were not replaced. The existing Flatpak host bridge is used by gallery operations, but no updated Flatpak build/smoke or AArch64 build was performed for this change.

## Continuous scrolling and launch-diagnostics verification

All 101 Flutter tests, `flutter analyze`, source-contract verification, Python helper compilation and the x64 Linux release build pass. The gallery is now a virtualized scroll grid over all matching images, not a paginated grid; serialized forty-image requests and an eight-batch cache bound preview memory. Tests reach the last of 2000 images, exercise both locales/all window sizes, and retain real import/edit/shortcut regressions.

New lifecycle tests hold log completion after PID exit and verify that window destruction waits for the real journal commit, including cross-instance reconciliation. The host-browser tests run the real xdg-open against a deterministic KDE 6 handler, confirming preservation of KDE_SESSION_VERSION and the absence of legacy integer warnings. Diagnostics/UI/report tests preserve complete raw output and explain TLS authority errors, disabled/unavailable wallets and unrecoverable interrupted exit status. Four secure-store editor tests verify explicit confirmation/cancellation and preservation of unrelated arguments, profile data paths and approval.

Host KWallet was found disabled and a GNOME Keyring Secret Service active. Those settings, profile arguments and old launch history were inspected read-only and not changed. The new encrypted-store option is opt-in for compatible Electron/Chromium apps, with a re-login warning. No TLS checks were disabled; the failing TLS endpoint is unknown from the supplied report. No claim of live Antigravity TLS/authentication repair or automatic credential migration is made. Updated executable: `build/linux/x64/release/bundle/atyaf`; installed binaries and `dist/` packages are unchanged, and no new ARM64/Flatpak build was performed.

## Clear-diagnostics verification

All 110 Flutter tests, `flutter analyze`, source-contract verification and the native x64 release build pass. The Errors and diagnostics page now offers a confirmed Clear errors action. The Linux repository transaction deletes only the captured Atyaf error IDs and dismisses unchanged completed failures; it preserves launch history, exit metadata and output files. Errors/new or changed launches arriving during confirmation are retained, and genuine late final failures reset their dismissal flag.

Nine new tests cover both locales/all three desktop sizes, cancellation, late/new diagnostics, empty-button state, persistent dismissal, running/changed-record protection, bound SQL parameters, rollback after an injected database failure, UI error reporting, and profile/application/log preservation. Only temporary test libraries were cleared, not the user's stored diagnostics. Updated executable: `build/linux/x64/release/bundle/atyaf`; keep the bundle's `lib` and `data` siblings intact. Installed binaries and distribution packages were not replaced; no new Flatpak or ARM64 build was performed.

## In-app icon flicker verification

All 116 Flutter tests, `flutter analyze`, source-contract verification and the native x64 release build pass. The library's one-second reconciliation refresh previously constructed a new decoded byte buffer/MemoryImage on each rebuild. The new desktop icon renderer retains the provider for unchanged PNG content, and application-ID row keys preserve its state across reordering. The editor and gallery use the same renderer; new or removed icons still update, without retaining stale images through gapless playback.

Six new tests assert both provider identity and the actually displayed frame immediately across the production timer under the widget test clock, Arabic/English split views, fresh SQLite models, rename/reorder/selection, content replacement/removal, theme/size/semantics changes and malformed-image fallback. Real Linux helpers and SQLite verify that rendering refreshes leave profile records and installed shortcut PNGs unchanged, including after original source deletion. Existing gallery/editor tests continue to cover all window sizes and bounded virtualization. No persistence migration, account changes or timer suppression was needed.

Updated executable: `build/linux/x64/release/bundle/atyaf`, with its `lib` and `data` siblings required. Installed applications and `dist/` artifacts were not replaced; no new Flatpak or ARM64 build was performed.

## Direct image-picker verification

All 125 Flutter tests, `flutter analyze`, source-contract verification and the native x64 release build pass. The icon gallery provides a new Choose image from device action alongside the existing folder-only chooser. The native single-file picker filters PNG/other gallery image formats, including uppercase extensions, and does not eagerly load source bytes. `LinuxDesktopEntries.readImage` reuses the confined GTK preview decoder for one normalized PNG; all input/output bounds and independent-copy persistence are retained.

Nine new tests cover both locales/all window sizes, file-vs-folder picker calls, cancellation/native failures/damaged images, preserving/replacing the editor icon, duplicate requests and late responses after dismissal. Real Linux decoding/SQLite/shortcut tests exercise special-character PNG paths, source deletion and database reopening, source/profile preservation, invalid/missing/oversized images, dimensional limits, escaping symlinks and relative/NUL paths. Installed plugin source was reviewed for Linux portal filters and no-byte-loading options; widget tests mock the native chooser, not a live portal session. Existing continuous-gallery and flicker regressions still pass.

Updated executable: `build/linux/x64/release/bundle/atyaf`; keep its `lib` and `data` siblings intact. Installed binaries and `dist/` artifacts were not replaced; no new Flatpak or ARM64 build was performed.

## Multi-format icons and GTK window controls

All 133 Flutter tests, `flutter analyze`, source-contract verification, Python helper compilation, formatting/diff checks and the native x64 release build pass. Image scanning and native picker filters now share the enabled formats advertised by installed GdkPixbuf loaders. JPEG, GIF, BMP, SVG and PNG fixtures are decoded and persisted as independent static PNG copies without altering original bytes; existing safety limits, uppercase extensions, cancellation and continuous-gallery tests still pass. Additional formats depend on installed decoders; the UI lists advertised formats rather than requiring PNG sources.

A read-only native GTK3 settings probe on the current KDE/Wayland host reproduces `menu:close` with isolated XDG config, versus full minimize/maximize/close on X11 using the same isolated paths. Copying the host's gtk-decoration-layout alone still yields `menu:close` on Wayland, so that ineffective prototype was removed. The editor instead offers an explicit confirmed GTK X11/XWayland option, enabled only when the host advertises DISPLAY. It sets one profile-local GDK_BACKEND value; Save/restart is required. Arabic/English widget tests verify confirmation/cancellation, delayed saving, other-field preservation, disabled availability and invalid-JSON handling; Linux tests verify environment isolation. No host configuration, dconf, credentials, application-specific settings or existing profiles were modified during development. The probe verifies GTK settings, not a live affected-program title-bar interaction; non-GTK/custom title bars and non-resizable dialogs are not claimed repaired. Scaling and Wayland integration may differ; confirmation also warns of X11's weaker window isolation. Updated executable: `build/linux/x64/release/bundle/atyaf`; keep the `lib` and `data` siblings intact. Installed binaries and `dist/` artifacts were not replaced; no new Flatpak or ARM64 build was performed.

## Electron window-button inheritance on Wayland

All 140 Flutter tests, flutter analyze, source-contract verification, helper compilation, formatting/diff checks and the native x64 release build pass. Actual profile queries reproduce appmenu:close for VS Code and both Antigravity installations, versus full host window controls. A profile-local compiled GSettings default now supplies only the host button-layout value; all other wm.preferences defaults/enums and parent schema lookup remain intact. Existing backend values, GTK layout, custom config/schema/backend choices, editor files, arguments and credentials are preserved. No dconf data is copied or written, and no automatic X11 switch occurs. Generation is confined to owned private managed directories, bounded/timed, checksummed, and atomically published. Missing host gsettings/glib-compile-schemas/schema XML makes this cosmetic integration unavailable, not an application launch error.

Seven new Linux regressions verify schema/default fidelity (including compiled distribution overrides), persistence/non-copying, cache integrity and host updates, explicit choices, aliases and native GTK3 Wayland behavior. The latter changes native gtk-decoration-layout from menu:close to minimize/maximize/close with the same Wayland backend. Existing profile widget tests verify the revised localized explanation; desktop matrix and unrelated icon/process/backup tests still pass. User libraries and host preferences were only read. No live user's VS Code/Antigravity window interaction is claimed; the tested GTK property is the native setting consumed by Electron controls. Updated executable: `build/linux/x64/release/bundle/atyaf`, requiring its `lib` and `data` siblings. No new Flatpak/ARM64 build or installed/dist artifact replacement is claimed.

## Hidden shortcut drain supervision

All 145 Flutter tests, clean `flutter analyze`, source-contract checks, diff checks and the native x64 release build pass. Hidden shortcuts await actual local process/log completion without a deadline or database-stop polling. Visible close retains its five-second bound and leaves the window open with a localized pending-log notice, without adding a spurious error. Expected duplicate contention also gets localized feedback; genuine shortcut failures fall back to the desktop without an automatic second launch. Approval review, identity validation, stream persistence and separate graceful/force termination behavior remain intact.

Regressions include a real Linux fork whose helper keeps stdout/stderr open beyond five seconds, cross-instance reconciliation and late final persistence, a launch race, pending-output launch refusal, and English/Arabic shutdown/retry. A native release smoke in a temporary library verified survival past the deadline without an X11 fallback window, one launch, complete late stdout/stderr, exit code 0 and no Atyaf errors. The user's SQLite records were only queried; their historical Studio exit code 2 and empty logs were not rewritten or diagnosed beyond available evidence. Hidden supervisors can intentionally remain alive until inherited pipes close; independently daemonized children are not newly tracked or killed.

Updated executable: `build/linux/x64/release/bundle/atyaf`, requiring its `lib` and `data` siblings. Installed binaries and `dist/` artifacts were not replaced; no new Flatpak/ARM64 build or live user IDE reproduction is claimed. Normalize generated localization documentation after building with `python3 tool/normalize_l10n.py` before running the source-contract checker.

## Non-stopping desktop close

All 152 Flutter tests, clean `flutter analyze`, source-contract/diff checks and `flutter build linux --release` pass. Closing now hides the window immediately without stopping programs. Local launch/restart and stream supervision continues without a shutdown deadline; the process exits after its own output/exit commits complete. Applications owned by an independent shortcut supervisor do not delay the visible instance's exit. Genuine close failures restore the UI. Eleven revised/new localized desktop tests use real Linux children and SQLite plus mocked native window calls to cover running/local/external/draining/preparing/idle closes, repeated events, full logs and failure recovery.

The initial release build failed because the generated CMake cache retained the old `/home/hossam/StudioProjects/atyaf` path after project relocation. Its generated release directory was preserved as `build/linux/x64/release-before-window-close-*`, then a clean build succeeded at `build/linux/x64/release/bundle/atyaf` (keep sibling `lib` and `data`). No installed binary, user library or `dist/` artifact was replaced. No new Flatpak/ARM64 build or live user IDE close interaction is claimed.

## Managed AppImage support

The desktop Add application and manual Update menus accept AppImage files through the native single-file portal filter. Import stores a private, executable, independent `application.AppImage` copy below managed application storage. Updates reuse the existing locked staged replacement/rollback mechanism; names, chosen icons, profile data and shortcuts are preserved. The source is checked/copied as data by the existing Python helper, never executed. Embedded icon reading now uses host 7-Zip (`7zz` or `7z`); native package metadata recommends the optional `7zip` package, with explicit localized notices and manual selection when missing. AppImage/Flatpak users also need this tool on the host; the existing Flatpak host bridge is reused. Running a particular AppImage can still require host FUSE and its own dependencies, which are not installed or bypassed automatically.

Verification: `flutter analyze`, all 191 tests with `flutter test --concurrency=1`, `python3 tool/verify_contract.py`, in-memory Python helper compilation, `git diff --check` and `flutter build linux --release` pass. Added coverage includes Arabic/English desktop import/edit/icon/update at all three supported test sizes, cancellation, header/type and resource checks, source preservation, two approved isolated-profile launches, stale approval, rollback, shortcut/icon/profile persistence and backup restoration. Process fixtures are native ELF files carrying AppImage identification bytes, allowing deterministic launch checks without a FUSE dependency; these do not establish third-party image compatibility. The real existing distribution AppImage was also copied/validated without execution in a temporary directory, with SHA256/source-mode/staged-mode assertions. A parallel full run encountered an icon-frame timing failure; the full serial rerun passed without an icon-rendering change.

Updated bundle: `build/linux/x64/release/bundle/` (keep executable, `lib` and `data` together). Its bundled archive helper matches the updated source. User libraries/profiles, installed binaries and `dist/` artifacts were not replaced. No new Flatpak/ARM64 package build or live third-party AppImage/FUSE launch is claimed.

### Embedded icon repair

The screenshot's empty gallery was caused by scanning a directory containing only the copied AppImage. `appimage_icons.py`, deployed beside the existing GTK icon helper, now lists SquashFS/ISO members and reads selected icon/desktop/link members through 7-Zip stdout. It never invokes the image runtime, AppRun, mounting or filesystem-wide extraction. It handles internal link chains and falls back from broken `.DirIcon` links to desktop Icon matches and internal logos. Only normalized PNGs are published below `.appimage-icons`, plus a private `.DirIcon` copy for automatic shortcut discovery. Paths from the archive are never host output paths. Reader subprocesses have bounded stdout, deadlines and CPU/address-space/descriptor limits; member/image/count/byte/link-chain limits and GTK's existing size/dimension checks apply. DwarFS is explicitly unsupported by this reader, rather than silently presenting an empty gallery.

Import's automatic action now persists the detected PNG for immediate library/shortcut display. An optional `Application.iconAutomatic` JSON field (false for old records) distinguishes automatic icons from manual overrides; updates replace automatic icons only when a new one was read, retain previous icons on reader failure, and refresh existing shortcuts under the library lock. Manual images remain unchanged. Restoring automatic discovery from the editor resolves the managed `.DirIcon` copy. No schema migration or user-account mutation is performed during development.

Verification: clean analysis, all 196 Flutter tests with `--concurrency=1` (including eleven Python reader boundary checks invoked by one test), source-contract/shell/diff checks, helper compilation and native x64 release build pass. Six localized import/edit/icon/update flows now use actual tiny SquashFS/ISO icon fixtures and check gallery thumbnails, automatic library icons and manual override preservation at all three sizes. New Linux tests cover real filesystem parsing, automatic replacement, SQLite/backup/shortcut preservation and missing tools; reader tests cover broken/absolute/internal/cyclic/escaping links, duplicate/unsafe paths, special/oversized members, damaged images, destination aliases, bounded output/time and candidate counts. The actual downloaded EpicGamesLauncher AppImage was read without execution in temporary storage: its `.DirIcon` points into a defunct CI workspace, but its correct Epic Games logo was recovered through internal desktop/icon fallbacks. The other downloaded RPCS3 image uses DwarFS, for which the UI reports unsupported parsing. No live AppImage program launch, ARM64 build or new distribution package build is claimed. Updated bundle remains `build/linux/x64/release/bundle/`; installed files, user accounts and `dist/` packages remain unchanged.

## Per-profile terminal commands

The desktop profile card/menu now opens an ARB-localized Terminal command dialog. Creating `rpcs3` installs a 0700 Python wrapper in host `~/.local/bin` which execs the persistent Atyaf launcher with `--launch-profile ID`, preserving approval, duplicate refusal, account settings and complete logs. Native installations use their configured executable; AppImage uses the persistent ATYAF_LAUNCHER path; Flatpak renders `/usr/bin/flatpak run com.h.atyaf`. The wrapper binds HOME/XDG_DATA_HOME to the originating library, rejects extra arguments with a localized message and does not bypass Atyaf. It is a foreground supervisor, not a detached terminal daemon. No new dependency is needed beyond existing Python 3.

`terminal_commands.py` runs through the existing host-command bridge and is privately deployed as a Flutter asset. A private, library-local registry records profile IDs and exact wrapper SHA256 values; it is not included in backups. Directory-relative no-follow operations, ownership/mode checks, regular-file/single-link checks, a registry lock and exclusive new-file publication protect user files. Invalid/common builtin names, files/links already using a name, another profile/library's wrapper and other executable PATH matches are refused. Changed wrappers are never overwritten or deleted. Creation uses the library lock; profile deletion and successful restoration remove only unchanged tracked wrappers. Shell configuration/aliases/functions are never modified. The dialog displays PATH guidance when necessary, existing commands and confirmed removal.

Verification: clean `flutter analyze`, all 216 Flutter tests serially, source-contract/diff checks, helper compilation and the native x64 release build pass. Twenty added tests cover real terminal invocation/exact argument and library binding with Unicode/quotes/metacharacter paths, extra-argument refusal, multiple accounts, collisions, invalid/builtin names, modified-file preservation, unsafe parent/registry aliases, missing PATH/no shell-file changes, concurrency, deletion/restore and Arabic/English creation/confirmation/cancellation/errors at all three desktop sizes. A separate temporary-library native release smoke invoked a terminal wrapper, launched exactly one approved isolated test profile, persisted complete stdout/stderr and exit 0, and recorded no Atyaf error. At the user's request, `~/.local/bin/rpcs3` was then created for the existing RPCS3 profile using `/usr/bin/atyaf`; `command -v rpcs3` resolves it and selected application/profile records were checked unchanged. RPCS3 itself was not launched during installation. No installed executable or distribution package was replaced, no shell startup file edited, and no new Flatpak/ARM64 build is claimed. Updated feature bundle: `build/linux/x64/release/bundle/`.

## Version 1.2.0 release pipeline

`build_linux.sh` and `flatpak_linux.sh` retain Flutter's internal x64/arm64 targets but name external artifacts `atyaf-<version>-linux-x86_64.*` or `atyaf-<version>-linux-aarch64.*`. Other architectures fail before allocating build directories. Flutter Linux has no armv7/i686 target in this SDK; no 32-bit release files are fabricated. Version 1.2.0+3 includes the already-verified desktop AppImage/icon/terminal-command features and their Linux integration; packaging adds no new runtime UI or automatic updater.

AppImage embeds `gh-releases-zsync|Hossam-Majrashi|atyaf|latest|atyaf-*-linux-<arch>.AppImage.zsync` and a versioned GitHub download URL. zsync is generated from the completed image, from within dist because appimagetool emits the control file into its current directory. Both files must exist. RPM explicitly uses format 4 and gzip payload for compatibility with older distribution tools even when built by RPM 6.

`tool/verify_release.py` reads payloads without executing/installing applications. It checks the native bundle and every plugin's ELF64 machine before packaging; verifies native package executable, AOT and engine headers and DEB/RPM/Arch architecture metadata; checks AppImage identification plus zsync filename/length/SHA1 binding; imports Flatpak into a disposable OSTree repository to check its ref, executable/AOT/engine machine and release metadata. RPM inspection uses a private temporary DB and rpm2cpio; no host package DB or Flatpak app installation is modified. `--write-checksums` emits SHA256SUMS only after every requested package passes. Inspection additionally needs rpm/rpm2cpio, bsdtar, flatpak and ostree.

`.github/workflows/release.yml` supports version-tag pushes and manual dispatch, with a pinned Flutter 3.47.7 SDK and native Ubuntu 24.04 x86_64/AArch64 runners. It runs analysis, the serial full suite and contract checks in parallel with building/validating seven assets per architecture; publication depends on every job succeeding. Its publication job revalidates all fourteen, creates checksums, uploads all fifteen files to a draft, checks asset count and only then publishes. Existing published releases are never overwritten; an existing version tag must point to the checked source commit. Manual publication creates the new version tag at that exact commit; no embedded/persisted personal token is used by CI (only its repository-scoped temporary GitHub token). SDK/build tools are installed on the runners, not in user libraries.

Local verification: clean analysis and all 221 Flutter tests pass, including ten Python validator boundary tests invoked by a Flutter test and four explicit native/Flatpak armv7/i686 rejection cases. All seven native x86_64 1.2.0 files were built with the actual scripts and passed the real package/Flatpak validator; SHA256SUMS was generated. Existing 1.1.0 dist files were preserved. ARM64/remote publication is separately verified through the workflow outcome, not inferred from local mocks. Installed applications, accounts and credentials are unchanged by this release build. Release notes explain dependencies, supported targets, zsync and checksum verification in both languages.

The first hosted run caught fixture assumptions absent from this workstation: Ubuntu 24.04's 7-Zip 23 cannot decode the original Zstd SquashFS fixture, and its older xdg-open needs display metadata/version-suffixed KDE handlers. Regenerated the same data-only SquashFS fixture with gzip, supplied both KDE handler spellings and a nonconnecting fixture DISPLAY, and made xdg-utils an explicit CI dependency. All 34 affected desktop/icon integration tests pass locally using the actual official 7-Zip 23.01 binary. Upstream xdg-utils 1.1.3 has no KDE 6 case and silently does nothing for that value; dispatch verification always tests supported KDE 5 and additionally KDE 6 on modern scripts, while the independent wrapper test always asserts KDE 6 metadata preservation. No failing test is skipped; the pre-existing real Wayland GTK probe remains conditional on an available Wayland session. Ubuntu xdg-utils 1.1.3 also splits whitespace in public MIME directory discovery; the real default-browser test now uses ordinary space-free public MIME directories while retaining Unicode/space paths for the isolated profile and browser executable. Arbitrary host path preservation remains covered by the direct-wrapper test. This was reproduced with the actual Ubuntu package, not assumed to be an Atyaf fix. Normalize generated localization documentation after tests before the source-contract gate.

### Published verification — v1.2.0

Published https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.0 from commit `ca538e8c37d5e4cf238b6c2e57a1d1961902ab37`. Workflow https://github.com/Hossam-Majrashi/atyaf/actions/runs/39456312549 completed successfully: analysis/tests, native x86_64 and AArch64 builds, both Flatpaks, and final publication/inspection. The release has fourteen architecture-specific files plus SHA256SUMS; the old Release/1.1.0 assets were preserved. No armv7/i686 files are provided.

Downloaded all fifteen public release assets into `dist/github-v1.2.0/`, checked every published SHA256SUMS entry and available GitHub asset digests, then independently re-inspected both architecture sets with `tool/verify_release.py`. All ELF64 headers, native package metadata, zsync bindings and Flatpak refs/payload/version metadata pass. These are actual ARM64 binaries from a native runner, not relabeled x64 outputs. No ARM64 GUI runtime smoke is claimed. Existing top-level local dist files were preserved separately.

Latest local verification also passes in a headless environment with the actual old 7-Zip 23.01 reader: 220 executed tests plus the one pre-existing Wayland-session-only test skipped when Wayland is absent. The earlier full workstation run executed all 221 successfully. Analysis is clean. A locally built x86_64 AppImage was also smoke-launched with one approved fixture in a temporary independent library; its runtime/AppRun/supervisor preserved complete stdout/stderr and exit 0 with no Atyaf errors. RPCS3 and other user profiles were not launched or changed, and no installed application was replaced.

## Version 1.2.1 — KDE shortcut repair (local build)

The desktop shortcut flow now presents already-running windows on KDE instead of silently exiting. The Linux supervisor optionally uses the privately deployed profile_windows.py host helper: boot/start/UID-checked process trees, exact Tauri SingleInstance ownership for tray restoration, and temporary PID-scoped KWin activation scripts with cleanup. Window resource classes discovered during the first 30 seconds populate missing StartupWMClass; StartupNotify=false removes misleading pending-launch icons. Explicit classes are retained. Automatically learned classes have a desktop-entry provenance marker, so icon refresh preserves them while clearing a manual application class still resets to automatic discovery. This uses optional gdbus/KWin APIs, with no new mandatory package dependency or permanent compositor rules. Other desktops retain manual StartupWMClass. Shared classes may share taskbar groups; no universal per-profile grouping guarantee is made.

Version 1.2.1+4 passed clean analysis and all 223 Flutter tests serially, including twelve Python window-helper boundary tests. Existing Arabic/English desktop flows at 800x600, 1100x760 and 1600x900 remain covered. Source-contract, helper compilation, shell/actionlint and diff checks pass. An actual native release smoke in temporary libraries confirms first-launch review is visible with zero executions before approval, and an approved shortcut remains hidden while complete stdout/stderr and exit 0 persist. On the live KDE/Wayland host, Epic's existing tray window was restored without a duplicate; the approved RPCS3 profile launched/reopened without an Atyaf window or an extra launch record. Its real window class is AppRun. Existing Epic/RPCS3 shortcuts were backed up under build/window-shortcut-backups and repaired in integration fields only; application/profile payload hashes remained identical. No settings or credentials were changed, although ordinary launch logs/history were created by the runtime checks.

Both actual x86_64 packaging scripts completed again with this source. The seven 1.2.1 files (AppImage, zsync, DEB, RPM, Arch, tar.gz, Flatpak) in dist passed verify_release.py, including ELF64/payload/version metadata, zsync binding and disposable Flatpak import. dist/SHA256SUMS currently describes these seven local 1.2.1 files; older versioned packages/downloaded 1.2.0 checksums remain preserved. No ARM64 build or hosted publication occurred for 1.2.1. /opt/atyaf and the installed shortcut Exec paths remain unchanged; install the new build to activate the runtime fix from the system menu.

At the end of that local-build session, GitHub publication was pending because the available personal credential had been exposed. The user subsequently renewed publication authorization; the verified hosted build/publication below supersedes that pending status. The exposed credential should be revoked, and new credentials must not be placed in chat, tracked files or remote URLs.

### Published verification — v1.2.1

Published https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.1 from source commit b2c8d5a65f2a6aa65b825e97d207eb50c63d0431. GitHub Actions run https://github.com/Hossam-Majrashi/atyaf/actions/runs/39468368964 completed analysis/tests, both real native x86_64/AArch64 build jobs and the final publication job successfully. All seven package/control files per architecture were built and inspected on the matching runner, including Flatpak; publication re-inspected both sets together and generated SHA256SUMS. The tag targets the checked source commit, and the release is public, non-draft and non-prerelease with exactly fifteen assets. v1.2.0 was not overwritten.

All public downloads were retrieved without authentication headers into dist/github-v1.2.1, independently hashed against the GitHub asset digests and the fourteen entries in the published manifest, then passed the full local verify_release.py check for both x86_64 and aarch64. This revalidates actual ELF64 payloads, native metadata, zsync binding and temporary-imported Flatpak refs/release metadata without installing the applications or executing ARM64 binaries. No ARM64 GUI smoke is claimed. The complete local 223-test suite and analysis also passed again for this publication session; no runtime code, user accounts or installed binaries changed.

Git used its existing local credential provider and token-free origin URL; the local API helper reads credentials only in memory, and public downloads never carry Authorization headers. No personal token was written to project source, workflow, release assets or helper scripts. CI publication used its temporary repository token. The user should revoke the exposed personal credential after publication. Source is pushed to main; binaries remain release assets rather than Git history.

## shadPS4 CLI startup — 1.2.2

The desktop profile editor has an explicit, confirmed `--big-picture` helper for compatible shadPS4 CLI builds. Startup advice now recognizes CLI help in stdout as well as stderr; it does not alter complete logs, guess executable-specific defaults, download a launcher or migrate emulator data. The reported empty-argument profile was repaired with a private backup and guarded update of that field only. Upstream https://github.com/shadps4-emu/shadPS4/blob/main/src/main.cpp documents the no-arguments return -1/help branch and Big Picture mode; Linux exposes that return as 255.

All 238 serial Flutter tests, analysis and source-contract/diff checks pass. Added tests exercise both languages/all three editor sizes, confirmation/cancellation, invalid JSON, idempotence, guest delimiters, unchanged settings and real Linux argument-list/XDG/full-log behavior. Existing bilingual log widget checks now cover stdout advice, and full reports preserve output beyond the preview limit. The native x86_64 release executable compiled. A real disposable-configuration shadPS4 startup with `--big-picture` reached its visible Save Migration prompt instead of CLI usage; no migration choice was made and no game or full UI flow is claimed. Native/Flatpak release packaging and hosted publication are independently verified below. Installed Atyaf binaries remain unchanged.

### Published verification — v1.2.2

https://github.com/Hossam-Majrashi/atyaf/actions/runs/39482472542 completed all four jobs successfully, building seven actual files each on native x86_64 and AArch64 runners (including Flatpak) and publishing the fifteen-asset release https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.2. Its tag targets checked source f087c6e11044226a17d26712e6b8cd193e9646b3. Previous releases remain intact. Every public file was downloaded unauthenticated into `dist/github-v1.2.2` and checked against GitHub SHA256 digests and the published manifest; both complete architecture sets then passed local ELF64/package metadata/AppImage-zsync/temporary Flatpak-import validation. ARM64 payloads were not executed or installed.

Both local x86_64 packaging scripts also returned 0, and all seven local 1.2.2 files passed validation. `dist/SHA256SUMS` describes those local outputs; the previous checksum file was preserved as `dist/SHA256SUMS-before-1.2.2`. The exact final source passed all 238 tests serially again and clean analysis, source-contract, shell/actionlint and diff checks. A real x86_64 release smoke in disposable libraries confirmed visible first approval without execution and hidden approved launch with full streams/exit 0. There is no claim of ARM64 GUI or complete shadPS4 migration/game testing. Existing installed binaries remain unchanged; the user's existing shadPS4 profile was repaired only in its arguments, with a private local pre-change backup excluded from Git.

## Large-library performance — 1.2.3

The desktop sidebar and compact selector share a searchable lazy application list; profile cards use slivers. SQLite retains unchanged validated application/profile snapshots, detects external/local commits and bypasses retention across transactions. History uses a parameter-bound profile query and additive expression index. No reconciliation, output capture, approval or account storage behavior is disabled to improve responsiveness.

Local analysis and the final complete 251-test serial run pass. Six bilingual/three-size widget tests exercise 2000 applications and 2000 accounts, bounded mounted widgets, search/selection/empty states and last-account scrolling. Six SQLite regressions cover invalidation/immutability/rollback/icon validation/indexed history. Existing dialog tests now scope field finders to dialogs rather than the sidebar search field. No wall-clock/FPS guarantee or faster external-program startup is claimed.

Both native and Flatpak x86_64 packaging returned 0; all seven `dist/atyaf-1.2.3-linux-x86_64.*` outputs and the regenerated checksums pass the existing full validator. The prior checksum manifest is preserved. Bundle: `build/linux/x64/release/bundle/atyaf` with its sibling lib/data. Installed executables and user libraries remain unchanged. ARM64 build and public release success require independent hosted verification.

### Published verification — v1.2.3

All four jobs in https://github.com/Hossam-Majrashi/atyaf/actions/runs/39492458391 succeeded, building native x86_64 and AArch64 packages and Flatpak, running analysis/tests, jointly validating fourteen files and publishing fifteen assets at https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.3. The tag targets source `4783457cf445`. Public downloads in `dist/github-v1.2.3` match GitHub SHA256 digests and all fourteen published checksums; both architecture sets pass the full independent local validator without executing ARM64 applications. Previous releases are preserved. The supplied-path checkout was also fast-forwarded safely, with seven new local x86_64 packages and a separate verified checksum manifest copied into its dist directory. No installed binary, profile or credential data was changed.

## Managed executables and KDE taskbar-class repair — 1.2.4

Executable imports now use the existing private host Python helper to stream one standalone executable into managed staging without running it. Final symlinks/FIFOs/special/empty/non-executable/privileged files, unsafe basenames, concurrent content changes and files above 8 GiB are rejected; the source is untouched and only the copy gets mode 0700. The existing managed transaction, rollback, backup and confinement cover both Add and explicit manual Update. Import full folders for neighboring resources/libraries. The desktop Add menu lists file types/formats in both languages. KDE window integration rejects automatically learned generic AppRun classes and repairs old managed mappings without touching manual classes or adding compositor rules.

All 263 final serial Flutter tests, clean analysis, fourteen Python window-helper boundary tests through the suite, source-contract/format/diff/shell/actionlint checks pass. The bilingual desktop flows cover all three sizes, independent source-deletion-safe imports, manual replacement, descriptions and cancellation with real Linux services and a substituted file picker. Real native x86_64 and Flatpak packaging succeeded; all seven local `dist/atyaf-1.2.4-linux-x86_64.*` outputs pass ELF/package/zsync/Flatpak validation. The previous manifest is retained as `dist/SHA256SUMS-before-1.2.4`. A disposable-library native release smoke explicitly approved a managed fixture, deleted the original source, and verified one supervised launch, isolated data, complete streams and exit 0. No real user application was launched for that smoke.

### Published verification — v1.2.4

All four jobs in https://github.com/Hossam-Majrashi/atyaf/actions/runs/39702766803 succeeded for source `ec66e51fcd8b`, including native x86_64/AArch64 packaging and Flatpak, analysis/tests and joint publication. The tag points to that source and https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.4 is public with fifteen assets. Every public file in `dist/github-v1.2.4` matches GitHub SHA256 digests and the fourteen-entry published manifest; both architecture sets pass the full independent local validator. No ARM64 application was executed or installed. Prior releases/packages and installed Atyaf binaries are preserved. The user-requested existing rusty-psn entry was migrated to a byte-verified managed copy, and only automatic AppRun lines were removed from the two affected shortcuts, with private original backups under ignored `build/`; account payloads and original executable permissions remain unchanged. No live emulator taskbar interaction or universal grouping guarantee is claimed. User data/backups and personal credentials are not in Git or release assets.

## XDG special-folder startup repair — 1.2.6

LinuxRuntime now prepares profile-local Documents, Downloads and six other standard XDG folders for default config/data paths. The bounded no-follow host Python helper writes private directories and checksummed user-dirs.dirs defaults, preserves existing user files/custom settings and refreshes untouched generated paths after relocation. This fixes the reproduced xrevive 0.1.22 Tauri setup unknown-path failure without changing HOME, application bytes, approval, arguments or credentials. Desktop editor help and exact-signature log/report advice are ARB-localized in both languages.

All 280 local serial Flutter tests, analysis and source-contract checks pass; native x86_64 and Flatpak scripts returned 0. All seven local `dist/atyaf-1.2.6-linux-x86_64.*` files and SHA256SUMS pass the real package/ELF/zsync/Flatpak validator. A disposable-library release smoke observed the real xrevive window after twelve seconds, no panic and no visible Atyaf fallback, then deliberately terminated that test process and verified persisted exit -15/complete streams. Without the folder definitions, the control exits 101. Source bytes/mode are unchanged. First-approval/hidden-supervision release smokes also pass. Authentication, gameplay and ARM64 graphical runtime are not claimed; hosted dual-architecture publication requires separate verification. The existing user's xrevive profile received only missing empty private folders/default definitions under the library lock, with all application/profile payloads unchanged. Installed Atyaf binaries remain untouched.

### Published verification — v1.2.6

All four jobs in https://github.com/Hossam-Majrashi/atyaf/actions/runs/39850228640 succeeded for source `cd141aee76d0552b4e8d6780feabd05da40eaa76`, including native x86_64/AArch64 packages and Flatpak, analysis/tests and joint publication. The v1.2.6 tag targets that exact source; https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.6 is public with fifteen assets. All public downloads in `dist/github-v1.2.6` match GitHub SHA256 digests and the fourteen-entry published manifest; both architecture sets independently pass the full local package/ELF/zsync/Flatpak validator. No ARM64 code was executed or installed. Prior releases, user account payloads and installed binaries remain preserved. The local xrevive fix and disposable-library smoke limits are documented above; credentials/private data were not uploaded.

## Internal-update supervision and lock wait — 1.2.7 source update

Version 1.2.7+10 passes clean analysis, all 293 serial Flutter tests, normalized localization/source-contract, formatting, shell syntax and diff checks. Native x86_64 release compilation returned 0; bundle is `build/linux/x64/release/bundle/atyaf` with adjacent `lib` and `data`. The disposable-library native smoke verifies visible first-approval/no execution followed by a hidden approved launch with complete stdout/stderr, exit 0 and no application errors. No installed executable, user library/profile/credential, old package or historical diagnostic was replaced.

The Linux lock tests use an independent Python process with real POSIX fcntl record locks, not flock/mocked contention. They check bounded asynchronous errno-11 waiting, cleanup and process-local connection/alias coordination. The self-updater fixture actually replaces its executable and starts a child retaining both streams: the original parent's exit 0 remains distinct from the child's exit 7, and changed bytes require fresh approval. PID/boot/start-verified supervisor ownership keeps the lifecycle reserved until complete output persistence, with bilingual pending-state desktop controls and update/heap diagnostic advice. Independent detached processes remain outside tracking; no final Epic exit or heap-corruption repair is inferred.

This session builds the native release bundle only, not new dist/Flatpak packages or an ARM64 binary. Source push is separate from release/tag publication; do not infer hosted builds or downloadable 1.2.7 assets from the version number. Existing 1.2.6 release packages are preserved. No personal token or private user data is included in Git.

### Published verification — v1.2.7

The user-authorized tag v1.2.7 targets `b5662b3eb482c166b5bc06d73688dcaf5ec099a3`. All four jobs in https://github.com/Hossam-Majrashi/atyaf/actions/runs/40053293581 succeeded: analysis/tests, native x86_64 packages, native AArch64 packages and publication. Each native runner built and validated seven real outputs, including Flatpak; the final job validated all fourteen package/control files before publishing fifteen assets. https://github.com/Hossam-Majrashi/atyaf/releases/tag/v1.2.7 is public, non-draft/non-prerelease and latest, with its tag/target matching the exact built source. Older releases are preserved.

All fifteen public files in `dist/github-v1.2.7` match GitHub SHA256 digests and all fourteen published checksum entries. Both architecture sets independently passed local ELF/package/metadata/zsync/Flatpak validation without installation or execution of ARM64 payloads. A new local full serial run passes all 293 tests, alongside clean analysis and source-contract/format/shell/diff checks; 60 affected desktop/lock tests also pass independently. No new ARM64 GUI smoke or live Epic repair is claimed. Release documentation is the only source change in the publication session. Installed binaries, user profiles/credentials and previous dist files remain unchanged; public verification requests carried no credentials, and local Git used the configured provider rather than a token in source/URLs.

## Official references

- https://docs.flutter.dev/platform-integration/linux/building
- https://specifications.freedesktop.org/basedir-spec/latest/
- https://specifications.freedesktop.org/desktop-entry-spec/latest/exec-variables.html
- https://pub.dev/packages/icons_launcher/versions/3.1.0
- https://docs.python.org/3/library/tarfile.html
- https://docs.python.org/3/library/shutil.html
- https://api.dart.dev/dart-io/Directory/rename.html
- https://api.flutter.dev/flutter/services/Clipboard-class.html
- https://man7.org/linux/man-pages/man7/unix.7.html
- https://www.freedesktop.org/software/systemd/man/latest/coredumpctl.html
- https://docs.flatpak.org/en/latest/first-build.html
- https://github.com/AppImage/appimagetool
