import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_case_events.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/shared/widgets/feature_page.dart';

import 'support/guardian_fakes.dart';

/// Guardian screens reacting to Volunteer-driven case events: an incoming
/// (validated) push signal or an app resume makes the currently visible
/// screen refetch authoritative state from the repository at once -- no
/// navigation, no manual refresh, no waiting for the fallback poll -- while
/// duplicates never double-fetch or double-notify and a transient refetch
/// failure keeps the last valid state on screen.
void main() {
  late TestAuth auth;
  late TestRepository repo;
  final events = GuardianCaseEvents.instance;
  setUp(() {
    auth = TestAuth();
    repo = TestRepository();
    GuardianPushService.resetForTesting();
  });
  tearDown(() async {
    await auth.events.close();
    GuardianPushService.resetForTesting();
  });

  Future<void> start(WidgetTester t) async {
    await t.pumpWidget(
      AppServices(
        auth: auth,
        guardian: repo,
        child: const RaddApp(locale: Locale('en')),
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

  Map<String, Object?> push(String caseId, String status) => {
    'role': 'guardian',
    'kind': 'status_update',
    'status': status,
    'case_id': caseId,
    'event_id': 'test-event',
  };

  final notice = find.byKey(const ValueKey('case-update-notice'));

  // Home's Active Cases section sits below the individual cards: scroll the
  // lazily-built page until `text` is realized (never taps it).
  Future<void> scrollToText(WidgetTester t, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await t.pumpAndSettle();
    }
  }

  // Lets the current in-app notice time out (its duration is a timer, not
  // a frame, so pumpAndSettle alone never dismisses it).
  Future<void> dismissNotice(WidgetTester t) async {
    await t.pumpAndSettle(); // entrance animation done -> its timer starts
    await t.pump(const Duration(seconds: 5)); // timer fires
    await t.pumpAndSettle(); // exit animation
    expect(notice, findsNothing);
  }

  // The lifecycle transitions Flutter's AppLifecycleListener accepts for
  // "went to the background, came back".
  void backgroundAndResume(WidgetTester t) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets('Case Status refetches immediately for a push about its case, '
      'and ignores one about another case', (t) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.caseStatus, arguments: case1.id);
    expect(find.text('Report Received'), findsWidgets);
    final before = repo.caseFetches;
    events.acceptPush(push('RD-OTHER', 'search_in_progress'));
    await t.pumpAndSettle();
    expect(repo.caseFetches, before); // not this case: no request at all
    repo.advanceCase(case1.id, 'search_in_progress');
    events.acceptPush(push(case1.id, 'search_in_progress'));
    await t.pumpAndSettle();
    expect(repo.caseFetches, before + 1);
    expect(find.text('Search in Progress'), findsWidgets);
    Navigator.pop(t.element(find.byType(CaseStatusScreen)));
    await t.pumpAndSettle();
  });

  testWidgets('Home updates the active-case presentation in place from a '
      'push and shows one in-app notice', (t) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.guardian);
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    await scrollToText(t, 'Report Received');
    expect(find.text('Report Received'), findsWidgets);
    final lists = repo.caseListFetches;
    repo.advanceCase(case1.id, 'search_in_progress');
    expect(events.acceptPush(push(case1.id, 'search_in_progress')), isTrue);
    await t.pump();
    expect(notice, findsOneWidget);
    await t.pumpAndSettle();
    expect(find.byType(GuardianHomeScreen), findsOneWidget); // no navigation
    expect(find.text('Search in Progress'), findsWidgets);
    expect(find.text('Report Received'), findsNothing);
    expect(repo.caseListFetches, lists + 1);
    expect(t.takeException(), isNull);
    await dismissNotice(t);
  });

  testWidgets('a duplicate push neither refetches again nor shows a second '
      'notice, but a newer status does', (t) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.guardian);
    repo.advanceCase(case1.id, 'search_in_progress');
    final lists = repo.caseListFetches;
    events.acceptPush(push(case1.id, 'search_in_progress'));
    await t.pump();
    expect(notice, findsOneWidget);
    await dismissNotice(t);
    expect(repo.caseListFetches, lists + 1);
    // Same case + status again (FCM retry / reconciliation re-send).
    expect(events.acceptPush(push(case1.id, 'search_in_progress')), isFalse);
    await t.pump();
    expect(notice, findsNothing);
    await t.pumpAndSettle();
    expect(repo.caseListFetches, lists + 1);
    // A legitimately newer status for the same case is processed.
    repo.advanceCase(case1.id, 'match_confirmed');
    expect(events.acceptPush(push(case1.id, 'match_confirmed')), isTrue);
    await t.pump();
    expect(notice, findsOneWidget);
    await t.pumpAndSettle();
    expect(repo.caseListFetches, lists + 2);
    await scrollToText(t, 'Match Confirmed');
    expect(find.text('Match Confirmed'), findsWidgets);
    await dismissNotice(t);
  });

  testWidgets('Cases list and Notifications refetch on a push', (t) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.cases);
    expect(find.byType(CasesScreen), findsOneWidget);
    expect(find.text('Report Received'), findsWidgets);
    repo.advanceCase(case1.id, 'search_in_progress');
    events.acceptPush(push(case1.id, 'search_in_progress'));
    await t.pumpAndSettle();
    expect(find.text('Search in Progress'), findsWidgets);
    Navigator.pop(t.element(find.byType(CasesScreen)));
    await t.pumpAndSettle();

    await route(t, AppRoutes.notifications);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Match Confirmed'), findsNothing);
    repo.advanceCase(case1.id, 'match_confirmed');
    events.acceptPush(push(case1.id, 'match_confirmed'));
    await t.pumpAndSettle();
    expect(find.text('Match Confirmed'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('app resume performs a recovery refetch on the visible screen', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.guardian); // GuardianGate attaches the observer
    expect(events.debugHasLifecycleListener, isTrue);
    final lists = repo.caseListFetches;
    repo.advanceCase(case1.id, 'search_in_progress'); // missed while away
    backgroundAndResume(t);
    await t.pumpAndSettle();
    expect(repo.caseListFetches, lists + 1);
    await scrollToText(t, 'Search in Progress');
    expect(find.text('Search in Progress'), findsWidgets);
    expect(notice, findsNothing); // recovery, not an announced event
    expect(t.takeException(), isNull);
  });

  testWidgets('a transient refetch failure keeps the last valid state and '
      'shows no error', (t) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.guardian);
    await scrollToText(t, 'Report Received');
    expect(find.text('Report Received'), findsWidgets);
    repo.failNextCases = true;
    events.acceptPush(push(case1.id, 'search_in_progress'));
    await t.pumpAndSettle();
    expect(find.text('Report Received'), findsWidgets); // last valid state
    expect(find.text('Test Person'), findsWidgets);
    expect(find.byType(ErrorNotice), findsNothing);
    expect(t.takeException(), isNull);
    await dismissNotice(t);
    // The next signal recovers.
    repo.advanceCase(case1.id, 'search_in_progress');
    events.signal();
    await t.pumpAndSettle();
    expect(find.text('Search in Progress'), findsWidgets);
    expect(find.byType(ErrorNotice), findsNothing);
  });

  testWidgets('Case Status: a transient refetch failure keeps the timeline '
      'and later signals recover', (t) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.caseStatus, arguments: case1.id);
    repo.failNextMissingCase = true;
    events.acceptPush(push(case1.id, 'search_in_progress'));
    await t.pumpAndSettle();
    expect(find.text('Report Received'), findsWidgets);
    expect(find.byType(ErrorNotice), findsNothing);
    repo.advanceCase(case1.id, 'search_in_progress');
    events.signal();
    await t.pumpAndSettle();
    expect(find.text('Search in Progress'), findsWidgets);
    Navigator.pop(t.element(find.byType(CaseStatusScreen)));
    await t.pumpAndSettle();
  });

  testWidgets('a Volunteer-role message is not acted on by Guardian screens', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    final case1 = await seedCase();
    await route(t, AppRoutes.guardian);
    final lists = repo.caseListFetches;
    expect(
      events.acceptPush({
        ...push(case1.id, 'search_in_progress'),
        'role': 'volunteer',
      }),
      isFalse,
    );
    await t.pumpAndSettle();
    expect(repo.caseListFetches, lists);
    expect(notice, findsNothing);
  });
}
