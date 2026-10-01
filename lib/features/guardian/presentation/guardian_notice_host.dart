import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/notice_banner.dart';
import '../data/guardian_push_service.dart';
import 'case_widgets.dart';

/// Transient top-of-screen banner for Guardian workflow updates received
/// while the app is in the foreground -- the Guardian counterpart of the
/// Volunteer workspace's notice overlay, built on the same NoticeBanner
/// card. Lives once above the navigator (see RaddApp) so it is visible on
/// every Guardian screen and never duplicated per route.
///
/// Source: [GuardianPushRefresh.notices], fed only by a real received push
/// that passed duplicate suppression; nothing here replays history, reacts
/// to rebuilds, tab changes, language changes or app resume. The
/// notification bell/history is untouched -- the same event stays there
/// according to the existing contract.
class GuardianNoticeHost extends StatefulWidget {
  const GuardianNoticeHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.autoDismiss = defaultAutoDismiss,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// How long a banner stays before removing itself (dismiss and the action
  /// remove it sooner).
  final Duration autoDismiss;
  static const defaultAutoDismiss = Duration(seconds: 8);

  /// Tracks the topmost route so "View Case" never pushes a second copy of
  /// the case screen the Guardian is already looking at.
  static final routeObserver = _TopRouteObserver();

  @override
  State<GuardianNoticeHost> createState() => _GuardianNoticeHostState();
}

class _TopRouteObserver extends NavigatorObserver {
  Route<dynamic>? current;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      current = route;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      current = previousRoute;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      current = newRoute;
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(current, route)) current = previousRoute;
  }
}

class _GuardianNoticeHostState extends State<GuardianNoticeHost> {
  StreamSubscription<GuardianNotice>? _subscription;
  GuardianNotice? _notice;
  String? _individualName;
  Timer? _timer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _subscription = GuardianPushRefresh.instance.notices.listen(_receive);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _receive(GuardianNotice notice) async {
    if (!mounted) return;
    final services = AppServices.maybeOf(context);
    if (services == null || !services.auth.signedIn) return;
    final generation = ++_generation;
    // Newest update replaces any banner still showing (as the Volunteer
    // workspace does); both remain in history.
    _timer?.cancel();
    setState(() {
      _notice = notice;
      _individualName = null;
    });
    _timer = Timer(widget.autoDismiss, () {
      if (mounted && generation == _generation) _dismiss();
    });
    // The push carries no names by design; the individual's name comes from
    // the Guardian's own authenticated case record. Until it arrives (or if
    // it cannot be loaded) the banner shows the case reference instead.
    try {
      final value = await services.guardian.missingCase(notice.caseId);
      if (mounted && generation == _generation) {
        setState(() => _individualName = value.name);
      }
    } catch (_) {
      // Keep the reference; nothing else to do.
    }
  }

  void _dismiss() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    setState(() {
      _notice = null;
      _individualName = null;
    });
  }

  void _open(GuardianNotice notice) {
    _dismiss();
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    final top = GuardianNoticeHost.routeObserver.current?.settings;
    if (top?.name == AppRoutes.caseStatus && top?.arguments == notice.caseId) {
      return; // Already on this case: the refresh already updated it.
    }
    navigator.pushNamed(AppRoutes.caseStatus, arguments: notice.caseId);
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    if (notice == null) return widget.child;
    final s = AppLocalizations.of(context)!;
    final name = _individualName;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 16,
          right: 16,
          // This host sits above the navigator, outside its Overlay; the
          // card's tooltip/ink need one, so the banner brings its own.
          child: Overlay.wrap(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: NoticeBanner(
                    materialKey: ValueKey('guardian-notice-${notice.id}'),
                    title: s.caseUpdateBanner,
                    message:
                        '${caseStatusLabel(notice.status, s)}. '
                        '${caseStageDescription(notice.status, s)}',
                    context: name ?? caseDisplayId(notice.caseId),
                    contextTextDirection: name == null
                        ? TextDirection.ltr
                        : null,
                    icon: Icons.notifications_active_outlined,
                    actionLabel: s.viewCase,
                    closeTooltip: s.close,
                    onOpen: () => _open(notice),
                    onDismiss: _dismiss,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
