// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'راد';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get pageNotFound => 'الصفحة غير موجودة';

  @override
  String get chooseLanguage => 'اختر لغتك';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get chooseRole => 'اختر دورك';

  @override
  String get guardianRole => 'ولي الأمر';

  @override
  String get volunteerRole => 'متطوع';

  @override
  String selectedRole(String role) {
    return 'الدور المحدد: $role';
  }

  @override
  String get languageHint => 'اختر اللغة التي تفضلها.';

  @override
  String get currentSelection => 'الاختيار الحالي';

  @override
  String get englishLanguage => 'اللغة الإنجليزية';

  @override
  String get arabicLanguage => 'اللغة العربية';

  @override
  String get brandFooter => 'راد • نجمع الأحبة من جديد';

  @override
  String get joinRadd => 'انضم إلى راد';

  @override
  String get roleHint => 'اختر كيف تود المتابعة';

  @override
  String get guardianDescription =>
      'سجّل الأفراد تحت رعايتك وتابع سلامتهم أثناء الفعالية.';

  @override
  String get volunteerDescription =>
      'ادخل إلى حسابك كمتطوع وساعد في الحالات النشطة أثناء الفعالية.';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get loginHint => 'سجّل الدخول للمتابعة';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get phoneHelp => 'أدخل رمز الدولة، مثل ‎+966501234567';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get createTitle => 'أنشئ حسابك';

  @override
  String get createHint => 'أنشئ حساب ولي الأمر للمتابعة';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get resetTitle => 'نسيت كلمة المرور؟';

  @override
  String get resetHint =>
      'أدخل بريدك الإلكتروني لطلب تعليمات استعادة كلمة المرور.';

  @override
  String get sendReset => 'إرسال تعليمات الاستعادة';

  @override
  String get resetSent =>
      'إذا كان هناك حساب مرتبط بهذا البريد، فستُرسل إليه تعليمات استعادة كلمة المرور.';

  @override
  String get noAccount => 'ليس لديك حساب؟';

  @override
  String get rememberPassword => 'تذكرت كلمة المرور؟';

  @override
  String get ageConfirm => 'أؤكد أن عمري 18 سنة أو أكثر.';

  @override
  String get privacyConfirm => 'قرأت إشعار الخصوصية وأوافق عليه.';

  @override
  String get privacyTitle => 'إشعار الخصوصية';

  @override
  String get privacyBody =>
      'معلومات عن المشروع — الإشعار النهائي قيد الاعتماد.\n\nيعالج راد المعلومات والصور لغرض لمّ الشمل ضمن الفعالية. يُنظّم الوصول وفق أدوار النظام. تخضع البيانات التعريفية والصور لقواعد الاحتفاظ والحذف الخاصة بالمشروع، وقد تُحتفظ معلومات إحصائية مجهولة الهوية وفق تصميم المشروع.\n\nسيُستبدل هذا الإشعار المؤقت بالنص المعتمد من الفريق.';

  @override
  String get requiredField => 'هذا الحقل مطلوب.';

  @override
  String get invalidName => 'أدخل اسماً لا يتجاوز 120 حرفاً.';

  @override
  String get invalidEmail => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get invalidPhone => 'أدخل + ثم رمز الدولة ورقم الهاتف (8–15 رقماً).';

  @override
  String get passwordHelp =>
      'استخدم 8 أحرف على الأقل، تتضمن حرفاً لاتينياً كبيراً وصغيراً ورقماً ورمزاً خاصاً.';

  @override
  String get confirmRequired => 'يجب تأكيد كلا الخيارين.';

  @override
  String get invalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get emailExists => 'هذا البريد الإلكتروني مسجل بالفعل.';

  @override
  String get networkError => 'تعذر الاتصال. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get serviceError => 'الخدمة غير متاحة حالياً. يرجى المحاولة مرة أخرى.';

  @override
  String get rateLimit => 'محاولات كثيرة. يرجى المحاولة لاحقاً.';

  @override
  String get roleError => 'لا يمكن لهذا الحساب الوصول إلى خدمات ولي الأمر.';

  @override
  String get notFoundError => 'هذا السجل لم يعد متاحاً.';

  @override
  String get activeCaseError =>
      'لا يمكن حذف الفرد أثناء وجود حالة نشطة. يجب حل الحالة أو إلغاؤها أولاً.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get home => 'الرئيسية';

  @override
  String get myIndividuals => 'الأفراد المسجلون';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get registerIndividual => 'تسجيل فرد';

  @override
  String get registerHint => 'أضف شخصاً تحت رعايتك';

  @override
  String get individualsHint => 'الأشخاص المسجلون تحت رعايتك';

  @override
  String get emptyTitle => 'لم يتم تسجيل أفراد بعد';

  @override
  String get emptyHint => 'ابدأ بتسجيل شخص تحت رعايتك.';

  @override
  String get addIndividual => 'إضافة فرد';

  @override
  String get editIndividual => 'تعديل بيانات الفرد';

  @override
  String get individualProfile => 'ملف الفرد';

  @override
  String get photoLabel => 'الصورة';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get retakePhoto => 'إعادة التقاط الصورة';

  @override
  String get cameraOnly => 'التقاط مباشر بكاميرا التطبيق فقط';

  @override
  String get cameraGuide =>
      'احرص على وضوح الوجه والإضاءة الجيدة وعدم وجود عوائق.';

  @override
  String get cameraDenied =>
      'تم رفض الوصول للكاميرا. اسمح باستخدامها لالتقاط صورة. إذا حُظرت الطلبات، فعّل الإذن من أذونات التطبيق في أندرويد.';

  @override
  String get cameraUnavailable => 'الكاميرا غير متاحة. يرجى المحاولة مجدداً.';

  @override
  String get capture => 'التقاط الصورة';

  @override
  String get photoRequired => 'التقط صورة قبل الحفظ.';

  @override
  String get photoTooLarge => 'الصورة كبيرة جداً. يرجى إعادة التقاطها.';

  @override
  String get age => 'العمر';

  @override
  String get invalidAge => 'أدخل العمر كعدد صحيح بين 0 و130.';

  @override
  String get gender => 'الجنس';

  @override
  String get female => 'أنثى';

  @override
  String get male => 'ذكر';

  @override
  String get relationship => 'صلة القرابة بولي الأمر';

  @override
  String get daughter => 'ابنة';

  @override
  String get son => 'ابن';

  @override
  String get parent => 'أحد الوالدين';

  @override
  String get sibling => 'أخ أو أخت';

  @override
  String get other => 'شخص آخر تحت رعايتي';

  @override
  String get save => 'حفظ';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get edit => 'تعديل';

  @override
  String get deleteIndividual => 'حذف الفرد';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get language => 'اللغة';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutTitle => 'تسجيل الخروج؟';

  @override
  String get logoutMessage => 'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get emailReadOnly =>
      'يُدار البريد عبر مصادقة Firebase ولا يمكن تعديله هنا.';

  @override
  String get volunteerUnavailable =>
      'دخول المتطوع غير متاح في هذا الإصدار بعد.';

  @override
  String get sessionExpired => 'يرجى تسجيل الدخول للمتابعة.';

  @override
  String get completeProfile => 'أكمل ملف ولي الأمر';

  @override
  String get completeProfileHint =>
      'تم تسجيل دخولك. أكمل ملفك أو أعد محاولة حفظه للمتابعة.';

  @override
  String get brandTagline => 'نجمع الأحبة من جديد';

  @override
  String get splashSupport => 'غد أكثر أماناً لكل رحلة';

  @override
  String get validationError => 'يرجى مراجعة المعلومات والمحاولة مجدداً.';

  @override
  String greeting(String name) {
    return 'مرحباً، $name';
  }

  @override
  String deleteMessage(String name) {
    return 'هل تريد حذف $name وصورته؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get emailPlaceholder => 'name@example.com';

  @override
  String get alreadyAccount => 'لديك حساب بالفعل؟';

  @override
  String get qrCode => 'رمز QR';

  @override
  String get cases => 'الحالات';

  @override
  String get comingLater => 'ستتوفر هذه الميزة في مرحلة لاحقة.';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get greetingIntro => 'مرحباً،';

  @override
  String get individualsTitle => 'الأفراد';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get add => 'إضافة';

  @override
  String get addIndividualHint => 'أضف معلومات الفرد لهذه الفعالية.';

  @override
  String get photoHeading => 'الصورة';

  @override
  String get cameraRequired => 'الكاميرا مطلوبة';

  @override
  String get enterFullName => 'أدخل الاسم الكامل';

  @override
  String get enterAge => 'أدخل العمر';

  @override
  String get selectRelationship => 'اختر صلة القرابة';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get accountInformation => 'معلومات الحساب';

  @override
  String get changePhotoCamera => 'تغيير الصورة (الكاميرا)';

  @override
  String get usePhoto => 'استخدام الصورة';

  @override
  String get deleteIndividualTitle => 'حذف الفرد؟';

  @override
  String get volunteerLogin => 'تسجيل دخول المتطوع';

  @override
  String get restoringSession => 'استعادة جلستك';

  @override
  String get restoringSessionHint => 'جارٍ التحقق من حسابك ودورك بأمان.';

  @override
  String get sessionRecovery => 'استعادة الحساب';

  @override
  String get missingProfileRecovery =>
      'تم تسجيل دخول حسابك، لكن ملفه غير مكتمل. أكمل ملف ولي الأمر أو اختر دورك للمتابعة.';

  @override
  String get expiredSessionRecovery =>
      'تعذر التحقق من جلستك. اختر دورك لتسجيل الدخول مجددًا.';

  @override
  String get roleRecovery =>
      'تعذر التحقق من هذا الحساب للدور المحدد. ارجع إلى اختيار الدور أو سجّل الدخول بالحساب الصحيح.';

  @override
  String get sessionUnavailable =>
      'تعذر التحقق من ملف حسابك لأن خدمة الحسابات غير متاحة. أعد المحاولة أو ارجع إلى اختيار الدور للوصول إلى تسجيل الدخول. لم يتم حذف حسابك.';

  @override
  String get completeGuardianProfile => 'إكمال ملف ولي الأمر';

  @override
  String get returnToRoles => 'العودة إلى اختيار الدور';

  @override
  String get startupFailed => 'تعذر بدء راد';

  @override
  String get startupFailedHint =>
      'لم تكتمل تهيئة التطبيق. يرجى إعادة المحاولة.';
}
