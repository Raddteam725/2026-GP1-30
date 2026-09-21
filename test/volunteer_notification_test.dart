import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';
import 'package:radd/features/volunteer/domain/volunteer_notification_event.dart';
import 'package:radd/features/volunteer/presentation/volunteer_notification_banner.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;

// Isolated event/widget tests. Production receives these fields from FCM;
// these tests do not claim Firebase delivery or insert real history/cases.
void main() {
  testWidgets('History opens exact case and back returns to Notifications', (
    tester,
  ) async {
    final repo = _NewCaseHistoryRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      harness(
        VolunteerWorkspace(
          account: MockVolunteerRepository.account,
          repository: repo,
          onLogout: () async {},
        ),
        'en',
      ),
    );
    await tester.tap(find.byTooltip('Notifications').first);
    await tester.pumpAndSettle();
    final button = find.widgetWithText(TextButton, 'View Case').first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Case Details'), findsOneWidget);
    expect(find.text(repo.cases.first.id), findsWidgets);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Case Details'), findsNothing);
  });

  for (final closed in [false, true]) {
    testWidgets('Unavailable history action is explicit (closed=$closed)', (
      tester,
    ) async {
      final repo = _UnavailableNotificationRepository(closed);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        harness(
          VolunteerWorkspace(
            account: MockVolunteerRepository.account,
            repository: repo,
            onLogout: () async {},
          ),
          'en',
        ),
      );
      await tester.tap(find.byTooltip('Notifications').first);
      await tester.pumpAndSettle();
      final action = find.widgetWithText(TextButton, 'View Case');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Case Details'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });
  }

  test('Stable event ID also deduplicates legacy FCM payloads', () {
    final dedup = VolunteerNotificationDeduplicator();
    final legacy = VolunteerNotificationEvent.fromData({
      'role': 'volunteer',
      'case_id': 'RD-test',
      'kind': 'general',
    })!;
    final current = VolunteerNotificationEvent.fromData({
      'role': 'volunteer',
      'case_id': 'RD-test',
      'kind': 'general',
      'notification_id': 'RD-test-new',
    })!;
    expect(dedup.accept(legacy), isTrue);
    expect(dedup.accept(current), isFalse);
    expect(
      VolunteerNotificationEvent.fromData({
        'role': 'guardian',
        'case_id': 'RD-test',
        'kind': 'general',
      }),
      isNull,
    );
  });

  for (final language in ['en', 'ar']) {
    for (final kind in AlertKind.values) {
      testWidgets(
        '$language foreground ${kind.name} popup is dismissible and localized',
        (tester) async {
          final repo = MockVolunteerRepository();
          final events = StreamController<VolunteerNotificationEvent>();
          addTearDown(repo.dispose);
          addTearDown(events.close);
          await tester.pumpWidget(
            harness(
              VolunteerWorkspace(
                account: MockVolunteerRepository.account,
                repository: repo,
                notificationEvents: events.stream,
                onLogout: () async {},
              ),
              language,
            ),
          );
          final event = VolunteerNotificationEvent(
            id: 'event-${kind.name}',
            caseId: repo.cases.first.id,
            kind: kind,
          );
          events.add(event);
          await tester.pumpAndSettle();
          expect(find.byType(VolunteerNotificationBanner), findsOneWidget);
          final bannerContext = tester.element(
            find.byType(VolunteerNotificationBanner),
          );
          expect(
            Directionality.of(bannerContext),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.descendant(
              of: find.byType(VolunteerNotificationBanner),
              matching: find.byIcon(Icons.close),
            ),
          );
          await tester.pumpAndSettle();
          events.add(event);
          await tester.pumpAndSettle();
          expect(find.byType(VolunteerNotificationBanner), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'New case notices are global across every root tab and overlay route; View Case opens its real ID',
    (tester) async {
      final repo = MockVolunteerRepository();
      final events = StreamController<VolunteerNotificationEvent>();
      addTearDown(repo.dispose);
      addTearDown(events.close);
      await tester.pumpWidget(
        harness(
          VolunteerWorkspace(
            account: MockVolunteerRepository.account,
            repository: repo,
            notificationEvents: events.stream,
            onLogout: () async {},
          ),
          'en',
        ),
      );
      final target = repo.cases.last;
      for (var tab = 0; tab < 5; tab++) {
        await tester.tap(find.byKey(ValueKey('radd-tab-$tab')));
        await tester.pump(const Duration(milliseconds: 300));
        events.add(
          VolunteerNotificationEvent(
            id: 'event-$tab',
            caseId: target.id,
            kind: AlertKind.newCase,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VolunteerNotificationBanner), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(VolunteerNotificationBanner),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pump();
      }
      final context = tester.element(find.byType(VolunteerWorkspace));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Camera route placeholder')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      events.add(
        VolunteerNotificationEvent(
          id: 'above-camera',
          caseId: target.id,
          kind: AlertKind.newCase,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: find.byType(VolunteerNotificationBanner),
          matching: find.text('View Case'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Camera route placeholder'), findsNothing);
      expect(find.text(target.id), findsWidgets);
      expect(find.text('Case Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Cancellation supersedes an undismissed new-case popup and opens history',
    (tester) async {
      final repo = MockVolunteerRepository();
      final events = StreamController<VolunteerNotificationEvent>();
      addTearDown(repo.dispose);
      addTearDown(events.close);
      await tester.pumpWidget(
        harness(
          VolunteerWorkspace(
            account: MockVolunteerRepository.account,
            repository: repo,
            notificationEvents: events.stream,
            onLogout: () async {},
          ),
          'en',
        ),
      );
      events.add(
        const VolunteerNotificationEvent(
          id: 'new',
          caseId: 'RD-test',
          kind: AlertKind.newCase,
        ),
      );
      await tester.pumpAndSettle();
      events.add(
        const VolunteerNotificationEvent(
          id: 'cancel',
          caseId: 'RD-test',
          kind: AlertKind.cancelled,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Case Cancelled'), findsOneWidget);
      expect(find.text('New Case Alert'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(VolunteerNotificationBanner),
          matching: find.text('Notifications'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _UnavailableNotificationRepository extends MockVolunteerRepository {
  _UnavailableNotificationRepository(this.closed);
  final bool closed;
  @override
  List<VolunteerAlert> alertsFor(String uid) => [
    VolunteerAlert(
      caseId: 'unavailable-test-only',
      kind: closed ? AlertKind.resolved : AlertKind.newCase,
      at: DateTime(2026),
    ),
  ];
}

class _NewCaseHistoryRepository extends MockVolunteerRepository {
  @override
  List<VolunteerAlert> alertsFor(String uid) => [
    VolunteerAlert(
      caseId: cases.first.id,
      kind: AlertKind.newCase,
      at: DateTime(2026),
    ),
  ];
}
