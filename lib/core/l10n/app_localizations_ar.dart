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
  String get addApplication => 'إضافة برنامج';

  @override
  String get executable => 'ملف تنفيذي';

  @override
  String get wmClass => 'فئة النافذة (اختياري)';

  @override
  String get wmClassHelp =>
      'حدد StartupWMClass فقط إذا كان البرنامج يحتاجه لربط نوافذه باختصار قائمة التطبيقات.';

  @override
  String get folder => 'مجلد البرنامج';

  @override
  String get archive => 'أرشيف برنامج محمول';

  @override
  String get chooseExecutable => 'اختر ملفًا تنفيذيًا';

  @override
  String get name => 'الاسم';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get closeConfirm =>
      'يجب إيقاف الملفات التي تعمل قبل إغلاق أطياف لتسجيل المخرجات ورموز الخروج. هل تريد إيقافها الآن؟';

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
      'أضف ملفًا تنفيذيًا أو مجلد برنامج أو أرشيفًا محمولًا لإنشاء ملفات شخصية مستقلة.';

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
  String get noErrors => 'لا توجد أخطاء لأطياف أو عمليات تشغيل فاشلة مسجلة';

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
      'التحديث يدوي. اختر مجلدًا كاملًا أو أرشيف tar.gz أو tar.xz أو tar.zst. تُستبدل ملفات البرنامج فقط؛ تبقى الملفات الشخصية وبياناتها واختصاراتها كما هي.';

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
