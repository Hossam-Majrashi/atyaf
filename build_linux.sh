#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
fail() { printf 'Atyaf packaging error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Required tool missing: $1"; }
for tool in flutter python3 dpkg-deb rpmbuild bsdtar zstd tar gzip install readlink readelf ldd desktop-file-validate appstreamcli appimagetool curl cp mv ln mktemp rm tee grep date du awk uname; do need "$tool"; done
arch="${1:-$(uname -m)}"
case "$arch" in
  x64|x86_64) target=x64; debarch=amd64; rpmarch=x86_64; apparch=x86_64 ;;
  arm64|aarch64) target=arm64; debarch=arm64; rpmarch=aarch64; apparch=aarch64 ;;
  *) fail "Supported Linux architectures: x64, arm64" ;;
esac
case "$(uname -m):$target" in x86_64:x64|aarch64:arm64) ;; *) fail "Native $target Linux host/toolchain required; see BUILD_NOTES.md" ;; esac
version="$(python3 -c "import re; print(re.search(r'^version:\\s*([^+\\s]+)',open('pubspec.yaml').read(),re.M).group(1))")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || fail 'Invalid pubspec version'
mkdir -p dist
work="$(mktemp -d "$PWD/build/package-$target.XXXXXX")"
trap 'rm -rf "$work"' EXIT
flutter build linux --release --target-platform "linux-$target"
python3 tool/normalize_l10n.py
bundle="$PWD/build/linux/$target/release/bundle"
[[ -x "$bundle/atyaf" ]] || fail 'Release bundle missing'
ldd "$bundle/atyaf" | tee "$work/ldd.txt"
! grep -q 'not found' "$work/ldd.txt" || fail 'Unresolved release dependencies'
stage="$work/root"
mkdir -p "$stage/opt/atyaf" "$stage/usr/bin" "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/1024x1024/apps"
cp -a "$bundle/." "$stage/opt/atyaf/"
ln -s /opt/atyaf/atyaf "$stage/usr/bin/atyaf"
install -m644 flatpak/com.h.atyaf.desktop "$stage/usr/share/applications/com.h.atyaf.desktop"
install -m644 assets/icon/icon.png "$stage/usr/share/icons/hicolor/1024x1024/apps/com.h.atyaf.png"
mkdir -p "$stage/usr/share/metainfo"
install -m644 flatpak/com.h.atyaf.metainfo.xml "$stage/usr/share/metainfo/com.h.atyaf.metainfo.xml"
install -Dm644 snap/gui/atyaf.png "$stage/usr/share/icons/hicolor/256x256/apps/com.h.atyaf.png"
install -Dm644 LICENSE "$stage/usr/share/licenses/atyaf/LICENSE"
install -Dm644 LICENSE "$stage/usr/share/doc/atyaf/copyright"
desktop-file-validate "$stage/usr/share/applications/com.h.atyaf.desktop"
# General archive includes the complete install tree and desktop integration assets.
tar -C "$stage" -czf "dist/atyaf-$version-linux-$target.tar.gz" opt usr
# Debian: GTK and plugin dependencies, plus tools used by the Linux runtime.
mkdir -p "$stage/DEBIAN"
cat > "$stage/DEBIAN/control" <<CONTROL
Package: atyaf
Version: $version
Architecture: $debarch
Maintainer: Hossam Majrashi <Hossam.Majrashi@gmail.com>
Section: utils
Priority: optional
Depends: libgtk-3-0, libglib2.0-0, libstdc++6, libgcc-s1, libc6 (>= 2.34), libsqlite3-0, libx11-6, python3, zstd, coreutils, xdg-utils, xdg-desktop-portal, xdg-desktop-portal-gtk | xdg-desktop-portal-kde | xdg-desktop-portal-gnome
Description: Independent application profiles for Linux
 Manage and launch executables and portable applications with isolated profile paths.
CONTROL
dpkg-deb --root-owner-group --build "$stage" "dist/atyaf-$version-linux-$target.deb"
rm -rf "$stage/DEBIAN"
# RPM automatically derives ELF requirements/provides, usable by dnf/yum/zypper.
rpmroot="$work/rpm"
mkdir -p "$rpmroot/"{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,db}
cat > "$rpmroot/SPECS/atyaf.spec" <<SPEC
Name: atyaf
Version: $version
Release: 1
Summary: Independent application profiles for Linux
License: MIT
URL: https://hossam-majrashi.github.io/Works/
BuildArch: $rpmarch
Requires: python3, zstd, coreutils, xdg-utils, xdg-desktop-portal, xdg-desktop-portal-gtk
Requires: libsqlite3.so.0()(64bit)
%global __os_install_post %{nil}
%description
Manage executables and portable applications with independently configured profiles.
%prep
%build
%install
mkdir -p %{buildroot}
cp -a "$stage/." %{buildroot}/
%files
/opt/atyaf
/usr/bin/atyaf
/usr/share/applications/com.h.atyaf.desktop
/usr/share/icons/hicolor/1024x1024/apps/com.h.atyaf.png
/usr/share/icons/hicolor/256x256/apps/com.h.atyaf.png
/usr/share/licenses/atyaf/LICENSE
/usr/share/doc/atyaf/copyright
/usr/share/metainfo/com.h.atyaf.metainfo.xml
SPEC
rpmbuild --define "_topdir $rpmroot" --define "_dbpath $rpmroot/db" --define '_binary_payload w9.gzdio' --target "$rpmarch" -bb "$rpmroot/SPECS/atyaf.spec"
cp "$rpmroot/RPMS/$rpmarch/atyaf-$version-1.$rpmarch.rpm" "dist/atyaf-$version-linux-$target.rpm"
# Arch packages require a native .PKGINFO and zstd tar stream, not an RPM rename.
cat > "$stage/.PKGINFO" <<PKGINFO
pkgname = atyaf
pkgbase = atyaf
pkgver = $version-1
pkgdesc = Independent application profiles for Linux
url = https://hossam-majrashi.github.io/Works/
builddate = $(date +%s)
packager = Hossam Majrashi <Hossam.Majrashi@gmail.com>
size = $(du -sb "$stage" | awk '{print $1}')
arch = $rpmarch
license = MIT
depend = gtk3
depend = glib2
depend = gcc-libs
depend = glibc
depend = sqlite
depend = libx11
depend = python
depend = zstd
depend = coreutils
depend = xdg-utils
depend = xdg-desktop-portal
depend = xdg-desktop-portal-gtk
PKGINFO
bsdtar --uid 0 --gid 0 -C "$stage" -cf - .PKGINFO opt usr | zstd -T0 -19 -o "dist/atyaf-$version-linux-$target.pkg.tar.zst" -f
rm "$stage/.PKGINFO"
appdir="$work/Atyaf.AppDir"
mkdir -p "$appdir/usr/lib/atyaf" "$appdir/usr/share/icons/hicolor/1024x1024/apps"
cp -a "$bundle/." "$appdir/usr/lib/atyaf/"
cp flatpak/com.h.atyaf.desktop "$appdir/com.h.atyaf.desktop"
install -Dm644 flatpak/com.h.atyaf.desktop "$appdir/usr/share/applications/com.h.atyaf.desktop"
cp assets/icon/icon.png "$appdir/com.h.atyaf.png"
cp assets/icon/icon.png "$appdir/usr/share/icons/hicolor/1024x1024/apps/com.h.atyaf.png"
install -Dm644 snap/gui/atyaf.png "$appdir/usr/share/icons/hicolor/256x256/apps/com.h.atyaf.png"
install -Dm644 LICENSE "$appdir/usr/share/licenses/atyaf/LICENSE"
mkdir -p "$appdir/usr/share/metainfo"
cp flatpak/com.h.atyaf.metainfo.xml "$appdir/usr/share/metainfo/com.h.atyaf.appdata.xml"
cat > "$appdir/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "$(readlink -f "$0")")"
export ATYAF_LAUNCHER="$APPIMAGE"
exec "$here/usr/lib/atyaf/atyaf" "$@"
APPRUN
chmod +x "$appdir/AppRun"
runtime_file="${APPIMAGE_RUNTIME_FILE:-$PWD/build/appimage-runtime-$apparch}"
if [[ ! -s "$runtime_file" ]]; then
  [[ -z "${APPIMAGE_RUNTIME_FILE:-}" ]] || fail "AppImage runtime file missing: $runtime_file"
  runtime_temp="$runtime_file.tmp-$$"
  if ! curl --fail --location --connect-timeout 15 --max-time 120 --retry 1 \
    "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-$apparch" -o "$runtime_temp"; then
    rm -f "$runtime_temp"
    fail 'Unable to fetch AppImage runtime; supply a matching APPIMAGE_RUNTIME_FILE for an offline build'
  fi
  mv "$runtime_temp" "$runtime_file"
fi
python3 - "$runtime_file" "$apparch" <<'PY'
import struct, sys
with open(sys.argv[1], 'rb') as stream:
    header = stream.read(20)
expected = 62 if sys.argv[2] == 'x86_64' else 183
if len(header) != 20 or header[:4] != b'\x7fELF' or header[4:6] != bytes([2, 1]) or struct.unpack('<H', header[18:20])[0] != expected:
    raise SystemExit('Atyaf packaging error: invalid or wrong-architecture AppImage runtime')
PY
ARCH="$apparch" appimagetool --appimage-extract-and-run --runtime-file "$runtime_file" "$appdir" "$PWD/dist/atyaf-$version-linux-$target.AppImage"
printf 'Created all five Linux %s formats in %s/dist\n' "$target" "$PWD"
