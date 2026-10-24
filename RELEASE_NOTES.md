# Atyaf 1.2.7 — أطياف

## العربية

- معالجة تنازع قفل المكتبة `errno 11` بانتظار غير حاجب حتى عشر ثوانٍ؛ لا تُعاد عملية تشغيل البرنامج، وتبقى الأخطاء الأخرى واضحة.
- الحفاظ على حجز الحساب أثناء مخرجات إعادة التشغيل الداخلي، عبر التحقق من هوية مشرف أطياف، ومنع تشخيص انقطاع زائف أو تشغيل مكرر أو استبدال الملفات أثناء الانتظار.
- عرض حالة الإشراف المعلق دون إتاحة إرسال إشارات إلى معرّف عملية قديم، مع توضيح نجاح التحديث الداخلي وتلف الذاكرة في التقارير بالعربية والإنجليزية.
- الحفاظ على موافقة الملف التنفيذي: بعد تغيّر محتواه يلزم اعتماد صريح جديد، دون تغيير الحسابات أو بيانات الدخول أو السجلات السابقة.

## English

- Wait asynchronously up to ten seconds for library-lock contention (`errno 11`), without retrying a program launch or hiding other filesystem failures.
- Verify the Atyaf supervisor identity while inherited relaunch output remains open. Keep the profile reserved against duplicate launch/update/deletion and avoid false interrupted-supervisor records.
- Show pending supervision without offering signals to a stale PID; explain successful internal updates and native heap corruption in bilingual diagnostics/reports.
- Preserve executable approval: changed content requires fresh explicit review, with no automatic profile, credential or historical-log changes.

**Scope / الحدود:** supervision is not adoption of independently detached processes. Original-parent exit status is not the final relaunched instance's status. No live Epic repair, historical exit-code recovery or ARM64 graphical runtime verification is claimed. Packages are published only after native builds on both architectures, analysis/tests and package validation succeed. / لا يُدّعى إصلاح Epic نفسه أو استعادة رموز خروج قديمة أو اختبار واجهة ARM64؛ لا تُنشر الحزم إلا بعد نجاح البناء الأصلي للمعماريتين والتحليل والاختبارات والتحقق من الحزم.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
