# Linux builds and distribution

Application ID: `com.h.atyaf`. Version is read from `pubspec.yaml` by both distribution scripts. `/dist` in the project contract means the repository-root `dist/` output directory, not a privileged directory at the filesystem root. Scripts run as an ordinary user and do not elevate privileges.

## Build requirements

Flutter stable with Linux Desktop enabled (verified using Flutter 3.47.6 / Dart 3.13.5), Git, Clang, CMake, Ninja, pkg-config, GTK3 development headers, GLib/GIO headers and the standard C++ toolchain. Linux runtime requirements: GTK3, GLib/GIO, libc, libstdc++, libgcc, X11 libraries, SQLite's `libsqlite3.so.0`, coreutils, Python 3, zstd, xdg-utils and a running XDG Desktop Portal with a file-chooser backend. Native package dependencies include the portal and a compatible backend; AppImage requires a functioning portal on the host. The executable, owner, mode, size and checksum are inspected using coreutils. `update-desktop-database` is optional; profile shortcuts remain valid without it.

After `flutter gen-l10n`, `python3 tool/normalize_l10n.py` removes the generator's unrelated platform documentation without changing localization code. `tool/generate_l10n.sh` combines these commands; distribution scripts normalize automatically.

The release bundle includes the Flutter engine, AOT library, plugins and all Flutter assets. It is dynamically linked against system libraries. Native packages and AppImage require the documented GTK3/SQLite runtime libraries; AppImage is relocatable but does not promise to replace libc or every system graphics library. RPM generates ELF dependency capabilities automatically so dnf/yum/zypper resolve the correct libraries. The verified x64 bundle requires GLIBC 2.34 or later. Build on the oldest supported Linux distribution/toolchain when expanding compatibility; inspect `ldd` and ELF version requirements rather than copying host system libc into a bundle.

Packaging tools: a **real** `dpkg-deb`, `rpmbuild`, `bsdtar`, `zstd`, `tar`, `gzip`, `appimagetool`, `desktop-file-validate`, `appstreamcli`, Curl, Python 3, POSIX awk and coreutils. No FPM dependency is required. AppImage generation uses the architecture-matching appimagetool/runtime and its `--appimage-extract-and-run` mode, so FUSE is not necessary on the build host. Curl fetches the runtime with bounded connection/transfer timeouts, then caches it in `build/appimage-runtime-x86_64` or `build/appimage-runtime-aarch64`; `APPIMAGE_RUNTIME_FILE` can supply a matching offline runtime. The script validates the ELF architecture and passes `--runtime-file` explicitly, avoiding the tool's unbounded automatic download. `tool/generate_icons.sh` additionally requires Inkscape and ImageMagick and invokes icons_launcher exactly 3.1.0 for Linux only.

This host originally had a contents-only dpkg-deb compatibility wrapper and no appimagetool or flatpak-builder. Real dpkg-deb and flatpak-builder binaries were extracted from the official Arch packages into `/tmp/atyaf-tools`, and the official appimagetool x86-64 release was downloaded there. Builds were executed with that directory prepended to PATH. GNOME 50 Platform and SDK were installed user-wide from Flathub. These environment tools are not project dependencies or bundled executables. The full dpkg-deb and appimagetool were subsequently installed persistently in `~/.local/bin` (the previous dpkg-deb script was backed up under `~/.local/share/atyaf-build-tools/backups/`), so the native script now works on this host's ordinary PATH without sudo. Flatpak-builder remains available in `/tmp/atyaf-tools` for the verified Flatpak build.

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

Release bundle: `build/linux/x64/release/bundle/`. Distribution outputs for the verified pubspec version 1.1.0 (the scripts derive future versions automatically):

- `dist/atyaf-1.1.0-linux-x64.deb`
- `dist/atyaf-1.1.0-linux-x64.rpm`
- `dist/atyaf-1.1.0-linux-x64.pkg.tar.zst`
- `dist/atyaf-1.1.0-linux-x64.tar.gz`
- `dist/atyaf-1.1.0-linux-x64.AppImage`
- `dist/atyaf-1.1.0-linux-x64.flatpak`

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

The bundle is `build/linux/arm64/release/bundle/`. All six output formats use the `linux-arm64` filename suffix; Debian architecture is `arm64`, RPM/Arch/Flatpak/AppImage architecture is `aarch64`. The scripts reject architecture mismatches instead of relabeling x64 binaries as ARM64.

**Verified environment constraint:** this machine is x86-64 and has no native AArch64 build environment. The actual command `flutter build linux --release --target-platform linux-arm64` returned: `Cross-build from Linux x64 host to Linux arm64 target is not currently supported.` The ARM64 package script also rejected the host explicitly. Therefore no ARM64 artifacts are claimed or fabricated. Both architecture commands and their required native environments are implemented/documented.

## Flatpak

GNOME 50 provides the GTK3/Flutter runtime and versioned SQLite runtime library. Before distribution, user-wide runtime/SDK installation is:

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
