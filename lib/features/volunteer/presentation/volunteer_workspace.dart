import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import 'volunteer_capture.dart';
import 'volunteer_consent_screen.dart';
import 'volunteer_notification_banner.dart';
import '../domain/volunteer_notification_event.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/app_locale_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../guardian/presentation/guardian_components.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../data/mock_volunteer_repository.dart';
import '../data/api_volunteer_repository.dart';
import '../data/volunteer_location.dart';
import '../data/volunteer_push_service.dart';
import '../data/volunteer_repository.dart';
import '../domain/volunteer_models.dart';
import 'volunteer_components.dart';

part 'volunteer_case_views.dart';
part 'volunteer_identification_views.dart';
part 'volunteer_account_views.dart';

enum IdentificationState {
  ready,
  processing,
  candidates,
  noReliableCandidate,
  unavailable,
  error,
}

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
    this.notificationEvents,
  });
  final Stream<VolunteerNotificationEvent>? notificationEvents;
  final VolunteerAccount account;
  final VolunteerRepository repository;
  final Future<void> Function() onLogout;
  @override
  State<VolunteerWorkspace> createState() => _VolunteerWorkspaceState();
}

class _VolunteerWorkspaceState extends State<VolunteerWorkspace>
    with WidgetsBindingObserver {
  Timer? _poll;
  VolunteerPushService? _push;
  bool _refreshing = false, _refreshAgain = false;
  final _noticeDedup = VolunteerNotificationDeduplicator();
  final _notices = <VolunteerNotificationEvent>[];
  StreamSubscription<VolunteerNotificationEvent>? _noticeSubscription;
  OverlayEntry? _noticeOverlay;
  VolunteerNotificationEvent? _pendingNotificationOpen;
  IdentificationState _identificationState = IdentificationState.ready;
  bool _independentReview = false;
  Uint8List? _pendingCapture;
  String? _captureRequestId;
  String? _manualRequestId;
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
  VolunteerAccount get account =>
      (repo is ApiVolunteerRepository
          ? (repo as ApiVolunteerRepository).account
          : null) ??
      widget.account;
  AppLocalizations get s => stringsOf(context);
  VolunteerView get view => _stack.last;
  Coordinates? get location => repo.isPreview
      ? MockVolunteerRepository.previewLocation
      : _location?.coordinates;
  @override
  void initState() {
    super.initState();
    repo.addListener(_refresh);
    _noticeSubscription = widget.notificationEvents?.listen(
      _receiveNotification,
    );
    if (repo is ApiVolunteerRepository) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _push = VolunteerPushService(
          repo as ApiVolunteerRepository,
          onNotification: _receiveNotification,
          onOpen: _openNotification,
          onAccessChanged: _checkParticipation,
        );
        _push!.setLocationAccess(_location?.accessGranted == true);
        unawaited(
          _push!.initialize(Localizations.localeOf(context).languageCode),
        );
        _syncParticipation();
        _loadRemote();
      });
      _poll = Timer.periodic(const Duration(seconds: 20), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed ||
            _location?.continuesInBackground == true) {
          _loadRemote();
        }
      });
    }
  }

  bool _configuringLocation = false;
  bool _hadLocationAccess = false;
  void _closeProtectedRoutes() {
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null && route.isActive) {
        Navigator.of(context)
            .popUntil((candidate) => identical(candidate, route));
      }
    });
  }

  bool _checkingAccess = false;
  Future<void> _checkParticipation() async {
    if (_checkingAccess || !mounted || repo is! ApiVolunteerRepository) return;
    _checkingAccess = true;
    try {
      await (repo as ApiVolunteerRepository).loadProfile();
      if (mounted) {
        _syncParticipation();
        unawaited(_loadRemote(event: true));
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd participation refresh: ${error.runtimeType}');
      }
    } finally {
      _checkingAccess = false;
    }
  }

  String? _participationEventId;
  void _syncParticipation() {
    if (!mounted || repo is! ApiVolunteerRepository) return;
    if (!(repo as ApiVolunteerRepository).consentCurrent ||
        (repo as ApiVolunteerRepository).account == null ||
        !account.eventAuthorized ||
        (_participationEventId != null &&
            _participationEventId != account.eventId)) {
      final previous = _location;
      if (_participationEventId != null) _closeProtectedRoutes();
      _hadLocationAccess = false;
      _location = null;
      previous?.dispose();
      _push?.setLocationAccess(false);
      _case = null;
      _person = null;
      _report?.photoBytes = null;
      _report = null;
      _pendingCapture = null;
      _candidates = [];
      _participationEventId = null;
      if (view != VolunteerView.profile && view != VolunteerView.badge) {
        _tab = 0;
        _stack
          ..clear()
          ..add(VolunteerView.home);
      }
      if (!(repo as ApiVolunteerRepository).consentCurrent ||
          (repo as ApiVolunteerRepository).account == null ||
          !account.eventAuthorized) {
        return;
      }
    }
    _participationEventId = account.eventId;
    if (_location == null) {
      final service = VolunteerLocation();
      _location = service;
      service.addListener(() {
        if (!mounted || !identical(_location, service)) return;
        if (_hadLocationAccess && !service.accessGranted) {
          _notices.clear();
          _dismissNotice();
          _closeProtectedRoutes();
        }
        final gainedAccess = !_hadLocationAccess && service.accessGranted;
        _hadLocationAccess = service.accessGranted;
        setState(() {});
        _push?.setLocationAccess(
          account.eventAuthorized && service.accessGranted,
        );
        _push?.sync(Localizations.localeOf(context).languageCode, location);
        _syncParticipation();
        if (gainedAccess && !_refreshing) unawaited(_loadRemote(event: true));
      });
      unawaited(service.initialize(askPermissionOnFirstUse: false));
    }
    final service = _location!;
    if (service.accessGranted &&
        !service.continuesInBackground &&
        !_configuringLocation &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _configuringLocation = true;
      unawaited(
        service
            .authorizeBackgroundParticipation(
              title: s.vLocationServiceTitle,
              description: s.vLocationServiceBody,
              channelName: s.vLocationServiceChannel,
            )
            .whenComplete(() => _configuringLocation = false),
      );
    }
  }

  Future<void> _loadRemote({bool event = false}) async {
    if (!mounted || repo is! ApiVolunteerRepository) return;
    if (_refreshing) {
      if (event) _refreshAgain = true;
      return;
    }
    setState(() => _refreshing = true);
    try {
      await _location?.request(askPermission: false);
      await (repo as ApiVolunteerRepository).loadProfile();
      if (!mounted) return;
      _syncParticipation();
      if (_canParticipate) {
        await (repo as ApiVolunteerRepository).refresh();
        final previous = _report;
        final refreshView = view;
        if (previous != null &&
            !_independentReview &&
            !_busy &&
            const {
              VolunteerView.matches,
              VolunteerView.finding,
              VolunteerView.manual,
              VolunteerView.matchDetails,
              VolunteerView.contact,
              VolunteerView.verify,
              VolunteerView.identifier,
              VolunteerView.verified,
              VolunteerView.handover,
              VolunteerView.verificationFailed,
            }.contains(view)) {
          final current = await (repo as ApiVolunteerRepository).loadReport(
            previous.id,
          );
          if (mounted &&
              identical(_report, previous) &&
              !_busy &&
              !_independentReview &&
              view == refreshView) {
            if (current.foundStatus != previous.foundStatus ||
                (current.verification != null) !=
                    (previous.verification != null)) {
              _restoreReport(current);
            } else {
              _report = current;
              _person = current.matchedPerson ?? _person;
            }
          }
        }
      }
      if (mounted) {
        _syncParticipation();
        _push?.sync(Localizations.localeOf(context).languageCode, location);
      }
    } catch (_) {
      // Keep the existing screen with an explicit retry; never populate fixtures.
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        if (_refreshAgain) {
          _refreshAgain = false;
          unawaited(_loadRemote(event: true));
        }
      }
    }
  }

  void _receiveNotification(VolunteerNotificationEvent event) {
    if (!mounted || !_canParticipate || !_noticeDedup.accept(event)) return;
    // A newly arriving important event is visible immediately, even if the
    // previous banner was not dismissed. Both remain in server-side history.
    _noticeOverlay?.remove();
    _noticeOverlay?.dispose();
    _noticeOverlay = null;
    _notices
      ..clear()
      ..add(event);
    _showNotice();
    // Display immediately; targeted authenticated lists/history reconcile the
    // event without waiting for a full workspace refresh or device registration.
    unawaited(_refreshEvent(event));
  }

  Future<void> _refreshEvent(VolunteerNotificationEvent event) async {
    if (!_canParticipate) return;
    if (kDebugMode) {
      debugPrint(
        'Radd event ${event.id} T6/T7 ${DateTime.now().toUtc().toIso8601String()}',
      );
    }
    if (repo is! ApiVolunteerRepository) return;
    try {
      await (repo as ApiVolunteerRepository).refreshEvent(caseId: event.caseId);
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint(
          'Radd event ${event.id} T8 ${DateTime.now().toUtc().toIso8601String()}',
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && kDebugMode) {
          debugPrint(
            'Radd event ${event.id} T9 ${DateTime.now().toUtc().toIso8601String()}',
          );
        }
      });
      setState(() {});
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd event refresh failed (${error.runtimeType})');
      }
    }
  }

  void _showNotice() {
    if (_noticeOverlay != null || _notices.isEmpty || !mounted) return;
    final event = _notices.first;
    _noticeOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: 0,
        left: 16,
        right: 16,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: VolunteerNotificationBanner(
                event: event,
                onDismiss: _dismissNotice,
                onOpen: () {
                  _dismissNotice();
                  _openNotification(event);
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_noticeOverlay!);
  }

  void _dismissNotice() {
    _noticeOverlay?.remove();
    _noticeOverlay?.dispose();
    _noticeOverlay = null;
    if (_notices.isNotEmpty) _notices.removeAt(0);
    _showNotice();
  }

  String? _openingNotification;

  void _openNotification(VolunteerNotificationEvent event) {
    if (!mounted ||
        _openingNotification == event.id ||
        (view == VolunteerView.caseDetails && _case?.id == event.caseId)) {
      return;
    }
    if (_busy) {
      _pendingNotificationOpen = event;
      return;
    }
    // Return from a camera/QR route only on an explicit notification action.
    // This never ends a Found Report or confirms a handover.
    final workspaceRoute = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == workspaceRoute);
    if (!event.opensCase) {
      if (view != VolunteerView.notifications) {
        _open(VolunteerView.notifications);
      }
      _message(volunteerAlertMessage(s, event.kind));
      unawaited(_loadRemote(event: true));
      return;
    }
    _openingNotification = event.id;
    _run(() async {
      try {
        final item = repo is ApiVolunteerRepository
            ? await (repo as ApiVolunteerRepository).loadCase(event.caseId)
            : repo.caseById(event.caseId);
        if (!mounted) return;
        if (item == null || !item.joinable) {
          await _notificationUnavailable(event);
          return;
        }
        _case = item;
        _open(VolunteerView.caseDetails);
      } on StateError catch (error) {
        if (error.message != 'not-found') rethrow;
        await _notificationUnavailable(event);
      } finally {
        _openingNotification = null;
      }
    });
  }

  Future<void> _notificationUnavailable(
    VolunteerNotificationEvent event,
  ) async {
    await _loadRemote(event: true);
    if (!mounted) return;
    if (view != VolunteerView.notifications) _open(VolunteerView.notifications);
    final updates =
        repo
            .alertsFor(account.uid)
            .where(
              (alert) =>
                  alert.caseId == event.caseId &&
                  alert.kind != AlertKind.newCase &&
                  alert.kind != AlertKind.priority,
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    _message(
      updates.isEmpty
          ? s.vNotificationCaseUnavailable
          : volunteerAlertMessage(s, updates.first.kind),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRemote();
    } else if (mounted && _location?.continuesInBackground != true) {
      _push?.sync(Localizations.localeOf(context).languageCode, null);
    }
  }

  void _refresh() {
    if (!mounted) return;
    _syncParticipation();
    setState(() {
      if (repo is ApiVolunteerRepository) {
        (repo as ApiVolunteerRepository).proximityLocation = location;
      }
      if (repo is ApiVolunteerRepository && _case != null) {
        // Preserve context when a case leaves active lists. Details render the
        // authoritative history outcome below instead of silently navigating.
        _case = repo.caseById(_case!.id) ?? _case;
      }
    });
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _noticeSubscription?.cancel();
    _noticeOverlay?.remove();
    _noticeOverlay?.dispose();
    _push?.close();
    WidgetsBinding.instance.removeObserver(this);
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
  Future<void> _run(
    Future<void> Function() action, {
    bool requiresLocation = true,
  }) async {
    if (_busy) return;
    if (requiresLocation &&
        repo is ApiVolunteerRepository &&
        !_canParticipate) {
      _message(s.vLocationHelp);
      return;
    }
    _update(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      assert(() {
        debugPrint(
          'Radd Volunteer action failed (${error.runtimeType})\n$stack',
        );
        return true;
      }());
      if (mounted) _message(s.vActionFailed);
    } finally {
      if (mounted) {
        _update(() => _busy = false);
        final pending = _pendingNotificationOpen;
        _pendingNotificationOpen = null;
        if (pending != null) _openNotification(pending);
      }
    }
  }

  Future<void> _logout() async {
    await _location?.stop();
    await widget.onLogout();
  }

  bool get _canParticipate =>
      repo.isPreview ||
      (account.eventAuthorized &&
          (repo is! ApiVolunteerRepository ||
              (repo as ApiVolunteerRepository).consentCurrent) &&
          _location?.accessGranted == true);

  bool get _locationBlocked =>
      repo is ApiVolunteerRepository &&
      !_canParticipate &&
      view != VolunteerView.profile &&
      view != VolunteerView.badge;

  List<Widget> _locationRequired() => [
    if (!account.eventAuthorized)
      VolunteerInfo(s.vEventUnassigned, title: s.vBadge)
    else ...[
      VolunteerInfo(
        _location?.servicesDisabled == true
            ? s.vLocationServicesDisabled
            : _location?.permanentlyDenied == true
            ? s.vLocationDeniedForever
            : s.vLocationHelp,
        title: s.vLocationRequired,
      ),
      const SizedBox(height: 16),
      VolunteerAction(
        _location?.servicesDisabled == true ||
                _location?.permanentlyDenied == true
            ? s.vLocationSettings
            : s.vAllowLocation,
        onPressed: _location == null || _location!.requesting
            ? null
            : () async {
                if (_location!.servicesDisabled ||
                    _location!.permanentlyDenied) {
                  await _location!.openSettings();
                } else {
                  await _location!.request();
                }
              },
      ),
    ],
  ];

  void _details(VolunteerCase item) {
    if (repo is ApiVolunteerRepository) {
      _run(() async {
        _case = await (repo as ApiVolunteerRepository).loadCase(item.id);
        if (mounted) _open(VolunteerView.caseDetails);
      });
    } else {
      _case = item;
      _open(VolunteerView.caseDetails);
    }
  }

  bool _isNearby(VolunteerCase item) =>
      item.joinable &&
      location != null &&
      item.information?.coordinates != null &&
      location!.distanceTo(item.information!.coordinates!) <=
          repo.proximityRadiusMeters;
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
        appBar: view == VolunteerView.home || view == VolunteerView.profile
            ? null
            : AppBar(
                backgroundColor: volunteerCanvas,
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
                          hasAlerts: repo
                              .alertsFor(account.uid)
                              .any((a) => a.readAt == null),
                        ),
                      ]
                    : null,
              ),
        bottomNavigationBar: GuardianNavigation(
          selected: _tab,
          onSelected: _selectTab,
          labels: roots,
          icons: icons,
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
              if (repo is ApiVolunteerRepository &&
                  !(repo as ApiVolunteerRepository).hasLoadedCases &&
                  !_refreshing &&
                  (repo as ApiVolunteerRepository).error != null)
                TextButton(onPressed: _loadRemote, child: Text(s.vLoadFailed)),
              if (_busy || _refreshing)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      key: ValueKey(view),
                      padding: const EdgeInsets.all(24),
                      children: _locationBlocked
                          ? _locationRequired()
                          : _initialDataPending
                          ? [const Center(child: CircularProgressIndicator())]
                          : _content(),
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

  bool get _initialDataPending {
    if (repo is! ApiVolunteerRepository) return false;
    final api = repo as ApiVolunteerRepository;
    final loaded = view == VolunteerView.notifications
        ? api.hasLoadedNotifications
        : api.hasLoadedCases;
    return [
          VolunteerView.home,
          VolunteerView.cases,
          VolunteerView.notifications,
        ].contains(view) &&
        !loaded &&
        (_refreshing || api.error == null);
  }

  List<Widget> _currentCaseDetails() {
    final id = _case?.id;
    final state = repo is ApiVolunteerRepository
        ? (repo as ApiVolunteerRepository).caseStates[id]
        : null;
    final stateKind = switch (state) {
      'cancelled' => AlertKind.cancelled,
      'resolved' => AlertKind.resolved,
      'reunited' => AlertKind.reunited,
      _ => null,
    };
    final outcomes =
        repo
            .alertsFor(account.uid)
            .where(
              (a) =>
                  a.caseId == id &&
                  (a.kind == AlertKind.cancelled ||
                      a.kind == AlertKind.resolved ||
                      a.kind == AlertKind.reunited ||
                      a.kind == AlertKind.statusUpdate),
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    final missing =
        repo is ApiVolunteerRepository &&
        id != null &&
        repo.caseById(id) == null;
    if (stateKind != null || outcomes.isNotEmpty || missing) {
      return [
        if (id != null) VolunteerHeading(id),
        const SizedBox(height: 20),
        if (stateKind != null || outcomes.isNotEmpty) ...[
          VolunteerHeading(
            volunteerAlertTitle(s, stateKind ?? outcomes.first.kind),
            large: true,
          ),
          const SizedBox(height: 12),
          Text(volunteerAlertMessage(s, stateKind ?? outcomes.first.kind)),
        ] else
          VolunteerInfo(s.vNotificationCaseUnavailable),
        const SizedBox(height: 20),
        VolunteerAction(
          s.vNotifications,
          onPressed: () => _open(VolunteerView.notifications),
        ),
      ];
    }
    return _caseDetails();
  }

  List<Widget> _content() => switch (view) {
    VolunteerView.home => _home(),
    VolunteerView.cases => _cases(),
    VolunteerView.caseDetails => _currentCaseDetails(),
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
