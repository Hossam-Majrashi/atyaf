# Atyaf 1.2.3 — أطياف

## العربية

- تحسين تصفّح المكتبات الكبيرة: قوائم البرامج والحسابات تبني العناصر الظاهرة والقريبة فقط بدل إنشاء القائمة كاملة عند كل تحديث.
- إضافة بحث فوري بأسماء البرامج في اللوحة الجانبية، واستبدال قائمة الاختيار الصغيرة بنافذة بحث قابلة للتمرير عند استخدام نافذة ضيقة.
- تقليل قراءة SQLite وفك الأيقونات المتكرر، وإزالة إعادة تحميل مكتبة البرامج لكل حساب. تظل تغييرات النوافذ الأخرى والاستعادة ظاهرة تلقائيًا؛ لا يتوقف تحديث حالات التشغيل.
- فهرسة سجل التشغيل حسب الحساب حتى لا تُقرأ وتُفك جميع سجلات المكتبة عند التحقق من كل حساب.
- الحفاظ على بيانات البرامج والحسابات، والأيقونات، وموافقة التنفيذ، والاختصارات، والمخرجات الكاملة. لا تُشغّل برامج أو تُغيّر إعدادات الحسابات تلقائيًا.

**الحدود:** هذه تحسينات لتصفّح المكتبة والنقر والتمرير، وليست ضمانًا لسرعة نسخ أرشيف أو AppImage كبير أو تشغيل برنامج خارجي. لا يتغير عزل الحسابات أو التحقق الأمني عند الاستيراد والتشغيل.

## English

- Virtualize application and profile lists: build visible/nearby rows instead of constructing every row on each refresh.
- Add immediate application-name search in the sidebar and a searchable, virtualized selector for compact windows.
- Reuse unchanged SQLite library snapshots and validated icons; remove repeated application-library reads per profile. Other instances' commits and restoration still invalidate snapshots, and process reconciliation remains enabled.
- Index launch history by profile instead of decoding the entire library's history for each account check.
- Preserve applications, profiles, icons, executable approval, shortcuts and complete process output. No automatic application launch or profile-setting changes.

**Limitations:** these changes address library navigation and interaction, not the cost of copying large archives/AppImages or launching third-party programs. Import/launch security and profile separation are unchanged.

## Packages and verification / الحزم والتحقق

Runtime requirements: GTK3, SQLite, Python 3, XDG tools and a working file-chooser portal. Flatpak uses GNOME 50. Optional AppImage icon reading uses host 7-Zip; DwarFS is unsupported by the icon reader, not prohibited from launching.

Supported package architectures are **x86_64** and **aarch64**; `armv7`/`i686` are unsupported by this Flutter Linux toolchain. Native packages must be built and validated on their actual architecture; local x86_64 output is not evidence of an ARM64 build or GitHub publication.

Download `SHA256SUMS` beside the release assets you need, then run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```
