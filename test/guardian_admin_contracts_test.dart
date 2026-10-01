import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/auth/presentation/session_screen.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

/// The Guardian side of two contracts the Admin module will drive later:
/// a case closed as Referred to Authority, and a deactivated Guardian
/// account. Guardian consumes both from authoritative backend state --
/// nothing here depends on how the Admin module is implemented.
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

  for (final (locale, label) in [
    ('en', 'Referred to Authority'),
    ('ar', 'تمت الإحالة إلى الجهة المختصة'),
  ]) {
    testWidgets('Referred to Authority ($locale): accepted as a push, shown as '
        'terminal history with its own colour, no navigation', (t) async {
      await start(t, locale: locale);
      auth.active = true;
      final value = await seedCase();
      await route(t, AppRoutes.cases);
      // The Admin module closed the case on the backend.
      repo.caseRecords
        ..removeWhere((c) => c.id == value.id)
        ..add(
          MissingCase(
            id: value.id,
            individualId: value.individualId,
            name: value.name,
            age: value.age,
            status: 'referred_to_authority',
            eventId: value.eventId,
            createdAt: value.createdAt,
            updatedAt: DateTime.now().toUtc(),
            stages: value.stages,
          ),
        );
      expect(
        channel.acceptPush({
          'role': 'guardian',
          'kind': 'status_changed',
          'status': 'referred_to_authority',
          'case_id': value.id,
          'event_id': 'test-event',
        }),
        isTrue,
      );
      await t.pumpAndSettle();
      expect(find.byType(CasesScreen), findsOneWidget);
      await scrollToText(t, label);
      expect(find.text(label), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  test('The retired identifier is not a Guardian status', () {
    expect(terminalStatuses, contains('referred_to_authority'));
    expect(terminalStatuses, isNot(contains('transferred_to_authority')));
    expect(
      GuardianPushRefresh.valid({
        'role': 'guardian',
        'case_id': 'RD-1',
        'status': 'transferred_to_authority',
      }),
      isFalse,
    );
  });

  testWidgets('A deactivated Guardian sees the deactivation message in '
      'session recovery and can sign out', (t) async {
    await start(t);
    auth.active = true;
    repo.deactivated = true;
    await route(t, AppRoutes.guardian);
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(
      find.textContaining('deactivated by the event administration'),
      findsOneWidget,
    );
    expect(find.text('Log Out'), findsOneWidget);
  });
}
