#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "$(readlink -f "$0")")")"
flutter gen-l10n
python3 tool/normalize_l10n.py
