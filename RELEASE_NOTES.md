# Atyaf 1.2.8 — أطياف

## العربية

- نقل المسارات المؤقتة الافتراضية إلى مجلدات خاصة وقصيرة تحت `/var/tmp` بدل `/tmp` لتجنب ضغط مساحة الملفات المؤقتة في الذاكرة وإعادة استخدام فك AppImage القديم غير المكتمل.
- الحفاظ على فصل الحسابات وحدود طول مقابس Electron/Chromium والمسارات ومتغيرات `TMPDIR` المخصصة. لا تُحذف الملفات المؤقتة القديمة أو بيانات الحسابات تلقائيًا.
- توضيح نفاد المساحة أو عُقد الملفات أثناء فك AppImage، والتمييز بين غياب بيانات `.desktop` المضمّنة وغياب اختصار سطح المكتب، في الواجهة والتقارير العربية والإنجليزية.
- الحفاظ على المخرجات الكاملة ورموز الخروج السابقة والموافقة على الملفات التنفيذية دون تعديل بيانات الدخول أو إضافة خيارات تعطّل الحماية.

## English

- Move default temporary storage from `/tmp` to short, private per-profile `/var/tmp` directories, avoiding pressure on memory-backed temporary filesystems and reuse of old incomplete AppImage extraction trees.
- Preserve profile isolation, Electron/Chromium Unix socket limits, custom paths and explicit `TMPDIR` overrides. Old temporary contents and account data are not automatically deleted.
- Explain extraction space/inode exhaustion and distinguish missing embedded `.desktop` metadata from a missing desktop shortcut in bilingual desktop diagnostics and complete reports.
- Preserve complete output, genuine exit status and executable approval without changing credentials or adding security-bypass flags.

**Scope / الحدود:** `/var/tmp` can also fill up or use a separately configured filesystem; inspect free space and inodes on the actual `TMPDIR` filesystem. Existing custom paths require explicit review. Studio's historical exit code 2 with empty streams does not establish a cause, and no historical status is reconstructed. / قد تمتلئ `/var/tmp` أيضًا؛ افحص المساحة وعُقد الملفات على نظام ملفات `TMPDIR` الفعلي. لا يكفي رمز خروج Studio القديم مع غياب المخرجات لتحديد السبب، ولا تُستعاد رموز خروج مجهولة.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Packages are published only after analysis/tests, actual native builds on both architectures and package validation succeed. No ARM64 graphical runtime verification is implied.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
