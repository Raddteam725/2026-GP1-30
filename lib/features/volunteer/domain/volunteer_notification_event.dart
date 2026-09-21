import 'volunteer_models.dart';

/// FCM contains navigation hints, never identity or authorization. Text is
/// localized in Radd; case details always go through the authenticated API.
class VolunteerNotificationEvent {
  const VolunteerNotificationEvent({
    required this.id,
    required this.caseId,
    required this.kind,
  });
  final String id, caseId;
  final AlertKind kind;
  bool get opensCase => kind == AlertKind.newCase || kind == AlertKind.priority;

  static VolunteerNotificationEvent? fromData(Map<String, dynamic> data) {
    if (data['role'] != 'volunteer') return null;
    final caseId = data['case_id'];
    if (caseId is! String || caseId.isEmpty || caseId.contains('/')) {
      return null;
    }
    final kind = parseKind(data['kind'], data['status']);
    if (kind == null) return null;
    final supplied = data['notification_id'];
    return VolunteerNotificationEvent(
      id: supplied is String && supplied.isNotEmpty
          ? supplied
          : '$caseId-${kind == AlertKind.newCase
                ? 'new'
                : kind == AlertKind.statusUpdate
                ? 'match_confirmed'
                : kind.name}',
      caseId: caseId,
      kind: kind,
    );
  }

  static AlertKind? parseKind(dynamic kind, dynamic status) => switch (kind) {
    'general' || 'new_case' => AlertKind.newCase,
    'priority' => AlertKind.priority,
    'status_update' => AlertKind.statusUpdate,
    'case_closed' => switch (status) {
      'cancelled' => AlertKind.cancelled,
      'resolved' => AlertKind.resolved,
      _ => null,
    },
    'cancelled' => AlertKind.cancelled,
    'resolved' => AlertKind.resolved,
    'reunited' => AlertKind.reunited,
    _ => null,
  };
}

/// Scoped to one authenticated workspace. Backend history uses the same stable
/// ID, so duplicate FCM deliveries cannot create extra history rows either.
class VolunteerNotificationDeduplicator {
  final Set<String> _seen = {};
  bool accept(VolunteerNotificationEvent event) => _seen.add(
    event.kind == AlertKind.cancelled || event.kind == AlertKind.resolved
        ? '${event.caseId}|${event.kind.name}'
        : event.id,
  );
}
