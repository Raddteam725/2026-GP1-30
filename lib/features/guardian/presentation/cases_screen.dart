import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';
import 'individual_widgets.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  Future<List<MissingCase>>? _data;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= AppServices.of(context).guardian.cases();
  }

  void _reload() => setState(() {
    _data = AppServices.of(context).guardian.cases();
  });
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<List<MissingCase>>(
      future: _data,
      builder: (context, state) {
        final cases = state.data ?? const <MissingCase>[];
        final activeCount = cases.where((c) => c.active).length;
        return FeaturePage(
          title: s.cases,
          subtitle: s.casesSubtitle,
          actions: [
            IconButton(
              tooltip: s.retry,
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottomNavigationBar: widget.embedded
              ? null
              : const GuardianNavigation(selected: 3),
          children: [
            if (state.hasError)
              ErrorNotice(
                message: failureMessage(state.error!, s),
                onRetry: _reload,
              )
            else if (!state.hasData)
              const Center(child: CircularProgressIndicator())
            else if (cases.isEmpty) ...[
              const Icon(Icons.folder_outlined, size: 48),
              const SizedBox(height: 24),
              Text(s.noCases, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(s.noCasesHint, textAlign: TextAlign.center),
            ] else ...[
              Row(
                children: [
                  Text(
                    s.activeCases,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final value in cases) ...[
                CaseCard(
                  value: value,
                  onTap: () async {
                    await Navigator.of(context)
                        .pushNamed(AppRoutes.caseStatus, arguments: value.id);
                    if (mounted) _reload();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],
          ],
        );
      },
    );
  }
}

class CaseStatusScreen extends StatefulWidget {
  const CaseStatusScreen({super.key, required this.id});
  final String id;
  @override
  State<CaseStatusScreen> createState() => _CaseStatusScreenState();
}

class _CaseStatusScreenState extends State<CaseStatusScreen> {
  Future<MissingCase>? _data;
  bool _busy = false;
  Object? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= AppServices.of(context).guardian.missingCase(widget.id);
  }

  void _reload() => setState(() {
    _data = AppServices.of(context).guardian.missingCase(widget.id);
  });

  Future<void> _terminate({required bool resolve}) async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await guardianConfirmation(
      context,
      title: resolve ? s.resolveReport : s.cancelReport,
      confirm: resolve ? s.resolveReport : s.cancelReport,
      message: resolve ? s.resolveReportConfirm : s.cancelReportConfirm,
      icon: resolve ? Icons.task_alt : Icons.cancel_outlined,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final guardian = AppServices.of(context).guardian;
      await (resolve
          ? guardian.resolveCase(widget.id)
          : guardian.cancelCase(widget.id));
      if (mounted) _reload();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<MissingCase>(
      future: _data,
      builder: (context, state) {
        final value = state.data;
        return FeaturePage(
          title: s.caseStatus,
          actions: [
            IconButton(
              tooltip: s.retry,
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottomNavigationBar: const GuardianNavigation(selected: 3),
          children: [
            if (state.hasError)
              ErrorNotice(
                message: failureMessage(state.error!, s),
                onRetry: _reload,
              )
            else if (value == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              GuardianPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IndividualPhoto(id: value.individualId, size: 56),
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
                          const SizedBox(height: 4),
                          Text('${s.age}: ${value.age}'),
                          Text(value.id, textDirection: TextDirection.ltr),
                          const SizedBox(height: 8),
                          StatusChip(status: value.status),
                          const SizedBox(height: 8),
                          Text(
                            '${s.lastUpdated}: ${caseDate(context, value.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!value.active) ...[
                GuardianPanel(
                  child: Row(
                    children: [
                      Icon(
                        value.status == 'reunited'
                            ? Icons.celebration_outlined
                            : Icons.info_outline,
                        color: value.status == 'reunited'
                            ? AppColors.secondary
                            : const Color(0xFF718096),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value.status == 'reunited'
                              ? s.reunitedOutcome
                              : s.caseClosedNotice,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              GuardianPanel(
                child: Column(
                  children: [
                    for (var index = 0; index < caseStages.length; index++)
                      _TimelineStep(
                        label: caseStatusLabel(caseStages[index], s),
                        completed: value.stages.containsKey(caseStages[index]),
                        current:
                            value.active && value.status == caseStages[index],
                        timestamp: value.stages[caseStages[index]] == null
                            ? null
                            : caseDate(
                                context,
                                DateTime.tryParse(
                                  value.stages[caseStages[index]].toString(),
                                ),
                              ),
                        isLast: index == caseStages.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (value.active && !value.reportSubmitted)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Navigator.of(context).pushNamed(
                            AppRoutes.guidedReport,
                            arguments: value.id,
                          );
                          if (mounted) _reload();
                        },
                  child: Text(s.reportingAssistant),
                ),
              if (value.active) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _terminate(resolve: true),
                        icon: const Icon(Icons.task_alt),
                        label: Text(s.resolveReport),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _terminate(resolve: false),
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(s.cancelReport),
                      ),
                    ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
              if (_error != null)
                ErrorNotice(message: failureMessage(_error!, s)),
              if (value.report case final report?) ...[
                const SizedBox(height: 24),
                Text(
                  s.caseDetails,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GuardianPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.sameLocationQuestion),
                      Text(report['same_location'] == true ? s.yes : s.no),
                      const SizedBox(height: 16),
                      Text(s.lastSeenDescription),
                      Text(
                        report['same_location'] == true
                            ? '${report['latitude']}, ${report['longitude']}'
                            : report['last_seen_description'].toString(),
                      ),
                      const SizedBox(height: 16),
                      Text(s.clothingQuestion),
                      Text(report['clothing'].toString()),
                      const SizedBox(height: 16),
                      Text(s.distinctiveQuestion),
                      Text(
                        report['carrying_distinctive'] == true
                            ? report['distinctive_description'].toString()
                            : s.no,
                      ),
                      const SizedBox(height: 16),
                      Text(s.additionalQuestion),
                      Text(report['additional_information'].toString()),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.completed,
    required this.current,
    required this.timestamp,
    required this.isLast,
  });
  final String label;
  final bool completed, current;
  final String? timestamp;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    final reached = completed || current;
    final lineColor = completed ? AppColors.secondary : const Color(0xFFE2E8F0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? AppColors.secondary : Colors.white,
                border: Border.all(
                  color: reached
                      ? AppColors.secondary
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : current
                  ? const SizedBox.square(
                      dimension: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary,
                        ),
                      ),
                    )
                  : null,
            ),
            if (!isLast) Container(width: 2, height: 36, color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    color: reached
                        ? AppColors.primary
                        : const Color(0xFF94A3B8),
                  ),
                ),
                if (timestamp != null)
                  Text(
                    timestamp!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF718096),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
