import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../shared/widgets/notice_banner.dart';
import '../domain/volunteer_models.dart';
import '../domain/volunteer_notification_event.dart';

String volunteerAlertTitle(AppLocalizations s, AlertKind kind) =>
    switch (kind) {
      AlertKind.newCase => s.vNewAlert,
      AlertKind.priority => s.vPriorityAlert,
      AlertKind.statusUpdate => s.vStatusAlert,
      AlertKind.cancelled => s.vCancelledAlert,
      AlertKind.resolved => s.vResolvedAlert,
      AlertKind.reunited => s.vReunited,
    };

String volunteerAlertMessage(AppLocalizations s, AlertKind kind) =>
    switch (kind) {
      AlertKind.newCase => s.vNewAlertMessage,
      AlertKind.priority => s.vPriorityAlertMessage,
      AlertKind.statusUpdate => s.vMatchAlertMessage,
      AlertKind.cancelled => s.vCancelledAlertMessage,
      AlertKind.resolved => s.vResolvedAlertMessage,
      AlertKind.reunited => s.vReunitedAlertMessage,
    };

/// Used in the root overlay, so camera/QR routes receive the same notice as
/// Home, Cases and Profile. Does not consume touches outside the card.
class VolunteerNotificationBanner extends StatelessWidget {
  const VolunteerNotificationBanner({
    super.key,
    required this.event,
    required this.onOpen,
    required this.onDismiss,
  });
  final VolunteerNotificationEvent event;
  final VoidCallback onOpen, onDismiss;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final priority = event.kind == AlertKind.priority;
    // Same shared card the Guardian workspace uses (NoticeBanner); only the
    // Volunteer wording, key and action differ.
    return NoticeBanner(
      materialKey: ValueKey('volunteer-notice-${event.id}'),
      title: volunteerAlertTitle(s, event.kind),
      message: volunteerAlertMessage(s, event.kind),
      context: event.caseId,
      contextTextDirection: TextDirection.ltr,
      highlighted: priority,
      icon: priority ? Icons.warning_amber_rounded : Icons.notifications_none,
      actionLabel: event.opensCase ? s.vViewCase : s.notifications,
      closeTooltip: s.close,
      onOpen: onOpen,
      onDismiss: onDismiss,
    );
  }
}
