# Atyaf 1.2.13 — أطياف

## العربية

- خيار **بدء التشغيل مصغّرًا** لكل حساب في نافذة **التشغيل عند تسجيل الدخول**. يقترح أطياف `--start-minimized` لـ Vesktop و`/startup` لـ MisterDownloadManager. للبرامج الأخرى، أدخل الوسائط التي تدعمها.
- لا تُستخدم وسائط التصغير عند الفتح اليدوي، ولا يجلب أطياف حسابًا يعمل بالفعل إلى المقدّمة عند بدء التشغيل المصغّر.
- تبقى الموافقة على الملف التنفيذي والعزل وسجلات التشغيل كما هي. لا يتغيّر أي حساب عند تثبيت التحديث.

**الاستخدام:** افتح **التشغيل عند تسجيل الدخول** من بطاقة الحساب، وفعّل **بدء التشغيل مصغّرًا**، ثم اختر **تفعيل بدء التشغيل** أو **حفظ**. لا يبدأ البرنامج فورًا. عند الدخول مرة أخرى، يحدد البرنامج نفسه هل يبدأ مصغّرًا أو يظهر بجانب الساعة.

## English

- Added a per-profile **Start minimized** checkbox to **Start at login**. Atyaf suggests `--start-minimized` for Vesktop and `/startup` for MisterDownloadManager. For other apps, enter their supported arguments.
- The extra arguments are used only at login. Manual launches are unchanged, and a minimized login request does not raise an already-running profile.
- Executable approval, isolation and launch logs are unchanged. Installing the update does not change existing profiles.

**Use:** Open **Start at login** on the account card, select **Start minimized**, then choose **Enable startup** or **Save**. The app does not start immediately. The app itself determines whether it starts minimized or in the tray.

## Packages and verification / الحزم والتحقق

Supported Linux package architectures: **x86_64** and **aarch64**. The Flutter Linux build does not support `armv7` or `i686`. Native packages require GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50.

The automated release requires successful analysis, tests, native builds and package validation on both architectures. The login launch was checked with a test profile; no live Vesktop or MisterDownloadManager tray test is claimed.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
