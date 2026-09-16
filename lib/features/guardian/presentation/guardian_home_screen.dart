import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../core/theme/app_colors.dart';
import 'guardian_components.dart';
import '../data/guardian_repository.dart';
import 'individual_widgets.dart';
import 'case_widgets.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  late int _tab = widget.initialTab;
  int _revision = 0;
  Future<(GuardianProfile, List<Individual>, bool, List<MissingCase>)>? _data;
  bool _loggingOut = false;
  Object? _logoutError;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<(GuardianProfile, List<Individual>, bool, List<MissingCase>)>
  _load() async {
    final repo = AppServices.of(context).guardian;
    final values = await Future.wait<Object>([
      repo.profile(),
      repo.individuals(),
      repo.notifications(),
      repo.cases(),
    ]);
    final notifications = values[2] as List<GuardianNotification>;
    return (
      values[0] as GuardianProfile,
      values[1] as List<Individual>,
      notifications.any((n) => !n.read),
      values[3] as List<MissingCase>,
    );
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (mounted) {
      setState(() {
        _revision++;
        _data = _load();
      });
    }
  }

  Future<void> _logout() async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await guardianConfirmation(
      context,
      title: s.logoutTitle,
      message: s.logoutMessage,
      confirm: s.logout,
      icon: Icons.logout,
    );
    if (confirmed != true || !mounted) return;
    final auth = AppServices.of(context).auth;
    final navigator = Navigator.of(context);
    setState(() => _loggingOut = true);
    try {
      await auth.logout();
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.languageSelection,
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _logoutError = e);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<
      (GuardianProfile, List<Individual>, bool, List<MissingCase>)
    >(
      future: _data,
      builder: (context, state) {
        final profile = state.data?.$1, people = state.data?.$2 ?? [];
        final hasUnread = state.data?.$3 ?? false;
        final cases = state.data?.$4 ?? const <MissingCase>[];
        final activeCases = cases.where((c) => c.active).toList();
        final caseByIndividual = {
          for (final c in activeCases) c.individualId: c,
        };
        return FeaturePage(
          title: _tab == 0
              ? s.home
              : _tab == 1
              ? s.myIndividuals
              : s.profile,
          showAppBar: false,
          bottomNavigationBar: GuardianNavigation(
            selected: _tab,
            onSelected: (i) => setState(() => _tab = i),
            enabled: !_loggingOut,
          ),
          children: [
            if (state.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (state.hasError) ...[
              ErrorNotice(
                message: failureMessage(state.error!, s),
                onRetry: () => setState(() {
                  _data = _load();
                }),
              ),
              // A profile fetch failure must never leave the Guardian stuck
              // on this screen with no way back to the sign-in flow.
              const SizedBox(height: 16),
              if (_logoutError != null)
                ErrorNotice(message: failureMessage(_logoutError!, s)),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: _loggingOut ? null : _logout,
                icon: _loggingOut
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(s.logout),
              ),
            ] else if (_tab == 4 && profile != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.profile,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _open(
                      AppRoutes.editGuardianProfile,
                      arguments: profile,
                    ),
                    child: Text(s.edit),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GuardianSummary(name: profile.fullName),
              const SizedBox(height: 24),
              Text(
                s.accountInformation,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              GuardianPanel(
                child: Column(
                  children: [
                    _info(s.fullName, profile.fullName, Icons.person_outline),
                    const Divider(height: 24),
                    _info(
                      s.email,
                      profile.email,
                      Icons.email_outlined,
                      ltr: true,
                    ),
                    const Divider(height: 24),
                    _info(
                      s.phone,
                      profile.phone,
                      Icons.phone_outlined,
                      ltr: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.language,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              GuardianPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.language,
                    color: AppColors.secondary,
                  ),
                  title: Text(s.language),
                  subtitle: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? s.arabicLanguage
                        : s.englishLanguage,
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  onTap: () =>
                      _open(AppRoutes.languageSelection, arguments: true),
                ),
              ),
              const SizedBox(height: 32),
              if (_logoutError != null)
                ErrorNotice(message: failureMessage(_logoutError!, s)),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: _loggingOut ? null : _logout,
                icon: _loggingOut
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(s.logout),
              ),
            ] else ...[
              if (_tab == 0 && profile != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.greetingIntro,
                            style: const TextStyle(
                              color: Color(0xFF718096),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            tooltip: s.notifications,
                            onPressed: () => _open(AppRoutes.notifications),
                            icon: const Icon(
                              Icons.notifications_none,
                              color: AppColors.primary,
                            ),
                          ),
                          if (hasUnread)
                            const Positioned(
                              right: 12,
                              top: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox.square(dimension: 6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _open(AppRoutes.addIndividual),
                    child: GuardianPanel(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_outlined,
                              color: AppColors.secondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.registerIndividual,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.registerHint,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: Color(0xFF718096),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.individualsTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _tab = 1),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_ios, size: 12),
                      label: Text(s.viewAll),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.myIndividuals,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _open(AppRoutes.addIndividual),
                      icon: const Icon(Icons.add),
                      label: Text(s.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.individualsHint,
                  style: const TextStyle(color: Color(0xFF718096)),
                ),
              ],
              const SizedBox(height: 16),
              if (people.isEmpty) const EmptyIndividuals(),
              for (final person in people) ...[
                IndividualCard(
                  individual: person,
                  revision: _revision,
                  activeCase: caseByIndividual[person.id],
                  onTap: () =>
                      _open(AppRoutes.individual, arguments: person.id),
                  onChanged: () => setState(() {
                    _revision++;
                    _data = _load();
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (_tab == 0 && activeCases.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  s.activeCases,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                for (final value in activeCases) ...[
                  CaseCard(
                    value: value,
                    actionLabel: s.trackStatus,
                    onTap: () =>
                        _open(AppRoutes.caseStatus, arguments: value.id),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _info(
    String label,
    String value,
    IconData icon, {
    bool ltr = false,
  }) => Row(
    children: [
      Icon(icon, color: const Color(0xFF718096), size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(fontSize: 14, color: AppColors.primary),
            ),
          ],
        ),
      ),
    ],
  );
}
