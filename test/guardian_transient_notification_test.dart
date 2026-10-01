import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_notice_host.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/shared/widgets/notice_banner.dart';

import 'support/guardian_fakes.dart';

/// Guardian transient in-app banner: the same top card the Volunteer
/// workspace shows, raised for a workflow update RECEIVED as a foreground
/// push while the Guardian is inside the app. History (bell) is untouched.
void main() {
  late TestAuth auth;
  late TestRepository repo;
  setUp(() {
    GuardianPushService.resetForTesting();
    auth = TestAuth();
    repo = TestRepository();
  });
  tearDown(() async {
    await auth.events.close();
    GuardianPushService.resetForTesting();
  });

  Future<void> start(WidgetTester t, {String locale = 'en'}) async {
    await t.pumpWidget(
      AppServices(
        auth: auth,
        guardian: repo,
        child: RaddApp(locale: Locale(locale)),
      ),
    );
    await t.pump(const Duration(milliseconds: 3800));
    await t.pumpAndSettle();
  }

  Future<void> route(WidgetTester t, String name, {Object? arguments}) async {
    final context = t.element(find.byType(LanguageSelectionScreen));
    Navigator.of(context).pushNamed(name, arguments: arguments);
    await t.pumpAndSettle();
  }

  Future<MissingCase> seedCase() async {
    repo.records.add(
      const Individual(
        id: 'test-id',
        fullName: 'Test Person',
        age: 7,
        gender: 'female',
        relationship: 'child',
      ),
    );
    return repo.reportMissing('test-id');
  }

  RemoteMessage push(
    String caseId,
    String status, {
    String kind = 'status_update',
  }) => RemoteMessage(
    data: {
      'role': 'guardian',
      'kind': kind,
      'status': status,
      'case_id': caseId,
      'event_id': 'test-event',
      'notification_id': '$caseId-$status',
    },
  );

  Finder banner(String caseId, String status) =>
      find.byKey(ValueKey('guardian-notice-$caseId-$status'));

  for (final locale in ['en', 'ar']) {
    testWidgets(
      'A Volunteer-driven update raises a contextual banner; View Case opens '
      'the case; history is untouched ($locale)',
      (t) async {
        await start(t, locale: locale);
        auth.active = true;
        final value = await seedCase();
        await route(t, AppRoutes.guardian);
        expect(find.byType(GuardianHomeScreen), findsOneWidget);
        final s = AppLocalizations.of(
          t.element(find.byType(GuardianHomeScreen)),
        )!;
        final historyBefore = repo.notificationRecords.length;
        // The search started (a Volunteer action) -- arrives as a push.
        GuardianPushService.debugReceive(push(value.id, 'search_in_progress'));
        await t.pumpAndSettle();
        final card = banner(value.id, 'search_in_progress');
        expect(card, findsOneWidget);
        expect(find.text(s.caseUpdateBanner), findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining(s.searchInProgress),
          ),
          findsOneWidget,
        );
        // Context: the individual's name, not an internal id.
        expect(
          find.descendant(of: card, matching: find.text('Test Person')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining(value.id)),
          findsNothing,
        );
        expect(
          Directionality.of(t.element(card)),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        // Bell/history: exactly as before, nothing added or removed here.
        expect(repo.notificationRecords.length, historyBefore);
        // View Case opens the existing Case Status screen for that case.
        await t.tap(find.descendant(of: card, matching: find.text(s.viewCase)));
        await t.pumpAndSettle();
        expect(card, findsNothing);
        expect(find.byType(CaseStatusScreen), findsOneWidget);
        expect(find.text('Test Person'), findsWidgets);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('Dismiss removes the banner; timeout removes it on its own', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.guardian);
    GuardianPushService.debugReceive(push(value.id, 'search_in_progress'));
    await t.pumpAndSettle();
    final first = banner(value.id, 'search_in_progress');
    expect(first, findsOneWidget);
    await t.tap(find.descendant(of: first, matching: find.byIcon(Icons.close)));
    await t.pumpAndSettle();
    expect(first, findsNothing);
    // Next update: left alone, it goes away after the host's duration.
    GuardianPushService.debugReceive(push(value.id, 'match_confirmed'));
    await t.pumpAndSettle();
    final second = banner(value.id, 'match_confirmed');
    expect(second, findsOneWidget);
    await t.pump(GuardianNoticeHost.defaultAutoDismiss ~/ 2);
    expect(second, findsOneWidget);
    await t.pump(GuardianNoticeHost.defaultAutoDismiss);
    await t.pumpAndSettle();
    expect(second, findsNothing);
    expect(find.byType(NoticeBanner), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'No replay on duplicate delivery, rebuild, navigation or language change',
    (t) async {
      await start(t);
      auth.active = true;
      final value = await seedCase();
      await route(t, AppRoutes.guardian);
      final message = push(value.id, 'search_in_progress');
      GuardianPushService.debugReceive(message);
      await t.pumpAndSettle();
      final card = banner(value.id, 'search_in_progress');
      expect(card, findsOneWidget);
      await t.tap(
        find.descendant(of: card, matching: find.byIcon(Icons.close)),
      );
      await t.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      // The same event delivered again (FCM retry) is not a new banner.
      GuardianPushService.debugReceive(message);
      await t.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      // Navigating around, opening history, resuming: still nothing replays.
      Navigator.of(t.element(find.byType(GuardianHomeScreen)))
          .pushNamed(AppRoutes.notifications);
      await t.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      GuardianPushRefresh.instance.didChangeAppLifecycleState(
        AppLifecycleState.resumed,
      );
      await t.pumpAndSettle();
      Navigator.of(t.element(find.byType(NotificationsScreen))).pop();
      await t.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    "The Guardian's own actions never raise a banner; Volunteer ones do",
    (t) async {
      await start(t);
      auth.active = true;
      final value = await seedCase();
      await route(t, AppRoutes.guardian);
      // Their own report creation (kind case_created) -- no banner.
      GuardianPushService.debugReceive(
        push(value.id, 'report_received', kind: 'case_created'),
      );
      await t.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      // Cancel/resolve are Guardian-only outcomes -- no banner; the history
      // list is whatever the backend recorded, untouched by the banner path.
      final history = repo.notificationRecords.length;
      await repo.cancelCase(value.id);
      GuardianPushService.debugReceive(
        push(value.id, 'cancelled', kind: 'status_changed'),
      );
      await t.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      expect(repo.notificationRecords.length, history);
      // A status the Guardian just produced on a second case (marked as its
      // own action by the screen that performed it) -- no banner either.
      repo.records.add(
        const Individual(
          id: 'second-id',
          fullName: 'Second Person',
          age: 9,
          gender: 'male',
          relationship: 'child',
        ),
      );
      final second = await repo.reportMissing('second-id');
      GuardianPushRefresh.instance.markOwnAction(second.id, 'match_confirmed');
      GuardianPushService.debugReceive(push(second.id, 'match_confirmed'));
      await t.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      // The Volunteer moving that case on IS surfaced, naming the individual.
      GuardianPushService.debugReceive(
        push(second.id, 'awaiting_guardian_verification'),
      );
      await t.pumpAndSettle();
      final card = banner(second.id, 'awaiting_guardian_verification');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Second Person')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('View Case on the case already open does not stack a copy', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.caseStatus, arguments: value.id);
    expect(find.byType(CaseStatusScreen), findsOneWidget);
    GuardianPushService.debugReceive(push(value.id, 'search_in_progress'));
    await t.pumpAndSettle();
    final card = banner(value.id, 'search_in_progress');
    expect(card, findsOneWidget);
    final s = AppLocalizations.of(t.element(find.byType(CaseStatusScreen)))!;
    await t.tap(find.descendant(of: card, matching: find.text(s.viewCase)));
    await t.pumpAndSettle();
    expect(find.byType(CaseStatusScreen), findsOneWidget);
    expect(card, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Unauthenticated sessions ignore Guardian notices', (t) async {
    await start(t);
    auth.active = false;
    GuardianPushService.debugReceive(push('RD-none', 'search_in_progress'));
    await t.pumpAndSettle();
    expect(find.byType(NoticeBanner), findsNothing);
    expect(t.takeException(), isNull);
  });
}
