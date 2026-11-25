import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/notice_banner.dart';
import '../data/guardian_push_service.dart';
import 'case_widgets.dart';

class GuardianNoticeHost extends StatefulWidget {
  const GuardianNoticeHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.autoDismiss = defaultAutoDismiss,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  final Duration autoDismiss;
  static const defaultAutoDismiss = Duration(seconds: 8);

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
    _timer?.cancel();
    setState(() {
      _notice = notice;
      _individualName = null;
    });
    _timer = Timer(widget.autoDismiss, () {
      if (mounted && generation == _generation) _dismiss();
    });
    try {
      if (notice.foundReportId != null) {
        final values = await services.guardian.notifications();
        final value = values.firstWhere((n) => n.id == notice.id);
        if (mounted && generation == _generation) {
          setState(() => _individualName = value.individualName);
        }
        return;
      }
      final value = await services.guardian.missingCase(notice.caseId);
      if (mounted && generation == _generation) {
        setState(() => _individualName = value.name);
      }
    } catch (_) {
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
    if (notice.foundReportId != null) {
      if (top?.name != AppRoutes.qrCode) navigator.pushNamed(AppRoutes.qrCode);
      return;
    }
    if (top?.name == AppRoutes.caseStatus && top?.arguments == notice.caseId) {
      return;
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
          child: Overlay.wrap(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: NoticeBanner(
                    materialKey: ValueKey('guardian-notice-${notice.id}'),
                    title: s.caseUpdateBanner,
                    message: notice.foundReportId != null
                        ? notice.status == 'reunited'
                              ? s.foundReportReunitedNotification(name ?? '')
                              : s.foundReportIdentifiedNotification(name ?? '')
                        : '${caseStatusLabel(notice.status, s)}. '
                              '${caseStageDescription(notice.status, s)}',
                    context:
                        name ??
                        notice.foundReportId ??
                        caseDisplayId(notice.caseId),
                    contextTextDirection: name == null
                        ? TextDirection.ltr
                        : null,
                    icon: Icons.notifications_active_outlined,
                    actionLabel: notice.foundReportId != null
                        ? s.qrCode
                        : s.viewCase,
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
