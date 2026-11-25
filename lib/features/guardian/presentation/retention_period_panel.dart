import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';

class RetentionChoice {
  const RetentionChoice(
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

String retentionPeriodLabel(AppLocalizations s, int hours) =>
    hours >= 24 && hours % 24 == 0
    ? s.registrationPeriodDays(hours ~/ 24)
    : s.registrationPeriodHours(hours);

String? retentionReasonLabel(AppLocalizations s, String? reason) =>
    switch (reason) {
      'deadline_passed' => s.retentionOptionPassed,
      'beyond_event' => s.retentionOptionBeyondEvent,
      _ => null,
    };

class RetentionPeriodPanel extends StatelessWidget {
  const RetentionPeriodPanel({
    super.key,
    required this.choices,
    required this.selectedId,
    required this.onChanged,
    required this.editing,
    this.enabled = true,
    this.eventName,
  });
  final List<RetentionChoice> choices;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool editing, enabled;
  final String? eventName;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final selected = selectedId == null
        ? (choices.isEmpty ? null : choices.last)
        : choices.cast<RetentionChoice?>().firstWhere(
            (c) => c!.id == selectedId,
            orElse: () => null,
          );
    return GuardianPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.registrationPeriodTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (eventName != null) ...[
            Row(
              key: const ValueKey('active-event'),
              children: [
                const Icon(Icons.event, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.registeringForEvent(eventName!),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(s.registrationPeriodHint),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('registration-period'),
            initialValue: selectedId,
            isExpanded: true,
            hint: Text(s.registrationPeriodDefault),
            items: [
              for (final choice in choices)
                DropdownMenuItem(
                  value: choice.id,
                  enabled: choice.available,
                  child: Text(
                    choice.available
                        ? retentionPeriodLabel(s, choice.hours)
                        : s.retentionOptionUnavailable(
                            retentionPeriodLabel(s, choice.hours),
                            retentionReasonLabel(s, choice.reason) ?? '',
                          ),
                    style: choice.available
                        ? null
                        : const TextStyle(color: mutedText),
                  ),
                ),
            ],
            onChanged: enabled ? onChanged : null,
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(
              s.retentionUntil(caseDate(context, selected.expiresAt)),
              key: const ValueKey('retention-until'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            editing ? s.retentionEditBoundary : s.registrationPeriodBoundary,
            style: const TextStyle(fontSize: 12, color: mutedText),
          ),
        ],
      ),
    );
  }
}
