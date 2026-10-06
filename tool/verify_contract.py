#!/usr/bin/env python3
"""Check executable-contract invariants against the actual Linux source tree."""
from pathlib import Path
import json
import re
import struct

root = Path(__file__).resolve().parent.parent
errors = []
incomplete_pattern = r'\b' + 'TO' + r'DO\b|' + 'implement' + ' later|' + 'omitted' + ' for brevity'


def require(condition, message):
    if not condition:
        errors.append(message)


for name in ['android', 'ios', 'windows', 'macos', 'web']:
    require(not (root / name).exists(), 'Unexpected target directory: ' + name)
require({p.name for p in (root / 'lib/platform').iterdir()} == {'linux'}, 'Only Linux implementations may exist')
require({p.name for p in (root / 'lib/screens').iterdir()} == {'desktop'}, 'All screens must be desktop screens')
for feature in ['onboarding', 'home', 'settings', 'applications', 'profiles', 'launcher', 'archives', 'updates', 'managed_storage', 'process_manager', 'desktop_entries', 'logs', 'backup']:
    require(any((root / 'lib/features' / feature).rglob('*.dart')), 'Missing feature implementation: ' + feature)
en = json.loads((root / 'lib/core/l10n/app_en.arb').read_text())
ar = json.loads((root / 'lib/core/l10n/app_ar.arb').read_text())
keys = lambda arb: {key for key in arb if not key.startswith('@')}
require(keys(en) == keys(ar), 'ARB language keys differ')
require(en.get('update') == 'Update' and ar.get('update') == 'تحديث', 'Missing manual update labels')
for path in [root / 'lib/features/updates/services/update_service.dart', root / 'lib/platform/linux/linux_managed_storage.dart']:
    require(not re.search(r'HttpClient|https?://|package:http|Timer|GitHub|apt-get|dnf', path.read_text()), 'Updates must not contain remote or background checkers')
for directory in ['lib', 'linux', 'assets/linux', 'test', 'tool', 'flatpak', 'snap']:
    for path in (root / directory).rglob('*'):
        if not path.is_file() or 'ephemeral' in path.parts or path.suffix not in ['.dart', '.cc', '.h', '.txt', '.py', '.sh', '.yaml', '.json', '.desktop', '.xml']:
            continue
        text = path.read_text()
        require(not re.search(incomplete_pattern, text), 'Incomplete source: ' + str(path.relative_to(root)))
        if path.suffix == '.dart' and 'lib' in path.parts:
            require(not re.search(r'\biOS\b|\bAndroid\b|\bWindows\b|\bmacOS\b|\bWeb\b', text), 'Unrelated platform code or documentation: ' + str(path.relative_to(root)))
        if path.suffix == '.dart' and 'lib' in path.parts:
            require('MediaQuery.of(context).size' not in text, 'Forbidden sizing API: ' + str(path))
            if 'theme' not in path.parts:
                require(not re.search(r'Color\(0x|Colors\.', text), 'Fixed color outside theme: ' + str(path))
            if 'screens' in path.parts or 'widgets' in path.parts or path.name == 'main.dart':
                require(not re.search(r'\b(?:Text|SelectableText)\(\s*[\'\"]', text), 'Fixed visible text: ' + str(path))
                require(not re.search(r'(?:labelText|hintText|tooltip):\s*[\'\"]', text), 'Fixed UI label: ' + str(path))
        if 'lib/platform/linux' in str(path.relative_to(root)):
            require(not re.search(r'\babstract\b', text), 'Abstract class in Linux implementation: ' + str(path))
pubspec = (root / 'pubspec.yaml').read_text()
require('icons_launcher: 3.1.0' in pubspec, 'Wrong icon launcher version')
require('flutter_launcher_icons' not in pubspec, 'Forbidden icon launcher')
for image in ['icon', 'foreground', 'background']:
    require((root / f'assets/icon/{image}.svg').exists(), 'Missing icon SVG: ' + image)
    png = (root / f'assets/icon/{image}.png').read_bytes()
    require(struct.unpack('>II', png[16:24]) == (1024, 1024), 'Wrong PNG size: ' + image)
for color in ['212327', '232627', 'EFEEF1', 'FEFEFE', 'CDCCCA', '14FFFFFF', '0F000000']:
    require(color in (root / 'lib/core/theme/app_theme.dart').read_text(), 'Missing exact palette value: ' + color)
for name in ['DESIGN_DECISIONS.md', 'PROJECT_NOTES.md', 'AGENTS.md', 'BUILD_NOTES.md', 'build_linux.sh', 'flatpak_linux.sh', 'flatpak/com.h.atyaf.json', 'flatpak/com.h.atyaf.metainfo.xml', 'flatpak/com.h.atyaf.desktop']:
    require((root / name).is_file(), 'Missing contract file: ' + name)
require(len((root / 'AGENTS.md').read_text().splitlines()) == 1, 'AGENTS.md must be one line')
if errors:
    raise SystemExit('\n'.join(errors))
print('Linux contract source checks passed; ARB keys, palette, icons, features and boundaries verified.')
