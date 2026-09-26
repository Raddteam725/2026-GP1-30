import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/case_widgets.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_qr_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/shared/widgets/feature_page.dart';

import 'support/guardian_fakes.dart';

/// Guardian screens keep themselves current through the reviewed real-time
/// path (validated FCM signal -> coalesced authoritative refetch, app-resume
/// recovery, slow fallback poll) -- so no manual refresh control is needed
/// on Cases or QR, and only an explicit load failure offers a retry.
void main() {
  late TestAuth auth;
  late TestRepository repo;
  final channel = GuardianPushRefresh.instance;
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

  Map<String, dynamic> push(String caseId, String status) => {
    'role': 'guardian',
    'kind': 'status_update',
    'status': status,
    'case_id': caseId,
    'event_id': 'test-event',
  };

  void advance(MissingCase value, String status) {
    repo.caseRecords
      ..removeWhere((c) => c.id == value.id)
      ..add(
        MissingCase(
          id: value.id,
          individualId: value.individualId,
          name: value.name,
          age: value.age,
          status: status,
          eventId: value.eventId,
          createdAt: value.createdAt,
          updatedAt: DateTime.now().toUtc(),
          stages: {...value.stages, status: 'now'},
        ),
      );
  }

  testWidgets('Cases: a terminal event moves the case from Active to History '
      'in place, with no refresh control and no navigation', (t) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.cases);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.text('Report Received'), findsWidgets);
    expect(find.text('CASE HISTORY'), findsNothing); // SectionLabel uppercases
    // The Guardian resolved it from another screen/device.
    await repo.resolveCase(value.id);
    expect(channel.acceptPush(push(value.id, 'resolved')), isTrue);
    await t.pumpAndSettle();
    expect(find.byType(CasesScreen), findsOneWidget);
    expect(find.text('No active cases right now.'), findsOneWidget);
    await scrollToText(t, 'CASE HISTORY');
    expect(find.text('CASE HISTORY'), findsOneWidget);
    await scrollToText(t, 'Resolved');
    expect(find.text('Resolved'), findsWidgets);
    expect(find.text('Report Received'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Cases: every stage change is reflected from the event alone', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.cases);
    for (final (status, label) in [
      ('search_in_progress', 'Search in Progress'),
      ('match_confirmed', 'Match Confirmed'),
      ('awaiting_guardian_verification', 'Awaiting Guardian Verification'),
      ('reunited', 'Reunited'),
    ]) {
      advance(repo.caseRecords.single, status);
      expect(channel.acceptPush(push(value.id, status)), isTrue);
      await t.pumpAndSettle();
      await scrollToText(t, label);
      expect(find.text(label), findsWidgets, reason: status);
    }
    // Reunited is terminal: it is history now.
    expect(find.text('No active cases right now.'), findsOneWidget);
  });

  testWidgets('Cases: duplicate delivery does not refetch again; near-'
      'simultaneous push, resume and generic signals coalesce', (t) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.cases);
    final before = repo.caseListFetches;
    expect(channel.acceptPush(push(value.id, 'search_in_progress')), isTrue);
    await t.pumpAndSettle();
    expect(repo.caseListFetches, before + 1);
    // Same case + status again (FCM retry / reconciliation re-send).
    expect(channel.acceptPush(push(value.id, 'search_in_progress')), isFalse);
    await t.pumpAndSettle();
    expect(repo.caseListFetches, before + 1);
    // Three signals landing together: one request in flight plus at most
    // one follow-up -- never one request per signal.
    channel.acceptPush(push(value.id, 'match_confirmed'));
    channel.didChangeAppLifecycleState(AppLifecycleState.resumed);
    channel.ping();
    await t.pumpAndSettle();
    expect(repo.caseListFetches - (before + 1), lessThanOrEqualTo(2));
  });

  testWidgets('Cases: app resume performs the recovery refetch', (t) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.cases);
    advance(value, 'search_in_progress'); // changed while the app was away
    final before = repo.caseListFetches;
    channel.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(repo.caseListFetches, before + 1);
    expect(find.text('Search in Progress'), findsWidgets);
  });

  testWidgets('Cases: only an explicit load failure offers a retry, and the '
      'retry recovers', (t) async {
    await start(t);
    auth.active = true;
    await seedCase();
    repo.failNextCases = true;
    await route(t, AppRoutes.cases);
    expect(find.byType(ErrorNotice), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    await t.tap(find.text('Try Again'));
    await t.pumpAndSettle();
    expect(find.byType(ErrorNotice), findsNothing);
    expect(find.text('Report Received'), findsWidgets);
  });

  testWidgets('Home: a terminal event clears the individual\'s active-case '
      'state and the Active Cases section without navigation', (t) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.guardian);
    expect(find.text('Active Case'), findsWidgets);
    await scrollToText(t, 'Active Cases');
    expect(find.text('Active Cases'), findsOneWidget);
    await repo.resolveCase(value.id);
    expect(channel.acceptPush(push(value.id, 'resolved')), isTrue);
    await t.pumpAndSettle();
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    expect(find.text('Active Case'), findsNothing);
    expect(find.text('Active Cases'), findsNothing);
    expect(find.text('Report Missing'), findsWidgets);
  });

  testWidgets('Home: the active-case card border and chip carry the same '
      'canonical colour as the status', (t) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.guardian);
    await scrollToText(t, 'Track Status');
    final card = t.widget<Container>(
      find
          .descendant(
            of: find.byType(CaseCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (card.decoration as BoxDecoration).border as Border;
    expect(
      border.top.color,
      caseStatusColor('report_received').withValues(alpha: .7),
    );
    advance(value, 'search_in_progress');
    channel.acceptPush(push(value.id, 'search_in_progress'));
    await t.pumpAndSettle();
    // Updated in place: the list stayed mounted (no loading flash), so the
    // card is still where the Guardian was looking.
    expect(find.byType(CaseCard), findsOneWidget);
    final updated = t.widget<Container>(
      find
          .descendant(
            of: find.byType(CaseCard),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      ((updated.decoration as BoxDecoration).border as Border).top.color,
      caseStatusColor('search_in_progress').withValues(alpha: .7),
    );
  });

  testWidgets('QR: the credential regenerates itself at expiry with no '
      'manual refresh, keeping the short-lived single-use mechanism', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.qrCode);
    expect(find.byType(GuardianQrScreen), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(repo.verificationRequests, 1);
    expect(find.textContaining('Valid until'), findsOneWidget);
    // Nothing happens before expiry (5 minutes, issued by the backend)...
    await t.pump(const Duration(minutes: 4));
    expect(repo.verificationRequests, 1);
    // ...and a fresh single-use credential is requested right at expiry --
    // the same backend mechanism, just without a button.
    await t.pump(const Duration(minutes: 1, seconds: 1));
    await t.pumpAndSettle();
    expect(repo.verificationRequests, 2);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Valid until'), findsOneWidget);
    Navigator.pop(t.element(find.byType(GuardianQrScreen)));
    await t.pumpAndSettle();
  });
}
