// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'رادّ';

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
  String get brandFooter => 'رادّ · نردّ الأحبة من جديد';

  @override
  String get joinRadd => 'انضم إلى رادّ';

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
  String get phoneHelp => 'رقم هاتف سعودي، مثل ‎0501234567 أو ‎+966501234567';

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
      'أدخل بريدك الإلكتروني لتصلك رسالة لإعادة تعيين كلمة المرور.';

  @override
  String get sendReset => 'إرسال رسالة إعادة التعيين';

  @override
  String get resetSent =>
      'إذا كان هناك حساب مرتبط بهذا البريد الإلكتروني، فستصلك رسالة لإعادة تعيين كلمة المرور.';

  @override
  String get noAccount => 'ليس لديك حساب؟';

  @override
  String get rememberPassword => 'تذكرت كلمة المرور؟';

  @override
  String get ageConfirm => 'أؤكد أن عمري 18 عامًا أو أكثر.';

  @override
  String get privacyConfirm =>
      'لقد قرأت وأوافق على إشعار الخصوصية الخاص برادّ.';

  @override
  String get privacyTitle => 'إشعار الخصوصية';

  @override
  String get privacyIntro =>
      'في رادّ، نحترم خصوصيتك وخصوصية الأشخاص المسجلين تحت رعايتك. قد تتضمن البيانات التي يعالجها النظام معلومات شخصية وصورًا لأطفال أو كبار سن أو غيرهم من الأشخاص الذين قد يحتاجون إلى المساعدة عند انفصالهم عن ذويهم خلال الفعالية.\n\nيوضح هذا الإشعار المعلومات التي يستخدمها رادّ، والغرض من استخدامها، وكيف يتم استخدامها أثناء عملية البحث والتعرف وإعادة لمّ الشمل، ومن يمكنه الوصول إليها، ومدة الاحتفاظ بها ومتى يتم حذفها.';

  @override
  String get privacyInfoTitle => 'المعلومات التي نجمعها ونستخدمها';

  @override
  String get privacyInfoBody =>
      'عند إنشاء حساب ولي الأمر واستخدام رادّ، يعالج النظام المعلومات اللازمة لإنشاء حسابك واستخدامه، بالإضافة إلى المعلومات التي تقدمها عن الأشخاص المسجلين تحت رعايتك، بما في ذلك بياناتهم التعريفية وصورهم.\n\nعند تقديم بلاغ فقدان، قد يعالج رادّ أيضًا المعلومات المرتبطة بالحالة، مثل تفاصيل الشخص المفقود، والمعلومات الوصفية التي تقدمها للمساعدة في البحث، ومعلومات آخر مكان شوهد فيه الشخص. وإذا اخترت استخدام موقع جهازك كموقع لآخر مشاهدة وسمحت للتطبيق بالوصول إلى الموقع، فقد يتم استخدام إحداثيات الموقع لهذا الغرض.\n\nتُستخدم هذه المعلومات لدعم عمليات التسجيل، والإبلاغ، والبحث، والتعرف، والتحقق، وإعادة لمّ الشمل ضمن الفعالية.\n\nتُحفظ معلومات حسابك (الاسم والبريد الإلكتروني ورقم الهاتف) ما دام حساب ولي الأمر قائمًا، ولا تُحذف ضمن قواعد الاحتفاظ التي تنطبق على بيانات الأفراد المسجلين.';

  @override
  String get privacyRegisteredPhotosTitle => 'صور الأشخاص المسجلين';

  @override
  String get privacyRegisteredPhotosBody =>
      'الصورة المرجعية التي تُلتقط عند تسجيل الفرد، وأي بيانات وجه مشتقة منها، جزء من بياناته المسجلة. يُحتفظ بها طوال مدة الاحتفاظ التي تختارها عند التسجيل، وتُحذف مع بقية بياناته عند انتهاء المدة. التقاط صورة جديدة لاحقًا يستبدل الصورة السابقة ولا يغيّر مدة الاحتفاظ.\n\nتُستخدم الصور فقط للمساعدة في التعرف على الفرد أثناء الفعالية، ولا تحل اقتراحات الذكاء الاصطناعي محل المراجعة البشرية والتحقق من ولي الأمر.';

  @override
  String get privacyVolunteerPhotosTitle => 'الصور التي يلتقطها المتطوعون';

  @override
  String get privacyVolunteerPhotosBody =>
      'إذا تم العثور على شخص أو انفصل عن ذويه، فقد يقوم متطوع مخوّل بالتقاط صورة له من خلال رادّ، وذلك فقط ضمن سير عمل التعرف وإعادة لمّ الشمل.\n\nقد تُستخدم هذه الصورة في عملية التعرف، بما في ذلك مقارنتها بالملفات المسجلة المؤهلة للمساعدة في إيجاد تطابقات محتملة. ويقتصر التقاط هذه الصور على المتطوعين المخولين أثناء مساعدتهم لشخص تم العثور عليه أو انفصل عن ذويه.\n\nتُحذف الصورة التي يلتقطها المتطوع عند انتهاء محاولة التعرف، سواء تم تأكيد وجود تطابق أم لا.';

  @override
  String get privacyLocationTitle => 'معلومات الموقع';

  @override
  String get privacyLocationBody =>
      'قد يستخدم رادّ معلومات الموقع لدعم البحث والتنبيهات المرتبطة بالقرب من آخر مكان شوهد فيه الشخص.\n\nبالنسبة لبلاغ الفقدان، إذا أكد ولي الأمر أنه موجود في المكان الذي شوهد فيه الشخص آخر مرة وسمح للتطبيق بالوصول إلى موقع الجهاز، يمكن تسجيل الموقع المتاح باعتباره موقع آخر مشاهدة للحالة. وإذا لم يسمح بالوصول إلى الموقع، أو لم يكن الموقع متاحًا، فلا يتم استخدام موقع الجهاز لهذا الغرض. ويمكن بدلًا من ذلك تقديم وصف نصي للموقع ضمن معلومات الحالة.\n\nكما يستخدم رادّ موقع المتطوع، عند منحه الإذن المطلوب، لتحديد ما إذا كان قريبًا من موقع آخر مشاهدة وإرسال تنبيه أولوية عند انطباق شروط القرب. وقد يتم تحديث موقع المتطوع أثناء تشغيل التطبيق في الخلفية عند توفر الإذن المطلوب.';

  @override
  String get privacyUsageTitle => 'كيف تُستخدم المعلومات أثناء البحث والتعرف';

  @override
  String get privacyUsageBody =>
      'عند وجود حالة نشطة، قد تُستخدم المعلومات والصور المسجلة وتفاصيل البلاغ لمساعدة المتطوعين المخولين في البحث ومراجعة التطابقات المحتملة.\n\nيستخدم رادّ المطابقة المدعومة بالذكاء الاصطناعي للمساعدة في مقارنة صورة الشخص الذي تم العثور عليه بالملفات المسجلة المؤهلة، وقد يعرض تطابقات محتملة للمراجعة. وإذا لم تكن المطابقة كافية، يمكن استخدام المراجعة اليدوية للمعلومات والصور المتاحة ضمن الحالة.\n\nنتائج المطابقة هي وسيلة مساعدة لعملية التعرف وليست قرارًا نهائيًا تلقائيًا؛ ويظل تأكيد التطابق والتحقق من ولي الأمر جزءًا من عملية إعادة لمّ الشمل.';

  @override
  String get privacyAccessTitle => 'الوصول إلى المعلومات وحمايتها';

  @override
  String get privacyAccessBody =>
      'لا تكون الصور والمعلومات الشخصية متاحة للتصفح العام. يقتصر الوصول إلى البيانات المحمية على المستخدمين المخولين ووفق أدوارهم، وبالقدر المطلوب لتنفيذ وظائفهم ضمن عملية البحث والتعرف والتحقق وإعادة لمّ الشمل.\n\nويطبق النظام التحقق من الصلاحيات على الطلبات التي تصل إلى البيانات المحمية أو تعدّلها، وليس اعتمادًا على إخفاء عناصر الواجهة فقط.';

  @override
  String get privacyRetentionTitle => 'الاحتفاظ بالصور وبيانات الحالات وحذفها';

  @override
  String get privacyRetentionBody =>
      'عند تسجيل فرد، تختار مدة الاحتفاظ ببياناته (بياناته التعريفية وصورته وبيانات الوجه) من الخيارات المهيأة للفعالية الحالية؛ وإذا لم تختر، تُطبَّق أطول مدة متاحة. لا يمكن أن تتجاوز المدة نهاية الفعالية. ويمكنك تغييرها لاحقًا من ملف الفرد ما دام الموعد الجديد لم يحل بعد وضمن مدة الفعالية.\n\nعند انتهاء المدة تُحذف البيانات تلقائيًا. وإذا كان هناك بلاغ فقد لا يزال نشطًا حينها، يؤجَّل الحذف حتى إغلاق البلاغ.\n\nالصور التي يلتقطها المتطوعون لشخص معثور عليه صور مؤقتة، وتُحذف فور انتهاء محاولة التعرف.\n\nتُحذف سجلات الحالات بعد انتهاء مدة الاحتفاظ بالحالة، ولا يبقى بعدها إلا المعلومات الإحصائية المحدودة الموضحة أدناه.';

  @override
  String get privacyStatisticsTitle => 'البيانات المستخدمة للإحصاءات والتقارير';

  @override
  String get privacyStatisticsBody =>
      'بعد انتهاء مدة الاحتفاظ بالحالة وحذف بياناتها التعريفية، يحتفظ رادّ فقط بالحد الأدنى من المعلومات اللازمة للتقارير الإحصائية: مرجع الحالة، ونتيجتها النهائية، ووقت إنشائها وإغلاقها، والفئة العمرية للفرد، والفعالية. تُجمَّع هذه المعلومات أو تُجهَّل حيثما ينطبق ذلك. وفي الحالات التي انتهت بلمّ الشمل، قد يُحتفظ بمرجع المتطوع الذي أتمّ التسليم لإعداد إحصاءات لمّ الشمل حسب المتطوع.\n\nلا يُحتفظ بأي أسماء أو صور أو معلومات اتصال أو بيانات وجه أو مواقع دقيقة.';

  @override
  String get privacyAgreementTitle => 'موافقتك';

  @override
  String get privacyAgreementBody =>
      'بالموافقة على إشعار الخصوصية، فإنك تقر بأنك قرأت هذا الإشعار وتوافق على جمع المعلومات والصور واستخدامها والوصول إليها والاحتفاظ بها وحذفها وفق ما هو موضح أعلاه.';

  @override
  String get requiredField => 'هذا الحقل مطلوب.';

  @override
  String get invalidName => 'أدخل اسماً لا يتجاوز 120 حرفاً.';

  @override
  String get invalidEmail => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get invalidPhone =>
      'أدخل رقم هاتف سعودي صحيح، مثل ‎0501234567 أو ‎+966501234567.';

  @override
  String get passwordHelp =>
      'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل، وتشمل حرفًا إنجليزيًا كبيرًا، وحرفًا إنجليزيًا صغيرًا، ورقمًا، ورمزًا خاصًا مثل ! أو @ أو # أو \$.';

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
      'لا يمكن تعديل الفرد أو حذفه أثناء وجود حالة نشطة. يجب حل الحالة أو إلغاؤها أولاً.';

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
  String get photoRequired => 'الصورة مطلوبة.';

  @override
  String get photoTooLarge => 'الصورة كبيرة جداً. يرجى إعادة التقاطها.';

  @override
  String get age => 'العمر';

  @override
  String get invalidAge => 'أدخل عمرًا صحيحًا.';

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
  String get other => 'أخرى';

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
  String get brandTagline => 'نردّ الأحبة من جديد';

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
  String get accountDeactivated =>
      'تم إيقاف هذا الحساب من قِبل إدارة الفعالية. تواصل مع منظّمي الفعالية للمساعدة.';

  @override
  String get completeGuardianProfile => 'إكمال ملف ولي الأمر';

  @override
  String get returnToRoles => 'العودة إلى اختيار الدور';

  @override
  String get startupFailed => 'تعذر بدء رادّ';

  @override
  String get startupFailedHint =>
      'لم تكتمل تهيئة التطبيق. يرجى إعادة المحاولة.';

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
  String get vScanHint => 'ثبّت رمز QR الخاص بولي الأمر داخل الإطار.';

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
      'إذن الموقع وتشغيل خدمات الموقع مطلوبان للمشاركة في الفعالية. يستخدم رادّ موقعك لإعطاء أولوية لتنبيهات الحالات القريبة. إذا تعذّر تقدير الموقع مؤقتًا يمكنك مواصلة المشاركة.';

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

  @override
  String get reportMissing => 'الإبلاغ عن مفقود';

  @override
  String get reportConfirm => 'هل تريد الإبلاغ عن فقدان هذا الفرد؟';

  @override
  String get confirm => 'تأكيد';

  @override
  String get reportReceived => 'تم استلام البلاغ';

  @override
  String get searchInProgress => 'البحث جارٍ';

  @override
  String get matchConfirmed => 'تم تأكيد التطابق';

  @override
  String get awaitingVerification => 'بانتظار تحقق ولي الأمر';

  @override
  String get reunited => 'تمت إعادة لمّ الشمل';

  @override
  String get unknownCaseStatus => 'الحالة غير متاحة';

  @override
  String get caseStatus => 'حالة البلاغ';

  @override
  String get viewStatus => 'عرض الحالة';

  @override
  String get trackStatus => 'متابعة الحالة';

  @override
  String get activeCases => 'البلاغات النشطة';

  @override
  String get noCases => 'لا توجد بلاغات بعد';

  @override
  String get noCasesHint => 'ستظهر بلاغاتك عن المفقودين هنا.';

  @override
  String get reportingAssistant => 'مساعد الإبلاغ';

  @override
  String get sameLocationQuestion =>
      'هل موقعك الحالي هو نفس المكان الذي شوهد فيه الفرد المفقود آخر مرة؟';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get lastSeenDescription => 'أين شوهد الفرد آخر مرة؟';

  @override
  String get clothingQuestion =>
      'ما الملابس التي كان يرتديها الفرد عند رؤيته آخر مرة؟';

  @override
  String get distinctiveQuestion =>
      'هل كان الفرد يحمل شيئًا مميزًا، مثل حقيبة أو لعبة؟';

  @override
  String get distinctiveDescription => 'صف الشيء المميز';

  @override
  String get additionalQuestion =>
      'هل توجد معلومات إضافية قد تساعد المتطوعين في العثور على الفرد؟';

  @override
  String get saveReport => 'حفظ تفاصيل البلاغ';

  @override
  String get reportSaved => 'تم حفظ تفاصيل البلاغ';

  @override
  String get locationRequired =>
      'اسمح بالوصول إلى الموقع لاستخدام موقعك الحالي، أو اختر لا وصف مكان آخر مشاهدة.';

  @override
  String get locationReady => 'تم تحديد موقعك الحالي لهذا البلاغ';

  @override
  String get useCurrentLocation => 'استخدام موقعي الحالي';

  @override
  String get noNotifications => 'لا توجد إشعارات بعد';

  @override
  String get notificationHint => 'ستظهر هنا التحديثات المتعلقة ببلاغاتك.';

  @override
  String get guardianVerification => 'رمز تحقق ولي الأمر';

  @override
  String get verificationExplanation =>
      'اعرض هذا الرمز لمتطوع مخوّل للتحقق من ارتباطك بهذا البلاغ. الرمز لا يحدد هوية الفرد المفقود.';

  @override
  String get noEligibleCases => 'لا توجد بلاغات بانتظار تحقق ولي الأمر.';

  @override
  String get verificationExpired =>
      'انتهت صلاحية الرمز. أنشئ رمزًا جديدًا للمتابعة.';

  @override
  String get refreshCode => 'إنشاء رمز جديد';

  @override
  String get showCaseIdentifier => 'عرض معرّف البلاغ';

  @override
  String get caseIdentifier => 'معرّف البلاغ';

  @override
  String get caseIdentifierHint =>
      'شارك هذا المرجع مع أحد أعضاء الفريق المخوّلين. المرجع وحده لا يثبت هويتك.';

  @override
  String get eventUnavailable =>
      'الإبلاغ غير متاح مؤقتًا لأن الفعالية الحالية لم تُفعّل. يرجى المحاولة لاحقًا.';

  @override
  String get guidedDetails => 'تفاصيل البلاغ';

  @override
  String get lastUpdated => 'آخر تحديث';

  @override
  String get requiredAnswer => 'يرجى إكمال هذه الإجابة.';

  @override
  String get activeCase => 'بلاغ نشط';

  @override
  String get verificationExpires => 'صالح حتى';

  @override
  String get close => 'إغلاق';

  @override
  String get vLoadFailed => 'تعذّر التحميل الآن. اضغط للمحاولة مجددًا.';

  @override
  String get vContinueReport => 'متابعة البلاغ';

  @override
  String get vAiUnavailable =>
      'المطابقة بالذكاء الاصطناعي غير متاحة. تم حفظ البلاغ ويمكنك المتابعة بالمراجعة اليدوية.';

  @override
  String get vQrRequired =>
      'اطلب من ولي الأمر عرض رمز QR الخاص بهذه الحالة من حسابه المسجّل في راد. رقم الحالة وحده لا يثبت الهوية.';

  @override
  String get child => 'ابن/ابنة';

  @override
  String get specifyRelationship => 'حدد صلة القرابة';

  @override
  String get casesAwaitingVerification => 'بلاغات بانتظار التحقق';

  @override
  String get resolved => 'تم الحل';

  @override
  String get cancelled => 'ملغي';

  @override
  String get referredToAuthority => 'تمت الإحالة إلى الجهة المختصة';

  @override
  String get casesSubtitle => 'تابع بلاغاتك عن الأفراد المفقودين';

  @override
  String get resolveReport => 'حل البلاغ';

  @override
  String get resolveReportConfirm =>
      'هل تريد حل هذا البلاغ؟ استخدم هذا فقط إذا وجدت الفرد بنفسك خارج رادّ.';

  @override
  String get cancelReport => 'إلغاء البلاغ';

  @override
  String get cancelReportConfirm =>
      'هل تريد إلغاء هذا البلاغ؟ استخدم هذا فقط إذا تم إنشاؤه بالخطأ.';

  @override
  String get reunitedOutcome => 'تم جمع شمل هذا الفرد مع ولي أمره.';

  @override
  String get caseClosedNotice =>
      'هذا البلاغ مغلق ولم يعد جزءًا من عمليات البحث والمطابقة النشطة.';

  @override
  String get caseDetails => 'تفاصيل الحالة';

  @override
  String get activeCaseLockNotice =>
      'التعديل والحذف غير متاحين أثناء وجود حالة نشطة لهذا الفرد.';

  @override
  String get guidedAssistantRequired =>
      'يرجى إكمال الأسئلة المطلوبة قبل مغادرة هذه الشاشة.';

  @override
  String get caseClosedActionError => 'هذا البلاغ مغلق ولا يمكن تغييره.';

  @override
  String get reportAlreadySubmitted =>
      'لقد تم تقديم هذا البلاغ مسبقًا ولا يمكن تعديله.';

  @override
  String get photoExpiredError =>
      'انتهت فترة التسجيل أو تعذّر تحديدها. أنشئ تسجيلًا جديدًا بفترة صالحة للفعالية.';

  @override
  String get photoExpiredNotice =>
      'هذا التسجيل غير مؤهل لبلاغ فقد جديد. التقاط صورة جديدة وحده لا يجدد فترة التسجيل.';

  @override
  String get updatePhotoRequired => 'تحديث الصورة';

  @override
  String get caseId => 'رقم البلاغ';

  @override
  String get updatedLabel => 'آخر تحديث';

  @override
  String ageYears(String value) {
    return '$value سنة';
  }

  @override
  String get caseHistory => 'سجل البلاغات';

  @override
  String get noActiveCasesHint => 'لا توجد بلاغات نشطة حالياً.';

  @override
  String get progressTimeline => 'مراحل التقدم';

  @override
  String stageLabel(String number) {
    return 'المرحلة $number';
  }

  @override
  String stageStatus(String number, String status) {
    return 'المرحلة $number: $status';
  }

  @override
  String get activeLabel => 'الحالية';

  @override
  String get completedLabel => 'مكتملة';

  @override
  String get statusUpdatesAutomatically => 'تُحدَّث الحالة تلقائياً';

  @override
  String get reportReceivedDescription =>
      'تم استلام بلاغك وإشعار المتطوعين النشطين.';

  @override
  String get searchInProgressDescription => 'يبحث المتطوعون حالياً عن الفرد.';

  @override
  String get matchConfirmedDescription =>
      'أكّد أحد المتطوعين وجود تطابق وسينتقل إلى التحقق من ولي الأمر.';

  @override
  String get awaitingVerificationDescription =>
      'اعرض رمز تحقق ولي الأمر للمتطوع لتأكيد هويتك.';

  @override
  String get reunitedDescription => 'تم جمع شمل الفرد معك بأمان.';

  @override
  String get outcomeLabel => 'النتيجة';

  @override
  String get lastSeenLocationLabel => 'موقع آخر مشاهدة';

  @override
  String get currentLocationConfirmed => 'تم تأكيد الموقع الحالي';

  @override
  String get clothingLabel => 'الملابس';

  @override
  String get distinctiveLabel => 'شيء مميز';

  @override
  String get additionalLabel => 'معلومات إضافية';

  @override
  String get none => 'لا يوجد';

  @override
  String get detailsPending => 'لم تكتمل تفاصيل البلاغ بعد.';

  @override
  String get reportedByGuardian => 'بلاغ من ولي الأمر';

  @override
  String get todayJustNow => 'اليوم • الآن';

  @override
  String assistantIntro(String name) {
    return 'تم تقديم بلاغ فقدان $name. سأطرح عليك بعض الأسئلة السريعة لمساعدة المتطوعين في البحث.';
  }

  @override
  String get locationHint => 'يُستخدم لتنسيق المتطوعين القريبين.';

  @override
  String get answersAutoSave => 'تُحفظ الإجابات تلقائياً في البلاغ النشط';

  @override
  String get typeAnswer => 'اكتب إجابتك…';

  @override
  String get send => 'إرسال';

  @override
  String get qrSubtitle => 'اعرض هذا الرمز للمتطوع للتحقق من ولي الأمر';

  @override
  String get qrVerifiesAccount =>
      'يتحقق هذا الرمز من أن حساب ولي الأمر المسجّل دخوله مرتبط بهذا البلاغ.';

  @override
  String get qrVerifiesAccountNoCase =>
      'يتحقق هذا الرمز من حساب ولي الأمر المسجّل دخوله، ولا يحدد هوية أي فرد مفقود.';

  @override
  String get selectActiveCase => 'اختر البلاغ النشط';

  @override
  String get scanInstruction => 'اطلب من المتطوع مسح هذا الرمز باستخدام رادّ.';

  @override
  String get cannotDisplayQr => 'يتعذر عرض رمز QR؟';

  @override
  String get caseIdentifierInstruction =>
      'اعرض هذا المعرّف للمتطوع للتحقق البديل.';

  @override
  String get caseIdentifierUsage =>
      'يُستخدم لتحديد البلاغ النشط والتحقق منه عندما يتعذر عرض رمز QR أو مسحه.';

  @override
  String get activeCaseIdentifier => 'معرّف البلاغ النشط';

  @override
  String get noActiveCaseQrNote =>
      'لا توجد لديك بلاغات نشطة حالياً. يبقى رمز ولي الأمر صالحاً للتحقق.';

  @override
  String get qrRefreshing => 'جارٍ إنشاء رمز جديد…';

  @override
  String get resetSentTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String get backToLogin => 'العودة إلى تسجيل الدخول';

  @override
  String get resendReset => 'إعادة الإرسال';

  @override
  String get vAccountDeactivated => 'حساب المتطوع غير نشط. تم تسجيل خروجك.';

  @override
  String get vEndIdentification => 'إنهاء محاولة التعرف';

  @override
  String get vEndIdentificationHint =>
      'هل تريد إنهاء محاولة التعرف وحذف الصورة الملتقطة؟ سيستمر بلاغ الفقدان والبحث دون تغيير.';

  @override
  String get locationNotRecorded =>
      'تعذّر تسجيل الموقع. يمكنك المتابعة؛ يبقى التنبيه العام نشطًا.';

  @override
  String get vCancelledAlert => 'إلغاء الحالة';

  @override
  String get vResolvedAlert => 'العثور على الشخص';

  @override
  String get vNewAlertMessage => 'تم تقديم بلاغ فقدان جديد.';

  @override
  String get vPriorityAlertMessage =>
      'تم تقديم بلاغ فقدان ضمن ٥٠٠ متر من موقعك المتاح.';

  @override
  String get vMatchAlertMessage =>
      'تم تأكيد تطابق لحالة انضممت للبحث عنها. لا يزال التحقق من ولي الأمر والتسليم مطلوبين.';

  @override
  String get vCancelledAlertMessage =>
      'ألغى ولي الأمر بلاغ الفقدان لهذه الحالة.';

  @override
  String get vResolvedAlertMessage => 'عثر ولي الأمر على الشخص وأغلق الحالة.';

  @override
  String get vReunitedAlertMessage => 'تم تسليم الشخص إلى ولي أمره بعد التحقق.';

  @override
  String get vLocationSettings => 'فتح الإعدادات';

  @override
  String get vLocationDeniedForever =>
      'فعّل إذن الموقع من الإعدادات لمواصلة المشاركة في الفعالية.';

  @override
  String get vLocationServicesDisabled =>
      'شغّل خدمات الموقع في الجهاز لمواصلة المشاركة في الفعالية.';

  @override
  String get vLocationServiceTitle => 'المشاركة في فعالية رادّ';

  @override
  String get vLocationServiceBody =>
      'يستخدم رادّ الموقع لتنبيهات الحالات القريبة أثناء مشاركتك المصرّح بها في الفعالية، بما في ذلك أثناء وجود التطبيق في الخلفية.';

  @override
  String get vLocationServiceChannel => 'موقع الفعالية';

  @override
  String get vEventAuthorized => 'مصرّح له بالمشاركة في الفعالية الحالية';

  @override
  String get vEventUnassigned => 'غير مكلّف بالفعالية الحالية';

  @override
  String get vAccountStatus => 'حالة الحساب';

  @override
  String get vNotificationCaseUnavailable =>
      'لم تعد هذه الحالة متاحة للبحث النشط. تم تحديث التنبيهات والحالات.';

  @override
  String get vJoinSearch => 'الانضمام للبحث';

  @override
  String get vFindWithAi => 'البحث عن تطابق بالذكاء الاصطناعي';

  @override
  String get vStandalonePending =>
      'لا يوجد بلاغ فقد مرتبط بهذا الشخص. تم حفظ بلاغ العثور. تأكيد التطابق والتحقق من ولي الأمر والتسليم لبلاغ العثور المستقل غير متاحة بعد.';

  @override
  String get vLocationRequired => 'الموقع مطلوب للمشاركة';

  @override
  String get vAiReady =>
      'تم حفظ بلاغ العثور. ابدأ التعرف بمساعدة الذكاء الاصطناعي، أو استخدم المراجعة اليدوية عند الحاجة.';

  @override
  String get vAiError =>
      'تعذّر إكمال التعرف. حاول مجددًا أو تابع بالمراجعة اليدوية.';

  @override
  String get vNoEligibleRegistrations =>
      'لا يوجد حاليًا أشخاص مسجلون مؤهلون للمراجعة في هذه الفعالية.';

  @override
  String get registrationPeriodTitle => 'مدة الاحتفاظ بالبيانات';

  @override
  String get registrationPeriodHint =>
      'اختر مدة الاحتفاظ ببيانات هذا الفرد. سيتم حذف بياناته تلقائيًا عند انتهاء المدة المحددة، وفقًا لإشعار الخصوصية.';

  @override
  String get registrationPeriodDefault => 'أطول فترة متاحة (افتراضيًا)';

  @override
  String registrationPeriodHours(int hours) {
    return '$hours ساعة';
  }

  @override
  String get registrationPeriodUnavailable =>
      'فترات التسجيل غير متاحة لهذه الفعالية حاليًا. حاول لاحقًا.';

  @override
  String get registrationPeriodBoundary =>
      'تبدأ المدة عند التسجيل ولا يمكن أن تتجاوز نهاية الفعالية. وإذا كان هناك بلاغ فقد لا يزال نشطًا عند انتهائها، يؤجَّل الحذف حتى إغلاق البلاغ.';

  @override
  String get retentionEditBoundary =>
      'تُحسب المدة من تاريخ التسجيل الأصلي. يمكنك تمديدها أو تقصيرها ما دام الموعد الجديد لم يحل بعد وضمن مدة الفعالية.';

  @override
  String registrationPeriodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String retentionUntil(String date) {
    return 'يُحتفظ بالبيانات حتى $date';
  }

  @override
  String get retentionPassedError =>
      'هذه المدة تكون قد انتهت بالفعل. اختر مدة أطول.';

  @override
  String get retentionInvalidError =>
      'مدة الاحتفاظ المختارة غير متاحة لهذه الفعالية.';

  @override
  String retentionOptionUnavailable(String label, String reason) {
    return '$label ($reason)';
  }

  @override
  String get retentionOptionPassed => 'انتهت بالفعل';

  @override
  String get retentionOptionBeyondEvent => 'بعد نهاية الفعالية';

  @override
  String get currentEvent => 'الفعالية الحالية';

  @override
  String eventDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String registeringForEvent(String event) {
    return 'التسجيل في الفعالية النشطة: $event';
  }

  @override
  String get vFoundReportTitle => 'بلاغ العثور على شخص';

  @override
  String get vIdentityConfirmed => 'تم تأكيد الهوية';

  @override
  String get vIdentificationInProgress => 'جارٍ تحديد الهوية';

  @override
  String get vFoundIdentifierHelp =>
      'اعرض معرّف بلاغ العثور من حساب ولي الأمر المسجّل دخوله في رد. قارن المعرّف كاملًا قبل تأكيد التحقق.';

  @override
  String get vFoundReportIdentifier => 'معرّف بلاغ العثور';

  @override
  String get vConfirmIdentity => 'تأكيد الهوية';

  @override
  String get vTermsDocument =>
      '### الغرض والنطاق\nيساعد رادّ في الإبلاغ والبحث والتعرّف والتحقق من ولي الأمر وإعادة الجمع خلال\nالفعاليات. التطبيق أداة للتنسيق؛ نتيجة التعرّف المحتملة ليست إثباتًا للهوية أو\nإذنًا بتسليم الشخص. تشمل هذه المسودة وظائف ولي الأمر والمتطوع الموضحة أدناه.\nواجهة المشرف ومحرك مطابقة الوجوه الفعلي غير منفذين حاليًا.\n\n### الحسابات والأدوار المصرّح بها\nيستخدم ولي الأمر حسابه المسجّل لإدارة بيانات الأفراد تحت رعايته وبلاغات الفقدان\nالحقيقية. يستخدم المتطوع حسابًا منشأً عبر إجراءات إدارة الحسابات المصرّح بها في\nالمشروع، ولا يسجّل حساب متطوع بنفسه. حافظ على خصوصية الدخول، واستخدم البيانات\nوالإجراءات المسموح بها لدورك فقط. لا تستخدم جلسة شخص آخر أو بيانات دخوله أو رمز\nالتحقق الخاص به للحصول على وصول غير مصرح به.\n\nحالة حساب المتطوع مستقلة عن انتسابه إلى الفعالية. تتطلب المشاركة تسجيل الدخول،\nوحسابًا مفعّلًا، وانتسابًا إلى الفعالية النشطة الحالية، وإذن الموقع المطلوب،\nوتشغيل خدمات الموقع. قد تتوقف المشاركة عند تعطيل الحساب أو إزالة الانتساب أو\nفقدان صلاحية الوصول المطلوبة. تعكس بطاقة المتطوع الرقمية فحص الحساب والانتساب،\nولا تحل محل التحقق من ولي الأمر.\n\n### الموقع شرط للمشاركة\nالوصول إلى موقع المتطوع مطلوب أثناء المشاركة في الفعالية النشطة لغرض التنسيق\nوإعطاء الأولوية للمتطوعين القريبين. قد يستمر تحديث الموقع عندما يعمل رادّ في\nالخلفية وفق تنفيذ Android، باستخدام خدمة الموقع والإشعار المستمر المطلوبين.\nيجب أن يتوقف الوصول المرتبط بالفعالية عند انتهاء أهلية المشاركة، بما يشمل\nتسجيل الخروج وتعطيل الحساب وإزالة الانتساب وفقدان الوصول إلى الفعالية النشطة\nوسحب الإذن أو تعطيل خدمات الموقع.\n\nيتحكم Android في خيارات الإذن. قبول الشروط لا يمنح إذن Android. يبقى الوصول\nإلى وظائف الفعالية محجوبًا عند رفض الإذن أو سحبه أو إيقاف خدمات الموقع حتى\nاستعادتها. إذا كان الإذن والخدمات صالحين لكن تعذّر تقدير الموقع مؤقتًا، تبقى\nالمشاركة والتنبيهات العامة متاحة؛ وتعود أهلية أولوية القرب عند توفر تقدير مناسب.\n\nموقع ولي الأمر يخضع لقاعدة مختلفة: في البلاغ الموجّه لا تُستخدم إحداثياته\nالحالية بوصفها آخر موقع شوهد فيه الشخص إلا إذا أكد أنه في ذلك الموقع وسمح\nبالوصول إليه. لا ينطبق عليه نمط تحديث موقع المتطوع أثناء المشاركة.\n\n### التسجيل والبلاغات\nينبغي أن يقدم ولي الأمر معلومات يملك صلاحية تقديمها عن الأفراد تحت رعايته،\nوتفاصيل دقيقة تدعم التعرّف. يعتمد التسجيل على الفعالية النشطة الوحيدة وخيارات\nالمدة الصالحة حاليًا. تحدد المدة المختارة انتهاء التسجيل؛ وإذا لم تُختر مدة،\nتُطبق أطول مدة صالحة حاليًا. لا يؤدي استبدال الصورة أو تمديد الفعالية إلى تجديد\nمدة تسجيل قائم تلقائيًا.\n\nبلاغ الفقدان المنشأ بواسطة ولي الأمر يختلف عن بلاغ العثور المنشأ بواسطة\nالمتطوع. بدء البحث أو الانضمام إليه يضيف مشاركة في الحالة نفسها ولا ينشئ حالة\nجديدة. يمكن أن يوجد بلاغ العثور دون بلاغ فقدان ولا يُحسب بلاغ فقدان لولي الأمر.\nويمكن ربط بلاغ فقدان حقيقي لاحق بمسار التعرّف القائم دون تكرار التحقق أو التسليم.\n\n### التعرّف والتعامل مع المعلومات\nمسار الكاميرا والذكاء الاصطناعي هو الطريقة الأساسية المخططة للتعرّف، ويتطلب\nصورة ملتقطة من داخل التطبيق. الذكاء الاصطناعي غير متاح حاليًا، ولا يجوز عرض\nتطابقات أو درجات تشابه مختلقة. عند دمجه لاحقًا ستبقى النتائج احتمالات تتطلب\nمراجعة بشرية وتأكيدًا صريحًا، ولن تؤكد الهوية تلقائيًا.\n\nالمراجعة اليدوية بديل تشغيلي يمكن فتحه دون تصوير أو فشل سابق للذكاء الاصطناعي.\nتبحث في التسجيلات المؤهلة للفعالية النشطة. لا يؤكد التصفح أو اختيار الملف\nالهوية ولا يصرّح بالاطلاع على تواصل ولي الأمر. يمكن أن ينشئ التأكيد اليدوي\nالصريح بلاغ العثور المستقل دون صورة. لا تستخدم صورة مختلقة أو بديلة لهذا الغرض.\n\nاستخدم المعلومات الشخصية وتواصل ولي الأمر المصرّح به لأغراض البحث والتعرّف\nوإعادة الجمع المعتمدة فقط. لا تشاركها خارج هذا الغرض ولا تحاول الوصول إلى بلاغ\nعثور خاص بمتطوع آخر.\n\n### التحقق والتسليم\nبعد تأكيد الهوية يستطيع المتطوع المصرّح له التنسيق مع ولي الأمر المرتبط بالشخص.\nيجب التحقق من ولي الأمر وسياق العملية باستخدام رمز حسابه QR أو بديل المعرّف\nالمعتمد. يتطلب البديل مشاهدة المعرّف المعني داخل حساب ولي الأمر المسجّل دخوله\nعلى جهازه. يمنع فشل التحقق التسليم. نجاح التحقق وحده لا يعني إتمام إعادة الجمع؛\nيؤكد المتطوع التسليم صراحةً بعد إعادة الشخص إلى ولي أمره. لا تتجاوز هذه الخطوات.\n\n### التنبيهات والتوفر والحدود\nتدعم تنبيهات الفقدان العامة وتنبيهات أولوية القرب التنسيق. تعتمد الأولوية على\nنطاق النموذج الأولي المهيّأ، وهو حاليًا 500 متر، وموقع آخر مشاهدة صالح وتقدير\nمناسب لموقع المتطوع. لا ينشئ تنبيه الأولوية حالة منفصلة. يعتمد وصول التنبيهات\nعلى جلسة دخول مؤهلة وأذونات Android وإعداداته والشبكة وتوفر الخدمة. قد يبقى\nسجل التنبيهات ظاهرًا دون إعادة تقديمه كتنبيه جديد. لا يضمن رادّ وصولًا فوريًا\nأو اتصالًا دائمًا أو تقدير موقع دقيقًا في كل لحظة.\n\n### الموافقة والتغييرات\nتحتاج هذه الوثائق إلى مراجعة قبل فرض الموافقة عليها. ستطلب بوابة المتطوع\nالمخططة قبول نسخ محددة من الشروط والخصوصية صراحةً؛ لا يُعد تسجيل الدخول قبولًا.\nقد تتطلب نسخة إلزامية لاحقة موافقة جديدة. لا تتجاوز الموافقة متطلبات الحساب\nوالانتساب والموقع والتعرّف والتحقق من ولي الأمر.';

  @override
  String get vPrivacyDocument =>
      '### النطاق والأفراد المعنيون\nتوضح هذه المسودة البيانات المستخدمة في مسارات ولي الأمر والمتطوع الحالية، بما\nفي ذلك بيانات الأطفال وكبار السن وغيرهم من المسجلين تحت رعاية ولي الأمر. كما\nتوضح حدود دمج الذكاء الاصطناعي مستقبلًا دون ادعاء تشغيل خدمة مطابقة وجوه فعلية.\nيجب أن يحدد مالك المشروع الجهة المسؤولة ووسيلة التواصل بشأن الخصوصية قبل الاعتماد.\n\n### بيانات الحساب والفعالية\nيعالج رادّ معرّفات الحسابات والأسماء والبريد الإلكتروني وأرقام الهواتف والأدوار\nبالقدر اللازم للمصادقة والتنسيق المصرّح به. تشمل بيانات المتطوع معرّفه وحالة\nتفعيل حسابه وانتسابه للفعالية. تُستخدم Firebase Authentication للمصادقة، وتتحقق\nخدمة FastAPI المشتركة من الدور والوصول إلى الفعالية عبر بيانات Firebase المشتركة.\nإنشاء الحساب وإدارته منفصلان عن سجل الموافقة المستقبلي. سيتضمن سجل الموافقة\nنسخ الوثائق المقبولة وأوقات القبول المسجلة بالخادم، لا ادعاء منح إذن Android.\n\n### الأفراد المسجلون والصور\nيقدم ولي الأمر اسم الفرد وعمره وجنسه وعلاقته به وصورته المرجعية، والمعلومات\nالوصفية ذات الصلة. ترتبط البيانات بفعالية ومدة تسجيل محددة. الصور بيانات\nقابلة للتعريف بالشخص، وأي تمثيل رقمي مستقبلي لملامح الوجه مشتق منها يتبع انتهاء\nالتسجيل وضوابط الحذف نفسها. لا يعمل محرك مطابقة وجوه فعلي في النسخة الحالية.\n\nيسجل الخادم بداية التسجيل وانتهاءه ومعرّف مدته وعدد ساعاتها. تُعرض خيارات\nالفعالية الصالحة حاليًا فقط، وتُطبق أطول مدة صالحة افتراضيًا. لا يغيّر استبدال\nالصورة أو تمديد الفعالية انتهاء تسجيل قائم. لا تُعتبر السجلات القديمة مجهولة\nمدة الاحتفاظ مؤهلة تلقائيًا.\n\n### بلاغات الفقدان والعثور والتعرّف\nتتضمن حالات الفقدان معلومات البحث وتحديثات الحالة والمشاركة. قد تشمل التفاصيل\nالموجّهة الملابس والأوصاف المميزة وآخر مشاهدة. بلاغ العثور سجل مستقل لعمل\nالمتطوع في التعرّف، وقد يوجد قبل تقديم ولي الأمر بلاغ فقدان.\n\nصور العثور الملتقطة بالكاميرا مؤقتة لأغراض التعرّف. تُحذف عند انتهاء المحاولة\nدون تطابق مؤكد أو فور تأكيد الهوية. تُعاد محاولة الحذف إذا انقطعت عملية Storage؛\nولا تُطلب الصورة المحذوفة لاحقًا للتحقق أو التسليم ولا تصبح صورة ملف مسجّل.\nيمكن أن ينشئ التأكيد اليدوي بلاغ العثور دون صورة ملتقطة.\n\nتعرض المراجعة اليدوية معلومات الملفات المسجلة المؤهلة للفعالية النشطة. اختيار\nالملف لا يؤكد الهوية. يُتاح تواصل ولي الأمر بعد التأكيد الصريح فقط ضمن سياق\nتعرّف وإعادة جمع مصرح به. ستكون درجات الذكاء الاصطناعي المستقبلية اقتراحات\nلتطابقات محتملة تخضع للتأكيد البشري.\n\n### الموقع\nإذن موقع المتطوع وتشغيل خدمات الموقع شرطان للمشاركة في الفعالية النشطة. قد\nتُحدث الإحداثيات أثناء المشاركة الصالحة، بما فيها الخلفية عبر خدمة Android\nالمنفذة، لغرض تنسيق الفعالية وإعطاء أولوية القرب. يتوقف الوصول المرتبط بالفعالية\nعند انتفاء شروط المشاركة. قد يتعذر تقدير الموقع أو تكون دقته غير كافية؛ عندها\nتتوقف أهلية أولوية القرب مؤقتًا دون اعتبار ذلك رفضًا للإذن. لا يحتاج هذا الغرض\nإلى سجل متواصل لمسار حركة المتطوع؛ يستخدم التنفيذ أحدث تقدير متاح ومدى حداثته.\n\nلا تُستخدم إحداثيات جهاز ولي الأمر بوصفها آخر موقع مشاهدة إلا بعد تأكيده أن\nالجهاز في ذلك الموقع ومنحه الإذن في مسار البلاغ الموجّه. يمكن تقديم وصف نصي\nللموقع بدلًا منها. لا يخضع ولي الأمر لقاعدة تحديث موقع المتطوع أثناء المشاركة.\n\n### التحقق والنتائج المكتملة\nيربط التحقق بـQR أو المعرّف العملية بولي الأمر الصحيح وسياقها. رموز QR قصيرة\nالصلاحية وأحادية الاستخدام. تسجل إيصالات التحقق السياق والأطراف والطريقة والوقت.\nيمكّن نجاح التحقق من تأكيد التسليم صراحةً، ولا يتمم إعادة الجمع تلقائيًا.\n\nعند وصول بلاغ العثور المستقل إلى Reunited تُزال تفاصيله التعريفية، ويقتصر السجل\nالحد الأدنى على المعرّف الداخلي والمنشأ والفعالية والنتيجة والأوقات الضرورية\nللإنشاء والتحديث والإكمال ومرجع المتطوع المؤكد وطريقة التحقق. لا يحتفظ بتواصل\nولي الأمر أو هوية الفرد أو نسخة ملفه أو صورة العثور أو سر QR. يُحتفظ بمرجع\nالمتطوع لأغراض إحصاءات إعادة الجمع لكل متطوع؛ فلا يصح وصف السجل بأنه مجهول\nالهوية بالكامل.\n\n### الاحتفاظ وتأجيل الحذف\nتتبع البيانات التعريفية المسجلة وصورتها وأي تمثيل مستقبلي للوجه تاريخ انتهاء\nالتسجيل المخزّن. إذا احتاجتها حالة فقدان نشطة معتمدة أو بلاغ العثور المؤكد الذي\nلم يكتمل بعد، يُؤجل الحذف فقط. لا يُمدد الانتهاء ولا يصبح السجل مؤهلًا عمومًا\nلتعرّف غير مرتبط أو إبلاغ جديد. عند انتهاء جميع أسباب التأجيل المعتمدة يمكن\nلمهام الحذف إزالة التسجيل التعريفي المنتهي. لا يُحذف تسجيل ما زال صالحًا لمجرد\nاكتمال بلاغ العثور، ولا تحذف هذه العمليات حساب ولي الأمر أو المتطوع.\n\nتخضع حالات الفقدان النهائية لقواعد احتفاظ وتقليل بيانات مستقلة. تفحص مهمة الحذف\nالمحلية البيانات دوريًا عند تفعيلها؛ قيود الوصول منفصلة عن جدولة الحذف، وتُعاد\nمحاولة عملية التخزين الفاشلة بدل الادعاء بنجاح حذفها. لم يُحدد مجدول إنتاج بعد.\nلا تضع هذه المسودة مدة جديدة لبيانات المحاولات المنتهية دون تطابق أو سجل الموافقة\nأو ذاكرة عرض التنبيهات على الجهاز؛ تظل تفاصيل دورة حياتها موضوعًا للمراجعة.\n\n### التنبيهات والوصول إلى الخدمات\nيخزن رادّ سجل التنبيهات وحالة قراءتها حيث تنطبق، باستخدام معرّفات أحداث ثابتة.\nتربط تسجيلات أجهزة FCM رمز الجهاز بالجلسة المصرّح بها والفعالية واللغة وتقدير\nالقرب المتاح. هذه الرموز ليست كلمات مرور. قد يعرض Android تنبيهات الفقدان العامة\nوالأولوية في الخلفية، أو يعرضها رادّ في المقدمة، وفق الأذونات وأهلية الجلسة.\nجلب التاريخ وتسجيل الجهاز لا يعنيان طلب إعادة إرسال التنبيهات القديمة. تحفظ\nذاكرة العرض المحلية معرّفات الأحداث المعالجة حسب المستخدم والفعالية لمنع تكرار\nبنرات المقدمة. تتجنب حمولة التنبيه بيانات الفرد والتواصل، ويخضع فتح الحالة لفحص\nصلاحيات موثّق.\n\n### الحماية ومزودو الخدمات والحدود\nيستخدم الباكند المشترك Firebase Authentication وFirestore وStorage وCloud Messaging\nللوظائف المنفذة. يُقيّد الوصول بالدور والفعالية وسياق العمل، لا بمجرد إخفاء أزرار.\nيجب أن تستبعد سجلات التطوير بيانات الاعتماد والمحتوى الشخصي. قد تقع أعطال في\nالشبكة أو الخدمة وتوجد حدود للتنفيذ؛ لا تعد هذه السياسة بأمن مطلق أو وصول مضمون\nللتنبيهات أو مطابقة مثالية. يجب استكمال استضافة الإنتاج وهوية الجهة ووسيلة\nالتواصل وإجراءات طلب الاطلاع أو التصحيح أو الحذف وأي إفصاحات لازمة قبل النشر.\nلا تدّعي المسودة وجود خدمة آلية لهذه الطلبات أو نشر إنتاجي قائم.';

  @override
  String get vConsentTitle => 'مرحبًا بك في Radd';

  @override
  String get vConsentIntro =>
      'قبل استخدام Radd كمتطوع، يرجى مراجعة الشروط التالية وشروط استخدام Radd وسياسة الخصوصية.';

  @override
  String get vConsentConditions =>
      'بمشاركتك كمتطوع، فإنك تقر بما يلي:\n\n• الوصول إلى الموقع مطلوب أثناء المشاركة في الفعالية النشطة.\n\n• قد يقوم Radd بتحديث موقعك أثناء مشاركتك الفعلية، بما في ذلك أثناء عمل التطبيق في الخلفية، لدعم تنسيق العمل وإعطاء الأولوية للمتطوعين القريبين.\n\n• إذا تم رفض إذن الموقع أو سحبه، أو تم تعطيل خدمات الموقع، فلن تتمكن من استخدام وظائف الفعالية حتى يتم استعادة الوصول إلى الموقع.\n\n• لا يجوز لك الاطلاع على البيانات الشخصية أو بيانات تواصل ولي الأمر إلا عندما تكون مخولًا بذلك ولأغراض التعرف وإعادة الجمع فقط.\n\n• نتائج الذكاء الاصطناعي أو المراجعة اليدوية لا تؤكد الهوية تلقائيًا؛ يجب تأكيد الهوية صراحةً والتحقق من ولي الأمر قبل التسليم.\n\n• يجب استخدام حساب المتطوع المصرح لك به فقط، وعدم مشاركة المعلومات المحمية خارج مسار العمل المعتمد في Radd.';

  @override
  String get vTermsTitle => 'شروط الاستخدام';

  @override
  String get vPrivacyTitle => 'سياسة الخصوصية';

  @override
  String get vConsentCheckbox =>
      'قرأت شروط استخدام Radd وسياسة الخصوصية وأوافق عليهما.';

  @override
  String get vConsentContinue => 'موافق ومتابعة';

  @override
  String get vConsentNotNow => 'ليس الآن';

  @override
  String get vDevelopmentPolicy =>
      'وثائق مشروع تطويري / أكاديمي — ليست سياسات إنتاجية خضعت لمراجعة قانونية.';

  @override
  String get vConsentUnavailable =>
      'نسخة الوثائق المطلوبة غير متاحة في هذا التطبيق. يرجى تحديث Radd والمحاولة مجددًا.';
}
