#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "$(readlink -f "$0")")")"
for tool in flutter dart inkscape magick; do
  command -v "$tool" >/dev/null || { printf 'Required icon tool missing: %s\n' "$tool" >&2; exit 1; }
done
for image in icon foreground background; do
  inkscape "assets/icon/$image.svg" -o "assets/icon/$image.png" -w 1024 -h 1024
done
for size in 64 128 512; do
  magick assets/icon/icon.png -resize "${size}x${size}" "assets/icon/icon-$size.png"
done
flutter pub get
python3 tool/normalize_l10n.py
dart run icons_launcher:create
cp flatpak/com.h.atyaf.desktop snap/gui/atyaf.desktop
rm -f snap/snapcraft.yaml
