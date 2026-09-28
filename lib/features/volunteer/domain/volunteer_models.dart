import 'dart:math' as math;
import 'dart:typed_data';

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
    this.assigned = false,
    this.eventId,
  });
  final String uid, volunteerId;
  final LocalizedData name;
  final bool active;
  final bool assigned;
  final String? eventId;
  bool get assignedToCurrentEvent => assigned && eventId != null;
  bool get eventAuthorized => active && assignedToCurrentEvent;
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
    this.photoBytes,
    this.information,
    this.confirmationAvailable = true,
  });
  final bool confirmationAvailable;
  final String id;
  final LocalizedData name;
  final int age;
  final Gender? gender;
  final Uint8List? photoBytes;
  final CaseInformation? information;
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
  RegisteredPerson person;
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

enum FoundStatus {
  identifying('identification_in_progress'),
  identified('identity_confirmed'),
  verifying('awaiting_guardian_verification'),
  reunited('reunited');

  const FoundStatus(this.value);
  final String value;
  static FoundStatus? parse(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

class FoundReport {
  FoundReport({
    required this.id,
    required this.volunteerUid,
    required this.photo,
    this.photoBytes,
    this.caseId,
    this.createdAt,
  });
  final String id, volunteerUid, photo;
  Uint8List? photoBytes;
  bool ended = false;
  FoundStatus? foundStatus;
  String? caseId;
  DateTime? createdAt;
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

enum AlertKind {
  newCase,
  priority,
  statusUpdate,
  cancelled,
  resolved,
  reunited,
}

class VolunteerAlert {
  const VolunteerAlert({
    required this.caseId,
    required this.kind,
    required this.at,
    this.status,
    this.id,
    this.readAt,
  });
  final String? id;
  final DateTime? readAt;
  final String caseId;
  final AlertKind kind;
  final DateTime at;
  final CaseStatus? status;
}
