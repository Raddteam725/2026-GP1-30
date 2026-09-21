import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_case_events.dart';
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
  // The latest authoritative list from an event-driven (push/resume) refetch;
  // takes precedence over the initial/explicit future so the list updates
  // in place without a loading flash, and is kept if a refetch fails.
  List<MissingCase>? _live;
  final _sync = CoalescedRefresh('cases');
  @override
  void initState() {
    super.initState();
    GuardianCaseEvents.instance.addListener(_onEvent);
  }

  @override
  void dispose() {
    GuardianCaseEvents.instance.removeListener(_onEvent);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= AppServices.of(context).guardian.cases();
  }

  void _onEvent() {
    final event = GuardianCaseEvents.instance.last;
    if (event == null || !mounted) return;
    final guardian = AppServices.of(context).guardian;
    _sync.run(() async {
      final value = await guardian.cases();
      if (mounted) setState(() => _live = value);
    });
    if (event.source == GuardianEventSource.push &&
        event.caseId != null &&
        event.status != null) {
      showCaseUpdateNotice(
        context,
        caseId: event.caseId!,
        status: event.status!,
      );
    }
  }

  void _reload() => setState(() {
    _live = null;
    _data = AppServices.of(context).guardian.cases();
  });

  Future<void> _openStatus(MissingCase value) async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.caseStatus, arguments: value.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<List<MissingCase>>(
      future: _data,
      builder: (context, state) {
        final loaded = _live ?? state.data;
        final cases = loaded ?? const <MissingCase>[];
        // Only non-terminal cases are Active; closed ones are history and
        // never counted or mixed into the active section.
        final active = cases.where((c) => c.active).toList();
        final closed = cases.where((c) => !c.active).toList();
        return FeaturePage(
          title: s.cases,
          showAppBar: false,
          bottomNavigationBar: widget.embedded
              ? null
              : const GuardianNavigation(selected: 3),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.cases,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.casesSubtitle,
                        style: const TextStyle(color: mutedText, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: s.retry,
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (state.hasError && loaded == null)
              ErrorNotice(
                message: failureMessage(state.error!, s),
                onRetry: _reload,
              )
            else if (loaded == null)
              const Center(child: CircularProgressIndicator())
            else if (cases.isEmpty)
              GuardianPanel(
                child: Column(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 40,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.noCases,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.noCasesHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: mutedText),
                    ),
                  ],
                ),
              )
            else ...[
              _SectionHeading(label: s.activeCases, count: active.length),
              const SizedBox(height: 16),
              if (active.isEmpty)
                GuardianPanel(
                  child: Text(
                    s.noActiveCasesHint,
                    style: const TextStyle(color: mutedText),
                  ),
                ),
              for (final value in active) ...[
                CaseCard(value: value, onTap: () => _openStatus(value)),
                const SizedBox(height: 16),
              ],
              if (closed.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeading(label: s.caseHistory, count: closed.length),
                const SizedBox(height: 16),
                for (final value in closed) ...[
                  CaseCard(value: value, onTap: () => _openStatus(value)),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SectionLabel(label, color: AppColors.primary, fontSize: 14),
      const SizedBox(width: 10),
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class CaseStatusScreen extends StatefulWidget {
  const CaseStatusScreen({super.key, required this.id});
  final String id;
  @override
  State<CaseStatusScreen> createState() => _CaseStatusScreenState();
}

// The case-status screen reflects Volunteer-driven progress (stage changes,
// guardian-verification requests) without the Guardian doing anything: the
// NORMAL path is the backend's FCM signal for this case (GuardianCaseEvents),
// answered by an immediate authoritative refetch. The quiet poll below is a
// FALLBACK only -- for a missed/delayed push -- so it is deliberately slow,
// restarted after every event-driven refetch (it never fires right behind
// one), coalesced with it (never a parallel request), and stopped once the
// case is terminal. Radd talks to the backend only through the REST API (no
// client-side Firestore listener), so the push signal + refetch is the
// contract-compliant real-time path.
const _fallbackPollInterval = Duration(seconds: 30);

class _CaseStatusScreenState extends State<CaseStatusScreen> {
  Future<MissingCase>? _data;
  MissingCase? _live;
  bool _busy = false;
  Object? _error;
  Timer? _poll;
  final _sync = CoalescedRefresh('case-status');
  @override
  void initState() {
    super.initState();
    GuardianCaseEvents.instance.addListener(_onEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= AppServices.of(context).guardian.missingCase(widget.id)
      ..then(_onLoaded);
  }

  void _onLoaded(MissingCase value) {
    if (!mounted) return;
    _live = value;
    _startPolling();
  }

  // Only an event about THIS case (or a case-less recovery/generic signal)
  // triggers a refetch; the push payload is never used for the state itself.
  void _onEvent() {
    final event = GuardianCaseEvents.instance.last;
    if (event == null || !mounted || !event.concerns(widget.id)) return;
    _refreshNow();
  }

  Future<void> _refreshNow() {
    _restartPolling();
    return _sync.run(_fetch);
  }

  void _startPolling() {
    if (_live?.active == false) return; // Terminal: nothing left to watch.
    _poll ??= Timer.periodic(_fallbackPollInterval, (_) => _sync.run(_fetch));
  }

  void _restartPolling() {
    if (_poll == null) return;
    _poll!.cancel();
    _poll = null;
    _startPolling();
  }

  Future<void> _fetch() async {
    if (_busy) return; // Never race a Guardian-initiated action's own reload.
    // A transient failure here is swallowed by CoalescedRefresh: it must not
    // surface as an error banner over an otherwise-fine screen, and the last
    // valid state stays; the next signal/tick (or manual refresh) retries.
    final value = await AppServices.of(context).guardian.missingCase(widget.id);
    if (!mounted) return;
    setState(() => _live = value);
    if (!value.active) {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _reload() => setState(() {
    _data = AppServices.of(context).guardian.missingCase(widget.id)
      ..then(_onLoaded);
  });

  @override
  void dispose() {
    _poll?.cancel();
    GuardianCaseEvents.instance.removeListener(_onEvent);
    super.dispose();
  }

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
        final value = _live ?? state.data;
        return FeaturePage(
          title: s.caseStatus,
          centerTitle: false,
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
              _summary(s, value),
              const SizedBox(height: 20),
              _timeline(s, value),
              const SizedBox(height: 20),
              if (value.active && !value.reportSubmitted) ...[
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Navigator.of(context).pushNamed(
                            AppRoutes.guidedReport,
                            arguments: value.id,
                          );
                          if (mounted) _reload();
                        },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(s.reportingAssistant),
                ),
                const SizedBox(height: 16),
              ],
              if (value.active) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _terminate(resolve: true),
                        icon: const Icon(Icons.task_alt, size: 20),
                        label: Text(s.resolveReport),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _terminate(resolve: false),
                        icon: const Icon(Icons.cancel_outlined, size: 20),
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
                const SizedBox(height: 20),
              ],
              if (_error != null)
                ErrorNotice(message: failureMessage(_error!, s)),
              _details(s, value),
            ],
          ],
        );
      },
    );
  }

  Widget _summary(AppLocalizations s, MissingCase value) => GuardianPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IndividualPhoto(id: value.individualId, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.age}: ${s.ageYears('${value.age}')}',
                    style: const TextStyle(color: mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Real identifiers are long; the chip wraps to its own
                      // line rather than squeezing the name.
                      CaseIdChip(id: value.id),
                      StatusChip(status: value.status),
                      Text(
                        caseDate(context, value.updatedAt),
                        style: const TextStyle(color: mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        if (value.active)
          Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF2E9E6E),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 7),
              ),
              const SizedBox(width: 8),
              Text(
                s.statusUpdatesAutomatically,
                style: const TextStyle(color: mutedText, fontSize: 13),
              ),
            ],
          )
        else
          Row(
            children: [
              Icon(
                value.status == 'reunited'
                    ? Icons.celebration_outlined
                    : Icons.info_outline,
                size: 20,
                color: value.status == 'reunited'
                    ? AppColors.secondary
                    : mutedText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.status == 'reunited'
                      ? s.reunitedOutcome
                      : s.caseClosedNotice,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _timeline(AppLocalizations s, MissingCase value) {
    // A terminal outcome that is not itself the fifth stage (resolved,
    // cancelled, transferred) is shown as its own clearly-labelled branch at
    // the end -- never as if Stage 5 "Reunited" had happened.
    final outcome = !value.active && value.status != 'reunited';
    final currentIndex = caseStages.indexOf(value.status);
    return GuardianPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(s.progressTimeline),
          const SizedBox(height: 20),
          for (var index = 0; index < caseStages.length; index++)
            _TimelineStep(
              number: index + 1,
              color: caseStatusColor(caseStages[index]),
              title: caseStatusLabel(caseStages[index], s),
              state:
                  value.stages.containsKey(caseStages[index]) &&
                      !(value.active && index == currentIndex)
                  ? _StepState.completed
                  : value.active && index == currentIndex
                  ? _StepState.current
                  : _StepState.upcoming,
              timestamp: value.stages[caseStages[index]] == null
                  ? null
                  : caseDate(
                      context,
                      DateTime.tryParse(
                        value.stages[caseStages[index]].toString(),
                      ),
                    ),
              description: value.active && index == currentIndex
                  ? caseStageDescription(caseStages[index], s)
                  : null,
              isLast: index == caseStages.length - 1 && !outcome,
            ),
          if (outcome)
            _TimelineStep(
              number: null,
              color: caseStatusColor(value.status),
              title: caseStatusLabel(value.status, s),
              state: _StepState.outcome,
              timestamp: caseDate(context, value.updatedAt),
              description: s.caseClosedNotice,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _details(AppLocalizations s, MissingCase value) {
    final report = value.report;
    String text(Object? v) => (v?.toString() ?? '').trim();
    final rows = <(String, String)>[];
    if (report != null && value.reportSubmitted) {
      rows.add((
        s.lastSeenLocationLabel,
        report['same_location'] == true
            ? s.currentLocationConfirmed
            : text(report['last_seen_description']),
      ));
      rows.add((s.clothingLabel, text(report['clothing'])));
      rows.add((
        s.distinctiveLabel,
        report['carrying_distinctive'] == true
            ? text(report['distinctive_description'])
            : s.none,
      ));
      final additional = text(report['additional_information']);
      rows.add((s.additionalLabel, additional.isEmpty ? s.none : additional));
    }
    return GuardianPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(s.caseDetails),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(s.detailsPending, style: const TextStyle(color: mutedText))
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(color: mutedText, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

enum _StepState { completed, current, upcoming, outcome }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.number,
    required this.color,
    required this.title,
    required this.state,
    required this.timestamp,
    required this.description,
    required this.isLast,
  });
  final int? number;

  /// The stage's own semantic status colour (see caseStatusColor); only
  /// reached steps paint with it, upcoming steps stay muted.
  final Color color;
  final String title;
  final _StepState state;
  final String? timestamp;
  final String? description;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final current = state == _StepState.current;
    final completed = state == _StepState.completed;
    final outcome = state == _StepState.outcome;
    final reached = completed || current || outcome;
    final lineColor = completed ? color : AppColors.border;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed || current ? color : Colors.white,
                border: Border.all(
                  color: reached ? color : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : current
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: SizedBox.square(dimension: 10),
                    )
                  : outcome
                  ? Icon(Icons.flag_outlined, size: 14, color: color)
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFCBD5E1),
                      ),
                      child: SizedBox.square(dimension: 8),
                    ),
            ),
            if (!isLast) Container(width: 2, height: 32, color: lineColor),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        number == null
                            ? s.outcomeLabel.toUpperCase()
                            : s.stageLabel('$number').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          color: current ? AppColors.primary : mutedText,
                        ),
                      ),
                    ),
                    if (current)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.activeLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (timestamp != null && reached)
                      Text(
                        timestamp!,
                        style: const TextStyle(fontSize: 11, color: mutedText),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: current || outcome ? 17 : 15,
                    fontWeight: current || outcome
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: reached
                        ? AppColors.primary
                        : const Color(0xFF94A3B8),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      description!,
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
