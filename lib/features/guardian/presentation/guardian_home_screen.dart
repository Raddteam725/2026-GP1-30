import 'package:flutter/material.dart';

import '../../../app/app_locale_scope.dart';
import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../core/theme/app_colors.dart';
import 'guardian_components.dart';
import '../data/guardian_push_service.dart';
import '../data/coalesced_refresh.dart';
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
  @override
  void initState() {
    super.initState();
    GuardianPushRefresh.instance.addListener(_recover);
  }

  @override
  void dispose() {
    GuardianPushRefresh.instance.removeListener(_recover);
    super.dispose();
  }

  int _eventGeneration = 0;
  final _eventRefresh = CoalescedRefresh();
  Future<void> _recover() => _eventRefresh.run(_recoverOnce);
  Future<void> _recoverOnce() async {
    if (!mounted) return;
    final generation = ++_eventGeneration;
    try {
      final data = await _load();
      if (!mounted || generation != _eventGeneration) return;
      setState(() {
        _data = Future.value(data);
      });
      assert(() {
        debugPrint(
          'Radd Guardian authoritative refresh T8/T9 ${DateTime.now().toUtc().toIso8601String()}',
        );
        return true;
      }());
    } catch (error) {
      assert(() {
        debugPrint(
          'Radd Guardian background refresh failed (${error.runtimeType})',
        );
        return true;
      }());
    }
  }

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

  void _refresh() => setState(() {
    ++_eventGeneration;
    _revision++;
    _data = _load();
  });

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (mounted) _refresh();
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
    final guardian = AppServices.of(context).guardian;
    final navigator = Navigator.of(context);
    setState(() => _loggingOut = true);
    try {
      // Must happen before signing out -- it needs this Guardian's still-valid
      // ID token to authorize removing this installation's own registration.
      // Never throws, so it can't turn a normal logout into a failed one.
      await GuardianPushService.handleLogout(guardian);
      await auth.logout();
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _logoutError = e);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  /// Language switch for a signed-in Guardian: a bottom sheet over the
  /// Profile tab (same pattern as the Volunteer profile). The new locale is
  /// applied and persisted by AppLocaleScope in place -- the session and
  /// this screen stay exactly where they are; the startup language screen
  /// is never involved.
  Future<void> _chooseLanguage() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) {
      final s = AppLocalizations.of(context)!;
      final current = Localizations.localeOf(context).languageCode;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                s.language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            for (final language in ['ar', 'en'])
              ListTile(
                key: ValueKey('language-$language'),
                title: Text(language == 'ar' ? 'العربية' : 'English'),
                trailing: current == language
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                selected: current == language,
                onTap: () {
                  AppLocaleScope.of(context).setLocale(Locale(language));
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );

  /// The greeting shows the Guardian's first name, large -- per the approved
  /// Home design -- never a fixture or placeholder name.
  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
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
                onRetry: _refresh,
              ),
              // A profile fetch failure must never leave the Guardian stuck
              // on this screen with no way back to the sign-in flow.
              const SizedBox(height: 16),
              if (_logoutError != null)
                ErrorNotice(message: failureMessage(_logoutError!, s)),
              _logoutButton(s),
            ] else if (_tab == 4 && profile != null)
              ..._profileTab(s, profile)
            else if (_tab == 0 && profile != null)
              ..._homeTab(
                s,
                profile,
                people,
                hasUnread,
                caseByIndividual,
                activeCases,
              )
            else
              ..._individualsTab(s, people, caseByIndividual),
          ],
        );
      },
    );
  }

  List<Widget> _homeTab(
    AppLocalizations s,
    GuardianProfile profile,
    List<Individual> people,
    bool hasUnread,
    Map<String, MissingCase> caseByIndividual,
    List<MissingCase> activeCases,
  ) {
    Widget card(Individual person) => HomeIndividualCard(
      individual: person,
      revision: _revision,
      activeCase: caseByIndividual[person.id],
      onTap: () => _open(AppRoutes.individual, arguments: person.id),
      onChanged: _refresh,
    );
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.greetingIntro,
                  style: const TextStyle(color: mutedText, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _firstName(profile.fullName),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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
                  const PositionedDirectional(
                    end: 12,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
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
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.registerHint,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: mutedText,
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
      const SizedBox(height: 28),
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
            label: Text(
              s.viewAll,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (people.isEmpty) const EmptyIndividuals(),
      for (var i = 0; i < people.length; i += 2) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card(people[i])),
            const SizedBox(width: 16),
            Expanded(
              child: i + 1 < people.length
                  ? card(people[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (activeCases.isNotEmpty) ...[
        const SizedBox(height: 12),
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
            style: CaseCardStyle.home,
            actionLabel: s.trackStatus,
            onTap: () => _open(AppRoutes.caseStatus, arguments: value.id),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ];
  }

  List<Widget> _individualsTab(
    AppLocalizations s,
    List<Individual> people,
    Map<String, MissingCase> caseByIndividual,
  ) => [
    Row(
      children: [
        Expanded(
          child: Text(
            s.myIndividuals,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.primary,
            shape: const StadiumBorder(),
          ),
          onPressed: () => _open(AppRoutes.addIndividual),
          icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
          label: Text(
            s.add,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
    const SizedBox(height: 6),
    Text(s.individualsHint, style: const TextStyle(color: mutedText)),
    const SizedBox(height: 20),
    if (people.isEmpty) const EmptyIndividuals(),
    for (final person in people) ...[
      IndividualCard(
        individual: person,
        revision: _revision,
        activeCase: caseByIndividual[person.id],
        onTap: () => _open(AppRoutes.individual, arguments: person.id),
        onChanged: _refresh,
      ),
      const SizedBox(height: 16),
    ],
  ];

  List<Widget> _profileTab(AppLocalizations s, GuardianProfile profile) => [
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
          onPressed: () =>
              _open(AppRoutes.editGuardianProfile, arguments: profile),
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
          _info(s.email, profile.email, Icons.email_outlined, ltr: true),
          const Divider(height: 24),
          _info(s.phone, profile.phone, Icons.phone_outlined, ltr: true),
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
        leading: const Icon(Icons.language, color: AppColors.secondary),
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
        onTap: _chooseLanguage,
      ),
    ),
    const SizedBox(height: 32),
    if (_logoutError != null)
      ErrorNotice(message: failureMessage(_logoutError!, s)),
    _logoutButton(s),
  ];

  Widget _logoutButton(AppLocalizations s) => OutlinedButton.icon(
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
  );

  Widget _info(
    String label,
    String value,
    IconData icon, {
    bool ltr = false,
  }) => Row(
    children: [
      Icon(icon, color: mutedText, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: mutedText)),
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
