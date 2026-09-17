class MissingCase {
  const MissingCase({
    required this.id,
    required this.individualId,
    required this.name,
    required this.age,
    required this.status,
    required this.eventId,
    this.createdAt,
    this.updatedAt,
    this.stages = const {},
    this.report,
  });
  final String id, individualId, name, status, eventId;
  final int age;
  final DateTime? createdAt, updatedAt;
  final Map<String, dynamic> stages;
  final Map<String, dynamic>? report;
  bool get active => status != 'reunited';
  bool get verificationEligible => status == 'awaiting_guardian_verification';
  factory MissingCase.fromJson(Map<String, dynamic> j) => MissingCase(
    id: j['id'] as String,
    individualId: j['individual_id'] as String,
    name: j['individual_name'] as String,
    age: j['age'] as int,
    status: j['status'] as String,
    eventId: j['event_id'] as String,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? ''),
    stages: (j['stage_timestamps'] as Map<String, dynamic>?) ?? {},
    report: j['guided_report'] as Map<String, dynamic>?,
  );
}

const caseStages = [
  'report_received',
  'search_in_progress',
  'match_confirmed',
  'awaiting_guardian_verification',
  'reunited',
];

class GuardianNotification {
  const GuardianNotification({
    required this.id,
    required this.caseId,
    required this.status,
    required this.read,
    this.createdAt,
  });
  final String id, caseId, status;
  final bool read;
  final DateTime? createdAt;
  factory GuardianNotification.fromJson(Map<String, dynamic> j) =>
      GuardianNotification(
        id: j['id'] as String,
        caseId: j['case_id'] as String,
        status: j['status'] as String,
        read: j['read_at'] != null,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}

class GuardianVerification {
  const GuardianVerification({
    required this.caseId,
    required this.payload,
    required this.expiresAt,
  });
  final String caseId, payload;
  final DateTime expiresAt;
  factory GuardianVerification.fromJson(Map<String, dynamic> j) =>
      GuardianVerification(
        caseId: j['case_id'] as String,
        payload: j['payload'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}
