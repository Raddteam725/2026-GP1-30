import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guided_report_screen.dart';
import 'package:radd/features/guardian/presentation/individual_form_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

/// The Guided Assistant asks exactly the documented predefined questions:
/// last-seen location Yes/No, clothing, distinctive item Yes/No (+ its
/// description when Yes), then optional additional information. Answering
/// "No" to the location question records no location and asks nothing more
/// about it. Registration shows the Active event it is associated with,
/// read from the backend -- never a hard-coded event.
void main() {
  late TestAuth auth;
  late TestRepository repo;
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

  // The send/save control is the round FilledButton in the input bar (reply
  // bubbles and the auto-save badge carry check icons of their own).
  Finder sendButton({bool last = false}) => find.ancestor(
    of: find.byIcon(last ? Icons.check : Icons.send),
    matching: find.byType(FilledButton),
  );

  Future<void> send(WidgetTester t, String text, {bool last = false}) async {
    await t.enterText(find.byType(TextField), text);
    await t.tap(sendButton(last: last));
    await t.pumpAndSettle();
  }

  testWidgets('"No" to the location question moves straight to clothing; the '
      'report completes with only the documented answers', (t) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.guidedReport, arguments: value.id);
    expect(find.byType(GuidedReportScreen), findsOneWidget);
    expect(find.textContaining('same as where'), findsOneWidget);
    await t.tap(find.widgetWithText(OutlinedButton, 'No'));
    await t.pumpAndSettle();
    // The retired free-text "Where was the individual last seen?" question is
    // never asked; clothing is next.
    expect(find.text('Where was the individual last seen?'), findsNothing);
    expect(find.textContaining('What clothing'), findsOneWidget);
    await send(t, 'Blue shirt');
    expect(find.textContaining('anything distinctive'), findsOneWidget);
    await t.tap(find.widgetWithText(OutlinedButton, 'No'));
    await t.pumpAndSettle();
    expect(find.textContaining('additional information'), findsOneWidget);
    await send(t, 'Near gate 3', last: true);
    final report = repo.caseRecords.single.report!;
    expect(report['completed'], isTrue);
    expect(report['same_location'], isFalse);
    expect(report['latitude'], isNull);
    expect(report['clothing'], 'Blue shirt');
    expect(report['carrying_distinctive'], isFalse);
    expect(report['additional_information'], 'Near gate 3');
    expect(report.containsKey('last_seen_description'), isFalse);
    expect(find.text('View Status'), findsOneWidget);
  });

  testWidgets('A distinctive item requires its description before moving on', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    final value = await seedCase();
    await route(t, AppRoutes.guidedReport, arguments: value.id);
    await t.tap(find.widgetWithText(OutlinedButton, 'No'));
    await t.pumpAndSettle();
    await send(t, 'Red jacket');
    await t.tap(find.widgetWithText(FilledButton, 'Yes'));
    await t.pumpAndSettle();
    // Empty description is refused (the answer is required when Yes).
    await t.tap(sendButton());
    await t.pumpAndSettle();
    expect(find.text('Please complete this answer.'), findsOneWidget);
    await send(t, 'Yellow backpack');
    expect(find.textContaining('additional information'), findsOneWidget);
    expect(
      repo.caseRecords.single.report!['distinctive_description'],
      'Yellow backpack',
    );
  });

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

  testWidgets('Registration shows the Active event name from the backend', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.addIndividual);
    expect(find.byType(IndividualFormScreen), findsOneWidget);
    await scrollToText(t, 'Registration period');
    expect(find.byKey(const ValueKey('active-event')), findsOneWidget);
    expect(find.textContaining('Test Event'), findsOneWidget);
  });

  testWidgets('Without an Active event nothing is invented: no event line', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.failNextEvent = true;
    await route(t, AppRoutes.addIndividual);
    await scrollToText(t, 'Registration period');
    expect(find.byKey(const ValueKey('active-event')), findsNothing);
    expect(find.textContaining('Test Event'), findsNothing);
  });
}
