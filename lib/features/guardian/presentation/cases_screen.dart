import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';

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

  void _reload() =>
      setState(() => _data = AppServices.of(context).guardian.cases());
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<List<MissingCase>>(
      future: _data,
      builder: (context, state) => FeaturePage(
        title: s.cases,
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
          else if (state.data!.isEmpty) ...[
            const Icon(Icons.folder_outlined, size: 48),
            const SizedBox(height: 24),
            Text(s.noCases, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.noCasesHint, textAlign: TextAlign.center),
          ] else
            for (final value in state.data!) ...[
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
      ),
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
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= AppServices.of(context).guardian.missingCase(widget.id);
  }

  void _reload() => setState(
    () => _data = AppServices.of(context).guardian.missingCase(widget.id),
  );
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
              onPressed: _reload,
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
              Text(
                value.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(value.id, textDirection: TextDirection.ltr),
              const SizedBox(height: 24),
              GuardianPanel(
                child: Column(
                  children: [
                    for (final stage in caseStages)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          stage == value.status
                              ? Icons.radio_button_checked
                              : value.stages.containsKey(stage)
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: value.stages.containsKey(stage)
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: Text(caseStatusLabel(stage, s)),
                        subtitle: value.stages[stage] == null
                            ? null
                            : Text(
                                caseDate(
                                  context,
                                  DateTime.tryParse(
                                    value.stages[stage].toString(),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (value.active)
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context)
                        .pushNamed(AppRoutes.guidedReport, arguments: value.id);
                    if (mounted) _reload();
                  },
                  child: Text(s.reportingAssistant),
                ),
              if (value.report case final report?) ...[
                const SizedBox(height: 24),
                Text(
                  s.guidedDetails,
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
