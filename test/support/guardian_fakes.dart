import 'dart:async';
import 'dart:typed_data';

import 'package:radd/features/auth/data/auth_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';

class TestAuth implements AuthService {
  bool active = false;
  int registrations = 0, logins = 0;
  final events = StreamController<bool>.broadcast();
  @override
  bool get signedIn => active;
  @override
  Future<bool> restoreSession() async => active;
  @override
  Stream<bool> get changes => events.stream;
  @override
  Future<void> login(String email, String password) async {
    logins++;
    active = true;
    events.add(true);
  }

  @override
  Future<void> register(String email, String password) async {
    registrations++;
    active = true;
    events.add(true);
  }

  @override
  Future<void> logout() async {
    active = false;
    events.add(false);
  }

  final List<String> resetRequests = [];
  @override
  Future<void> resetPassword(String email) async {
    resetRequests.add(email);
  }
}

class TestRepository implements GuardianRepository {
  @override
  Future<String> accountRole() async => 'guardian';
  GuardianProfile person = const GuardianProfile(
    fullName: 'Test Guardian',
    email: 'test@example.test',
    phone: '+966500000001',
  );
  final List<Individual> records = [];
  final List<MissingCase> caseRecords = [];
  final List<GuardianNotification> notificationRecords = [];
  int caseFetches = 0;
  bool failNextMissingCase = false;
  int _caseCounter = 0;
  @override
  Future<GuardianProfile> profile() async => person;
  @override
  Future<GuardianProfile> createProfile(String name, String phone) async =>
      person = GuardianProfile(
        fullName: name,
        email: person.email,
        phone: phone,
      );
  @override
  Future<GuardianProfile> updateProfile(String name, String phone) =>
      createProfile(name, phone);
  @override
  Future<List<Individual>> individuals() async => List.of(records);
  @override
  Future<Individual> individual(String id) async =>
      records.singleWhere((i) => i.id == id);
  @override
  Future<Individual> saveIndividual(
    IndividualInput input, {
    String? id,
    Uint8List? photo,
  }) async {
    final existing = id == null ? null : records.singleWhere((i) => i.id == id);
    final p = Individual(
      id: id ?? 'test-id',
      activeCaseId: existing?.activeCaseId,
      fullName: input.fullName,
      age: input.age,
      gender: input.gender,
      relationship: input.relationship,
      relationshipOther: input.relationship == 'other'
          ? input.relationshipOther
          : null,
    );
    records.removeWhere((i) => i.id == p.id);
    records.add(p);
    return p;
  }

  @override
  Future<void> deleteIndividual(String id) async {
    final p = records.singleWhere((i) => i.id == id);
    if (p.activeCaseId != null) throw const AppFailure('conflict');
    records.removeWhere((i) => i.id == id);
  }

  // Counts authoritative list refetches (event/resume-driven) and simulates
  // one transient load failure (flips back after throwing once).
  int caseListFetches = 0;
  bool failNextCases = false;
  @override
  Future<List<MissingCase>> cases() async {
    caseListFetches++;
    if (failNextCases) {
      failNextCases = false;
      throw const AppFailure('unavailable');
    }
    return List.of(caseRecords);
  }

  @override
  Future<MissingCase> missingCase(String id) async {
    caseFetches++;
    if (failNextMissingCase) {
      failNextMissingCase = false;
      throw const AppFailure('unavailable');
    }
    return caseRecords.singleWhere((c) => c.id == id);
  }

  @override
  Future<MissingCase> reportMissing(String individualId) async {
    final p = records.singleWhere((i) => i.id == individualId);
    if (p.activeCaseId != null) {
      return caseRecords.singleWhere((c) => c.id == p.activeCaseId);
    }
    final now = DateTime.now().toUtc();
    final value = MissingCase(
      id: 'RD-TEST${++_caseCounter}',
      individualId: individualId,
      name: p.fullName,
      age: p.age,
      status: 'report_received',
      eventId: 'test-event',
      createdAt: now,
      updatedAt: now,
      stages: {'report_received': now.toIso8601String()},
    );
    caseRecords.add(value);
    records
      ..removeWhere((i) => i.id == individualId)
      ..add(
        Individual(
          id: p.id,
          activeCaseId: value.id,
          fullName: p.fullName,
          age: p.age,
          gender: p.gender,
          relationship: p.relationship,
          relationshipOther: p.relationshipOther,
        ),
      );
    notificationRecords.add(
      GuardianNotification(
        id: '${value.id}-report_received',
        caseId: value.id,
        status: value.status,
        read: false,
        createdAt: now,
      ),
    );
    return value;
  }

  @override
  Future<MissingCase> saveGuidedReport(
    String id,
    Map<String, dynamic> report,
  ) async {
    final current = caseRecords.singleWhere((c) => c.id == id);
    if (current.status == 'reunited') throw const AppFailure('conflict');
    final updated = MissingCase(
      id: current.id,
      individualId: current.individualId,
      name: current.name,
      age: current.age,
      status: current.status,
      eventId: current.eventId,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      stages: current.stages,
      report: report,
    );
    caseRecords
      ..removeWhere((c) => c.id == id)
      ..add(updated);
    return updated;
  }

  @override
  Future<List<GuardianNotification>> notifications() async =>
      List.of(notificationRecords);
  @override
  Future<void> readNotification(String id) async {
    final n = notificationRecords.singleWhere((n) => n.id == id);
    if (n.read) return;
    notificationRecords
      ..removeWhere((existing) => existing.id == id)
      ..add(
        GuardianNotification(
          id: n.id,
          caseId: n.caseId,
          status: n.status,
          read: true,
          createdAt: n.createdAt,
        ),
      );
  }

  int _verificationCounter = 0;

  /// How many short-lived credentials the QR screen has requested.
  int get verificationRequests => _verificationCounter;
  @override
  Future<GuardianVerification>
  accountVerification() async => GuardianVerification(
    payload:
        'radd:guardian-verification:v1:test-guardian:test-nonce-${++_verificationCounter}',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
  );

  Future<MissingCase> _terminate(String id, String outcome) async {
    final current = caseRecords.singleWhere((c) => c.id == id);
    if (!current.active) throw const AppFailure('conflict');
    final updated = MissingCase(
      id: current.id,
      individualId: current.individualId,
      name: current.name,
      age: current.age,
      status: outcome,
      eventId: current.eventId,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      stages: current.stages,
      report: current.report,
    );
    caseRecords
      ..removeWhere((c) => c.id == id)
      ..add(updated);
    final person = records.singleWhere((i) => i.id == current.individualId);
    records
      ..removeWhere((i) => i.id == person.id)
      ..add(
        Individual(
          id: person.id,
          fullName: person.fullName,
          age: person.age,
          gender: person.gender,
          relationship: person.relationship,
          relationshipOther: person.relationshipOther,
        ),
      );
    return updated;
  }

  @override
  Future<MissingCase> cancelCase(String id) => _terminate(id, 'cancelled');
  @override
  Future<MissingCase> resolveCase(String id) => _terminate(id, 'resolved');

  final List<String> registeredFcmTokens = [];
  final List<String> unregisteredFcmTokens = [];
  String? lastRegisteredLocale;
  // Lets tests simulate a temporary failure (e.g. offline) without any real
  // network involved -- both flip back to false after throwing once, since a
  // real failure is transient, not a permanent condition.
  bool failNextFcmRegister = false;
  bool failNextFcmUnregister = false;
  @override
  Future<void> registerFcmToken(String token, String locale) async {
    if (failNextFcmRegister) {
      failNextFcmRegister = false;
      throw const AppFailure('network');
    }
    lastRegisteredLocale = locale;
    if (!registeredFcmTokens.contains(token)) registeredFcmTokens.add(token);
  }

  @override
  Future<void> unregisterFcmToken(String token) async {
    if (failNextFcmUnregister) {
      failNextFcmUnregister = false;
      throw const AppFailure('network');
    }
    unregisteredFcmTokens.add(token);
    registeredFcmTokens.remove(token);
  }

  @override
  Future<Uint8List> photo(String id) async => Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    11,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    96,
    0,
    2,
    0,
    0,
    5,
    0,
    1,
    165,
    246,
    69,
    64,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ]);
}
