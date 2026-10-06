#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
fail() { printf 'Atyaf Flatpak error: %s\n' "$*" >&2; exit 1; }
for tool in flutter flatpak flatpak-builder python3 desktop-file-validate appstreamcli strip readlink uname mkdir; do
  command -v "$tool" >/dev/null || fail "Required tool missing: $tool"
done
case "${1:-$(uname -m)}" in
  x64|x86_64) target=x64; arch=x86_64 ;;
  arm64|aarch64) target=arm64; arch=aarch64 ;;
  *) fail 'Supported Linux architectures: x64, arm64' ;;
esac
[[ "$(uname -m)" == "$arch" ]] || fail "Native $arch Linux host required; see BUILD_NOTES.md"
version="$(python3 -c "import re; print(re.search(r'^version:\\s*([^+\\s]+)',open('pubspec.yaml').read(),re.M).group(1))")"
flatpak info --user org.gnome.Platform//50 >/dev/null 2>&1 || fail 'Install org.gnome.Platform//50 from Flathub'
flatpak info --user org.gnome.Sdk//50 >/dev/null 2>&1 || fail 'Install org.gnome.Sdk//50 from Flathub'
flutter build linux --release --target-platform "linux-$target"
python3 tool/normalize_l10n.py
mkdir -p dist build/flatpak-input
python3 - "$target" "$version" <<'PY'
import json, pathlib, sys, xml.etree.ElementTree as ET
base = pathlib.Path.cwd()
manifest = json.loads((base/'flatpak/com.h.atyaf.json').read_text())
sources = manifest['modules'][0]['sources']
sources[0]['path'] = str(base / f'build/linux/{sys.argv[1]}/release/bundle')
for source in sources[1:]:
    source['path'] = str((base/'flatpak'/source['path']).resolve())
metadata = ET.parse(base/'flatpak/com.h.atyaf.metainfo.xml')
releases = ET.SubElement(metadata.getroot(), 'releases')
ET.SubElement(releases, 'release', {'version':sys.argv[2], 'date':__import__('datetime').date.today().isoformat()})
output = base/'build/flatpak-input/com.h.atyaf.metainfo.xml'
metadata.write(output, encoding='UTF-8', xml_declaration=True)
sources[2]['path'] = str(output)
(base/'build/flatpak-input/com.h.atyaf.json').write_text(json.dumps(manifest, indent=2))
PY
desktop-file-validate flatpak/com.h.atyaf.desktop
appstreamcli validate --no-net build/flatpak-input/com.h.atyaf.metainfo.xml
flatpak-builder --user --force-clean --arch="$arch" --repo=build/flatpak-repo "build/flatpak-$target" build/flatpak-input/com.h.atyaf.json
flatpak build-bundle --arch="$arch" build/flatpak-repo "dist/atyaf-$version-linux-$target.flatpak" com.h.atyaf --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo
