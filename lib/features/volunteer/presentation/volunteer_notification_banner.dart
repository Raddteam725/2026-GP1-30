import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
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
    return Semantics(
      liveRegion: true,
      child: Material(
        key: ValueKey('volunteer-notice-${event.id}'),
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: priority ? const Color(0xFFF7B500) : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: priority
                        ? const Color(0xFFFFF8E4)
                        : AppColors.secondary.withValues(alpha: .1),
                    child: Icon(
                      priority
                          ? Icons.warning_amber_rounded
                          : Icons.notifications_none,
                      color: priority
                          ? const Color(0xFF996A00)
                          : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      volunteerAlertTitle(s, event.kind),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: s.close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(volunteerAlertMessage(s, event.kind)),
              const SizedBox(height: 4),
              Text(
                event.caseId,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppColors.primary, fontSize: 12),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onOpen,
                  child: Text(event.opensCase ? s.vViewCase : s.notifications),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
