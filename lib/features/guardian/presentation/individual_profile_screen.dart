import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'individual_widgets.dart';
import 'guardian_components.dart';
import 'case_widgets.dart';
import '../../../core/theme/app_colors.dart';

class IndividualProfileScreen extends StatefulWidget {
  const IndividualProfileScreen({super.key, required this.id});
  final String id;
  @override
  State<IndividualProfileScreen> createState() =>
      _IndividualProfileScreenState();
}

class _IndividualProfileScreenState extends State<IndividualProfileScreen> {
  Future<(Individual, MissingCase?)>? _data;
  bool _busy = false;
  Object? _error;
  int _revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<(Individual, MissingCase?)> _load() async {
    final guardian = AppServices.of(context).guardian;
    final person = await guardian.individual(widget.id);
    final activeCaseId = person.activeCaseId;
    final activeCase = activeCaseId == null
        ? null
        : await guardian.missingCase(activeCaseId);
    return (person, activeCase);
  }

  Future<void> _delete(Individual person) async {
    final s = AppLocalizations.of(context)!;
    final yes = await guardianConfirmation(
      context,
      title: s.deleteIndividualTitle,
      message: s.deleteMessage(person.fullName),
      confirm: s.delete,
      icon: Icons.delete_outline,
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).guardian.deleteIndividual(widget.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Individual person) async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.editIndividual, arguments: person);
    if (mounted) {
      setState(() {
        _revision++;
        _data = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: FutureBuilder<(Individual, MissingCase?)>(
        future: _data,
        builder: (context, state) {
          final p = state.data?.$1;
          final activeCase = state.data?.$2;
          final locked = activeCase != null;
          return FeaturePage(
            title: s.individualProfile,
            bottomNavigationBar: GuardianNavigation(
              selected: 1,
              enabled: !_busy,
            ),
            actions: [
              if (p != null && !locked)
                TextButton(
                  onPressed: _busy ? null : () => _edit(p),
                  child: Text(s.edit),
                ),
            ],
            children: [
              if (state.hasError)
                ErrorNotice(
                  message: failureMessage(state.error!, s),
                  onRetry: () => setState(() {
                    _data = _load();
                  }),
                )
              else if (p == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Center(
                  child: IndividualPhoto(
                    id: p.id,
                    size: 144,
                    revision: _revision,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  p.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${s.age}: ${p.age}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF718096)),
                ),
                const SizedBox(height: 32),
                GuardianPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.personalInformation,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _row(s.fullName, p.fullName),
                      const Divider(height: 24),
                      _row(s.age, p.age.toString()),
                      const Divider(height: 24),
                      _row(s.gender, genderLabel(p.gender, s)),
                      const Divider(height: 24),
                      _row(s.relationship, relationshipDisplay(p, s)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ReportMissingAction(
                  individual: p,
                  activeCase: activeCase,
                  onChanged: () => setState(() {
                    _revision++;
                    _data = _load();
                  }),
                ),
                if (locked) ...[
                  const SizedBox(height: 16),
                  GuardianPanel(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Color(0xFF718096),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.activeCaseLockNotice)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: _busy || locked ? null : () => _delete(p),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s.deleteIndividual),
                ),
                if (_busy) const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  ErrorNotice(message: failureMessage(_error!, s)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF718096), fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(color: AppColors.primary, fontSize: 16),
      ),
    ],
  );
}
