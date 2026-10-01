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
    this.verificationCode,
  });
  final String id, individualId, name, status, eventId;
  final int age;
  final DateTime? createdAt, updatedAt;
  final Map<String, dynamic> stages;
  final Map<String, dynamic>? report;

  /// The 6-digit code the Guardian reads to the Volunteer when the QR cannot
  /// be scanned. Belongs to this active case only; [id] stays internal and
  /// is never the value a person types. Null once the case is terminal.
  final String? verificationCode;
  bool get active => !terminalStatuses.contains(status);
  bool get verificationEligible => status == 'awaiting_guardian_verification';
  bool get reportSubmitted => report?['completed'] == true;
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
    verificationCode: j['verification_code']?.toString(),
  );
}

const caseStages = [
  'report_received',
  'search_in_progress',
  'match_confirmed',
  'awaiting_guardian_verification',
  'reunited',
];
// Reachable from any active case (never sequential); 'reunited' is both the
// last ordered stage above and a terminal outcome on its own. Guardians
// cancel/resolve; Volunteers reunite; an Admin refers to the authority.
const terminalStatuses = {
  'reunited',
  'resolved',
  'cancelled',
  'referred_to_authority',
};

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

/// An active standalone Found Report (no Missing Case) in which this
/// Guardian's registered individual was identified. [verificationCode] is
/// the short code the Guardian reads to the Volunteer when the QR cannot be
/// scanned; [id] is the internal report id and is not shown as that code.
class GuardianFoundReport {
  const GuardianFoundReport({
    required this.id,
    required this.status,
    this.individualId,
    this.individualName,
    this.verificationCode,
  });
  final String id, status;

  /// The Guardian's own registration name for the identified individual, so
  /// each code can be told apart when several reports are active.
  final String? individualId, individualName, verificationCode;

  /// Stages at which Guardian verification information may be shown. The
  /// backend applies the same rule; this guards against any stale item.
  static const verificationStages = {
    'identity_confirmed',
    'awaiting_guardian_verification',
  };
  bool get awaitingVerification => verificationStages.contains(status);
  factory GuardianFoundReport.fromJson(Map<String, dynamic> j) =>
      GuardianFoundReport(
        id: j['id'] as String,
        status: j['status']?.toString() ?? '',
        individualId: j['individual_id']?.toString(),
        individualName: j['individual_name']?.toString(),
        verificationCode: j['verification_code']?.toString(),
      );
}

/// Account-level: one Guardian verification QR, not one per case. The case
/// context is supplied by whichever case the Volunteer is currently on.
class GuardianVerification {
  const GuardianVerification({required this.payload, required this.expiresAt});
  final String payload;
  final DateTime expiresAt;
  factory GuardianVerification.fromJson(Map<String, dynamic> j) =>
      GuardianVerification(
        payload: j['payload'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}
