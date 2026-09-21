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
    final kind = switch (data['kind']) {
      'general' || 'new_case' => AlertKind.newCase,
      'priority' => AlertKind.priority,
      'status_update' => AlertKind.statusUpdate,
      'cancelled' => AlertKind.cancelled,
      'resolved' => AlertKind.resolved,
      'reunited' => AlertKind.reunited,
      _ => null,
    };
    if (kind == null) return null;
    final suffix = switch (kind) {
      AlertKind.newCase => 'new',
      AlertKind.statusUpdate => 'match_confirmed',
      _ => kind.name,
    };
    final supplied = data['notification_id'];
    return VolunteerNotificationEvent(
      id: supplied is String && supplied.isNotEmpty
          ? supplied
          : '$caseId-$suffix',
      caseId: caseId,
      kind: kind,
    );
  }
}

/// Scoped to one authenticated workspace. Backend history uses the same stable
/// ID, so duplicate FCM deliveries cannot create extra history rows either.
class VolunteerNotificationDeduplicator {
  final Set<String> _seen = {};
  bool accept(VolunteerNotificationEvent event) => _seen.add(event.id);
}
