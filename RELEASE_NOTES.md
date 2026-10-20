# Atyaf 1.2.2 — أطياف

## العربية

- تشخيص شاشة استخدام shadPS4 CLI في المخرجات القياسية، وليس الأخطاء فقط. التشغيل بلا وسائط في النسخة المبلّغ عنها يُرجع `255` ولا يعني انهيارًا للنظام.
- إضافة خيار مؤكد «shadPS4: استخدام Big Picture» في محرر الحساب لإضافة `--big-picture`، مع الحفاظ على الوسائط الأخرى وإعدادات الحساب. لا يُطبّق إلا بعد الحفظ وإعادة التشغيل؛ لا تُضاف وسائط إلى البرامج تلقائيًا.
- توضيح الفرق بين وضع Big Picture وواجهة shadPS4 Qt Launcher المنفصلة، وإمكانية تحديد لعبة باستخدام `--game`.
- الاحتفاظ بالمخرجات الأصلية كاملةً عند نسخ التقارير وتصديرها، وبالموافقة على التنفيذ ومنع النسخ المكررة وتكامل اختصارات KDE.

**الحدود:** يجب أن تعرض نسخة shadPS4 المستوردة خيار `--big-picture` في المساعدة. قد يعرض المحاكي حوار الإعداد أو نقل الحفظ عند أول تشغيل؛ لا يختار أطياف نقل البيانات نيابةً عنك. هذا ليس تضمينًا للمحاكي أو تنزيلًا تلقائيًا له، ولا ضمانًا لتوافق الألعاب.

**متطلبات التشغيل:** GTK3 وSQLite وPython 3 وأدوات XDG وبوابة اختيار الملفات. Flatpak يستخدم GNOME 50. قراءة أيقونات AppImage اختيارية عبر 7-Zip؛ DwarFS غير مدعوم لقارئ الأيقونات، وليس ممنوعًا من التشغيل.

## English

- Diagnose shadPS4 CLI usage in stdout as well as stderr. The reported version exits with `255` when started without arguments; this is not evidence of a system crash.
- Add an explicitly confirmed **shadPS4: use Big Picture** profile-editor option for `--big-picture`, preserving unrelated arguments and settings. Save and restart are required; no application flags are injected automatically.
- Explain Big Picture versus the separate shadPS4 Qt Launcher desktop GUI, and the alternative of specifying a game with `--game`.
- Preserve complete original report output, executable approval, duplicate prevention and KDE shortcut integration.

**Limitations:** the imported shadPS4 version must advertise `--big-picture`. First launch may display emulator setup/save-migration prompts; Atyaf never chooses data migration for you. This does not bundle/download the emulator or guarantee game compatibility.

**Runtime requirements:** GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

## Packages and verification / الحزم والتحقق

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
