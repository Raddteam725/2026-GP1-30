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
    final generation = ++_eventGeneration;
    try {
      final data = await AppServices.of(context).guardian.notifications();
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

  Future<List<GuardianNotification>>? _data;
  Object? _error;
  @override
  void initState() {
    super.initState();
    // A foreground push is only ever a hint that server state may have
    // changed -- this always re-fetches from the authenticated backend
    // rather than trusting anything from the push payload itself.
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
    _data ??= AppServices.of(context).guardian.notifications();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _data = AppServices.of(context).guardian.notifications();
    });
  }

  Future<void> _open(GuardianNotification value) async {
    try {
      await AppServices.of(context).guardian.readNotification(value.id);
      if (!mounted) return;
      await Navigator.of(context)
          .pushNamed(AppRoutes.caseStatus, arguments: value.caseId);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<List<GuardianNotification>>(
      future: _data,
      builder: (context, state) => FeaturePage(
        title: s.notifications,
        actions: [
          IconButton(
            tooltip: s.retry,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        children: [
          if (_error != null) ErrorNotice(message: failureMessage(_error!, s)),
          if (state.hasError)
            ErrorNotice(
              message: failureMessage(state.error!, s),
              onRetry: _reload,
            )
          else if (!state.hasData)
            const Center(child: CircularProgressIndicator())
          else if (state.data!.isEmpty) ...[
            const Icon(Icons.notifications_none, size: 48),
            const SizedBox(height: 24),
            Text(s.noNotifications, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.notificationHint, textAlign: TextAlign.center),
          ] else
            for (final value in state.data!) ...[
              GuardianPanel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    value.read
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                  ),
                  title: Text(caseStatusLabel(value.status, s)),
                  subtitle: Text(
                    '${value.caseId}\n${caseDate(context, value.createdAt)}',
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
