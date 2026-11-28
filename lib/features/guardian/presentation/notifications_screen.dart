import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_push_service.dart';
import '../data/coalesced_refresh.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _eventGeneration = 0;
  final _eventRefresh = CoalescedRefresh();
  Future<void> _recover() => _eventRefresh.run(_recoverOnce);
  Future<void> _recoverOnce() async {
    if (!mounted) return;
    final loaded = await _fetch(
      AppServices.of(context).guardian.notifications,
      silent: true,
    );
    assert(() {
      debugPrint(
        loaded
            ? 'Radd Guardian authoritative refresh T8/T9 ${DateTime.now().toUtc().toIso8601String()}'
            : 'Radd Guardian background refresh failed',
      );
      return true;
    }());
  }

  List<GuardianNotification>? _items;
  Object? _loadError;
  bool _started = false;
  Object? _error;

  Future<bool> _fetch(
    Future<List<GuardianNotification>> Function() load, {
    bool silent = false,
  }) async {
    final generation = ++_eventGeneration;
    try {
      final data = await load();
      if (!mounted || generation != _eventGeneration) return false;
      setState(() {
        _items = data;
        _loadError = null;
      });
      return true;
    } catch (error) {
      if (!mounted || generation != _eventGeneration) return false;
      final accessLost = guardianAccessLost(error);
      if (accessLost || !silent || _items == null) {
        setState(() {
          _loadError = error;
          if (accessLost) _items = null;
        });
      }
      return false;
    }
  }
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _fetch(_viewNotifications);
  }

  Future<List<GuardianNotification>> _viewNotifications() async {
    final repo = AppServices.of(context).guardian;
    await repo.readAllNotifications();
    return repo.notifications();
  }

  Future<List<GuardianNotification>> _revisitNotifications() async {
    final repo = AppServices.of(context).guardian;
    final current = await repo.notifications();
    if (current.every((n) => n.read)) return current;
    await repo.readAllNotifications();
    return repo.notifications();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _loadError = null);
    _fetch(_viewNotifications);
  }

  Future<void> _open(GuardianNotification value) async {
    try {
      if (!value.read) {
        await AppServices.of(context).guardian.readNotification(value.id);
      }
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        value.foundReportId != null ? AppRoutes.qrCode : AppRoutes.caseStatus,
        arguments: value.caseId,
      );
      if (mounted) _fetch(_revisitNotifications);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final items = _items;
    return Builder(
      builder: (context) => FeaturePage(
        title: s.notifications,
        children: [
          if (_error != null) ErrorNotice(message: failureMessage(_error!, s)),
          if (_loadError != null)
            ErrorNotice(
              message: failureMessage(_loadError!, s),
              onRetry: _reload,
            ),
          if (items == null) ...[
            if (_loadError == null)
              const Center(child: CircularProgressIndicator()),
          ] else if (items.isEmpty) ...[
            const Icon(Icons.notifications_none, size: 48),
            const SizedBox(height: 24),
            Text(s.noNotifications, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.notificationHint, textAlign: TextAlign.center),
          ] else
            for (final value in items) ...[
              GuardianPanel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    value.read
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                    color: caseStatusColor(value.status),
                  ),
                  title: Text(
                    value.foundReportId == null
                        ? caseStatusLabel(value.status, s)
                        : value.status == 'reunited'
                        ? s.foundReportReunitedNotification(
                            value.individualName ?? '',
                          )
                        : s.foundReportIdentifiedNotification(
                            value.individualName ?? '',
                          ),
                  ),
                  subtitle: Text(
                    '${value.foundReportId ?? value.caseId}\n${caseDate(context, value.createdAt)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(value),
                ),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}
