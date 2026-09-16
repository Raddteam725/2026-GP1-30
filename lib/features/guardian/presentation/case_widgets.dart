import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'guardian_components.dart';
import 'individual_widgets.dart';

String caseStatusLabel(String status, AppLocalizations s) => switch (status) {
  'report_received' => s.reportReceived,
  'search_in_progress' => s.searchInProgress,
  'match_confirmed' => s.matchConfirmed,
  'awaiting_guardian_verification' => s.awaitingVerification,
  'reunited' => s.reunited,
  'resolved' => s.resolved,
  'cancelled' => s.cancelled,
  'transferred_to_authority' => s.transferredToAuthority,
  _ => s.unknownCaseStatus,
};
String caseDate(BuildContext context, DateTime? date) => date == null
    ? '—'
    : DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
          .add_jm()
          .format(date.toLocal());

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final terminal = terminalStatuses.contains(status) && status != 'reunited';
    final color = status == 'reunited'
        ? AppColors.secondary
        : terminal
        ? const Color(0xFF718096)
        : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        caseStatusLabel(status, s),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class CaseCard extends StatelessWidget {
  const CaseCard({
    super.key,
    required this.value,
    required this.onTap,
    this.actionLabel,
  });
  final MissingCase value;
  final VoidCallback onTap;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return GuardianPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IndividualPhoto(id: value.individualId),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${s.age}: ${value.age}'),
                    Text(value.id, textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StatusChip(status: value.status),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            '${s.lastUpdated}: ${caseDate(context, value.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onTap,
            child: Text(actionLabel ?? s.viewStatus),
          ),
        ],
      ),
    );
  }
}

class ReportMissingAction extends StatefulWidget {
  const ReportMissingAction({
    super.key,
    required this.individual,
    required this.onChanged,
    this.activeCase,
  });
  final Individual individual;
  final MissingCase? activeCase;
  final VoidCallback onChanged;
  @override
  State<ReportMissingAction> createState() => _ReportMissingActionState();
}

class _ReportMissingActionState extends State<ReportMissingAction> {
  bool _busy = false;
  Object? _error;
  Future<void> _report() async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await guardianConfirmation(
      context,
      title: s.reportMissing,
      message: '${s.reportConfirm}\n\n${widget.individual.fullName}',
      confirm: s.confirm,
      icon: Icons.person_search_outlined,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await AppServices.of(context).guardian
          .reportMissing(widget.individual.id);
      if (!mounted) return;
      await Navigator.of(context)
          .pushNamed(AppRoutes.guidedReport, arguments: value.id);
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final activeId = widget.individual.activeCaseId;
    final active = widget.activeCase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeId != null)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.of(context)
                  .pushNamed(AppRoutes.caseStatus, arguments: activeId);
              if (mounted) widget.onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      active == null
                          ? s.activeCase
                          : caseStatusLabel(active.status, s),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeId,
                      textDirection: TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _busy ? null : _report,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_search_outlined),
            label: Text(s.reportMissing),
          ),
        if (_error != null) ErrorNotice(message: failureMessage(_error!, s)),
      ],
    );
  }
}
