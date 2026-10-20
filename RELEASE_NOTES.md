# Atyaf 1.2.1 — أطياف

## العربية

- إصلاح النقر على اختصار حساب يعمل مسبقًا على KDE: إظهار نافذته بدل انتهاء الاختصار بصمت، دون تشغيل نسخة ثانية. يشمل استدعاء نافذة Epic المخفية في صينية النظام عبر خدمة نسخته الموجودة.
- ربط نافذة البرنامج باختصاره باستخدام فئة النافذة الفعلية من KWin، بما فيها برامج AppImage مثل RPCS3، دون تخمين الاسم أو إنشاء قواعد نوافذ دائمة.
- إضافة `StartupNotify=false` لإزالة انتظار التشغيل الوهمي من الاختصارات التي يشرف عليها أطياف مخفيًا، والاحتفاظ بفئة النافذة المكتشفة عند تحديث الأيقونة.
- تبقى الموافقة الأولى وفحص تغيّر الملف التنفيذي ومنع النسخ المكررة وإعدادات الحساب والسجلات الكاملة كما هي.

**الحدود:** إظهار النوافذ والتعرّف التلقائي يتطلبان KDE مع `gdbus` وواجهات KWin المتاحة. يجري التعرّف خلال أول 30 ثانية؛ يمكن ضبط StartupWMClass يدويًا من محرر التطبيق على أسطح المكتب الأخرى أو عند تعذّر التعرّف. قد تتشارك الحسابات ذات فئة النافذة نفسها مجموعة واحدة. لا يضاف تجاوز أمني أو اعتماد إلزامي جديد.

**متطلبات التشغيل:** GTK3 وSQLite وPython 3 وأدوات XDG وبوابة اختيار الملفات. Flatpak يستخدم GNOME 50. قراءة أيقونات AppImage اختيارية عبر 7-Zip؛ DwarFS غير مدعوم لقارئ الأيقونات، وليس ممنوعًا من التشغيل.

## English

- Fix reopening a running profile shortcut on KDE: present its window instead of silently exiting, without launching a duplicate. Includes requesting Epic's tray-hidden window through its existing single-instance service.
- Associate program windows with their shortcuts using the actual KWin window class, including AppImage programs such as RPCS3, without guessing names or installing permanent window rules.
- Set `StartupNotify=false` for hidden-supervisor shortcuts to avoid misleading startup spinners, and retain learned window classes when refreshing icons.
- First-launch approval, changed-executable checks, duplicate prevention, profile settings and complete logging remain intact.

**Limitations:** automatic activation/matching requires KDE with available `gdbus` and KWin interfaces. Discovery runs during the first 30 seconds; use the application's StartupWMClass editor on other desktops or when discovery is unavailable. Profiles sharing a window class may share a taskbar group. No security bypass or mandatory new dependency is introduced.

**Runtime requirements:** GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

## Packages and verification / الحزم والتحقق

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
