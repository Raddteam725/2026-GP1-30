import 'case_models.dart';
export 'case_models.dart';

import 'dart:typed_data';

class GuardianProfile {
  const GuardianProfile({
    required this.fullName,
    required this.email,
    required this.phone,
  });
  final String fullName, email, phone;
  factory GuardianProfile.fromJson(Map<String, dynamic> j) => GuardianProfile(
    fullName: j['full_name'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String,
  );
}

class Individual {
  const Individual({
    this.activeCaseId,
    this.relationshipOther,
    this.photoExpired = false,
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationship,
  });
  final String? activeCaseId, relationshipOther;
  final String id, fullName, gender, relationship;
  final int age;

  /// Server-computed, from the photo's own capture time -- never derived
  /// from this device's clock. When true, Report Missing is unavailable
  /// (the backend enforces this independently; this only drives the UI).
  final bool photoExpired;
  factory Individual.fromJson(Map<String, dynamic> j) => Individual(
    activeCaseId: j['active_case_id'] as String?,
    relationshipOther: j['relationship_other'] as String?,
    photoExpired: j['photo_expired'] as bool? ?? false,
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    age: j['age'] as int,
    gender: j['gender'] as String,
    relationship: j['relationship'] as String,
  );
}

class IndividualInput {
  const IndividualInput({
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationship,
    this.relationshipOther,
  });
  final String fullName, gender, relationship;
  final String? relationshipOther;
  final int age;
  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'age': age,
    'gender': gender,
    'relationship': relationship,
    'relationship_other': relationship == 'other'
        ? relationshipOther?.trim()
        : null,
  };
}

class AppFailure implements Exception {
  const AppFailure(this.code);
  final String code;
}

abstract class GuardianRepository {
  /// Server-owned role, resolved without assuming a Guardian profile.
  Future<String> accountRole();
  Future<GuardianProfile> profile();
  Future<GuardianProfile> createProfile(String name, String phone);
  Future<GuardianProfile> updateProfile(String name, String phone);
  Future<List<Individual>> individuals();
  Future<Individual> individual(String id);
  Future<Individual> saveIndividual(
    IndividualInput input, {
    String? id,
    Uint8List? photo,
  });
  Future<void> deleteIndividual(String id);
  Future<Uint8List> photo(String id);

  Future<List<MissingCase>> cases();
  Future<MissingCase> missingCase(String id);
  Future<MissingCase> reportMissing(String individualId);
  Future<MissingCase> saveGuidedReport(String id, Map<String, dynamic> report);
  Future<List<GuardianNotification>> notifications();
  Future<void> readNotification(String id);

  /// Account-level: one Guardian QR, not one per case.
  Future<GuardianVerification> accountVerification();
  Future<MissingCase> cancelCase(String id);
  Future<MissingCase> resolveCase(String id);

  /// Registers (or refreshes) this installation's FCM registration for the
  /// authenticated Guardian. Idempotent -- safe to call again with the same
  /// token, and safe to call once per installation for a different one.
  /// [locale] is this installation's own current in-app language ('en'/'ar'
  /// -- see Localizations.localeOf), used only to pick which of two fixed,
  /// pre-translated strings the visible push notification is sent in.
  Future<void> registerFcmToken(String token, String locale);

  /// Removes this installation's FCM registration -- called at logout so it
  /// stops being able to receive the signing-out Guardian's pushes. Scoped
  /// to the caller's own registrations only; idempotent (a repeat call, or
  /// one for an already-removed token, succeeds as a no-op).
  Future<void> unregisterFcmToken(String token);
}
