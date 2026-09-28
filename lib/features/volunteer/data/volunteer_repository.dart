import 'package:flutter/foundation.dart';

import '../domain/volunteer_models.dart';

/// Future FastAPI implementation must authorize every operation on the server.
abstract class VolunteerRepository extends ChangeNotifier {
  /// Prototype default for previews/older servers; production reads the shared
  /// backend's configured radius with the authenticated profile.
  double get proximityRadiusMeters => 500;
  bool get isPreview;
  bool get connected;
  List<VolunteerCase> get cases;
  List<RegisteredPerson> get profiles;
  List<VolunteerAlert> alertsFor(String uid);
  List<FoundReport> get foundReports => const [];
  List<VolunteerCase> availableFor(String uid) =>
      cases.where((c) => c.joinable && !c.joinedBy.contains(uid)).toList();
  List<VolunteerCase> myCases(String uid) => cases
      .where(
        (c) => c.joinable ? c.joinedBy.contains(uid) : c.confirmedBy == uid,
      )
      .toList();
  List<RegisteredPerson> get reviewableProfiles => profiles
      .where(
        (person) =>
            !cases.any((item) => item.person.id == person.id && !item.joinable),
      )
      .toList();

  VolunteerCase? caseForPerson(String personId) {
    for (final item in cases) {
      if (item.person.id == personId && item.status != CaseStatus.reunited) {
        return item;
      }
    }
    return null;
  }

  VolunteerCase? caseById(String id) {
    for (final item in cases) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> startSearch(VolunteerAccount account, VolunteerCase item);
  Future<FoundReport> submitFound(
    VolunteerAccount account, {
    Uint8List? photo,
    String? requestId,
  });
  Future<List<MatchCandidate>> findMatches(FoundReport report);
  Future<void> confirmMatch(
    VolunteerAccount account,
    FoundReport report,
    RegisteredPerson person,
  );
  Future<void> beginVerification(VolunteerAccount account, FoundReport report);
  Future<bool> verify(
    VolunteerAccount account,
    FoundReport report,
    VerificationMethod method,
    String value, {
    bool authenticatedAccountShown = false,
  });
  Future<void> handover(VolunteerAccount account, FoundReport report);
}

/// No mock data is returned to a real signed-in account.
class UnconnectedVolunteerRepository extends VolunteerRepository {
  @override
  bool get isPreview => false;
  @override
  bool get connected => false;
  @override
  List<VolunteerCase> get cases => const [];
  @override
  List<RegisteredPerson> get profiles => const [];
  @override
  List<VolunteerAlert> alertsFor(String uid) => const [];
  Never _unavailable() => throw StateError('backend-unavailable');
  @override
  Future<void> startSearch(
    VolunteerAccount account,
    VolunteerCase item,
  ) async => _unavailable();
  @override
  Future<FoundReport> submitFound(
    VolunteerAccount account, {
    Uint8List? photo,
    String? requestId,
  }) async => _unavailable();
  @override
  Future<List<MatchCandidate>> findMatches(FoundReport report) async =>
      _unavailable();
  @override
  Future<void> confirmMatch(
    VolunteerAccount account,
    FoundReport report,
    RegisteredPerson person,
  ) async => _unavailable();
  @override
  Future<void> beginVerification(
    VolunteerAccount account,
    FoundReport report,
  ) async => _unavailable();
  @override
  Future<bool> verify(
    VolunteerAccount account,
    FoundReport report,
    VerificationMethod method,
    String value, {
    bool authenticatedAccountShown = false,
  }) async => _unavailable();
  @override
  Future<void> handover(VolunteerAccount account, FoundReport report) async =>
      _unavailable();
}
