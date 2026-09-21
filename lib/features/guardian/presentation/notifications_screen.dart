import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_case_events.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<GuardianNotification>>? _data;
  // Latest authoritative list from an event-driven refetch (push/resume):
  // shown in place of the initial/explicit future, kept if a refetch fails.
  List<GuardianNotification>? _live;
  final _sync = CoalescedRefresh('notifications');
  Object? _error;
  @override
  void initState() {
    super.initState();
    // A push is only ever a signal that server state may have changed --
    // this always re-fetches the durable notification history from the
    // authenticated backend rather than trusting anything in the payload.
    GuardianCaseEvents.instance.addListener(_onEvent);
  }

  @override
  void dispose() {
    GuardianCaseEvents.instance.removeListener(_onEvent);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= AppServices.of(context).guardian.notifications();
  }

  void _onEvent() {
    final event = GuardianCaseEvents.instance.last;
    if (event == null || !mounted) return;
    final guardian = AppServices.of(context).guardian;
    _sync.run(() async {
      final value = await guardian.notifications();
      if (mounted) setState(() => _live = value);
    });
    if (event.source == GuardianEventSource.push &&
        event.caseId != null &&
        event.status != null) {
      showCaseUpdateNotice(
        context,
        caseId: event.caseId!,
        status: event.status!,
      );
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _live = null;
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
      builder: (context, state) {
        final items = _live ?? state.data;
        return FeaturePage(
          title: s.notifications,
          actions: [
            IconButton(
              tooltip: s.retry,
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          children: [
            if (_error != null)
              ErrorNotice(message: failureMessage(_error!, s)),
            if (state.hasError && items == null)
              ErrorNotice(
                message: failureMessage(state.error!, s),
                onRetry: _reload,
              )
            else if (items == null)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty) ...[
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
        );
      },
    );
  }
}
