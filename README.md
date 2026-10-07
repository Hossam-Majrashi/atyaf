<p align="center">
  <img src="assets/icon/icon.png" width="112" alt="أيقونة أطياف" />
</p>

# أطياف · Atyaf

[العربية](#arabic) · [English](#english)

<a id="arabic"></a>

<div dir="rtl">

## العربية

**برنامج واحد، حسابات متعددة بإعدادات مستقلة.**

أطياف تطبيق لسطح مكتب Linux يتيح إدارة وتشغيل عدة ملفات شخصية للبرنامج نفسه. افصل حساب العمل عن حسابك الشخصي أو بيئة التجربة، مع الاحتفاظ بإعدادات وبيانات مستقلة لكل حساب وإمكانية تشغيله من قائمة تطبيقات الجهاز.

مبني باستخدام Flutter وDart، بواجهة عربية وإنجليزية، ودعم اتجاه الكتابة من اليمين إلى اليسار، ومظهر فاتح وداكن أو مطابق للنظام.

### لقطات الشاشة

<a id="screenshot-home"></a>

#### الصفحة الرئيسية مع أمثلة حية لتشغيل التطبيقات

<img width="1920" height="1080" alt="الصفحة الرئيسية لأطياف مع أمثلة حية لتشغيل التطبيقات" src="https://github.com/user-attachments/assets/8d819bc9-fa2e-4385-8b50-b952198a7c33" />

<a id="screenshot-settings"></a>

#### الإعدادات

<img width="1920" height="1040" alt="صفحة إعدادات أطياف" src="https://github.com/user-attachments/assets/09204d21-0c87-4518-ac0b-ea7a342b7670" />

<a id="screenshot-errors"></a>

#### سجل الأخطاء والتشخيص

<img width="1920" height="1039" alt="صفحة سجل الأخطاء والتشخيص في أطياف" src="https://github.com/user-attachments/assets/811d6785-4fef-4d18-afc1-55403f8eb1dc" />

### المميزات

- **حسابات مستقلة:** مسارات منفصلة للإعدادات والبيانات والتخزين المؤقت والحالة والملفات المؤقتة، مع تخصيص وسائط التشغيل ومتغيرات البيئة ومجلد العمل.
- **مكتبة برامج محلية:** إضافة ملف تنفيذي مثبت، أو استيراد مجلد برنامج كامل أو أرشيف محمول بصيغة `.tar.gz` أو `.tar.xz` أو `.tar.zst`.
- **اختيار أيقونة من صور المشروع:** بعد اختيار الملف التنفيذي، تصفح صور المشروع ومجلداته الفرعية واختر أيقونة البرنامج، أو استخدم الاكتشاف التلقائي. يمكن تغييرها لاحقًا من «تعديل ← اختر أيقونة البرنامج». تُحفظ نسخة مستقلة مع المكتبة وتُحدّث أيقونات اختصارات الحسابات الموجودة عند الحفظ.
- **تحديث يدوي دون فقد الحسابات:** استبدال ملفات البرنامج من مجلد أو أرشيف جديد مع الحفاظ على بيانات الحسابات وإعداداتها، والتراجع عن الاستبدال عند فشل العملية. لا توجد تحديثات شبكية أو تلقائية.
- **اختصارات بأسماء الحسابات:** حفظ الحساب ينشئ اختصارًا باسمه في قائمة التطبيقات، بأيقونة البرنامج الأصلية عند اكتشافها، أو أيقونة أطياف كبديل. يمكن تحديث اختصارات الحسابات السابقة من زر «إضافة إلى قائمة تطبيقات الجهاز».
- **تشغيل مباشر:** الاختصارات المعتمدة تشغّل الحساب دون ظهور نافذة أطياف، مع بقاء المشرف في الخلفية لتسجيل المخرجات وحالة الخروج. التشغيل الأول أو تغيّر الملف التنفيذي يتطلب مراجعة وتأكيدًا.
- **متصفح الجهاز الافتراضي:** الروابط التي تفتحها البرامج عبر `xdg-open` تستخدم إعدادات الجهاز بدل إعدادات الحساب المعزول. تبقى متغيرات `PATH` و`BROWSER` المخصصة محترمة.
- **إدارة العمليات:** تشغيل وإيقاف تدريجي وإعادة تشغيل، مع إيقاف قسري منفصل ومؤكد عند الحاجة.
- **سجلات وتشخيص:** عرض سجل التشغيل والمخرجات والأخطاء، ونسخ التقارير كاملة أو تصديرها إلى TXT. زر «حذف الأخطاء» في صفحة «الأخطاء والتشخيص» يزيل الأخطاء القديمة بتأكيد لمراقبة الأخطاء الجديدة، دون حذف سجل تشغيل الحسابات أو ملفات المخرجات. صدّر تقارير أخطاء أطياف أولًا إن كنت تحتاجها. تتوفر تفاصيل انهيار النظام عند توفر `coredumpctl` والصلاحيات المناسبة.
- **نسخ احتياطي واستعادة:** تصدير المكتبة المُدارة واستعادتها، دون تضمين الملفات التنفيذية الخارجية أو بيانات المسارات المخصصة.
- **مسارات مؤقتة قصيرة:** تجنّب حدود طول مسارات مقابس Unix في تطبيقات Electron وChromium، دون تعطيل آليات الحماية الخاصة بها.

### الاستخدام

1. أضف البرنامج من ملف تنفيذي أو مجلد كامل أو أرشيف محمول. عند الاستيراد، اختر الملف التنفيذي الرئيسي صراحةً، ثم اختر الأيقونة من معرض الصور أو عبر زر «اختيار صورة من الجهاز» لتحديد ملف PNG أو صورة أخرى مباشرةً، أو اضغط «استخدام الأيقونة التلقائية». للملف الخارجي، يمكنك اختيار مجلد المشروع من المعرض. يتوفر البحث في مسارات الصور بالضغط على Enter، وتظهر جميع النتائج في شبكة واحدة بالتمرير مع تحميل المعاينات تلقائيًا؛ لا تُتبع المجلدات المرتبطة رمزيًا.
2. أنشئ حسابًا وسمّه، واضبط المسارات أو وسائط التشغيل إذا كان البرنامج يحتاج خيارات خاصة بالملفات الشخصية.
3. راجع الملف التنفيذي واعتمده عند التشغيل الأول.
4. شغّل الحساب من أطياف أو ابحث عن اسمه في قائمة تطبيقات الجهاز. لتجديد اختصار موجود وأيقونته، اضغط «إضافة إلى قائمة تطبيقات الجهاز».

إذا ظهرت أخطاء KWallet في برنامج Electron/Chromium، تحقق من محفظة الجهاز أولًا. عند استخدام خدمة Secret Service تعمل بدلًا منها، يتوفر في محرر الحساب خيار «Electron/Chromium: استخدام Secret Service» بتأكيد صريح. يغيّر مخزن التشفير وقد يتطلب تسجيل الدخول مجددًا؛ لا ينقل بيانات الدخول القديمة ولا يغيّر إعدادات النظام. احفظ الحساب وأعد تشغيله للتطبيق. يشرح سجل التشغيل أخطاء الشهادات `-202` وانقطاع المشرف؛ لا تُعطَّل حماية الشهادات ولا تُختلق رموز خروج مفقودة.

تقبل الأيقونات PNG وJPEG وGIF وBMP وSVG وغيرها بحسب مفككات GdkPixbuf المتاحة على الجهاز؛ يعرض زر اختيار الصورة الصيغ المتاحة في التلميح. ليست PNG شرطًا للملف الأصلي: تُحفظ نسخة PNG مستقلة داخليًا، وإطار ثابت للصور المتحركة.

الحسابات ذات مسار الإعدادات الافتراضي ترث الآن ترتيب أزرار النظام لتطبيقات GTK/Electron، ومنها VS Code وAntigravity، دون مغادرة Wayland. تُغيَّر القيمة الافتراضية لـ`button-layout` فقط عبر مخطط GSettings محلي؛ لا تُنسخ قواعد dconf أو بيانات الدخول ولا تُعدَّل ملفات settings.json. التفضيلات المحفوظة والمسارات المخصصة وإعدادات GSettings الصريحة تبقى كما هي. أعد تشغيل الحساب من النسخة الجديدة للتطبيق. يتطلب التوريث أدوات `gsettings` و`glib-compile-schemas` ومصادر `gsettings-desktop-schemas` على المضيف؛ غيابها لا يمنع تشغيل البرنامج.

كبديل اختياري لبرامج GTK المتوافقة، يتوفر في محرر الحساب خيار «GTK: تجربة أزرار النوافذ عبر X11» عند وجود DISPLAY للجهاز. يتطلب تأكيدًا ويضع `GDK_BACKEND=x11` للحساب وحده؛ احفظ وأعد تشغيل الحساب. قد يختلف التحجيم أو تكامل Wayland ويكون عزل النوافذ أضعف عبر X11، ولا يُفرض التغيير تلقائيًا أو على إعدادات الجهاز. للتراجع احذف المتغير أو غيّره إلى `wayland`. لا يمكن فرض أزرار التكبير والتصغير في الحوارات غير القابلة لتغيير الحجم أو أشرطة العنوان الخاصة بالبرنامج؛ برامج Qt/Electron قد تحتاج إعدادًا خاصًا بها.

وسائط التشغيل مصفوفة نصوص JSON، وليست أمرًا يُنفّذ في الصدفة. مثال لبرنامج يدعم خيار مسار بيانات المستخدم:

<div dir="ltr">

```json
["--user-data-dir={data}"]
```

</div>

يمكن استخدام `{config}` و`{data}` و`{cache}` و`{state}` و`{temp}` و`{home}` و`{profile}` في الوسائط وقيم البيئة. أعد تشغيل الحسابات العاملة لتطبيق إعدادات التشغيل الجديدة.

### البناء من المصدر

يتطلب البناء Flutter مع دعم Linux، وClang وCMake وNinja و`pkg-config` ومكتبات تطوير GTK3. يتطلب التشغيل Python 3 وSQLite و`xdg-utils` وXDG Desktop Portal مع واجهة اختيار ملفات مناسبة، و`zstd` لأرشيفات `.tar.zst`. التفاصيل في [ملاحظات البناء](BUILD_NOTES.md).

نفّذ من مجلد المشروع على جهاز Linux x86-64:

<div dir="ltr">

```bash
flutter pub get
bash tool/generate_l10n.sh
flutter build linux --release --target-platform linux-x64
./build/linux/x64/release/bundle/atyaf
```

</div>

لا تنقل الملف التنفيذي وحده؛ يحتاج مجلدي `lib` و`data` الموجودين معه في حزمة البناء.

لإنشاء حزم DEB وRPM وArch والأرشيف العام وAppImage، أو حزمة Flatpak، بعد تجهيز أدوات التحزيم الموضحة في ملاحظات البناء:

<div dir="ltr">

```bash
./build_linux.sh x64
./flatpak_linux.sh x64
```

</div>

تُحفظ الحزم في `dist/`. تدعم إعدادات المشروع Linux x86-64 وAArch64؛ يتطلب بناء ARM64 جهازًا أو بيئة Linux من المعمارية نفسها وأدوات Flutter المناسبة. راجع ملاحظات البناء للقيود؛ لا يُفترض توفر حزم ARM64 مبنية لمجرد وجود دعمها في السكربتات.

### الأمان والخصوصية

**فصل إعدادات الحسابات ليس عزلًا أمنيًا.** شغّل البرامج الموثوقة فقط. لا يُغيّر أطياف `HOME` الحقيقي افتراضيًا، والبرامج التي لا تدعم مسارات XDG تحتاج خياراتها الخاصة لفصل الحسابات.

- تُحفظ المكتبة افتراضيًا في `~/.local/share/com.h.atyaf`، أو تحت `XDG_DATA_HOME` عند تخصيصه.
- لا تُحذف البرامج الخارجية أو بيانات المسارات المخصصة عند حذف حساب.
- قد تحتوي السجلات والنسخ الاحتياطية ولقطات الشاشة على بيانات خاصة؛ راجعها قبل نشرها. نسخ التقرير إلى الحافظة محدود بـ64 ميبيبايت؛ تصدير TXT لا يقتطع السجلات.
- لا يشمل تكامل المتصفح البرامج التي تستخدم متصفحًا مدمجًا أو تتجاوز `xdg-open`. لا يُضمن نجاح كل تدفقات تسجيل الدخول في جميع البرامج.
- يُفضل استخدام خيارات التشغيل في المقدمة للبرامج التي تفصل نفسها إلى عمليات خلفية، حتى يبقى تتبع دورة التشغيل موثوقًا.

### المساهمة والنشر

اقتراحات التحسين وتقارير الأخطاء مرحّب بها. عند الإبلاغ عن مشكلة، اذكر توزيعة Linux وخطوات إعادة الإنتاج وأرفق تقريرًا بعد إزالة البيانات الحساسة.

يستبعد `.gitignore` ملفات البناء والحزم والملفات المحلية وبيانات التشغيل. ارفع الشفرة والمصادر إلى المستودع، وانشر الحزم الثنائية كمرفقات في **GitHub Releases** بدل إضافتها إلى تاريخ Git. ملف `.gitignore` لا يزيل الملفات التي سبق تتبعها ولا يغني عن مراجعة الملفات قبل النشر.

### الوثائق والترخيص

- [ملاحظات البناء والتحزيم](BUILD_NOTES.md)
- [بنية المشروع وقواعد التنفيذ](PROJECT_NOTES.md)
- [قرارات التصميم](DESIGN_DECISIONS.md)
- [رخصة MIT](LICENSE)

</div>

---

<a id="english"></a>

## English

**One application. Multiple accounts with independent settings.**

Atyaf is a Linux desktop application for managing and running multiple profiles of the same program. Keep work, personal and testing accounts separate, with independent settings and data for each profile and direct access from the system applications menu.

Built with Flutter and Dart, with Arabic and English interfaces, right-to-left support, and light, dark or system appearance.

### Screenshots

The screenshots are displayed in the Arabic section above:

- [Home screen with live application examples](#screenshot-home)
- [Settings](#screenshot-settings)
- [Errors and diagnostics](#screenshot-errors)

### Features

- **Independent profiles:** Separate config, data, cache, state and temporary paths, with configurable arguments, environment variables and working directory.
- **Local application library:** Reference an installed executable, or import a complete application folder or a portable `.tar.gz`, `.tar.xz` or `.tar.zst` archive.
- **Choose an icon from project images:** After selecting an executable, browse images throughout the project and its subfolders, or keep automatic discovery. Change it later through **Edit → Choose an application icon**. A separate copy is saved with the library, and existing account shortcut icons are refreshed on save.
- **Manual updates without losing profiles:** Replace application files from a new folder or archive while preserving profile data and settings, with rollback on failed replacement. No remote or automatic update checks.
- **Account-named shortcuts:** Saving a profile adds a system applications-menu shortcut with its own name and the original application's icon when discoverable, falling back to Atyaf's icon. Existing shortcuts can be refreshed using **Add to applications menu**.
- **Direct launching:** Approved shortcuts launch without the Atyaf window. A background supervisor preserves complete output and exit status. First launches and changed executables require review and approval.
- **Host default browser:** Links opened through `xdg-open` use the device's desktop settings rather than isolated profile defaults. Explicit `PATH` and `BROWSER` overrides are preserved.
- **Process management:** Launch, stop gracefully and restart, with force termination as a separate confirmed action.
- **Logs and diagnostics:** Inspect launch history, output and errors, copy complete reports or export TXT. **Clear errors** in **Errors and diagnostics** confirms removal of previous diagnostics so you can monitor new errors, without deleting profile launch history or output files. Export Atyaf error reports first if needed. System crash details are available when `coredumpctl` and permissions allow access.
- **Backup and restore:** Export and restore the managed library without including external executables or custom data paths.
- **Short temporary paths:** Avoid Electron/Chromium Unix socket pathname limits without disabling their security mechanisms.

### Usage

1. Add an executable, complete application folder or portable archive. Explicitly select the main executable when importing, then select a gallery image, use **Choose image from device** to pick a PNG or another image file directly, or select **Use automatic icon**. For an external executable, the gallery lets you choose its project folder. Search image paths by pressing Enter and scroll through all results in one grid with automatically loaded previews; symbolic-link directories are not followed.
2. Create and name a profile. Configure paths or arguments if the application requires its own profile options.
3. Review and approve the executable on the first launch.
4. Launch from Atyaf or search for the profile name in your system applications menu. Use **Add to applications menu** to refresh an existing shortcut and its icon.

For Electron/Chromium KWallet errors, check the host wallet first. If you intentionally use an active Secret Service instead, the profile editor offers **Electron/Chromium: use Secret Service** with explicit confirmation. This changes the encryption backend and may require signing in again; it neither migrates existing credentials nor changes system settings. Save and restart the profile to apply. Launch logs explain certificate error `-202` and interrupted supervision; certificate checks remain enabled and missing exit codes are never invented.

Icons accept PNG, JPEG, GIF, BMP, SVG and other formats advertised by installed GdkPixbuf decoders; the file-picker action's tooltip lists available formats. PNG is not required for the source: Atyaf stores an independent normalized PNG copy, using a still frame for animations.

Default-config profiles now inherit system window buttons for GTK/Electron apps, including VS Code and Antigravity, without leaving Wayland. Only the button-layout default changes through a local GSettings schema; no dconf database, credentials or settings.json are copied or edited. Stored preferences, custom paths and explicit GSettings setups remain unchanged. Restart the profile from the updated bundle to apply. This optional integration needs host gsettings, glib-compile-schemas and gsettings-desktop-schemas XML sources; missing tools never block application startup.

As an optional GTK-compatible alternative, the profile editor offers **GTK: try X11 window controls** when the host advertises DISPLAY. Explicit confirmation sets `GDK_BACKEND=x11` for that profile only; Save and restart to apply. Scaling or Wayland integration may differ, and X11 offers weaker window isolation. No automatic backend switch or host-settings change occurs; remove the variable or set it to `wayland` to undo. This cannot force minimize/maximize into non-resizable dialogs or custom title bars; Qt/Electron programs may need their own application-specific setting.

Arguments are a JSON array of strings, not a shell command. For an application that supports a user-data directory option:

```json
["--user-data-dir={data}"]
```

Arguments and environment values support `{config}`, `{data}`, `{cache}`, `{state}`, `{temp}`, `{home}` and `{profile}` substitutions. Restart running profiles to apply changed launch settings.

### Build from source

Building requires Flutter with Linux support, Clang, CMake, Ninja, `pkg-config` and GTK3 development libraries. Runtime requirements include Python 3, SQLite, `xdg-utils`, XDG Desktop Portal with a suitable file-chooser backend, and `zstd` for `.tar.zst` archives. See [build notes](BUILD_NOTES.md) for details.

Run from the project directory on Linux x86-64:

```bash
flutter pub get
bash tool/generate_l10n.sh
flutter build linux --release --target-platform linux-x64
./build/linux/x64/release/bundle/atyaf
```

Keep the executable together with the bundle's `lib` and `data` directories; copying the executable alone is not sufficient.

To generate DEB, RPM, Arch, general archive and AppImage packages, or a Flatpak bundle, after installing the packaging tools documented in the build notes:

```bash
./build_linux.sh x64
./flatpak_linux.sh x64
```

Packages are written to `dist/`. Project configuration supports Linux x86-64 and AArch64. ARM64 builds require a matching native Linux machine or environment and suitable Flutter tools. See the build notes for limitations; ARM64 script support does not imply that prebuilt ARM64 packages are available.

### Security and privacy

**Profile separation is not a security sandbox.** Only run trusted programs. Atyaf retains your real `HOME` by default; applications that ignore XDG paths require their own profile flags.

- The library defaults to `~/.local/share/com.h.atyaf`, or the configured `XDG_DATA_HOME`.
- Deleting a profile does not delete external programs or custom data paths.
- Logs, backups and screenshots may contain private information; review them before sharing. Clipboard reports have a 64 MiB limit; TXT export does not truncate logs.
- Browser integration does not cover applications using embedded browsers or bypassing `xdg-open`. Not every application's authentication flow is guaranteed to work.
- Prefer foreground launch options for applications that daemonize, so lifecycle tracking remains reliable.

### Contributing and publishing

Suggestions and bug reports are welcome. Include your Linux distribution and reproduction steps, and remove sensitive information from any attached diagnostics.

The `.gitignore` excludes builds, packages, local files and runtime data. Commit source files to the repository and publish binary packages as **GitHub Releases** assets rather than adding them to Git history. Ignore rules do not remove already-tracked files or replace a review of what you publish.

### Documentation and license

- [Build and packaging notes](BUILD_NOTES.md)
- [Project architecture and execution guidelines](PROJECT_NOTES.md)
- [Design decisions](DESIGN_DECISIONS.md)
- [MIT license](LICENSE)
