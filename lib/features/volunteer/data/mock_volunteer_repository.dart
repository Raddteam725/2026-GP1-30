import 'dart:typed_data';

import '../domain/volunteer_models.dart';
import 'volunteer_repository.dart';

/// In-memory design fixtures ONLY. Never writes to Firebase or sends notifications.
class MockVolunteerRepository extends VolunteerRepository {
  MockVolunteerRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _cases = [
      VolunteerCase(
        id: 'RD-8042',
        person: _profiles[0],
        createdAt: _now.subtract(const Duration(minutes: 10)),
        updatedAt: _now.subtract(const Duration(minutes: 10)),
      ),
      VolunteerCase(
        id: 'RD-8049',
        person: _profiles[1],
        createdAt: _now.subtract(const Duration(minutes: 25)),
        updatedAt: _now.subtract(const Duration(minutes: 20)),
        status: CaseStatus.searchInProgress,
        joinedBy: {'preview-other'},
        information: const CaseInformation(
          lastSeen: LocalizedData(
            'East promenade, food court',
            'الممشى الشرقي، منطقة المطاعم',
          ),
        ),
      ),
      VolunteerCase(
        id: 'RD-8055',
        person: _profiles[2],
        createdAt: _now.subtract(const Duration(minutes: 40)),
        updatedAt: _now.subtract(const Duration(minutes: 40)),
      ),
      VolunteerCase(
        id: 'RD-8035',
        person: _profiles[3],
        createdAt: _now.subtract(const Duration(minutes: 55)),
        updatedAt: _now.subtract(const Duration(minutes: 30)),
        status: CaseStatus.searchInProgress,
        joinedBy: {account.uid},
        information: updatedInformation,
      ),
    ];
    _alerts[account.uid] = [
      VolunteerAlert(
        caseId: 'RD-8035',
        kind: AlertKind.priority,
        at: _now.subtract(const Duration(minutes: 5)),
      ),
      VolunteerAlert(
        caseId: 'RD-8042',
        kind: AlertKind.newCase,
        at: _cases[0].createdAt,
      ),
      VolunteerAlert(
        caseId: 'RD-8049',
        kind: AlertKind.newCase,
        at: _cases[1].createdAt,
      ),
    ];
  }
  static const account = VolunteerAccount(
    uid: 'preview-ahmed',
    name: LocalizedData('Ahmed Khalid', 'أحمد خالد'),
    volunteerId: 'VOL-1024',
    active: true,
    assigned: true,
    eventId: 'preview-event',
    email: 'ahmed.khalid@example.com',
    phone: '+966 55 123 4567',
  );
  static const inactiveAccount = VolunteerAccount(
    uid: 'preview-ahmed',
    name: LocalizedData('Ahmed Khalid', 'أحمد خالد'),
    volunteerId: 'VOL-1024',
    active: false,
    email: 'ahmed.khalid@example.com',
    phone: '+966 55 123 4567',
  );
  static const previewLocation = Coordinates(24.7167, 46.6753);
  final DateTime _now;
  late final List<VolunteerCase> _cases;
  final Map<String, List<VolunteerAlert>> _alerts = {};
  final Map<String, FoundReport> _found = {};
  int _sequence = 0;
  static const _profiles = [
    RegisteredPerson(
      id: 'omar',
      name: LocalizedData('Omar Hassan', 'عمر حسن'),
      age: 7,
      gender: Gender.male,
      photo: 'assets/images/volunteer/omar.jpg',
      guardian: GuardianContact(
        id: 'fatimah',
        name: LocalizedData('Fatimah Hassan', 'فاطمة حسن'),
        relationship: LocalizedData('Mother', 'الأم'),
        phone: '+966 50 123 4567',
      ),
    ),
    RegisteredPerson(
      id: 'layla',
      name: LocalizedData('Layla Jenkins', 'ليلى جينكنز'),
      age: 11,
      gender: Gender.female,
      photo: 'assets/images/volunteer/layla.jpg',
      guardian: GuardianContact(
        id: 'marcus',
        name: LocalizedData('Marcus Jenkins', 'ماركوس جينكنز'),
        relationship: LocalizedData('Father', 'الأب'),
        phone: '+966 50 234 5678',
      ),
    ),
    RegisteredPerson(
      id: 'maya',
      name: LocalizedData('Maya Al-Naimi', 'مايا النعيمي'),
      age: 6,
      gender: Gender.female,
      guardian: GuardianContact(
        id: 'maya-guardian',
        name: LocalizedData('Amina Al-Naimi', 'أمينة النعيمي'),
        relationship: LocalizedData('Mother', 'الأم'),
      ),
    ),
    RegisteredPerson(
      id: 'tariq',
      name: LocalizedData('Tariq Mansoor', 'طارق منصور'),
      age: 6,
      gender: Gender.male,
      photo: 'assets/images/volunteer/tariq.jpg',
      guardian: GuardianContact(
        id: 'amina',
        name: LocalizedData('Amina Mansoor', 'أمينة منصور'),
        relationship: LocalizedData('Mother', 'الأم'),
        phone: '+966 50 345 6789',
      ),
    ),
    // The same registered profile can be identified without a missing-person report.
    RegisteredPerson(
      id: 'unreported',
      name: LocalizedData('Omar Khalid', 'عمر خالد'),
      age: 7,
      gender: Gender.male,
      guardian: GuardianContact(
        id: 'khalid',
        name: LocalizedData('Khalid Hassan', 'خالد حسن'),
        relationship: LocalizedData('Father', 'الأب'),
      ),
    ),
  ];
  @override
  bool get isPreview => true;
  @override
  bool get connected => true;
  @override
  List<VolunteerCase> get cases => List.unmodifiable(_cases);
  @override
  List<RegisteredPerson> get profiles => List.unmodifiable(_profiles);
  @override
  List<VolunteerAlert> alertsFor(String uid) =>
      List.unmodifiable(_alerts[uid] ?? []);
  void _active(VolunteerAccount a) {
    if (!a.active) throw StateError('inactive');
  }

  void _owned(VolunteerAccount a, FoundReport r) {
    _active(a);
    if (_found[r.id] != r || r.volunteerUid != a.uid) {
      throw StateError('unauthorized');
    }
  }

  @override
  Future<void> startSearch(VolunteerAccount account, VolunteerCase item) async {
    _active(account);
    if (!_cases.contains(item) || !item.joinable) {
      throw StateError('case-not-joinable');
    }
    if (!item.joinedBy.add(account.uid)) return;
    if (item.status == CaseStatus.reportReceived) {
      item.status = CaseStatus.searchInProgress;
      item.updatedAt = DateTime.now();
    }
    notifyListeners();
  }

  /// Controlled fixture update for initial/updated report verification, not a volunteer action.
  void receiveGuardianDetails(String id, CaseInformation information) {
    final c = caseById(id)!;
    c.information = information;
    notifyListeners();
  }

  static const updatedInformation = CaseInformation(
    lastSeen: LocalizedData(
      'Gate 4, main concourse',
      'البوابة ٤، البهو الرئيسي',
    ),
    coordinates: Coordinates(24.7136, 46.6753),
    clothing: LocalizedData(
      'Blue hoodie, dark gray joggers, white sneakers',
      'سترة زرقاء وبنطال رمادي داكن وحذاء رياضي أبيض',
    ),
    distinctive: LocalizedData(
      'Carrying a small green dinosaur backpack',
      'يحمل حقيبة ظهر صغيرة خضراء بشكل ديناصور',
    ),
    additional: LocalizedData(
      'Speaks Arabic and English, responds to nickname “Ammour”.',
      'يتحدث العربية والإنجليزية ويستجيب للقب «عمّور».',
    ),
  );
  @override
  Future<FoundReport> submitFound(
    VolunteerAccount account, {
    Uint8List? photo,
    String? requestId,
  }) async {
    _active(account);
    final report = FoundReport(
      id: 'FR-${1000 + ++_sequence}',
      volunteerUid: account.uid,
      photo: 'assets/images/volunteer/found.jpg',
    );
    _found[report.id] = report;
    return report;
  }

  @override
  Future<List<MatchCandidate>> findMatches(FoundReport report) async {
    if (_found[report.id] != report) throw StateError('unknown-report');
    return [
        MatchCandidate(_profiles[0], similarity: .94),
        MatchCandidate(_profiles[1], similarity: .88),
        MatchCandidate(_profiles[3], similarity: .76),
      ].where((candidate) {
        return reviewableProfiles.contains(candidate.person);
      }).toList()
      ..sort((a, b) => (b.similarity ?? -1).compareTo(a.similarity ?? -1));
  }

  @override
  Future<void> confirmMatch(
    VolunteerAccount account,
    FoundReport report,
    RegisteredPerson person,
  ) async {
    _owned(account, report);
    if (report.matchedPerson != null || !reviewableProfiles.contains(person)) {
      throw StateError('invalid-match');
    }
    final item = caseForPerson(person.id);
    if (item != null && !item.joinable) throw StateError('already-confirmed');
    report.matchedPerson = person;
    report.status = CaseStatus.matchConfirmed;
    if (item != null) {
      for (final uid in item.joinedBy.where((id) => id != account.uid)) {
        (_alerts[uid] ??= []).insert(
          0,
          VolunteerAlert(
            caseId: item.id,
            kind: AlertKind.statusUpdate,
            status: CaseStatus.matchConfirmed,
            at: DateTime.now(),
          ),
        );
      }
      item.confirmedBy = account.uid;
      item.joinedBy.add(account.uid);
      item.status = CaseStatus.matchConfirmed;
      item.updatedAt = DateTime.now();
    }
    notifyListeners();
  }

  String identifierFor(FoundReport report) =>
      caseForPerson(report.matchedPerson!.id)?.id ?? report.id;
  @override
  Future<void> beginVerification(
    VolunteerAccount account,
    FoundReport report,
  ) async {
    _owned(account, report);
    if (report.status != CaseStatus.matchConfirmed &&
        report.status != CaseStatus.awaitingGuardianVerification) {
      throw StateError('match-required');
    }
    report.status = CaseStatus.awaitingGuardianVerification;
    final item = caseForPerson(report.matchedPerson!.id);
    if (item != null) {
      item.status = CaseStatus.awaitingGuardianVerification;
      item.updatedAt = DateTime.now();
    }
    notifyListeners();
  }

  @override
  Future<bool> verify(
    VolunteerAccount account,
    FoundReport report,
    VerificationMethod method,
    String value, {
    bool authenticatedAccountShown = false,
  }) async {
    _owned(account, report);
    if (report.status != CaseStatus.awaitingGuardianVerification) {
      throw StateError('verification-not-ready');
    }
    final id = identifierFor(report);
    final valid = method == VerificationMethod.caseIdentifier
        ? authenticatedAccountShown && value.trim() == id
        : value == 'preview-qr:$id:${report.matchedPerson!.guardian.id}';
    report.verification = valid
        ? VerificationReceipt(
            caseId: id,
            guardianId: report.matchedPerson!.guardian.id,
            volunteerUid: account.uid,
            method: method,
            at: DateTime.now(),
          )
        : null;
    final item = caseForPerson(report.matchedPerson!.id);
    if (item != null) item.verification = report.verification;
    notifyListeners();
    return valid;
  }

  @override
  Future<void> handover(VolunteerAccount account, FoundReport report) async {
    _owned(account, report);
    final receipt = report.verification;
    if (report.status != CaseStatus.awaitingGuardianVerification ||
        receipt == null ||
        receipt.volunteerUid != account.uid ||
        receipt.guardianId != report.matchedPerson!.guardian.id ||
        receipt.caseId != identifierFor(report)) {
      throw StateError('verification-required');
    }
    final item = caseForPerson(report.matchedPerson!.id);
    report.status = CaseStatus.reunited;
    report.handedOverBy = account.uid;
    report.handedOverAt = DateTime.now();
    if (item != null) {
      item.status = CaseStatus.reunited;
      item.handedOverBy = account.uid;
      item.handedOverAt = report.handedOverAt;
      item.updatedAt = report.handedOverAt!;
    }
    notifyListeners();
  }
}
