# Atyaf 1.2.12 — أطياف

## العربية

- إصلاح قراءة الأيقونات من AppImage الذي تتضمن بيئة تشغيله بيانات مضغوطة قبل نظام ملفات التطبيق، كما في xrevive 0.4.6. يختار القارئ نوع SquashFS/ISO صراحةً لعرض الشعار الصحيح، دون تشغيل الملف أو تركيبه أو تغيير الأصل.
- إضافة خيار «MisterDownloadManager: ربط متصفح الجهاز» في محرر الحساب، مع تأكيد صريح ثم حفظ وإعادة تشغيل. يعالج اختلاف مسار البيانات وقناة الاتصال الذي يجعل إضافة المتصفح تفتح نسخة ثانية من البرنامج بدل الحساب العامل في أطياف.
- دعم المتغير `{hostData}` في الوسائط وقيم البيئة للإشارة الاختيارية إلى مجلد بيانات XDG الأصلي للجهاز، دون تغيير مسارات الحساب المعزولة افتراضيًا.
- الحفاظ على البيانات المعزولة السابقة دون حذف أو دمج، وعلى موافقات التشغيل والوسائط ومسارات الحساب الأخرى وتسجيلات المتصفح.

**التطبيق:** لاستيراد قديم بلا أيقونة، استخدم «تحديث ← ملف AppImage» وحدد الملف نفسه ثم الأيقونة التلقائية. لربط MisterDownloadManager، أغلق نسخه الأخرى ثم فعّل الخيار في محرر الحساب وأكّد واحفظ وأعد التشغيل من النسخة المحدّثة. تثبيت التحديث وحده لا يفعّل المشاركة على الحسابات الجديدة أو الموجودة؛ يلزم تفعيل الخيار لكل حساب مطلوب صراحةً.

**تنبيه المشاركة:** يضبط خيار الربط `MDM_DATA_DIR={hostData}/misterdownloadmanager`، فيشارك البرنامج إعداداته وتنزيلاته مع نسخته العادية على الجهاز؛ ليس هذا فصلًا لحساباته. البيانات المشتركة خارج نسخ أطياف الاحتياطية وحذفه المُدار. الخيار للتكامل القياسي غير المحمول؛ تحتاج بيئة الإضافة المخصصة أو مجلدات البيانات المحمولة مسارات متطابقة تضبط يدويًا. لا يبدأ تشغيل برنامج أو تعديل حساب تلقائيًا.

## English

- Fix embedded icons in AppImages whose runtime contains compressed data before the application filesystem, as in xrevive 0.4.6. Explicit SquashFS/ISO selection recovers the correct logo without executing, mounting or changing the source image.
- Add **MisterDownloadManager: connect host browser** to the profile editor, with explicit confirmation followed by Save/restart. This addresses different data/IPC paths causing the browser extension to open a second instance instead of the running Atyaf profile.
- Support the opt-in `{hostData}` argument/environment substitution for the original host XDG data directory; normal isolated profile paths remain unchanged.
- Preserve old isolated data without deletion or merging, executable approval, arguments, other profile paths and browser registrations.

**Applying:** For an older iconless import, use **Update → AppImage file** with the same file and its automatic icon. For MisterDownloadManager, close other instances, enable the new profile-editor option, confirm, Save and restart from the updated Atyaf build. Installing the update alone does not enable sharing on new or existing profiles; explicitly enable it for each intended profile.

**Data sharing:** The helper sets `MDM_DATA_DIR={hostData}/misterdownloadmanager`, deliberately sharing MisterDownloadManager settings/downloads with its normal host instance rather than providing separate-account isolation for this app. Shared host data is outside Atyaf backups/managed deletion. The helper targets standard non-portable integration; custom native-host environments or portable data folders require manually matching both paths. No application is launched or profile changed automatically.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Embedded AppImage icon reading uses optional host 7-Zip; support for filesystem compression depends on the installed reader. DwarFS is unsupported by the icon reader, not prohibited from launching.

The real x86_64 Firefox/MisterDownloadManager flow was reproduced before applying the per-profile setting, then verified with one supervised GUI instance and a completed GitHub release download matching its published SHA256. No private profile settings or credentials are distributed in these packages.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Packages are published only after analysis/tests, actual native builds on both architectures and package validation succeed. Native ARM64 packaging does not imply ARM64 graphical runtime verification.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
