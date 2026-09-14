// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'رد';

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
  String get vApp => 'متطوع رادّ';

  @override
  String get vHome => 'الرئيسية';

  @override
  String get vCases => 'الحالات';

  @override
  String get vReport => 'إبلاغ';

  @override
  String get vBadge => 'البطاقة';

  @override
  String get vProfile => 'حسابي';

  @override
  String get vAccount => 'حساب المتطوع';

  @override
  String get vActive => 'نشط';

  @override
  String get vInactive => 'غير نشط';

  @override
  String get vAvailable => 'الحالات المتاحة';

  @override
  String get vMyCases => 'حالاتي';

  @override
  String get vPriorityCases => 'حالات قريبة ذات أولوية';

  @override
  String get vNearby => 'ضمن ٥٠٠ متر';

  @override
  String get vViewCase => 'عرض الحالة';

  @override
  String get vViewAll => 'عرض الكل';

  @override
  String get vQuickActions => 'إجراءات سريعة';

  @override
  String get vReportFound => 'الإبلاغ عن شخص عُثر عليه';

  @override
  String get vDigitalId => 'بطاقة المتطوع الرقمية';

  @override
  String get vVolunteerId => 'رقم المتطوع';

  @override
  String get vStartSearch => 'بدء البحث';

  @override
  String get vReportReceived => 'تم استلام البلاغ';

  @override
  String get vSearchProgress => 'البحث جارٍ';

  @override
  String get vMatchConfirmed => 'تم تأكيد التطابق';

  @override
  String get vAwaitingGuardian => 'بانتظار التحقق من ولي الأمر';

  @override
  String get vReunited => 'تم لمّ الشمل';

  @override
  String get vCaseDetails => 'تفاصيل الحالة';

  @override
  String get vMissingReport => 'بلاغ شخص مفقود';

  @override
  String get vAge => 'العمر';

  @override
  String get vGender => 'الجنس';

  @override
  String get vMale => 'ذكر';

  @override
  String get vFemale => 'أنثى';

  @override
  String get vCaseId => 'رقم الحالة';

  @override
  String get vStatus => 'الحالة';

  @override
  String get vReported => 'وقت البلاغ';

  @override
  String get vUpdated => 'آخر تحديث';

  @override
  String get vPendingDetails => 'جارٍ جمع التفاصيل الإضافية';

  @override
  String get vPendingHint =>
      'ستظهر المعلومات الإضافية عندما يقدّمها ولي الأمر. يمكنك بدء البحث الآن.';

  @override
  String get vLastSeen => 'آخر ظهور';

  @override
  String get vCaseInformation => 'معلومات الحالة';

  @override
  String get vClothing => 'الملابس';

  @override
  String get vDistinctive => 'الأغراض أو السمات المميزة';

  @override
  String get vAdditional => 'معلومات إضافية';

  @override
  String get vJoined => 'أُضيفت إلى حالاتي';

  @override
  String get vNoCases => 'لا توجد حالات هنا حاليًا';

  @override
  String get vNoCasesHint => 'ستظهر الحالات هنا عند توفرها.';

  @override
  String get vNotifications => 'الإشعارات';

  @override
  String get vAllAlerts => 'كل التنبيهات';

  @override
  String get vPriorityOnly => 'حالات الأولوية';

  @override
  String get vRecentAlerts => 'التنبيهات الأخيرة';

  @override
  String get vNewAlert => 'تنبيه حالة جديدة';

  @override
  String get vPriorityAlert => 'حالة قريبة ذات أولوية';

  @override
  String get vStatusAlert => 'تحديث حالة';

  @override
  String get vPriorityHint =>
      'تعتمد تنبيهات الأولوية على وجودك ضمن ٥٠٠ متر من آخر موقع ظهور مُبلّغ عنه بإحداثيات متاحة.';

  @override
  String get vNoAlerts => 'لا توجد إشعارات بعد';

  @override
  String get vClose => 'إغلاق';

  @override
  String get vCaptureNotice =>
      'التقط صورة فقط عند مساعدة شخص عُثر عليه أو انفصل عن ذويه.';

  @override
  String get vPositionFace => 'اجعل الوجه ظاهرًا بوضوح';

  @override
  String get vPhotoHint => 'تأكد من وضوح الوجه وجودة الإضاءة.';

  @override
  String get vOpenCamera => 'فتح الكاميرا';

  @override
  String get vPhotoPurpose =>
      'تُستخدم الصورة الملتقطة للبحث عن تطابقات محتملة فقط.';

  @override
  String get vFinding => 'البحث عن تطابق';

  @override
  String get vSearchingProfiles => 'جارٍ البحث في الملفات المسجلة…';

  @override
  String get vMatchingHint =>
      'مراجعة الملفات المسجلة المؤهلة بحثًا عن تطابقات محتملة.';

  @override
  String get vCancelSearch => 'إلغاء البحث';

  @override
  String get vPotentialMatches => 'التطابقات المحتملة';

  @override
  String get vPotentialMatch => 'تطابق محتمل';

  @override
  String get vCandidateHint =>
      'هذه تطابقات محتملة وليست هويات مؤكدة. راجع معلومات الشخص قبل اختيار التطابق.';

  @override
  String get vSimilarity => 'التشابه';

  @override
  String get vViewDetails => 'عرض التفاصيل';

  @override
  String get vManualFallback => 'لا يوجد تطابق مناسب؟ تابع بالمراجعة اليدوية.';

  @override
  String get vManualReview => 'المراجعة اليدوية';

  @override
  String get vSearchName => 'البحث بالاسم';

  @override
  String get vAll => 'الكل';

  @override
  String get vClearFilters => 'مسح التصفية';

  @override
  String get vRegisteredIndividuals => 'الأفراد المسجلون';

  @override
  String get vNoResults => 'لا توجد ملفات مطابقة';

  @override
  String get vMatchDetails => 'تفاصيل التطابق';

  @override
  String get vFoundIndividual => 'الشخص الذي عُثر عليه';

  @override
  String get vRegisteredProfile => 'الملف المسجل';

  @override
  String get vCompare => 'مقارنة الصور';

  @override
  String get vMatchNotice =>
      'يتطلب التطابق المحتمل مراجعة المتطوع والتحقق من ولي الأمر. لا تُؤكد الهوية تلقائيًا.';

  @override
  String get vConfirmMatch => 'تأكيد التطابق';

  @override
  String get vConfirmMatchQuestion => 'تأكيد التطابق؟';

  @override
  String get vConfirmMatchHint =>
      'هل تريد اختيار هذا الشخص كتطابق والانتقال إلى التواصل مع ولي الأمر؟';

  @override
  String get vCancel => 'إلغاء';

  @override
  String get vBackResults => 'العودة إلى النتائج';

  @override
  String get vGuardianContact => 'التواصل مع ولي الأمر';

  @override
  String get vMatchedIndividual => 'الشخص المطابق';

  @override
  String get vGuardianDetails => 'بيانات ولي الأمر';

  @override
  String get vGuardianName => 'اسم ولي الأمر';

  @override
  String get vRelationship => 'صلة القرابة';

  @override
  String get vMother => 'الأم';

  @override
  String get vFather => 'الأب';

  @override
  String get vRegisteredContact => 'وسيلة التواصل المسجلة';

  @override
  String get vContactGuardian => 'الاتصال بولي الأمر';

  @override
  String get vProceedVerification => 'المتابعة إلى التحقق';

  @override
  String get vVerifyGuardian => 'التحقق من ولي الأمر';

  @override
  String get vScanInstruction =>
      'امسح رمز QR المعروض في حالة ولي الأمر داخل رادّ.';

  @override
  String get vScanHint => 'ثبّت رمز الحالة داخل الإطار.';

  @override
  String get vScanCode => 'مسح رمز QR';

  @override
  String get vUnableScan => 'يتعذر عرض رمز QR؟';

  @override
  String get vUseIdentifier => 'استخدام رقم الحالة';

  @override
  String get vVerifyIdentifier => 'التحقق من رقم الحالة';

  @override
  String get vIdentifierHelp =>
      'اطلب من ولي الأمر عرض رقم الحالة من حسابه المسجّل دخوله في رادّ إذا تعذر عرض رمز QR.';

  @override
  String get vGuardianIdentifier => 'رقم الحالة لدى ولي الأمر';

  @override
  String get vExactIdentifier =>
      'يجب أن يتطابق الرقمان. قارنه بالحالة المعروضة على جهاز ولي الأمر نفسه.';

  @override
  String get vAuthenticatedAccount =>
      'يعرض ولي الأمر هذه الحالة من حسابه المسجّل دخوله في رادّ.';

  @override
  String get vVerify => 'التحقق من الرقم';

  @override
  String get vVerificationFailed => 'فشل التحقق';

  @override
  String get vVerificationMismatch =>
      'الرمز أو الرقم لا يطابق ولي الأمر والحالة.';

  @override
  String get vNoHandover => 'لا تسلّم الشخص. أعد التحقق أو استخدم رقم الحالة.';

  @override
  String get vTryAgain => 'إعادة المحاولة';

  @override
  String get vGuardianVerified => 'تم التحقق من ولي الأمر';

  @override
  String get vVerificationSuccess => 'نجح التحقق';

  @override
  String get vAccountCaseVerified => 'تم التحقق من حساب ولي الأمر لهذه الحالة.';

  @override
  String get vVerifiedTime => 'وقت التحقق';

  @override
  String get vVerificationMethod => 'طريقة التحقق';

  @override
  String get vQrMethod => 'رمز QR الخاص بالحالة';

  @override
  String get vIdentifierMethod => 'رقم الحالة';

  @override
  String get vContinueHandover => 'المتابعة إلى التسليم';

  @override
  String get vConfirmHandover => 'تأكيد التسليم';

  @override
  String get vHandoverHint =>
      'أكّد فقط بعد تسليم الشخص إلى ولي الأمر الذي تم التحقق منه.';

  @override
  String get vHandoverQuestion => 'تأكيد لمّ الشمل؟';

  @override
  String get vHandoverConfirmHint =>
      'أكّد تسليم الشخص بأمان إلى ولي الأمر الذي تم التحقق منه.';

  @override
  String get vCompleted => 'اكتملت الحالة';

  @override
  String get vCompletedHint => 'تم تأكيد التسليم بنجاح.';

  @override
  String get vHandoverTime => 'وقت التسليم';

  @override
  String get vConfirmedBy => 'أكّد التسليم';

  @override
  String get vDone => 'تم';

  @override
  String get vAuthorized => 'متطوع رادّ معتمد';

  @override
  String get vVolunteerName => 'اسم المتطوع';

  @override
  String get vAccountInformation => 'معلومات الحساب';

  @override
  String get vFullName => 'الاسم الكامل';

  @override
  String get vEmail => 'البريد الإلكتروني';

  @override
  String get vPhone => 'رقم الجوال';

  @override
  String get vLanguage => 'اللغة';

  @override
  String get vLogout => 'تسجيل الخروج';

  @override
  String get vLogoutQuestion => 'هل تريد إنهاء جلسة المتطوع؟';

  @override
  String get vPreview => 'معاينة التصميم · بيانات تجريبية';

  @override
  String get vPreviewOpen => 'معاينة تصاميم المتطوع';

  @override
  String get vPreviewCamera => 'معاينة الكاميرا';

  @override
  String get vPreviewCameraHint =>
      'تستخدم المعاينة صورة تجريبية من التصميم. لن تُلتقط صورة ولن يُرسل طلب للذكاء الاصطناعي.';

  @override
  String get vPreviewCapture => 'محاكاة الالتقاط';

  @override
  String get vPreviewQr => 'معاينة التحقق بالرمز';

  @override
  String get vPreviewQrHint =>
      'اختر نتيجة تجريبية. لن يُمسح رمز ولن يُتحقق من ولي أمر حقيقي.';

  @override
  String get vPreviewValid => 'رمز مطابق';

  @override
  String get vPreviewInvalid => 'رمز غير مطابق';

  @override
  String get vPreviewCall =>
      'وسيلة تواصل تجريبية فقط. لا تُجرى مكالمة في معاينة التصميم.';

  @override
  String get vUnavailable => 'هذه الخدمة غير مربوطة بعد.';

  @override
  String get vBackendHint => 'ستتاح خدمات الحالات بعد ربط خادم الفعالية.';

  @override
  String get vInactiveHint => 'حساب المتطوع غير نشط. تواصل مع منظّم الفعالية.';

  @override
  String get vLocation => 'تنبيهات الحالات القريبة';

  @override
  String get vLocationHelp =>
      'اسمح بالموقع أثناء استخدام رادّ لمعرفة قربك ضمن ٥٠٠ متر من موقع مُبلّغ عنه. تبقى التنبيهات العامة متاحة دون الموقع.';

  @override
  String get vAllowLocation => 'السماح بالموقع';

  @override
  String get vLocationUnavailable =>
      'الموقع غير متاح. يمكنك الاستمرار في استخدام رادّ واستلام التنبيهات العامة.';

  @override
  String get vLocationReady => 'الموقع متاح أثناء استخدام رادّ.';

  @override
  String get vLogin => 'تسجيل الدخول';

  @override
  String get vWelcome => 'أهلًا بعودتك';

  @override
  String get vLoginHint => 'سجّل الدخول إلى حساب المتطوع';

  @override
  String get vPassword => 'كلمة المرور';

  @override
  String get vForgot => 'نسيت كلمة المرور؟';

  @override
  String get vReset => 'استعادة كلمة المرور';

  @override
  String get vResetHint =>
      'أدخل بريدك الإلكتروني لاستلام تعليمات استعادة كلمة المرور.';

  @override
  String get vSendReset => 'إرسال التعليمات';

  @override
  String get vResetSent =>
      'إذا كان البريد مسجلًا، فستصلك تعليمات استعادة كلمة المرور.';

  @override
  String get vAccountManaged => 'يوفّر منظّم الفعالية حسابات المتطوعين.';

  @override
  String get vRequired => 'هذا الحقل مطلوب.';

  @override
  String get vInvalidEmail => 'أدخل بريدًا إلكترونيًا صحيحًا.';

  @override
  String get vInvalidLogin => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get vNetworkError => 'تحقق من اتصال الإنترنت وحاول مجددًا.';

  @override
  String get vAccessDenied => 'يلزم حساب متطوع معتمد. تواصل مع منظّم الفعالية.';

  @override
  String get vActionFailed => 'تعذر إتمام الإجراء. حاول مجددًا.';

  @override
  String get vNoMissingReport => 'لا يوجد بلاغ فقدان';

  @override
  String get vSearchJoinedHint => 'بدأت البحث في هذه الحالة.';

  @override
  String get vAdditionalReceived => 'وصلت معلومات إضافية';

  @override
  String vAgeValue(String value) {
    return 'العمر $value';
  }

  @override
  String vCount(String count) {
    return '$count حالات';
  }

  @override
  String vSimilarityValue(String value) {
    return 'التشابه $value٪';
  }
}
