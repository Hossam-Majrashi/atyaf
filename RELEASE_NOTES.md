# Atyaf 1.2.14 — أطياف

## العربية

- **استيراد وتحديث البرامج:** يدعم أطياف ZIP وTAR بالإضافة إلى TAR المضغوط بـ Gzip وXZ وBzip2 وZstandard، بما في ذلك الاختصارات مثل `.tgz`. يعرض منتقي الملفات الصيغ المدعومة. لملف AppImage اختر **ملف AppImage**، ولصيغة مثل 7z أو RAR فك الضغط ثم اختر **مجلد البرنامج**.
- **اختيار بطاقة الرسوميات:** خيار **تفضيل بطاقة NVIDIA ‏(PRIME)** يضيف إعدادات NVIDIA إلى بيئة الحساب بعد الموافقة والحفظ. أعد تشغيل البرنامج لتطبيقها. في PCSX2 اختر Vulkan وبطاقة NVIDIA داخل إعدادات الرسوميات. هذا الخيار لا يفرض استخدام 100٪ من البطاقة ولا يغيّر أي حساب تلقائيًا.

لا تُشغّل الملفات أثناء الاستيراد. يتطلب ZIP صلاحيات التنفيذ الأصلية ولا يقبل الروابط الرمزية. تظل النسخ الاحتياطية بصيغة TAR المضغوط كما كانت.

## English

- **Application import and updates:** Atyaf supports ZIP, TAR, and TAR compressed with Gzip, XZ, Bzip2, or Zstandard, including short extensions such as `.tgz`. The file chooser filters to supported formats. Use **AppImage file** for AppImages; unpack formats such as 7z or RAR and choose **Application folder**.
- **Graphics adapter choice:** **Prefer NVIDIA (PRIME)** sets NVIDIA launch environment variables for one profile after confirmation and save. Restart the application to apply. In PCSX2, choose Vulkan and select the NVIDIA adapter in Graphics settings. This option does not force 100% GPU utilization or change profiles automatically.

Importing never runs archive contents. ZIP imports require stored Unix executable bits and reject symbolic links. Backup exports remain compressed TAR.

## Packages and verification / الحزم والتحقق

Linux packages target **x86_64** and **aarch64**. Native packages require GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Zstandard TAR files require `zstd` on the host. Flatpak uses GNOME 50.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
