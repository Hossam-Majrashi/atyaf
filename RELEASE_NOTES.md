# Atyaf 1.2.9 — أطياف

## العربية

- إضافة «التشغيل عند تسجيل الدخول» لكل حساب في بطاقته وقائمته، مع تفعيل وتعطيل صريحين دون تشغيل فوري.
- استدعاء أطياف بمعرّف الحساب ومكتبته عند بدء جلسة سطح المكتب بدل تشغيل AppImage مباشرة؛ تبقى إعدادات الحساب وعزل بياناته والموافقة ومنع التكرار والسجلات الكاملة فعّالة.
- توضيح سبب عدم عمل خيار بدء التشغيل الداخلي عند كتابة ملفه داخل إعدادات معزولة، وخطر فتح البرنامج مباشرة ببيانات المستخدم العامة.
- حماية ملفات بدء التشغيل الموجودة أو المعدّلة يدويًا، وإزالة التسجيلات المدارة عند حذف الحساب أو استعادة المكتبة. لا تُفعّل النسخ الاحتياطية برامج تلقائيًا.

## English

- Add an explicit per-account **Start at login** action to account cards and menus, with enable/disable controls and no immediate launch.
- Invoke Atyaf with the stable account ID and originating library at desktop-session login instead of launching AppImages directly. Saved settings, storage isolation, approval, duplicate checks and complete supervision remain in effect.
- Explain why application-owned startup files inside isolated settings are invisible to the host desktop and how a direct executable launch can create another instance using normal user data.
- Preserve existing or manually modified startup entries; remove registered entries on account deletion/library restore. Backups never silently enable startup.

**Scope / الحدود:** Startup requires a desktop session supporting XDG autostart, and occurs after login, not at early system boot. First or changed executables require normal approval. Direct launches outside Atyaf are not adopted or terminated. No data is merged/deleted and no historical unknown exit status is reconstructed. The supplied ArtCraft log does not establish a crash or Flatpak installer failure. / يتطلب التشغيل جلسة تدعم XDG autostart ويحدث بعد تسجيل الدخول. تبقى الموافقة على الملفات الجديدة أو المتغيّرة مطلوبة. لا تُتبنّى النسخ الخارجية أو تُوقف، ولا تُدمج أو تُحذف بياناتها أو تُستعاد رموز خروج قديمة مجهولة. لا يثبت سجل ArtCraft المرفق انهيارًا أو فشل مثبت Flatpak.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Packages are published only after analysis/tests, actual native builds on both architectures and package validation succeed. No ARM64 graphical runtime verification is implied.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
