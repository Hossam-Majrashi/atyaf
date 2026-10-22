# Atyaf 1.2.4 — أطياف

## العربية

- إصلاح سبب خلط أيقونات شريط المهام في KDE بين RPCS3 وPCSX2: لا تُسجّل فئة `AppRun` العامة تلقائيًا، وتُزال روابطها التلقائية القديمة من اختصارات أطياف عند تشغيل حساب. تبقى الفئات اليدوية والأيقونات والأسماء ووسائط التشغيل كما هي.
- خيار «ملف تنفيذي» يحفظ الآن نسخة مستقلة داخل مكتبة أطياف؛ حذف الملف الأصلي من التنزيلات لا يعطّل النسخة المحفوظة. لا يُشغّل الملف أثناء الاستيراد ولا تتغير صلاحيات الأصل.
- إضافة «ملف تنفيذي» إلى مصادر التحديث اليدوي، بما يسمح بتحويل المراجع الخارجية القديمة إلى نسخ مُدارة مع الحفاظ على الحسابات وبياناتها وإعداداتها.
- إظهار أنواع الملفات بجانب خيارات «إضافة برنامج»: Linux ELF / سكربتات `.sh` أو بلا امتداد، مجلد كامل، `.tar.gz` / `.tar.xz` / `.tar.zst`، و`.AppImage`.
- استمرار اعتماد التنفيذ والتحقق الأمني والنسخ الاحتياطي والتراجع عند الفشل وحفظ المخرجات كاملة.

**الحدود:** انسخ مجلد البرنامج كاملًا إذا كان يحتاج موارد أو مكتبات مجاورة؛ استيراد ملف منفرد لا يجعل اعتمادياته محمولة. لا تُنقل المراجع الخارجية القديمة تلقائيًا؛ اختر «تحديث ← ملف تنفيذي». يعتمد تجميع النوافذ والأيقونة الاحتياطية على بيانات البرنامج وKDE؛ لا تُفرض هوية نافذة ولا قواعد KWin دائمة.

## English

- Prevent KDE taskbar icon confusion between RPCS3 and PCSX2 by no longer learning the generic `AppRun` class. Old automatically learned AppRun mappings in Atyaf shortcuts are repaired on a profile launch. Manual classes, images, names and launch arguments remain intact.
- **Executable** now saves an independent managed copy: deleting the original download no longer breaks the saved application. Import does not execute the file or change source permissions.
- Add **Executable** as a manual update source, including conversion of legacy external references into managed copies while preserving profiles, settings and data.
- Describe file types beside every **Add application** option: Linux ELF / scripts (`.sh` or extensionless), complete folders, `.tar.gz` / `.tar.xz` / `.tar.zst`, and `.AppImage`.
- Preserve executable approval, security validation, backup, failure rollback and complete process output.

**Limitations:** import the complete folder for applications needing adjacent resources/libraries; copying one executable does not bundle its dependencies. Legacy external references are not silently migrated: use **Update → Executable**. Window grouping/fallback icons still depend on application metadata and KDE; no window identity or permanent KWin rule is forced.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
