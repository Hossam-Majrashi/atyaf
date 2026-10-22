// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'أطياف';

  @override
  String get intro => 'برنامج واحد. هويات مستقلة متعددة.';

  @override
  String get introDetail =>
      'افصل ملفات العمل والاستخدام الشخصي والتجربة. أدر البرامج التنفيذية والمحمولة محليًا على Linux.';

  @override
  String get next => 'متابعة';

  @override
  String get finish => 'فتح المكتبة';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get theme => 'المظهر';

  @override
  String get dark => 'داكن';

  @override
  String get light => 'نهاري';

  @override
  String get system => 'حسب النظام';

  @override
  String get settings => 'الإعدادات';

  @override
  String get library => 'البرامج';

  @override
  String get searchApplications => 'بحث في البرامج';

  @override
  String get noMatchingApplications => 'لا توجد برامج مطابقة.';

  @override
  String get addApplication => 'إضافة برنامج';

  @override
  String get executable => 'ملف تنفيذي';

  @override
  String get executableFormats => 'Linux ELF / سكربتات (.sh أو بلا امتداد)';

  @override
  String get folderFormats => 'مجلد كامل يضم ملفات البرنامج';

  @override
  String get archiveFormats => '.tar.gz · .tar.xz · .tar.zst';

  @override
  String get appImageFormats => '.AppImage';

  @override
  String get executableImportHelp =>
      'تُحفظ نسخة مستقلة من هذا الملف داخل مكتبة أطياف؛ حذف الملف من التنزيلات لا يحذف النسخة المحفوظة. إن كان البرنامج يحتاج موارد أو مكتبات مجاورة، استورد مجلد البرنامج كاملًا بدلًا من الملف وحده. لا يؤدي الاستيراد إلى تشغيل الملف.';

  @override
  String get wmClass => 'فئة النافذة (اختياري)';

  @override
  String get wmClassHelp =>
      'يكتشف KDE فئة النافذة بعد التشغيل. تُتجاهل AppRun العامة لتجنب خلط أيقونات شريط المهام؛ استخدم فئة خاصة بالبرنامج.';

  @override
  String get folder => 'مجلد البرنامج';

  @override
  String get archive => 'أرشيف برنامج محمول';

  @override
  String get appImage => 'ملف AppImage';

  @override
  String get appImageHelp =>
      'تُحفظ نسخة مستقلة من AppImage دون تشغيلها. تُقرأ أيقونات التطبيق المضمّنة بأمان وتظهر في المعرض؛ يستخدم الاختيار التلقائي الشعار المكتشف، ويمكنك اختيار صورة أخرى. تستخدم الحسابات مسارات XDG؛ البرامج التي تتجاهلها تحتاج وسائط خاصة بها. قد يتطلب التشغيل FUSE أو اعتماديات أخرى. لا تُستورد مجلدات ‎.home/‎.config المجاورة.';

  @override
  String get appImageIconToolMissing =>
      'تحتاج قراءة أيقونات AppImage المضمّنة إلى 7-Zip ‏(7zz أو 7z) على الجهاز المضيف. ثبّت حزمة 7zip بمدير الحزم ثم أعد الاستيراد. يمكنك اختيار صورة يدويًا دون ذلك.';

  @override
  String get appImageIconUnsupported =>
      'نظام الملفات داخل AppImage غير مدعوم بقارئ الأيقونات المثبّت، مثل DwarFS. لم يُشغّل التطبيق. اختر صورة يدويًا أو استخدم الأيقونة البديلة.';

  @override
  String get appImageIconUnavailable =>
      'لم تُعثر على أيقونة تطبيق مضمّنة قابلة للقراءة، أو فشلت القراءة أو تجاوزت حدودها. اختر صورة يدويًا أو استخدم الأيقونة البديلة. لم يُشغّل التطبيق.';

  @override
  String get chooseExecutable => 'اختر ملفًا تنفيذيًا';

  @override
  String get managedLinksHelp =>
      'تبقى الروابط الرمزية الداخلية قابلة للنقل داخل البرنامج المستورد. تُرفض الروابط إلى ملفات خارجه والأهداف المفقودة وحلقات الروابط. لا يؤدي الاستيراد إلى تشغيل أي ملف تنفيذي.';

  @override
  String get applicationIcon => 'أيقونة البرنامج';

  @override
  String get chooseApplicationIcon => 'اختر أيقونة البرنامج';

  @override
  String get applicationIconHelp =>
      'اختر PNG أو JPG أو SVG وغيرها حسب دعم النظام. نحفظ نسخة PNG مستقلة؛ الصور المتحركة تُحفظ كصورة ثابتة. زر المجلد يقبل المجلدات فقط.';

  @override
  String supportedImageFormats(String formats) {
    return 'صيغ الصور المتاحة على هذا الجهاز: $formats';
  }

  @override
  String get chooseImageFolder => 'اختيار مجلد المشروع أو الصور';

  @override
  String get chooseImageFile => 'اختيار صورة من الجهاز';

  @override
  String get automaticIcon => 'استخدام الأيقونة التلقائية';

  @override
  String get searchImages => 'بحث في مسارات الصور (اضغط Enter)';

  @override
  String get noProjectImages =>
      'لا توجد صور مطابقة. اختر صورة مباشرةً من جهازك أو مجلد صور آخر، أو استخدم الأيقونة التلقائية.';

  @override
  String get imageUnavailable =>
      'الصورة تالفة أو غير مدعومة أو تتجاوز الحد المسموح (16 ميبيبايت / 8192 بكسل).';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String imageCount(int count) {
    return '$count صورة · مرّر لتصفحها';
  }

  @override
  String get launchAdvice => 'تشخيص التشغيل والاقتراحات';

  @override
  String get serviceConnectionAdvice =>
      'تشير Telemetry ConnectionFailed أو Social Overlay STOMP 4004 (Inactive timeout) إلى مشكلة اتصال في تلك الخدمات، وليس إلى دليل على انهيار البرنامج. إذا استمرت المشكلة فتحقق من اتصال الشبكة وحالة الخدمة. لا تثبت هذه الرسائل وحدها السبب أو حالة الخروج؛ ولا يغيّر أطياف إعدادات الشبكة أو TLS أو الحساب.';

  @override
  String get recoveredUiAdvice =>
      'يذكر السجل التعافي من خطأ عرض React #424. الإبلاغ عن التعافي لا يضمن عمل كل وظائف الواجهة ولا يفسّر خروجًا لاحقًا. راجع حالة الخروج الفعلية والمخرجات اللاحقة؛ لا تُضاف خيارات عرض أو تعطيل للعزل تلقائيًا.';

  @override
  String get lostExitAdvice =>
      'انقطع المشرف قبل تسجيل حالة الخروج. عدم توفر رمز الخروج لا يثبت انهيار البرنامج، ولا يمكن استرجاع الرموز القديمة المفقودة من هذه السجلات.';

  @override
  String get certificateAdvice =>
      'يعني خطأ Chromium رقم -202 أن جهة إصدار الشهادة غير موثوقة. افحص سلسلة شهادات الموقع ومخزن شهادات النظام وأي وكيل يفحص HTTPS. لا يحدد هذا السجل الموقع المتأثر. لا تعطّل التحقق من الشهادات ولا تستورد شهادة غير موثوقة.';

  @override
  String get walletAdvice =>
      'تعذر الاتصال بمحفظة KDE. تحقق من تفعيل KWallet وتوفرها على الجهاز. إذا كنت تستخدم عمدًا خدمة Secret Service تعمل بدلًا منها، يمكنك اختيارها صراحةً لملفات Electron/Chromium من محرر الحساب. قد يتطلب تغيير المخزن تسجيل الدخول مجددًا؛ لا يُنصح بالتخزين النصي غير المشفر.';

  @override
  String get desktopHandlerAdvice =>
      'يأتي تحذير الأعداد من مسار KDE القديم في xdg-open. يحافظ أطياف المحدّث على إصدار جلسة KDE للجهاز. أعد تشغيل الحساب بالنسخة المحدّثة لتجديد معالج الروابط.';

  @override
  String get shadps4CliAdvice =>
      'هذه شاشة استخدام نسخة shadPS4 CLI، وليست تقرير انهيار للنظام. النسخ التي تدعم Big Picture تحتاج --big-picture أو -b لفتح واجهتها؛ وقد تنتهي برمز 255 عند تشغيلها بلا وسائط. من محرر الحساب اختر خيار shadPS4 Big Picture ثم احفظ وأعد التشغيل. ويمكن بدلًا من ذلك استيراد shadPS4 Qt Launcher المنفصل للواجهة المكتبية، أو تحديد لعبة باستخدام --game. تعتمد الوسائط على النسخة المستوردة؛ لا يضيفها أطياف تلقائيًا.';

  @override
  String get useShadps4BigPicture => 'shadPS4: استخدام Big Picture';

  @override
  String get shadps4BigPictureConfirm =>
      'إضافة --big-picture إلى وسائط هذا الحساب؟ استخدمه فقط مع نسخة shadPS4 CLI التي تعرض هذا الخيار في المساعدة. يفتح وضع Big Picture وليس Qt Launcher المنفصل. تبقى الوسائط الأخرى وبيانات الحساب كما هي؛ لا تُنقل البيانات ولا يبدأ التشغيل تلقائيًا. احفظ الحساب وأعد تشغيله للتطبيق.';

  @override
  String get useSecretService => 'Electron/Chromium: استخدام Secret Service';

  @override
  String get secretServiceConfirm =>
      'إضافة --password-store=gnome-libsecret إلى وسائط هذا الحساب؟ استخدمه فقط مع برنامج Electron/Chromium متوافق وخدمة Secret Service تعمل على الجهاز مثل GNOME Keyring. يغيّر هذا مخزن التشفير وقد يتطلب تسجيل الدخول مجددًا. لا يتم نقل بيانات الدخول السابقة أو حذفها. احفظ الحساب وأعد تشغيله للتطبيق؛ لا تتغير KWallet أو إعدادات النظام.';

  @override
  String get name => 'الاسم';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get outputStreamsPending =>
      'لا يزال حفظ السجلات جاريًا. حاول التشغيل مجددًا بعد انتهاء البرنامج وعملياته المساعدة. يمكنك إغلاق نافذة أطياف؛ سيستمر تسجيل المخرجات في الخلفية. لم يتم تجاهل أي مخرجات.';

  @override
  String get profileAlreadyRunning =>
      'هذا الملف الشخصي يعمل بالفعل. لم يتم تشغيل نسخة ثانية.';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get deleteConfirm =>
      'حذف هذا العنصر وبياناته المُدارة؟ لا تُحذف الملفات الخارجية أو المسارات المخصصة مطلقًا.';

  @override
  String get emptyLibrary => 'مكتبتك تبدأ هنا';

  @override
  String get emptyLibraryDetail =>
      'أضف ملفًا تنفيذيًا أو مجلد برنامج أو أرشيفًا محمولًا أو AppImage لإنشاء ملفات شخصية مستقلة.';

  @override
  String get selectApplication => 'اختر برنامجًا لعرض ملفاته الشخصية';

  @override
  String get profiles => 'الملفات الشخصية';

  @override
  String get newProfile => 'ملف شخصي جديد';

  @override
  String get emptyProfiles => 'أنشئ هويتك الأولى لهذا البرنامج';

  @override
  String get launch => 'تشغيل';

  @override
  String get stop => 'إيقاف تدريجي';

  @override
  String get forceKill => 'إيقاف قسري';

  @override
  String get forceConfirm =>
      'قد يؤدي الإيقاف القسري إلى فقد العمل غير المحفوظ. هل تريد إنهاء العملية الآن؟';

  @override
  String get restart => 'إعادة تشغيل';

  @override
  String get running => 'يعمل';

  @override
  String get stopped => 'متوقف';

  @override
  String get shortcut => 'إضافة إلى قائمة تطبيقات الجهاز';

  @override
  String get shortcutUpdated =>
      'تم تحديث الاختصار وأيقونته في قائمة تطبيقات الجهاز.';

  @override
  String get desktopIntegrationHelp =>
      'يضيف حفظ الحساب اختصارًا باسمه في قائمة تطبيقات الجهاز، بأيقونة البرنامج إن توفرت. تعمل الاختصارات المعتمدة دون نافذة أطياف؛ يلزم تأكيد التشغيل الأول أو عند تغير الملف التنفيذي. تفتح الروابط عبر xdg-open في متصفح الجهاز الافتراضي، مع احترام متغيرات PATH وBROWSER المخصصة.';

  @override
  String get removeShortcut => 'إزالة الاختصار';

  @override
  String get terminalCommand => 'أمر الطرفية';

  @override
  String get createTerminalCommand => 'إنشاء الأمر';

  @override
  String get terminalCommandName => 'اسم الأمر، مثل rpcs3';

  @override
  String get terminalCommandHelp =>
      'أنشئ أمرًا في ‎~/.local/bin لتشغيل هذا الحساب تحديدًا عبر أطياف، مع إعداداته واعتماده وسجلاته. اختر أسماء مختلفة لأوامر الحسابات المتعددة. لا تُستبدل الأوامر الموجودة. تغيير اسم الحساب لا يغيّر أسماء أوامره.';

  @override
  String get terminalCommandInvalid =>
      'استخدم 1–64 حرفًا إنجليزيًا صغيرًا أو رقمًا أو نقطة أو شرطة أو شرطة سفلية، مع البدء بحرف. أسماء أوامر الصدفة المضمّنة محجوزة.';

  @override
  String get terminalArgumentsHelp =>
      'لا يقبل هذا الأمر وسائط إضافية. اضبط وسائط التطبيق من محرر الحساب في أطياف.';

  @override
  String terminalCommandCreated(String name) {
    return 'اكتب $name في الطرفية لتشغيل هذا الحساب. يظل التشغيل الأول أو تغيّر الملف التنفيذي بحاجة إلى الاعتماد داخل أطياف.';
  }

  @override
  String terminalCommandConflict(String detail) {
    return 'الاسم مستخدم بالفعل لحساب آخر أو أمر موجود: $detail. اختر اسمًا مختلفًا؛ لم يُستبدل أي ملف.';
  }

  @override
  String terminalCommandUnsafe(String detail) {
    return 'تعذّرت إدارة الأمر بأمان، مع الحفاظ على الملفات الموجودة. التفاصيل: $detail';
  }

  @override
  String get terminalPathMissing =>
      'المجلد ‎~/.local/bin غير موجود في PATH للمضيف. لجلسة Bash أو Zsh نفّذ السطر التالي قبل استخدام الأمر. أضفه بنفسك إلى إعدادات صدفتك إن أردت استمراره؛ لا يعدّل أطياف ملفات الصدفة. قد تتقدّم الأسماء المستعارة والدوال على هذا الأمر.';

  @override
  String get terminalPathCommand => 'export PATH=\"\$HOME/.local/bin:\$PATH\"';

  @override
  String get existingTerminalCommands => 'أوامر هذا الحساب';

  @override
  String get removeTerminalCommands => 'إزالة أوامر الطرفية';

  @override
  String get removeTerminalCommandsConfirm =>
      'هل تريد إزالة أوامر أطياف غير المعدّلة لهذا الحساب؟ يبقى التطبيق وبيانات الحساب واختصارات سطح المكتب والعمليات العاملة كما هي. تُترك الملفات المعدّلة دون مساس.';

  @override
  String get terminalCommandsRemoved =>
      'أُزيلت أوامر الطرفية مع الحفاظ على الحساب وبياناته.';

  @override
  String terminalCommandsPreserved(String names) {
    return 'أُزيلت الأوامر المُدارة. تُركت الملفات المعدّلة دون مساس وأصبحت خارج الإدارة: $names';
  }

  @override
  String get logs => 'سجل التشغيل والمخرجات';

  @override
  String get noLogs => 'لم يُسجّل تشغيل بعد';

  @override
  String get arguments => 'وسائط التشغيل (مصفوفة نصوص JSON)';

  @override
  String get environment => 'متغيرات البيئة (كائن JSON بقيم نصية)';

  @override
  String get workingDirectory =>
      'مجلد العمل (الفارغ يستخدم مجلد الملف التنفيذي)';

  @override
  String get configPath => 'مسار الإعدادات';

  @override
  String get dataPath => 'مسار البيانات';

  @override
  String get cachePath => 'مسار التخزين المؤقت';

  @override
  String get statePath => 'مسار الحالة';

  @override
  String get tempPath => 'مسار الملفات المؤقتة';

  @override
  String get homePath => 'مسار HOME (الفارغ يبقي HOME الحقيقي)';

  @override
  String get profileHelp =>
      'تُعزل مسارات XDG افتراضيًا ولا يتغير HOME. استخدم خيارات البرنامج الخاصة إن لم يدعم XDG. يمكن استخدام {config} و{data} و{cache} و{state} و{temp} و{home} و{profile} في الوسائط وقيم البيئة. هذا ليس عزلًا أمنيًا.';

  @override
  String get windowControlsHelp =>
      'يرث الحساب الافتراضي ترتيب أزرار النظام لتطبيقات GTK/Electron، مثل VS Code وAntigravity، دون مغادرة Wayland أو تغيير البيانات والتفضيلات الصريحة. المسارات المخصصة وإعدادات GSettings الخاصة لا تُغيَّر. خيار X11 أدناه بديل اختياري لـGTK، وليس الحل الأساسي لمحررات Electron.';

  @override
  String get useX11WindowControls => 'GTK: تجربة أزرار النوافذ عبر X11';

  @override
  String get x11Unavailable =>
      'يتطلب هذا الخيار وجود DISPLAY لجلسة X11 أو XWayland على الجهاز.';

  @override
  String get x11WindowControlsConfirm =>
      'تعيين GDK_BACKEND=x11 لهذا الحساب فقط؟ يناسب برامج GTK المتوافقة مع X11/XWayland، وقد يؤثر في التحجيم أو تكامل Wayland. عزل النوافذ في X11 أضعف منه في Wayland. لا يضمن الأزرار للحوارات غير القابلة لتغيير الحجم أو أشرطة العنوان الخاصة. تبقى بقية المتغيرات والوسائط وبيانات الحساب دون تغيير. احفظ وأعد تشغيل الحساب للتطبيق. للتراجع، احذف GDK_BACKEND من متغيرات البيئة أو غيّر قيمته إلى wayland.';

  @override
  String get invalidInput =>
      'أدخل اسمًا وJSON صالحًا. المسارات يجب أن تكون مطلقة ومفاتيح البيئة معرّفات صالحة.';

  @override
  String error(String detail) {
    return 'تعذر إكمال العملية. التفاصيل التقنية: $detail';
  }

  @override
  String get done => 'اكتملت العملية';

  @override
  String get openFailed => 'تعذر فتح الرابط';

  @override
  String get developer => 'المطور';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get website => 'الموقع';

  @override
  String get backup => 'النسخ الاحتياطي والاستعادة';

  @override
  String get exportBackup => 'تصدير المكتبة المُدارة';

  @override
  String get importBackup => 'استعادة المكتبة المُدارة';

  @override
  String get backupHelp =>
      'تتضمن النسخة الملفات الشخصية المُدارة والبرامج المحمولة وإعدادات المكتبة، دون ملفات البرامج الخارجية أو المسارات المخصصة. تتطلب الاستعادة توقف جميع الملفات وتستبدل المكتبة المُدارة. تبقى تفضيلات الواجهة كما هي.';

  @override
  String get restoreConfirm => 'استبدال المكتبة المُدارة بهذه النسخة؟';

  @override
  String get securityTitle => 'مراجعة الملف التنفيذي قبل التشغيل';

  @override
  String get securityWarning =>
      'شغّل البرامج الموثوقة فقط. العزل يفصل الإعدادات ولا يمنع الوصول إلى ملفاتك. تم فحص المسار الحقيقي للملف التنفيذي.';

  @override
  String fileReview(String path, String owner, int size, String mode) {
    return 'المسار: $path\nمعرّف المالك: $owner\nالحجم: $size بايت\nالصلاحيات: $mode';
  }

  @override
  String get trustLaunch => 'وثوق وتشغيل';

  @override
  String launchRecord(int pid, String start, String stop, String code) {
    return 'العملية $pid · البداية $start · النهاية $stop · رمز الخروج $code';
  }

  @override
  String get crashed => 'خروج غير متوقع';

  @override
  String get interrupted => 'انقطع المشرف؛ رمز الخروج غير متاح';

  @override
  String get openFullLog => 'فتح السجل الكامل';

  @override
  String get logPreview =>
      'معاينة أول 256 كيلوبايت. انسخ التقرير كاملًا أو صدّره إلى TXT للحصول على جميع المحتويات.';

  @override
  String get refreshLog => 'تحديث المعاينة';

  @override
  String get stdoutLabel => 'المخرجات القياسية';

  @override
  String get stderrLabel => 'الأخطاء القياسية';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get isolationNotice => 'مسارات مستقلة، وليست بيئة عزل أمني';

  @override
  String get busy => 'جارٍ التنفيذ';

  @override
  String get noExecutables => 'لم تُعثر على ملفات تنفيذية في هذا المجلد';

  @override
  String get errors => 'الأخطاء والتشخيص';

  @override
  String get noErrors => 'لا توجد أخطاء أو عمليات تشغيل فاشلة جديدة';

  @override
  String get clearErrors => 'حذف الأخطاء';

  @override
  String get clearErrorsConfirm =>
      'حذف أخطاء أطياف المعروضة وإزالة عمليات التشغيل الفاشلة الحالية من صفحة التشخيص؟ لا تتغير البرامج أو الحسابات، وتبقى سجلات التشغيل وملفات المخرجات في سجل الحساب. صدّر التقارير أولًا إن كنت تحتاجها. الأخطاء التي تصل بعد فتح هذا التأكيد لا تُحذف.';

  @override
  String get errorsCleared =>
      'تم حذف الأخطاء السابقة من صفحة التشخيص. ستظهر الأخطاء الجديدة تلقائيًا.';

  @override
  String get applicationErrors => 'أخطاء أطياف';

  @override
  String get failedLaunches => 'عمليات التشغيل الفاشلة';

  @override
  String get copyAll => 'نسخ التقرير كاملًا';

  @override
  String get exportTxt => 'تصدير TXT';

  @override
  String get copied => 'تم نسخ التقرير كاملًا';

  @override
  String get reportPrivacy =>
      'قد تتضمن التقارير مسارات خاصة وأسرارًا تطبعها البرامج وتفاصيل انهيار النظام. راجعها قبل مشاركتها. المعاينة محدودة؛ النسخ والتصدير يشملان السجلات كاملة.';

  @override
  String get copyTooLarge =>
      'يتجاوز التقرير حد الحافظة البالغ 64 ميبيبايت. صدّر TXT لحفظ التقرير كاملًا دون اقتطاع.';

  @override
  String get diagnosticDetails => 'التفاصيل التقنية';

  @override
  String get stackTrace => 'تتبّع الاستدعاءات';

  @override
  String get systemCrash => 'تفاصيل انهيار النظام';

  @override
  String get loadSystemCrash => 'عرض تفاصيل انهيار النظام';

  @override
  String get noSystemCrash =>
      'لا تتوفر تفاصيل انهيار النظام. قد تكون coredumpctl غير متاحة أو صلاحيات الوصول محدودة أو حُذف التقرير سابقًا.';

  @override
  String reportMetadata(
    String profile,
    String executable,
    String pid,
    String start,
    String stop,
    String code,
  ) {
    return 'الملف الشخصي: $profile\nالملف التنفيذي: $executable\nالعملية: $pid\nالبداية: $start\nالنهاية: $stop\nرمز الخروج: $code';
  }

  @override
  String get tempHelp =>
      'يستخدم المسار المؤقت الافتراضي مجلد Linux قصيرًا وخاصًا بكل ملف شخصي، لتجنب حدود مسارات مقابس Unix في برامج Electron وChromium. تبقى المسارات المؤقتة ومتغيرات TMPDIR المخصصة كما هي.';

  @override
  String get update => 'تحديث';

  @override
  String get updateSource => 'اختر مصدر الإصدار الجديد';

  @override
  String get updateHelp =>
      'التحديث يدوي. اختر ملفًا تنفيذيًا مستقلًا أو مجلدًا كاملًا أو أرشيف tar.gz أو tar.xz أو tar.zst أو ملف AppImage جديدًا. تُستبدل ملفات البرنامج فقط؛ تبقى الأسماء والأيقونات المختارة والحسابات وبياناتها واختصاراتها كما هي. يعمل AppImage كملف دون استخراج تلقائي أو تثبيت اعتماديات.';

  @override
  String get updateRunning =>
      'توجد ملفات شخصية تعمل لهذا البرنامج. أوقفها تدريجيًا قبل التحديث. لا يُستخدم الإيقاف القسري تلقائيًا.';

  @override
  String get updateSummary => 'استبدال البرنامج بهذا المصدر؟';

  @override
  String get source => 'المصدر';

  @override
  String get updateSuccess =>
      'تم تحديث البرنامج مع الحفاظ على الملفات الشخصية وإعداداتها.';

  @override
  String get managedApplication => 'برنامج مُدار — مستقل عن المصدر الأصلي';

  @override
  String get externalApplication =>
      'مرجع خارجي — يستورد التحديث نسخة مُدارة دون تغيير الملفات الخارجية';

  @override
  String executableCandidate(String path, int size, String mode) {
    return '$path · $size بايت · $mode';
  }
}
