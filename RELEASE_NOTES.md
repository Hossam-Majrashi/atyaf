# Atyaf 1.2.10 — أطياف

## العربية

- تغيير مجلد تخزين المكتبة إلى `~/.local/share/atyaf` أو `$XDG_DATA_HOME/atyaf`، مع عرض المسار الفعلي في الإعدادات.
- ترحيل المكتبة القديمة عند إغلاق النسخ التي تستخدمها، مع الحفاظ على الحسابات والبيانات والاختصارات والموافقات. يبقى رابط توافق صغير باسم `com.h.atyaf` للمسارات المطلقة القديمة دون تكرار الملفات؛ لا تُدمج مكتبتان موجودتان مسبقًا.
- إصلاح حذف البرامج ليزيل مجلد `applications/<id>` كاملًا بدل ترك المجلد الأب بعد حذف `current`، مع حذف الحسابات والسجلات والملفات المؤقتة الافتراضية والاختصارات وأوامر الطرفية وتسجيلات بدء التشغيل المدارة التابعة لها.
- تنظيف مجلدات UUID الفارغة التي تركتها الإصدارات القديمة تلقائيًا، مع الحفاظ على المجلدات المجهولة غير الفارغة والبرامج الخارجية والمسارات المخصصة.

## English

- Store the library under `~/.local/share/atyaf` or `$XDG_DATA_HOME/atyaf`, and show its actual path in Settings.
- Rename an idle legacy library while preserving profiles, data, shortcuts and approvals. A small `com.h.atyaf` compatibility symlink keeps old absolute references working without duplicating files. Distinct existing libraries are never merged.
- Delete the complete `applications/<id>` directory instead of leaving its parent behind after deleting `current`, together with associated profiles, logs, default temporary files and managed desktop/terminal/startup integration.
- Automatically remove empty UUID directories left by older releases. Preserve unknown nonempty folders, external programs and custom data paths.

**Migration / الترحيل:** Close old Atyaf instances and background supervisors before reopening the updated version; an open old library defers migration. Stop profiles before deleting them. The Linux/Flatpak application ID remains `com.h.atyaf`; only the library folder name changes. / أغلق النسخ القديمة ومشرفيها بالخلفية ثم افتح النسخة المحدّثة؛ يتأجل الترحيل إذا كانت المكتبة القديمة مفتوحة. أوقف الحسابات قبل حذفها. يتغير اسم مجلد البيانات فقط، لا معرّف التطبيق وFlatpak.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Packages are published only after analysis/tests, actual native builds on both architectures and package validation succeed. No ARM64 graphical runtime verification is implied.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
