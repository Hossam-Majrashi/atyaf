# Atyaf 1.2.5 — أطياف

## العربية

- توضيح تحذيرات `Telemetry ConnectionFailed` وانقطاع `Social Overlay STOMP 4004: Inactive timeout` في عرض السجل وتقارير التشغيل: تشير إلى اتصال تلك الخدمات ولا تثبت انهيار البرنامج أو تحدد سبب خروجه.
- توضيح رسالة التعافي من خطأ عرض `React #424` دون افتراض نجاح كل وظائف الواجهة أو تفسير خروج لاحق.
- التعرف على العلامات المرتبطة داخل السطر نفسه في معاينة stdout أو stderr، ومنع تكرار النصيحة في التقرير عند ورود التحذير في القناتين.
- الحفاظ على رمز الخروج الفعلي، وتشخيص انقطاع الإشراف، والسجلات الأصلية كاملة عند النسخ والتصدير. لا تُعدّل السجلات التاريخية أو الحسابات أو خيارات التشغيل.

**الحدود:** لا يغيّر هذا الإصدار برنامج Epic أو يعالج خدماته البعيدة. حالة الخروج القديمة المفقودة لا يمكن استرجاعها من هذه السجلات، والتحذيرات وحدها لا تثبت التعطل. التشخيص يقرأ المعاينة المحدودة فقط؛ النسخ والتصدير يحفظان المخرجات كاملة. لا تُغيّر إعدادات الشبكة أو TLS أو التصيير أو العزل تلقائيًا.

## English

- Explain `Telemetry ConnectionFailed` and `Social Overlay STOMP 4004: Inactive timeout` in log previews and launch reports: these indicate connectivity issues in those services, not proof of an application crash or its exit cause.
- Explain recovered `React #424` rendering errors without claiming every interface feature works or diagnosing a later exit.
- Require related markers on the same line in either stdout or stderr previews; deduplicate report advice when both channels contain the warning.
- Preserve genuine exit status, interrupted-supervisor diagnostics and complete original streams in copy/export. Historical records, profiles and launch arguments are not modified.

**Limitations:** this does not modify Epic or repair its remote services. Old missing exit codes cannot be recovered from these logs; warnings alone do not establish a crash. Advice examines bounded previews only, while copy/export retains complete output. Network, TLS, rendering and sandbox settings are not changed automatically.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
