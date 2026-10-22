# Atyaf 1.2.6 — أطياف

## العربية

- إصلاح تعطل xrevive 0.1.22 عند بدء التشغيل بالرمز 101 ورسالة Tauri `unknown path`: كانت إعدادات XDG المعزولة تفتقد تعريف مجلدات المستخدم القياسية.
- إنشاء تعريفات خاصة لكل حساب للمستندات والتنزيلات وبقية مجلدات XDG القياسية داخل بيانات الحساب الافتراضية، دون نسخ الملفات الشخصية أو تغيير HOME أو بيانات تسجيل الدخول.
- الحفاظ على ملفات `user-dirs.dirs` التي أنشأها المستخدم أو عدّلها وعلى مسارات الإعدادات والبيانات المخصصة. تُعاد مواءمة التعريفات التلقائية غير المعدّلة إذا انتقل جذر المكتبة عند الاستعادة.
- توضيح رسالة Tauri المحددة في معاينة السجل وتقارير النسخ وتصدير TXT بالعربية والإنجليزية، دون تغيير رمز الخروج أو السجلات الأصلية.

**الحدود:** جرى التحقق من ظهور نافذة xrevive الحقيقي في مكتبة اختبار مستقلة، وليس تسجيل الدخول أو تشغيل الألعاب. لا يغيّر الإصدار ملفات xrevive ولا يصلح كل خطأ `unknown path` محتمل. قد تتطلب ملفات التعريف أو المسارات المخصصة مراجعة يدوية؛ لا تُكتب فوقها الإعدادات الافتراضية.

## English

- Fix xrevive 0.1.22 exiting at startup with code 101 and Tauri `unknown path`: isolated XDG configuration lacked standard user-folder definitions.
- Supply private per-profile Documents, Downloads and other standard XDG folders within default profile data, without copying personal files or changing HOME or credentials.
- Preserve user-created/edited `user-dirs.dirs` files and custom config/data paths. Untouched generated definitions are relocated when a restored library moves.
- Explain the exact Tauri setup signature in bilingual log previews, copied reports and TXT exports without altering genuine exit status or original output.

**Limitations:** the real xrevive window was verified in a disposable library, not authentication or gameplay. This does not modify xrevive or fix every possible `unknown path` failure. Existing custom definitions/paths may need manual review; defaults do not overwrite them.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
