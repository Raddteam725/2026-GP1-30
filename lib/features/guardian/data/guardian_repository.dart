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
    this.registrationPeriodId,
    this.registrationExpiresAt,
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationship,
  });
  final String? activeCaseId, relationshipOther;
  final String id, fullName, gender, relationship;
  final int age;

  final bool photoExpired;

  final String? registrationPeriodId;
  final DateTime? registrationExpiresAt;
  factory Individual.fromJson(Map<String, dynamic> j) => Individual(
    activeCaseId: j['active_case_id'] as String?,
    relationshipOther: j['relationship_other'] as String?,
    photoExpired: j['photo_expired'] as bool? ?? false,
    registrationPeriodId: j['registration_period_id'] as String?,
    registrationExpiresAt: DateTime.tryParse(
      j['registration_expires_at']?.toString() ?? '',
    ),
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    age: j['age'] as int,
    gender: j['gender'] as String,
    relationship: j['relationship'] as String,
  );
}

class RetentionOption {
  const RetentionOption(
    this.id,
    this.hours,
    this.expiresAt, {
    this.available = true,
    this.reason,
  });
  final String id;
  final int hours;
  final DateTime expiresAt;

  final bool available;
  final String? reason;
}

class RetentionOptions {
  const RetentionOptions({
    required this.currentPeriodId,
    required this.expiresAt,
    required this.editable,
    required this.options,
  });
  final String? currentPeriodId;
  final DateTime? expiresAt;

  final bool editable;
  final List<RetentionOption> options;
  factory RetentionOptions.fromJson(Map<String, dynamic> j) => RetentionOptions(
    currentPeriodId: j['current_period_id'] as String?,
    expiresAt: DateTime.tryParse(j['expires_at']?.toString() ?? ''),
    editable: j['editable'] as bool? ?? false,
    options: [
      for (final o in j['options'] as List)
        RetentionOption(
          o['id'] as String,
          o['duration_hours'] as int,
          DateTime.parse(o['expires_at'] as String),
          available: o['available'] as bool? ?? true,
          reason: o['reason'] as String?,
        ),
    ],
  );
}

class IndividualInput {
  const IndividualInput({
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationship,
    this.relationshipOther,
    this.registrationPeriodId,
  });
  final String? registrationPeriodId;
  final String fullName, gender, relationship;
  final String? relationshipOther;
  final int age;
  Map<String, dynamic> toJson() => {
    if (registrationPeriodId != null)
      'registration_period_id': registrationPeriodId,
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

class RegistrationPeriod {
  const RegistrationPeriod(this.id, this.hours);
  final String id;
  final int hours;
}

class ActiveEvent {
  const ActiveEvent({
    required this.id,
    required this.name,
    required this.status,
    this.location,
    this.startsAt,
    this.endsAt,
  });
  final String id, name, status;
  final String? location;
  final DateTime? startsAt, endsAt;
  factory ActiveEvent.fromJson(Map<String, dynamic> j) => ActiveEvent(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'active',
    location: j['location'] as String?,
    startsAt: DateTime.tryParse(j['starts_at']?.toString() ?? ''),
    endsAt: DateTime.tryParse(j['ends_at']?.toString() ?? ''),
  );
}

abstract class GuardianRepository {
  Future<ActiveEvent> activeEvent();
  Future<List<RegistrationPeriod>> registrationPeriods();

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

  Future<RetentionOptions> retentionOptions(String id);
  Future<Uint8List> photo(String id);

  Future<List<MissingCase>> cases();
  Future<MissingCase> missingCase(String id);
  Future<MissingCase> reportMissing(String individualId);
  Future<MissingCase> saveGuidedReport(String id, Map<String, dynamic> report);
  Future<List<GuardianNotification>> notifications();
  Future<void> readNotification(String id);
  Future<void> readAllNotifications();

  Future<GuardianVerification> accountVerification();

  Future<List<GuardianFoundReport>> activeFoundReports();

  Future<void> registerFcmToken(String token, String locale);

  Future<void> unregisterFcmToken(String token);
}
