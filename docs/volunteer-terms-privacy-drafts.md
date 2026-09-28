# Radd Terms and Privacy — review drafts, not enforced

Proposed development identifiers: `terms_version = draft-2026-09` and
`privacy_version = draft-2026-09`. These are proposals, not accepted policy versions.
No acceptance screen, persistence or enforcement has been enabled by this document.
The English and Arabic texts below describe the same intended conditions. Review
both before approval. Operator identity, privacy contact and any jurisdiction-specific
provisions must be supplied by the project owner; none are invented here.

## 1. English Terms of Use — DRAFT

### Purpose and scope
Radd supports event-based reporting, searching, identification, Guardian verification
and reunification. It provides coordination tools; a possible identification result
is not proof of identity or authorization to hand over a person. These draft terms
cover the Guardian and Volunteer functions described below. The Admin interface and
actual AI face-matching engine are not currently implemented.

### Accounts and authorized roles
Guardians use their authenticated accounts to manage individuals under their care
and genuine missing-person reports. Volunteers use accounts provisioned through the
project's authorized account-management process; they do not self-register. Keep
account access private and use only the data and actions authorized for your role.
Do not use another person's session, credentials or verification code to obtain
unauthorized access.

An enabled Volunteer account is separate from assignment to an event. Volunteer
event participation requires authentication, an enabled account, assignment to the
current Active Event, required device location permission and enabled Location
Services. Deactivation, removal of assignment or loss of the required device access
can stop participation. The Digital Volunteer ID reflects the account and assignment
checks; it does not replace Guardian verification.

### Location as a participation condition
Location access is required during Volunteer Active Event participation for event
coordination and proximity-based prioritization. Where supported by the Android
implementation, location may continue updating while Radd is in the background,
using the required foreground location service and ongoing notification. Event-related
location collection must stop when participation is no longer authorized, including
logout, deactivation, unassignment, loss of Active Event access, permission revocation
or disabled Location Services.

Android controls permission choices. Acceptance of these terms does not grant Android
permission. If permission is denied/revoked or Location Services are off, event actions
remain blocked until the conditions are restored. If permission and services are valid
but a location estimate is temporarily unavailable, participation and standard alerts
remain available; proximity prioritization resumes when a suitable estimate returns.

Guardian location follows a different rule. In the guided missing report, current
coordinates are used as the last-seen location only when the Guardian confirms that
they are at that location and permits access. This is not the Volunteer participation
location-update rule.

### Registration and reports
Guardians should provide information they are authorized to provide about individuals
under their care and accurate details to support identification. Registration uses the
single Active Event and its currently valid configured periods. The selected period,
or the longest currently valid option if none is selected, determines the stored
registration expiry. Replacing a photograph or extending the event does not renew an
existing registration automatically.

Guardian Missing Cases and Volunteer Found Individual Reports are distinct. Starting
or joining a search participates in the same Missing Case; it does not create a new
case. A standalone Found Report can exist without a Guardian missing report and does
not count as a Guardian Missing Case. An actual later Guardian report may link to the
existing identification workflow without duplicating verification or handover.

### Identification and handling information
The camera/AI path is the primary planned identification method. It requires an in-app
captured photograph. AI is presently unavailable: Radd must not present invented
matches or scores. When integrated later, AI results will be possible matches requiring
human review and explicit confirmation, not automatic identity confirmation.

Manual Review is an operational fallback and can be opened without camera capture or
an AI failure. It searches eligible registrations for the Active Event. Browsing or
selecting a profile does not confirm identity and does not authorize access to Guardian
contact details. Explicit manual confirmation can create a standalone Found Report
without a photograph. Do not capture substitute or fabricated images for this purpose.

Use personal information and authorized Guardian contact details only for the approved
search, identification and reunification work. Do not share them outside that purpose
or try to access another Volunteer's privately owned Found Report.

### Verification and handover
After identity confirmation, the authorized Volunteer may coordinate with the associated
Guardian. The legitimate Guardian/context must be verified using the account QR or
approved identifier fallback. The fallback requires viewing the relevant identifier
inside the Guardian's authenticated Radd account on their own device. A failed check
blocks handover. A successful check alone does not mark Reunited: the Volunteer must
explicitly confirm handover after reunification. Do not bypass these steps.

### Notifications, availability and limitations
Standard Missing Case alerts and nearby priority alerts support coordination; priority
uses the configured prototype radius, currently 500 metres, and a suitable reported
last-seen location and Volunteer estimate. A priority alert does not create a separate
case. Notification delivery depends on an eligible authenticated session, Android
permissions/settings, network connectivity and service availability. History may remain
visible without being replayed as a new alert. Radd does not guarantee instant delivery,
continuous connectivity or an accurate location estimate at every moment.

### Agreement and changes
These documents require review before they become an enforced consent requirement.
The planned Volunteer gate will request explicit acceptance of specified Terms and
Privacy versions; login alone will not constitute acceptance. A later required version
may require renewed acceptance. Acceptance will not bypass account, assignment,
location, identification or Guardian verification requirements.

## 2. شروط الاستخدام بالعربية — مسودة

### الغرض والنطاق
يساعد رادّ في الإبلاغ والبحث والتعرّف والتحقق من ولي الأمر وإعادة الجمع خلال
الفعاليات. التطبيق أداة للتنسيق؛ نتيجة التعرّف المحتملة ليست إثباتًا للهوية أو
إذنًا بتسليم الشخص. تشمل هذه المسودة وظائف ولي الأمر والمتطوع الموضحة أدناه.
واجهة المشرف ومحرك مطابقة الوجوه الفعلي غير منفذين حاليًا.

### الحسابات والأدوار المصرّح بها
يستخدم ولي الأمر حسابه المسجّل لإدارة بيانات الأفراد تحت رعايته وبلاغات الفقدان
الحقيقية. يستخدم المتطوع حسابًا منشأً عبر إجراءات إدارة الحسابات المصرّح بها في
المشروع، ولا يسجّل حساب متطوع بنفسه. حافظ على خصوصية الدخول، واستخدم البيانات
والإجراءات المسموح بها لدورك فقط. لا تستخدم جلسة شخص آخر أو بيانات دخوله أو رمز
التحقق الخاص به للحصول على وصول غير مصرح به.

حالة حساب المتطوع مستقلة عن انتسابه إلى الفعالية. تتطلب المشاركة تسجيل الدخول،
وحسابًا مفعّلًا، وانتسابًا إلى الفعالية النشطة الحالية، وإذن الموقع المطلوب،
وتشغيل خدمات الموقع. قد تتوقف المشاركة عند تعطيل الحساب أو إزالة الانتساب أو
فقدان صلاحية الوصول المطلوبة. تعكس بطاقة المتطوع الرقمية فحص الحساب والانتساب،
ولا تحل محل التحقق من ولي الأمر.

### الموقع شرط للمشاركة
الوصول إلى موقع المتطوع مطلوب أثناء المشاركة في الفعالية النشطة لغرض التنسيق
وإعطاء الأولوية للمتطوعين القريبين. قد يستمر تحديث الموقع عندما يعمل رادّ في
الخلفية وفق تنفيذ Android، باستخدام خدمة الموقع والإشعار المستمر المطلوبين.
يجب أن يتوقف الوصول المرتبط بالفعالية عند انتهاء أهلية المشاركة، بما يشمل
تسجيل الخروج وتعطيل الحساب وإزالة الانتساب وفقدان الوصول إلى الفعالية النشطة
وسحب الإذن أو تعطيل خدمات الموقع.

يتحكم Android في خيارات الإذن. قبول الشروط لا يمنح إذن Android. يبقى الوصول
إلى وظائف الفعالية محجوبًا عند رفض الإذن أو سحبه أو إيقاف خدمات الموقع حتى
استعادتها. إذا كان الإذن والخدمات صالحين لكن تعذّر تقدير الموقع مؤقتًا، تبقى
المشاركة والتنبيهات العامة متاحة؛ وتعود أهلية أولوية القرب عند توفر تقدير مناسب.

موقع ولي الأمر يخضع لقاعدة مختلفة: في البلاغ الموجّه لا تُستخدم إحداثياته
الحالية بوصفها آخر موقع شوهد فيه الشخص إلا إذا أكد أنه في ذلك الموقع وسمح
بالوصول إليه. لا ينطبق عليه نمط تحديث موقع المتطوع أثناء المشاركة.

### التسجيل والبلاغات
ينبغي أن يقدم ولي الأمر معلومات يملك صلاحية تقديمها عن الأفراد تحت رعايته،
وتفاصيل دقيقة تدعم التعرّف. يعتمد التسجيل على الفعالية النشطة الوحيدة وخيارات
المدة الصالحة حاليًا. تحدد المدة المختارة انتهاء التسجيل؛ وإذا لم تُختر مدة،
تُطبق أطول مدة صالحة حاليًا. لا يؤدي استبدال الصورة أو تمديد الفعالية إلى تجديد
مدة تسجيل قائم تلقائيًا.

بلاغ الفقدان المنشأ بواسطة ولي الأمر يختلف عن بلاغ العثور المنشأ بواسطة
المتطوع. بدء البحث أو الانضمام إليه يضيف مشاركة في الحالة نفسها ولا ينشئ حالة
جديدة. يمكن أن يوجد بلاغ العثور دون بلاغ فقدان ولا يُحسب بلاغ فقدان لولي الأمر.
ويمكن ربط بلاغ فقدان حقيقي لاحق بمسار التعرّف القائم دون تكرار التحقق أو التسليم.

### التعرّف والتعامل مع المعلومات
مسار الكاميرا والذكاء الاصطناعي هو الطريقة الأساسية المخططة للتعرّف، ويتطلب
صورة ملتقطة من داخل التطبيق. الذكاء الاصطناعي غير متاح حاليًا، ولا يجوز عرض
تطابقات أو درجات تشابه مختلقة. عند دمجه لاحقًا ستبقى النتائج احتمالات تتطلب
مراجعة بشرية وتأكيدًا صريحًا، ولن تؤكد الهوية تلقائيًا.

المراجعة اليدوية بديل تشغيلي يمكن فتحه دون تصوير أو فشل سابق للذكاء الاصطناعي.
تبحث في التسجيلات المؤهلة للفعالية النشطة. لا يؤكد التصفح أو اختيار الملف
الهوية ولا يصرّح بالاطلاع على تواصل ولي الأمر. يمكن أن ينشئ التأكيد اليدوي
الصريح بلاغ العثور المستقل دون صورة. لا تستخدم صورة مختلقة أو بديلة لهذا الغرض.

استخدم المعلومات الشخصية وتواصل ولي الأمر المصرّح به لأغراض البحث والتعرّف
وإعادة الجمع المعتمدة فقط. لا تشاركها خارج هذا الغرض ولا تحاول الوصول إلى بلاغ
عثور خاص بمتطوع آخر.

### التحقق والتسليم
بعد تأكيد الهوية يستطيع المتطوع المصرّح له التنسيق مع ولي الأمر المرتبط بالشخص.
يجب التحقق من ولي الأمر وسياق العملية باستخدام رمز حسابه QR أو بديل المعرّف
المعتمد. يتطلب البديل مشاهدة المعرّف المعني داخل حساب ولي الأمر المسجّل دخوله
على جهازه. يمنع فشل التحقق التسليم. نجاح التحقق وحده لا يعني إتمام إعادة الجمع؛
يؤكد المتطوع التسليم صراحةً بعد إعادة الشخص إلى ولي أمره. لا تتجاوز هذه الخطوات.

### التنبيهات والتوفر والحدود
تدعم تنبيهات الفقدان العامة وتنبيهات أولوية القرب التنسيق. تعتمد الأولوية على
نطاق النموذج الأولي المهيّأ، وهو حاليًا 500 متر، وموقع آخر مشاهدة صالح وتقدير
مناسب لموقع المتطوع. لا ينشئ تنبيه الأولوية حالة منفصلة. يعتمد وصول التنبيهات
على جلسة دخول مؤهلة وأذونات Android وإعداداته والشبكة وتوفر الخدمة. قد يبقى
سجل التنبيهات ظاهرًا دون إعادة تقديمه كتنبيه جديد. لا يضمن رادّ وصولًا فوريًا
أو اتصالًا دائمًا أو تقدير موقع دقيقًا في كل لحظة.

### الموافقة والتغييرات
تحتاج هذه الوثائق إلى مراجعة قبل فرض الموافقة عليها. ستطلب بوابة المتطوع
المخططة قبول نسخ محددة من الشروط والخصوصية صراحةً؛ لا يُعد تسجيل الدخول قبولًا.
قد تتطلب نسخة إلزامية لاحقة موافقة جديدة. لا تتجاوز الموافقة متطلبات الحساب
والانتساب والموقع والتعرّف والتحقق من ولي الأمر.

## 3. English Privacy Policy — DRAFT update

### Scope and people concerned
This draft describes data used by Radd's current Guardian and Volunteer workflows,
including information about children, older adults and other people registered under
Guardian care. It also identifies the future AI boundary rather than claiming an
operational face-matching service. The project owner must provide the responsible
operator's identity and a privacy contact before final approval.

### Account and event data
Radd processes account identifiers, names, email addresses, phone numbers and roles
as needed for authentication and authorized coordination. Volunteer records additionally
include the Volunteer ID, enabled status and event assignment. Authentication uses
Firebase Authentication; the shared FastAPI service enforces role and event access
against the shared Firebase data. Account provision/management is separate from a
future consent record. The planned consent record contains accepted document versions
and server acceptance times, not an assertion that Android permission was granted.

### Registered individuals and photographs
A Guardian supplies a registered individual's name, age, gender, relationship and
reference photograph, with applicable descriptive information. Records belong to an
event and an established registration period. Photographs are identifiable information.
Any future facial embedding derived from them must follow the same registration expiry
and deletion controls. No actual AI matching engine is operating in the current build.

The server records registration start, expiry, period ID and duration. Only currently
valid event options may be selected; the longest valid option applies by default.
Neither photo replacement nor event extension changes a previously established expiry.
Legacy records with unknown retention periods are not silently made eligible.

### Missing Cases, Found Reports and identification
Missing Cases contain the information needed to search, status updates and participation
records. Guided details may include clothing, distinguishing descriptions and last-seen
information. A Found Report is a separate record of a Volunteer's identification work;
it may exist before a Guardian submits a missing report.

Camera-based Found photographs are temporary identification images. They are deleted
when the attempt ends without a confirmed match or immediately after confirmed identity.
Interrupted Storage deletion uses the existing retry mechanism; deleted Found photos
are not required for subsequent verification/handover and do not become profile photos.
Manual-only confirmation may create a Found Report without any captured photograph.

Manual Review exposes eligible registered profile information for the current Active
Event. Selecting a profile is not confirmation. Guardian contact is available only after
explicit confirmation in an authorized identification/reunification context. Any future
AI scores will be possible-match suggestions, subject to human confirmation.

### Location
Volunteer location permission and enabled services are mandatory for Active Event
participation. Coordinates may update during valid participation, including in the
background through the implemented Android location service. The purpose is event
coordination and proximity prioritization. Event-related location access stops when
participation conditions cease. The device estimate may be unavailable or insufficiently
accurate; this removes proximity eligibility temporarily without equating it to denied
permission. Radd does not need a continuous historical movement trail for this purpose;
the implementation uses the latest available estimate and its freshness.

Guardian device coordinates are used as a reported last-seen location only after the
Guardian confirms that the device is at that location and grants permission through
the guided reporting flow. A textual last-seen description can be supplied instead.
Guardian location is not subject to the continuous Volunteer participation rule.

### Verification and completed outcomes
QR/identifier checks bind verification to the legitimate Guardian and workflow. QR
challenges are short-lived and single-use. Verification receipts record the relevant
context, participants, method and time. A successful check enables explicit handover;
it does not complete reunification automatically.

On standalone Found Report Reunited, identifying report details are removed and the
minimal record retains only the internal report identifier, origin, event, outcome,
necessary creation/update/completion timestamps, confirming Volunteer reference and
verification method. It does not retain Guardian contact, person identity/snapshot,
Found photograph or QR secret. A Volunteer reference is retained for approved
per-Volunteer statistics; it must not be represented as fully anonymous data.

### Retention and deletion holds
Registered identifiable event information, its photograph and any future embedding
follow the registration's stored expiry. If an approved active Missing Case or an
identified active Found Report still requires that information, deletion alone is
deferred. Expiry is not extended and the record is not generally eligible again for
unrelated identification or new reporting. When no approved active hold remains, due
cleanup can delete the expired identifiable registration. A still-valid registration
is not deleted merely because one Found Report completes. Account records are not
deleted by these workflow cleanup operations.

Terminal Missing Cases use their separate existing retention/minimization rules.
The current local cleanup worker checks periodically when enabled; access restrictions
and deletion scheduling are separate, and a failed storage operation is retried rather
than falsely reported as deleted. No production scheduler has been selected. This draft
does not invent a new retention duration for ended, unmatched report metadata, consent
history or device presentation memory; those lifecycle details remain review items.

### Notifications and service access
Radd stores notification history and applicable read state with stable event IDs.
FCM device registrations associate a token with the authenticated session, event,
language and available proximity estimate. Tokens are not passwords. Standard and
priority Missing Case notifications may be displayed by Android in the background or
by Radd in the foreground, subject to permissions and session eligibility. History
fetches and device registration are not requests to replay old notifications. Local
presentation memory stores handled event IDs, scoped to the user/event, to suppress
repeated foreground banners. Notification payloads avoid person/contact details;
opening a case performs authenticated authorization checks.

### Protection, providers and limits
The shared backend uses Firebase Authentication, Firestore, Storage and Cloud Messaging
for the implemented functions. Access is restricted by role, event and workflow rather
than by hiding buttons alone. Development diagnostics should exclude credentials and
personal payloads. Network/service failures and implementation limitations may occur;
this notice does not promise absolute security, guaranteed delivery or perfect matching.
Production hosting, operator contact, requests for access/correction/deletion, and any
additional required legal disclosures must be finalized before publication. No automatic
rights-request service or production deployment is claimed by this draft.

## 4. سياسة الخصوصية بالعربية — مسودة تحديث

### النطاق والأفراد المعنيون
توضح هذه المسودة البيانات المستخدمة في مسارات ولي الأمر والمتطوع الحالية، بما
في ذلك بيانات الأطفال وكبار السن وغيرهم من المسجلين تحت رعاية ولي الأمر. كما
توضح حدود دمج الذكاء الاصطناعي مستقبلًا دون ادعاء تشغيل خدمة مطابقة وجوه فعلية.
يجب أن يحدد مالك المشروع الجهة المسؤولة ووسيلة التواصل بشأن الخصوصية قبل الاعتماد.

### بيانات الحساب والفعالية
يعالج رادّ معرّفات الحسابات والأسماء والبريد الإلكتروني وأرقام الهواتف والأدوار
بالقدر اللازم للمصادقة والتنسيق المصرّح به. تشمل بيانات المتطوع معرّفه وحالة
تفعيل حسابه وانتسابه للفعالية. تُستخدم Firebase Authentication للمصادقة، وتتحقق
خدمة FastAPI المشتركة من الدور والوصول إلى الفعالية عبر بيانات Firebase المشتركة.
إنشاء الحساب وإدارته منفصلان عن سجل الموافقة المستقبلي. سيتضمن سجل الموافقة
نسخ الوثائق المقبولة وأوقات القبول المسجلة بالخادم، لا ادعاء منح إذن Android.

### الأفراد المسجلون والصور
يقدم ولي الأمر اسم الفرد وعمره وجنسه وعلاقته به وصورته المرجعية، والمعلومات
الوصفية ذات الصلة. ترتبط البيانات بفعالية ومدة تسجيل محددة. الصور بيانات
قابلة للتعريف بالشخص، وأي تمثيل رقمي مستقبلي لملامح الوجه مشتق منها يتبع انتهاء
التسجيل وضوابط الحذف نفسها. لا يعمل محرك مطابقة وجوه فعلي في النسخة الحالية.

يسجل الخادم بداية التسجيل وانتهاءه ومعرّف مدته وعدد ساعاتها. تُعرض خيارات
الفعالية الصالحة حاليًا فقط، وتُطبق أطول مدة صالحة افتراضيًا. لا يغيّر استبدال
الصورة أو تمديد الفعالية انتهاء تسجيل قائم. لا تُعتبر السجلات القديمة مجهولة
مدة الاحتفاظ مؤهلة تلقائيًا.

### بلاغات الفقدان والعثور والتعرّف
تتضمن حالات الفقدان معلومات البحث وتحديثات الحالة والمشاركة. قد تشمل التفاصيل
الموجّهة الملابس والأوصاف المميزة وآخر مشاهدة. بلاغ العثور سجل مستقل لعمل
المتطوع في التعرّف، وقد يوجد قبل تقديم ولي الأمر بلاغ فقدان.

صور العثور الملتقطة بالكاميرا مؤقتة لأغراض التعرّف. تُحذف عند انتهاء المحاولة
دون تطابق مؤكد أو فور تأكيد الهوية. تُعاد محاولة الحذف إذا انقطعت عملية Storage؛
ولا تُطلب الصورة المحذوفة لاحقًا للتحقق أو التسليم ولا تصبح صورة ملف مسجّل.
يمكن أن ينشئ التأكيد اليدوي بلاغ العثور دون صورة ملتقطة.

تعرض المراجعة اليدوية معلومات الملفات المسجلة المؤهلة للفعالية النشطة. اختيار
الملف لا يؤكد الهوية. يُتاح تواصل ولي الأمر بعد التأكيد الصريح فقط ضمن سياق
تعرّف وإعادة جمع مصرح به. ستكون درجات الذكاء الاصطناعي المستقبلية اقتراحات
لتطابقات محتملة تخضع للتأكيد البشري.

### الموقع
إذن موقع المتطوع وتشغيل خدمات الموقع شرطان للمشاركة في الفعالية النشطة. قد
تُحدث الإحداثيات أثناء المشاركة الصالحة، بما فيها الخلفية عبر خدمة Android
المنفذة، لغرض تنسيق الفعالية وإعطاء أولوية القرب. يتوقف الوصول المرتبط بالفعالية
عند انتفاء شروط المشاركة. قد يتعذر تقدير الموقع أو تكون دقته غير كافية؛ عندها
تتوقف أهلية أولوية القرب مؤقتًا دون اعتبار ذلك رفضًا للإذن. لا يحتاج هذا الغرض
إلى سجل متواصل لمسار حركة المتطوع؛ يستخدم التنفيذ أحدث تقدير متاح ومدى حداثته.

لا تُستخدم إحداثيات جهاز ولي الأمر بوصفها آخر موقع مشاهدة إلا بعد تأكيده أن
الجهاز في ذلك الموقع ومنحه الإذن في مسار البلاغ الموجّه. يمكن تقديم وصف نصي
للموقع بدلًا منها. لا يخضع ولي الأمر لقاعدة تحديث موقع المتطوع أثناء المشاركة.

### التحقق والنتائج المكتملة
يربط التحقق بـQR أو المعرّف العملية بولي الأمر الصحيح وسياقها. رموز QR قصيرة
الصلاحية وأحادية الاستخدام. تسجل إيصالات التحقق السياق والأطراف والطريقة والوقت.
يمكّن نجاح التحقق من تأكيد التسليم صراحةً، ولا يتمم إعادة الجمع تلقائيًا.

عند وصول بلاغ العثور المستقل إلى Reunited تُزال تفاصيله التعريفية، ويقتصر السجل
الحد الأدنى على المعرّف الداخلي والمنشأ والفعالية والنتيجة والأوقات الضرورية
للإنشاء والتحديث والإكمال ومرجع المتطوع المؤكد وطريقة التحقق. لا يحتفظ بتواصل
ولي الأمر أو هوية الفرد أو نسخة ملفه أو صورة العثور أو سر QR. يُحتفظ بمرجع
المتطوع لأغراض إحصاءات إعادة الجمع لكل متطوع؛ فلا يصح وصف السجل بأنه مجهول
الهوية بالكامل.

### الاحتفاظ وتأجيل الحذف
تتبع البيانات التعريفية المسجلة وصورتها وأي تمثيل مستقبلي للوجه تاريخ انتهاء
التسجيل المخزّن. إذا احتاجتها حالة فقدان نشطة معتمدة أو بلاغ العثور المؤكد الذي
لم يكتمل بعد، يُؤجل الحذف فقط. لا يُمدد الانتهاء ولا يصبح السجل مؤهلًا عمومًا
لتعرّف غير مرتبط أو إبلاغ جديد. عند انتهاء جميع أسباب التأجيل المعتمدة يمكن
لمهام الحذف إزالة التسجيل التعريفي المنتهي. لا يُحذف تسجيل ما زال صالحًا لمجرد
اكتمال بلاغ العثور، ولا تحذف هذه العمليات حساب ولي الأمر أو المتطوع.

تخضع حالات الفقدان النهائية لقواعد احتفاظ وتقليل بيانات مستقلة. تفحص مهمة الحذف
المحلية البيانات دوريًا عند تفعيلها؛ قيود الوصول منفصلة عن جدولة الحذف، وتُعاد
محاولة عملية التخزين الفاشلة بدل الادعاء بنجاح حذفها. لم يُحدد مجدول إنتاج بعد.
لا تضع هذه المسودة مدة جديدة لبيانات المحاولات المنتهية دون تطابق أو سجل الموافقة
أو ذاكرة عرض التنبيهات على الجهاز؛ تظل تفاصيل دورة حياتها موضوعًا للمراجعة.

### التنبيهات والوصول إلى الخدمات
يخزن رادّ سجل التنبيهات وحالة قراءتها حيث تنطبق، باستخدام معرّفات أحداث ثابتة.
تربط تسجيلات أجهزة FCM رمز الجهاز بالجلسة المصرّح بها والفعالية واللغة وتقدير
القرب المتاح. هذه الرموز ليست كلمات مرور. قد يعرض Android تنبيهات الفقدان العامة
والأولوية في الخلفية، أو يعرضها رادّ في المقدمة، وفق الأذونات وأهلية الجلسة.
جلب التاريخ وتسجيل الجهاز لا يعنيان طلب إعادة إرسال التنبيهات القديمة. تحفظ
ذاكرة العرض المحلية معرّفات الأحداث المعالجة حسب المستخدم والفعالية لمنع تكرار
بنرات المقدمة. تتجنب حمولة التنبيه بيانات الفرد والتواصل، ويخضع فتح الحالة لفحص
صلاحيات موثّق.

### الحماية ومزودو الخدمات والحدود
يستخدم الباكند المشترك Firebase Authentication وFirestore وStorage وCloud Messaging
للوظائف المنفذة. يُقيّد الوصول بالدور والفعالية وسياق العمل، لا بمجرد إخفاء أزرار.
يجب أن تستبعد سجلات التطوير بيانات الاعتماد والمحتوى الشخصي. قد تقع أعطال في
الشبكة أو الخدمة وتوجد حدود للتنفيذ؛ لا تعد هذه السياسة بأمن مطلق أو وصول مضمون
للتنبيهات أو مطابقة مثالية. يجب استكمال استضافة الإنتاج وهوية الجهة ووسيلة
التواصل وإجراءات طلب الاطلاع أو التصحيح أو الحذف وأي إفصاحات لازمة قبل النشر.
لا تدّعي المسودة وجود خدمة آلية لهذه الطلبات أو نشر إنتاجي قائم.

## 5. English first-login Volunteer consent summary — DRAFT

Before participating, please review Radd's **Terms of Use** and **Privacy Policy**.
Your account is provided through authorized account management; signing in is not
acceptance. Location access and enabled Location Services are required during Active
Event participation for event coordination and proximity prioritization. Location may
continue updating in the background through the Android participation service, and
must stop when participation ends or its requirements are no longer met.

Accepting these documents does **not** grant Android location permission. Radd will
check/request that permission separately. A temporary unavailable GPS estimate does
not block participation when permission and services remain valid.

Proposed controls (not implemented): Open Terms of Use; Open Privacy Policy;
unchecked “I have read and accept the Terms of Use and Privacy Policy”; Continue
(disabled until checked); Not now / Sign out (no event access). Required document
versions must be shown/available and the server must record their explicit acceptance.

## 6. ملخص موافقة المتطوع عند أول دخول — مسودة

قبل المشاركة، يرجى مراجعة **شروط استخدام رادّ** و**سياسة الخصوصية**. يُوفر الحساب
عبر إدارة الحسابات المصرّح بها؛ ولا يُعد تسجيل الدخول موافقة. الوصول إلى الموقع
وتشغيل خدماته مطلوبان أثناء المشاركة في الفعالية النشطة لتنسيق العمل وإعطاء
أولوية القرب. قد يستمر تحديث الموقع في الخلفية عبر خدمة المشاركة في Android،
ويجب أن يتوقف عند انتهاء المشاركة أو انتفاء شروطها.

قبول الوثائق **لا يمنح إذن الموقع في Android**؛ سيتحقق رادّ منه ويطلبه منفصلًا.
لا يمنع تعذّر تقدير GPS مؤقتًا المشاركة إذا ظل الإذن والخدمات صالحين.

عناصر مقترحة غير منفذة: فتح شروط الاستخدام؛ فتح سياسة الخصوصية؛ مربع غير محدد
مسبقًا «قرأت شروط الاستخدام وسياسة الخصوصية وأوافق عليهما»؛ متابعة لا تتاح قبل
التحديد؛ ليس الآن / تسجيل الخروج دون إتاحة وظائف الفعالية. يجب إتاحة النسخ
المطلوبة وتسجيل قبولها الصريح بالخادم.

## Future consent design — pending document approval

Use the authenticated users document, with server-owned required version constants
or configuration shared by the consent API and access checks. Proposed fields:
`terms_version`, `privacy_version`, `terms_accepted_at`, `privacy_accepted_at`.
Names are a proposal, not a migrated schema. Accept only the currently required
versions and explicit affirmative acceptance; use server timestamps, reject stale
version requests, and make identical retries idempotent. Do not auto-populate consent
for Admin-provisioned accounts or infer it from Guardian privacy acknowledgements.

Allow account/consent/logout endpoints before consent; block protected Volunteer
event operations server-side until both required versions match. Then perform the
separate location explanation and actual OS permission/services checks. Re-check
enabled status and assignment before event access. Stop/withhold participation
location collection before consent. Keep documents accessible later in Profile.
A future version change must require re-consent, not rely on a permanent boolean.
Returning users with current consent skip the acceptance form but never skip real
location checks. Rejecting/not accepting leaves event access blocked. Guardian
registration behavior is not changed by this proposed Volunteer gate.

No consent implementation or Firebase acceptance write is authorized by this draft
alone. Remaining approval inputs: final text/version IDs, responsible operator and
contact, publication format/links, and retention requirements for consent audit data.
