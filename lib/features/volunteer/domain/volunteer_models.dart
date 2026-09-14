import 'dart:math' as math;

enum CaseStatus {
  reportReceived,
  searchInProgress,
  matchConfirmed,
  awaitingGuardianVerification,
  reunited,
}

enum Gender { male, female }

enum VerificationMethod { qr, caseIdentifier }

/// Bilingual fixture/user content, distinct from localized interface strings.
class LocalizedData {
  const LocalizedData(this.en, this.ar);
  final String en, ar;
  String inLanguage(String language) => language == 'ar' ? ar : en;
}

class VolunteerAccount {
  const VolunteerAccount({
    required this.uid,
    required this.name,
    required this.volunteerId,
    required this.active,
    this.email,
    this.phone,
  });
  final String uid, volunteerId;
  final LocalizedData name;
  final bool active;
  final String? email, phone;
}

class GuardianContact {
  const GuardianContact({
    required this.id,
    required this.name,
    required this.relationship,
    this.phone,
  });
  final String id;
  final LocalizedData name;
  final LocalizedData relationship;
  final String? phone;
}

class RegisteredPerson {
  const RegisteredPerson({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.guardian,
    this.photo,
  });
  final String id;
  final LocalizedData name;
  final int age;
  final Gender gender;
  final GuardianContact guardian;
  final String? photo;
}

class Coordinates {
  const Coordinates(this.latitude, this.longitude);
  final double latitude, longitude;
  double distanceTo(Coordinates other) {
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.latitude - latitude),
        dLon = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371000 *
        2 *
        math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt((1 - a).clamp(0, 1)));
  }
}

class CaseInformation {
  const CaseInformation({
    this.lastSeen,
    this.coordinates,
    this.clothing,
    this.distinctive,
    this.additional,
  });
  final LocalizedData? lastSeen, clothing, distinctive, additional;
  final Coordinates? coordinates;
}

class VolunteerCase {
  VolunteerCase({
    required this.id,
    required this.person,
    required this.createdAt,
    required this.updatedAt,
    this.status = CaseStatus.reportReceived,
    this.information,
    Set<String>? joinedBy,
    this.confirmedBy,
  }) : joinedBy = {...?joinedBy};
  final String id;
  final RegisteredPerson person;
  final DateTime createdAt;
  DateTime updatedAt;
  CaseStatus status;
  CaseInformation? information;
  final Set<String> joinedBy;
  String? confirmedBy, handedOverBy;
  DateTime? handedOverAt;
  VerificationReceipt? verification;
  bool get joinable =>
      status == CaseStatus.reportReceived ||
      status == CaseStatus.searchInProgress;
}

class MatchCandidate {
  const MatchCandidate(this.person, {this.similarity});
  final RegisteredPerson person;
  final double? similarity;
}

class FoundReport {
  FoundReport({
    required this.id,
    required this.volunteerUid,
    required this.photo,
  });
  final String id, volunteerUid, photo;
  RegisteredPerson? matchedPerson;
  CaseStatus? status;
  VerificationReceipt? verification;
  String? handedOverBy;
  DateTime? handedOverAt;
}

class VerificationReceipt {
  const VerificationReceipt({
    required this.caseId,
    required this.guardianId,
    required this.volunteerUid,
    required this.method,
    required this.at,
  });
  final String caseId, guardianId, volunteerUid;
  final VerificationMethod method;
  final DateTime at;
}

enum AlertKind { newCase, priority, statusUpdate }

class VolunteerAlert {
  const VolunteerAlert({
    required this.caseId,
    required this.kind,
    required this.at,
    this.status,
  });
  final String caseId;
  final AlertKind kind;
  final DateTime at;
  final CaseStatus? status;
}
