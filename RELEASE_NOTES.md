# Atyaf 1.2.0 — أطياف

## العربية

- استيراد AppImage وتحديثه يدويًا بنسخة مستقلة دون فقد الحسابات أو بياناتها، ودون تشغيل الملف أثناء الاستيراد.
- قراءة أيقونات AppImage المضمّنة دون تشغيله، مع اختيار صورة يدويًا والمحافظة عليها عند التحديث. يحتاج الاستخراج 7-Zip على المضيف؛ DwarFS غير مدعوم حاليًا.
- أمر طرفية مستقل لكل حساب، مثل `rpcs3` أو `rpcs3-work`، مع حماية الأوامر الموجودة والمحافظة على إعدادات الحساب والاعتماد والسجلات.
- نشر حزم Linux أصلية لمعمارية **x86_64** و**aarch64**: AppImage وAppImage.zsync وDEB وRPM وArch وtar.gz وFlatpak.
- ملفات `SHA256SUMS` للتحقق من التنزيلات. ملفات zsync بيانات تحديث فقط؛ لم تُضف تحديثات تلقائية داخل التطبيق.

**المتطلبات:** GTK3 وSQLite وPython 3 وأدوات XDG/بوابة اختيار الملفات على المضيف. Flatpak يستخدم GNOME 50. لا تنقل الحزمة سجلاتك أو حساباتك إلى خدمة خارجية. راجع README وBUILD_NOTES لمعرفة الاعتماديات والقيود.

**معماريات 32 بت:** لا تتوفر حزم `armv7` أو `i686`؛ Flutter Linux المستخدم لا يدعم هذين الهدفين. لم تُعد تسمية حزم 64 بت على أنها 32 بت.

## English

- Import and manually update independent managed AppImages without losing profiles/data or executing the image during import.
- Discover embedded AppImage logos as data, preserve manual icon overrides, and refresh automatic logos on updates. Host 7-Zip is optional; DwarFS is currently unsupported.
- Create per-profile terminal commands such as `rpcs3` or `rpcs3-work`, preserving existing host commands, account settings, approval and complete logs.
- Native **x86_64** and **aarch64** Linux packages: AppImage, AppImage.zsync, DEB, RPM, Arch, tar.gz and Flatpak.
- `SHA256SUMS` verifies downloads. zsync files are passive update metadata, not an automatic in-app updater.

**Requirements:** host GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. No user library, credentials or logs are uploaded by the application. See README and BUILD_NOTES for dependencies/limitations.

**32-bit architectures:** `armv7` and `i686` are not supported by this Flutter Linux toolchain. No renamed 64-bit packages are provided for those targets.

## Verify downloads / التحقق من التنزيلات

Download `SHA256SUMS` beside the assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
