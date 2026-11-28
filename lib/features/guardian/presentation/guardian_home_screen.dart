import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
import 'cases_screen.dart';
import 'guardian_qr_screen.dart';

typedef _HomeData = ({
  GuardianProfile profile,
  List<Individual> people,
  bool hasUnread,
  List<MissingCase> cases,
  ActiveEvent? event,
});

enum _HomePart { profile, people, notifications, cases, event }

const _afterIndividual = {
  _HomePart.people,
  _HomePart.notifications,
  _HomePart.cases,
};
const _afterNotifications = {_HomePart.notifications, _HomePart.cases};

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

  final _eventRefresh = CoalescedRefresh();
  Future<void> _recover() => _eventRefresh.run(_recoverOnce);
  Future<void> _recoverOnce() async {
    if (!mounted) return;
    final loaded = await _load(_HomePart.values.toSet(), silent: true);
    assert(() {
      debugPrint(
        loaded
            ? 'Radd Guardian authoritative refresh T8/T9 ${DateTime.now().toUtc().toIso8601String()}'
            : 'Radd Guardian background refresh failed',
      );
      return true;
    }());
  }

  late int _tab = widget.initialTab;
  int? _workspaceTab;
  final _visitedTabs = <int>{};

  void _selectTab(int tab) {
    final returningHome = _workspaceTab != null && tab != 2 && tab != 3;
    setState(() {
      if (tab == 2 || tab == 3) {
        _workspaceTab = tab;
        _visitedTabs.add(tab);
      } else {
        _workspaceTab = null;
        _tab = tab;
      }
    });
    if (returningHome && !_isFresh) {
      _load(const {
        _HomePart.people,
        _HomePart.notifications,
        _HomePart.cases,
      }, silent: true);
    }
  }

  int _revision = 0;
  _HomeData? _home;
  Object? _homeError;
  bool _started = false;
  int _loadSequence = 0, _successSequence = 0;
  final _appliedSequence = <_HomePart, int>{};
  DateTime? _loadedAt;
  bool _loggingOut = false;
  Object? _logoutError;

  bool get _isFresh =>
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) < guardianRevisitFreshness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(_HomePart.values.toSet());
  }

  Future<bool> _load(Set<_HomePart> requested, {bool silent = false}) async {
    final parts = _home == null ? _HomePart.values.toSet() : requested;
    final sequence = ++_loadSequence;
    final repo = AppServices.of(context).guardian;
    Future<Object?> fetch(_HomePart part, Future<Object?> Function() load) =>
        parts.contains(part) ? load() : Future<Object?>.value();
    try {
      final values = await Future.wait<Object?>([
        fetch(_HomePart.profile, repo.profile),
        fetch(_HomePart.people, repo.individuals),
        fetch(_HomePart.notifications, repo.notifications),
        fetch(_HomePart.cases, repo.cases),
        fetch(
          _HomePart.event,
          () => repo.activeEvent().then<ActiveEvent?>(
            (event) => event,
            onError: (Object _) => null,
          ),
        ),
      ]);
      if (!mounted) return false;
      bool take(_HomePart part) {
        if (!parts.contains(part)) return false;
        if ((_appliedSequence[part] ?? 0) > sequence) return false;
        _appliedSequence[part] = sequence;
        return true;
      }

      final current = _home;
      final notifications = values[2] as List<GuardianNotification>?;
      setState(() {
        _home = (
          profile: take(_HomePart.profile)
              ? values[0] as GuardianProfile
              : current!.profile,
          people: take(_HomePart.people)
              ? values[1] as List<Individual>
              : current!.people,
          hasUnread: take(_HomePart.notifications)
              ? notifications!.any((n) => !n.read)
              : current!.hasUnread,
          cases: take(_HomePart.cases)
              ? values[3] as List<MissingCase>
              : current!.cases,
          event: take(_HomePart.event)
              ? values[4] as ActiveEvent?
              : current!.event,
        );
        if (sequence > _successSequence) _successSequence = sequence;
        _homeError = null;
        if (parts.contains(_HomePart.people) &&
            parts.contains(_HomePart.cases)) {
          _loadedAt = DateTime.now();
        }
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      final accessLost = guardianAccessLost(error);
      if (accessLost || (!silent && sequence > _successSequence)) {
        setState(() {
          _homeError = error;
          if (accessLost) _home = null;
        });
      }
      return false;
    }
  }

  void _refresh() {
    setState(() {
      _revision++;
      _homeError = null;
    });
    _load(_HomePart.values.toSet());
  }

  Future<void> _open(
    String route, {
    Object? arguments,
    required Set<_HomePart> refresh,
    bool onlyIfChanged = false,
  }) async {
    final result = await Navigator.of(context)
        .pushNamed(route, arguments: arguments);
    if (!mounted || (onlyIfChanged && result != true)) return;
    if (refresh.contains(_HomePart.people)) setState(() => _revision++);
    _load(refresh);
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

  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _workspaceTab == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _workspaceTab != null) _selectTab(_tab);
      },
      child: Scaffold(
        bottomNavigationBar: GuardianNavigation(
          selected: _workspaceTab ?? _tab,
          onSelected: _selectTab,
          enabled: !_loggingOut,
        ),
        body: IndexedStack(
          index: switch (_workspaceTab) {
            3 => 1,
            2 => 2,
            _ => 0,
          },
          children: [
            TickerMode(
              enabled: _workspaceTab == null,
              child: _buildHome(context),
            ),
            if (_visitedTabs.contains(3))
              TickerMode(
                enabled: _workspaceTab == 3,
                child: CasesScreen(embedded: true, active: _workspaceTab == 3),
              )
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(2))
              TickerMode(
                enabled: _workspaceTab == 2,
                child: GuardianQrScreen(
                  embedded: true,
                  active: _workspaceTab == 2,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final data = _home;
    final profile = data?.profile, people = data?.people ?? [];
    final hasUnread = data?.hasUnread ?? false;
    final cases = data?.cases ?? const <MissingCase>[];
    final event = data?.event;
    final activeCases = cases.where((c) => c.active).toList();
    final caseByIndividual = {for (final c in activeCases) c.individualId: c};
    return FeaturePage(
      title: _tab == 0
          ? s.home
          : _tab == 1
          ? s.myIndividuals
          : s.profile,
      showAppBar: false,
      children: [
        if (data == null && _homeError == null)
          const Center(child: CircularProgressIndicator())
        else if (data == null) ...[
          ErrorNotice(
            message: failureMessage(_homeError!, s),
            onRetry: _refresh,
          ),
          const SizedBox(height: 16),
          if (_logoutError != null)
            ErrorNotice(message: failureMessage(_logoutError!, s)),
          _logoutButton(s),
        ] else ...[
          if (_homeError != null) ...[
            ErrorNotice(
              message: failureMessage(_homeError!, s),
              onRetry: _refresh,
            ),
            const SizedBox(height: 16),
          ],
          if (_tab == 4 && profile != null)
            ..._profileTab(s, profile)
          else if (_tab == 0 && profile != null)
            ..._homeTab(
              s,
              profile,
              people,
              hasUnread,
              caseByIndividual,
              activeCases,
              event,
            )
          else
            ..._individualsTab(s, people, caseByIndividual),
        ],
      ],
    );
  }

  List<Widget> _homeTab(
    AppLocalizations s,
    GuardianProfile profile,
    List<Individual> people,
    bool hasUnread,
    Map<String, MissingCase> caseByIndividual,
    List<MissingCase> activeCases,
    ActiveEvent? event,
  ) {
    Widget card(Individual person) => HomeIndividualCard(
      individual: person,
      revision: _revision,
      activeCase: caseByIndividual[person.id],
      onTap: () => _open(
        AppRoutes.individual,
        arguments: person.id,
        refresh: _afterIndividual,
      ),
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
                  onPressed: () => _open(
                    AppRoutes.notifications,
                    refresh: _afterNotifications,
                  ),
                  icon: const Icon(
                    Icons.notifications_none,
                    color: AppColors.primary,
                  ),
                ),
                if (hasUnread)
                  const PositionedDirectional(
                    key: ValueKey('guardian-notification-dot'),
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
      const SizedBox(height: 20),
      _eventCard(s, event),
      const SizedBox(height: 20),
      Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(
            AppRoutes.addIndividual,
            refresh: _afterIndividual,
            onlyIfChanged: true,
          ),
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
            onTap: () => _open(
              AppRoutes.caseStatus,
              arguments: value.id,
              refresh: _afterIndividual,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ];
  }

  Widget _eventCard(AppLocalizations s, ActiveEvent? event) {
    final locale = Localizations.localeOf(context).languageCode;
    String day(DateTime value) =>
        DateFormat.yMMMd(locale).format(value.toLocal());
    if (event == null) {
      return GuardianPanel(
        key: const ValueKey('home-event-unavailable'),
        child: Row(
          children: [
            const Icon(Icons.event_busy_outlined, color: mutedText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.eventUnavailable,
                style: const TextStyle(fontSize: 13, color: mutedText),
              ),
            ),
          ],
        ),
      );
    }
    return GuardianPanel(
      key: const ValueKey('home-event'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event, color: AppColors.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.currentEvent,
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
                const SizedBox(height: 2),
                Text(
                  event.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty)
                  Text(
                    event.location!,
                    style: const TextStyle(fontSize: 13, color: mutedText),
                  ),
                if (event.startsAt != null && event.endsAt != null)
                  Text(
                    s.eventDates(day(event.startsAt!), day(event.endsAt!)),
                    style: const TextStyle(fontSize: 13, color: mutedText),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
          onPressed: () => _open(
            AppRoutes.addIndividual,
            refresh: _afterIndividual,
            onlyIfChanged: true,
          ),
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
        onTap: () => _open(
          AppRoutes.individual,
          arguments: person.id,
          refresh: _afterIndividual,
        ),
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
          onPressed: () => _open(
            AppRoutes.editGuardianProfile,
            arguments: profile,
            refresh: const {_HomePart.profile},
            onlyIfChanged: true,
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
    const SizedBox(height: 12),
    OutlinedButton.icon(
      key: const ValueKey('guardian-delete-account'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
      ),
      onPressed: _loggingOut ? null : _deleteAccount,
      icon: const Icon(Icons.delete_outline),
      label: Text(s.deleteAccount),
    ),
  ];

  Future<void> _deleteAccount() async {
    final s = AppLocalizations.of(context)!;
    await guardianConfirmation(
      context,
      title: s.deleteAccount,
      confirm: s.deleteAccount,
      message: s.deleteAccountConfirm,
      icon: Icons.delete_outline,
      onConfirm: () {},
    );
  }

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
