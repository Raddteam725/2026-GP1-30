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

/// What the Guardian is told at each stage of the reunification path -- the
/// wording under the emphasized (current) step of the progress timeline.
String caseStageDescription(String status, AppLocalizations s) =>
    switch (status) {
      'report_received' => s.reportReceivedDescription,
      'search_in_progress' => s.searchInProgressDescription,
      'match_confirmed' => s.matchConfirmedDescription,
      'awaiting_guardian_verification' => s.awaitingVerificationDescription,
      'reunited' => s.reunitedDescription,
      _ => s.caseClosedNotice,
    };

String caseDate(BuildContext context, DateTime? date) => date == null
    ? '—'
    : DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
          .add_jm()
          .format(date.toLocal());

/// Case identifiers are always presented with a leading '#', as in the
/// approved design ("#RD-…"); the raw id is what the backend actually uses.
String caseDisplayId(String id) => '#$id';

/// The identifier for use INSIDE mixed-direction rich text (Arabic label +
/// Latin id): Unicode isolates keep "#RD-…" reading left-to-right as a unit
/// without affecting the surrounding paragraph. Widgets that show the id on
/// its own use `textDirection: TextDirection.ltr` instead.
String caseDisplayIdIsolated(String id) => '\u2066${caseDisplayId(id)}\u2069';

/// 1-based position on the five-stage reunification path, or null for a
/// terminal outcome that is not itself a stage (resolved/cancelled/...).
int? caseStageNumber(String status) {
  final index = caseStages.indexOf(status);
  return index < 0 ? null : index + 1;
}

const mutedText = Color(0xFF718096);
const _greyBackground = Color(0xFFEDF2F7);

/// The ONE semantic colour per canonical backend case status, used by every
/// Guardian status chip, badge, card and timeline indicator. Keyed on the
/// backend identifier, never on a translated label.
const caseStatusColors = <String, Color>{
  'report_received': Color(0xFF2563EB),
  'search_in_progress': Color(0xFFF59E0B),
  'match_confirmed': Color(0xFF7C3AED),
  'awaiting_guardian_verification': Color(0xFF0D9488),
  'reunited': Color(0xFF16A34A),
  'resolved': Color(0xFF15803D),
  'cancelled': Color(0xFF64748B),
  'transferred_to_authority': Color(0xFFEA580C),
};
Color caseStatusColor(String status) => caseStatusColors[status] ?? mutedText;

/// Light tint of a status colour for chip/badge backgrounds.
Color caseStatusTint(String status) =>
    caseStatusColor(status).withValues(alpha: .12);

/// "Report Missing" is an ACTION, not a status: always this red.
const reportMissingColor = Color(0xFFDC2626);

/// The one status vocabulary used on every screen, coloured by
/// [caseStatusColor] from the canonical status.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.withStageNumber = false,
  });
  final String status;
  final bool withStageNumber;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final color = caseStatusColor(status);
    final stage = caseStageNumber(status);
    final label = withStageNumber && stage != null
        ? s.stageStatus('$stage', caseStatusLabel(status, s))
        : caseStatusLabel(status, s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: caseStatusTint(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 7),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small navy-on-light identifier chip ("#RD-…"), as on Case Status.
class CaseIdChip extends StatelessWidget {
  const CaseIdChip({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _greyBackground,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      caseDisplayId(id),
      textDirection: TextDirection.ltr,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
      ),
    ),
  );
}

enum CaseCardStyle {
  /// Home "Active Cases": amber outline, "Track Status" action.
  home,

  /// Cases list: teal accent bar on the leading edge, "View Status" action.
  list,
}

class CaseCard extends StatelessWidget {
  const CaseCard({
    super.key,
    required this.value,
    required this.onTap,
    this.actionLabel,
    this.style = CaseCardStyle.list,
  });
  final MissingCase value;
  final VoidCallback onTap;
  final String? actionLabel;
  final CaseCardStyle style;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final home = style == CaseCardStyle.home;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: home && value.active
              ? AppColors.accent.withValues(alpha: .7)
              : AppColors.border.withValues(alpha: .7),
          width: home && value.active ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // IntrinsicHeight: the accent bar stretches to the content's height
          // even though the card sits in a list with unbounded height.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!home)
                  Container(
                    width: 5,
                    color: value.active
                        ? AppColors.secondary
                        : AppColors.border,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IndividualPhoto(id: value.individualId, size: 56),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.ageYears('${value.age}'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: StatusChip(status: value.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Full width: real identifiers are long (RD-…12 hex).
                        Text.rich(
                          TextSpan(
                            text: '${s.caseId}: ',
                            style: const TextStyle(
                              fontSize: 13,
                              color: mutedText,
                            ),
                            children: [
                              TextSpan(
                                text: caseDisplayIdIsolated(value.id),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: mutedText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${s.updatedLabel}: ${caseDate(context, value.updatedAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: mutedText,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: onTap,
                              iconAlignment: IconAlignment.end,
                              style: TextButton.styleFrom(
                                foregroundColor: home
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                              ),
                              label: Text(
                                actionLabel ?? s.viewStatus,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ONE Report Missing flow, shared by every entry point (Home, My
/// Individuals, Individual Profile): confirmation -> real case creation on the
/// backend (which is what triggers the initial Volunteer alert) -> the
/// required Guided Assistant opens automatically. Returns true once a case
/// exists for this individual so the caller can refresh its own state.
/// Backend failures propagate to the caller, which surfaces them in place.
Future<bool> startReportMissing(
  BuildContext context,
  Individual individual, {
  ValueChanged<bool>? onBusy,
}) async {
  final s = AppLocalizations.of(context)!;
  final confirmed = await guardianConfirmation(
    context,
    title: s.reportMissing,
    message: '${s.reportConfirm}\n\n${individual.fullName}',
    confirm: s.confirm,
    icon: Icons.person_search_outlined,
  );
  if (confirmed != true || !context.mounted) return false;
  // Busy only from here: the confirmation itself is not "in progress".
  onBusy?.call(true);
  try {
    final value = await AppServices.of(context).guardian
        .reportMissing(individual.id);
    if (!context.mounted) return true;
    await Navigator.of(context)
        .pushNamed(AppRoutes.guidedReport, arguments: value.id);
    return true;
  } finally {
    onBusy?.call(false);
  }
}

enum ReportMissingVariant {
  /// My Individuals card: compact red button / amber "Active Case" row.
  list,

  /// Individual Profile: large full-width red button.
  profile,

  /// Home grid card: a single small chip-style control.
  chip,
}

class ReportMissingAction extends StatefulWidget {
  const ReportMissingAction({
    super.key,
    required this.individual,
    required this.onChanged,
    this.activeCase,
    this.variant = ReportMissingVariant.list,
  });
  final Individual individual;
  final MissingCase? activeCase;
  final VoidCallback onChanged;
  final ReportMissingVariant variant;
  @override
  State<ReportMissingAction> createState() => _ReportMissingActionState();
}

class _ReportMissingActionState extends State<ReportMissingAction> {
  bool _busy = false;
  Object? _error;
  Future<void> _report() async {
    if (_busy) return;
    setState(() => _error = null);
    try {
      final created = await startReportMissing(
        context,
        widget.individual,
        onBusy: (busy) {
          if (mounted) setState(() => _busy = busy);
        },
      );
      if (created && mounted) widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      if (widget.variant == ReportMissingVariant.chip) {
        // No room for an inline notice on the compact Home card.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage(e, AppLocalizations.of(context)!)),
          ),
        );
      } else {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCase(String id) async {
    await Navigator.of(context).pushNamed(AppRoutes.caseStatus, arguments: id);
    if (mounted) widget.onChanged();
  }

  Future<void> _updatePhoto() async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.editIndividual, arguments: widget.individual);
    if (mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final activeId = widget.individual.activeCaseId;
    if (widget.variant == ReportMissingVariant.chip) return _chip(s, activeId);
    final profile = widget.variant == ReportMissingVariant.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeId != null)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openCase(activeId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _ActiveCaseChip(
                    label: s.activeCase,
                    status: widget.activeCase?.status,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${s.caseId} ',
                        style: const TextStyle(color: mutedText, fontSize: 13),
                        children: [
                          TextSpan(
                            text: caseDisplayIdIsolated(activeId),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: mutedText,
                  ),
                ],
              ),
            ),
          )
        else if (widget.individual.photoExpired) ...[
          Text(
            s.photoExpiredNotice,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: _updatePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(s.updatePhotoRequired),
          ),
        ] else
          Align(
            alignment: profile
                ? Alignment.center
                : AlignmentDirectional.centerStart,
            child: SizedBox(
              width: profile ? double.infinity : null,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: reportMissingColor,
                  minimumSize: Size(0, profile ? 52 : 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: _busy ? null : _report,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_search_outlined, size: 20),
                label: Text(s.reportMissing),
              ),
            ),
          ),
        if (_error != null) ErrorNotice(message: failureMessage(_error!, s)),
      ],
    );
  }

  Widget _chip(AppLocalizations s, String? activeId) {
    if (activeId != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCase(activeId),
        child: _ActiveCaseChip(
          label: s.activeCase,
          status: widget.activeCase?.status,
        ),
      );
    }
    final expired = widget.individual.photoExpired;
    final color = expired ? AppColors.error : reportMissingColor;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _busy ? null : (expired ? _updatePhoto : _report),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .6)),
          ),
          child: _busy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  expired ? s.updatePhotoRequired : s.reportMissing,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Active Case" indicator on an individual's card, coloured by that case's
/// canonical status (navy when the status is not loaded on this screen).
class _ActiveCaseChip extends StatelessWidget {
  const _ActiveCaseChip({required this.label, this.status});
  final String label;
  final String? status;
  @override
  Widget build(BuildContext context) {
    final color = status == null ? AppColors.primary : caseStatusColor(status!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 7),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The in-app notice for a case update that arrived (by push) while the
/// Guardian is using Radd: the status in Radd's own words plus the case
/// identifier -- the same status vocabulary as everywhere else, never a
/// technical or Firebase message. Shown only by the screen currently on top
/// so stacked screens never show it twice; the screen's own authoritative
/// refetch is what actually changes what is displayed.
void showCaseUpdateNotice(
  BuildContext context, {
  required String caseId,
  required String status,
}) {
  if (ModalRoute.of(context)?.isCurrent != true) return;
  final s = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('case-update-notice'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: caseStatusColor(status),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 10),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${caseStatusLabel(status, s)} · ${caseDisplayIdIsolated(caseId)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
}
