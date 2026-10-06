#!/usr/bin/env python3
"""Keep generated localization documentation scoped to the Linux application."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
path = root / 'lib/core/l10n/app_localizations.dart'
text = path.read_text()
text, count = re.subn(
    r'/// Callers can lookup localized strings[\s\S]*?(?=abstract class AppLocalizations)',
    '/// Linux Desktop strings generated from the Arabic and English ARB sources.\n',
    text,
    count=1,
)
if count:
    path.write_text(text)
print('Generated localization documentation is Linux-only.')
