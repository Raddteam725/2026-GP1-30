import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_locale_scope.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../data/mock_volunteer_repository.dart';
import '../data/volunteer_location.dart';
import '../data/volunteer_repository.dart';
import '../domain/volunteer_models.dart';
import 'volunteer_components.dart';

part 'volunteer_case_views.dart';
part 'volunteer_identification_views.dart';
part 'volunteer_account_views.dart';

enum VolunteerView {
  home,
  cases,
  report,
  badge,
  profile,
  notifications,
  caseDetails,
  finding,
  matches,
  manual,
  matchDetails,
  contact,
  verify,
  identifier,
  verificationFailed,
  verified,
  handover,
  reunited,
}

class VolunteerWorkspace extends StatefulWidget {
  const VolunteerWorkspace({
    super.key,
    required this.account,
    required this.repository,
    required this.onLogout,
  });
  final VolunteerAccount account;
  final VolunteerRepository repository;
  final Future<void> Function() onLogout;
  @override
  State<VolunteerWorkspace> createState() => _VolunteerWorkspaceState();
}

class _VolunteerWorkspaceState extends State<VolunteerWorkspace> {
  final List<VolunteerView> _stack = [VolunteerView.home];
  int _tab = 0, _searchGeneration = 0;
  bool _mine = false,
      _priorityOnly = false,
      _busy = false,
      _authenticatedShown = false;
  Gender? _gender;
  final _search = TextEditingController(),
      _identifier = TextEditingController();
  final _identifierForm = GlobalKey<FormState>();
  VolunteerCase? _case;
  RegisteredPerson? _person;
  FoundReport? _report;
  List<MatchCandidate> _candidates = [];
  double? _similarity;
  VolunteerLocation? _location;
  VolunteerRepository get repo => widget.repository;
  VolunteerAccount get account => widget.account;
  AppLocalizations get s => stringsOf(context);
  VolunteerView get view => _stack.last;
  Coordinates? get location => repo.isPreview
      ? MockVolunteerRepository.previewLocation
      : _location?.coordinates;
  @override
  void initState() {
    super.initState();
    repo.addListener(_refresh);
    if (!repo.isPreview) {
      _location = VolunteerLocation()..addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  @override
  void dispose() {
    ++_searchGeneration;
    repo.removeListener(_refresh);
    _location?.dispose();
    _search.dispose();
    _identifier.dispose();
    super.dispose();
  }

  void _open(VolunteerView page) {
    _update(() => _stack.add(page));
  }

  void _replace(VolunteerView page) {
    _update(() => _stack[_stack.length - 1] = page);
  }

  void _back() {
    if (_busy) return;
    ++_searchGeneration;
    if (_stack.length > 1) {
      _update(() => _stack.removeLast());
    } else {
      _selectTab(0);
    }
  }

  void _selectTab(int tab) {
    if (_busy) return;
    ++_searchGeneration;
    _update(() {
      _tab = tab;
      _stack
        ..clear()
        ..add(VolunteerView.values[tab]);
    });
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _update(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _message(s.vActionFailed);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  void _details(VolunteerCase item) {
    _case = item;
    _open(VolunteerView.caseDetails);
  }

  bool _isNearby(VolunteerCase item) =>
      item.joinable &&
      location != null &&
      item.information?.coordinates != null &&
      location!.distanceTo(item.information!.coordinates!) <= 500;
  Future<bool> _confirm(String title, String message, String action) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: volunteerNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.vCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ).then((value) => value ?? false);
  String get _title => switch (view) {
    VolunteerView.home => s.vApp,
    VolunteerView.cases => s.vCases,
    VolunteerView.report => s.vReportFound,
    VolunteerView.badge => s.vDigitalId,
    VolunteerView.profile => s.vProfile,
    VolunteerView.notifications => s.vNotifications,
    VolunteerView.caseDetails => s.vCaseDetails,
    VolunteerView.finding => s.vFinding,
    VolunteerView.matches => s.vPotentialMatches,
    VolunteerView.manual => s.vManualReview,
    VolunteerView.matchDetails => s.vMatchDetails,
    VolunteerView.contact => s.vGuardianContact,
    VolunteerView.verify => s.vVerifyGuardian,
    VolunteerView.identifier => s.vVerifyIdentifier,
    VolunteerView.verificationFailed => s.vVerificationFailed,
    VolunteerView.verified => s.vGuardianVerified,
    VolunteerView.handover => s.vConfirmHandover,
    VolunteerView.reunited => s.vReunited,
  };
  @override
  Widget build(BuildContext context) {
    final roots = [s.vHome, s.vCases, s.vReport, s.vBadge, s.vProfile];
    final icons = [
      Icons.home_outlined,
      Icons.folder_open_outlined,
      Icons.add_circle_outline,
      Icons.badge_outlined,
      Icons.person_outline,
    ];
    return PopScope(
      canPop: _stack.length == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: volunteerCanvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: _stack.length > 1
              ? BackButton(onPressed: _busy ? null : _back)
              : null,
          title: Text(
            _title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: volunteerNavy,
            ),
          ),
          actions: _stack.length == 1
              ? [
                  VolunteerBell(
                    onPressed: () => _open(VolunteerView.notifications),
                    hasAlerts: repo.alertsFor(account.uid).isNotEmpty,
                  ),
                ]
              : null,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFBCF7FC),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? volunteerNavy
                  : const Color(0xFF434652),
            ),
          ),
          destinations: [
            for (var i = 0; i < 5; i++)
              NavigationDestination(
                icon: Icon(icons[i], color: volunteerNavy),
                label: roots[i],
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (repo.isPreview)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF8E4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    s.vPreview,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF84600A),
                    ),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      key: ValueKey(view),
                      padding: const EdgeInsets.all(20),
                      children: _content(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content() => switch (view) {
    VolunteerView.home => _home(),
    VolunteerView.cases => _cases(),
    VolunteerView.caseDetails => _caseDetails(),
    VolunteerView.notifications => _notifications(),
    VolunteerView.report => _reportView(),
    VolunteerView.finding => _finding(),
    VolunteerView.matches => _matches(),
    VolunteerView.manual => _manual(),
    VolunteerView.matchDetails => _matchDetails(),
    VolunteerView.contact => _contact(),
    VolunteerView.verify => _verify(),
    VolunteerView.identifier => _identifierView(),
    VolunteerView.verificationFailed => _failed(),
    VolunteerView.verified => _verified(),
    VolunteerView.handover => _handover(),
    VolunteerView.reunited => _reunited(),
    VolunteerView.badge => _badge(),
    VolunteerView.profile => _profile(),
  };
}
