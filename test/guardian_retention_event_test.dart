import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/individual_form_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

/// Sprint-0 retention and event awareness on the Guardian side:
/// - registration explains the retention choice in plain words and previews
///   the deletion date;
/// - an existing registration's retention can be changed from Edit (only a
///   changed choice is sent; other edits never touch it);
/// - the profile shows the deletion deadline;
/// - Home shows the authoritative Active event once, and says when there is
///   none -- never a built-in event name.
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

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text).last;
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
    } else {
      await t.ensureVisible(f);
    }
    await t.pumpAndSettle();
    await t.tap(f);
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

  Individual person({String period = 'test-long'}) => Individual(
    id: 'test-id',
    fullName: 'Test Person',
    age: 7,
    gender: 'female',
    relationship: 'child',
    registrationPeriodId: period,
    registrationExpiresAt: repo.retentionStart.add(const Duration(hours: 48)),
  );

  testWidgets('Registration explains the retention choice and previews the '
      'deletion date in plain words', (t) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.addIndividual);
    await scrollToText(t, 'Data retention period');
    expect(
      find.textContaining("Choose how long this individual's data"),
      findsOneWidget,
    );
    expect(find.textContaining('deleted automatically'), findsOneWidget);
    // Longest option is the default: its deadline is previewed immediately.
    expect(find.byKey(const ValueKey('retention-until')), findsOneWidget);
    expect(find.textContaining('Data kept until'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('registration-period')));
    await t.pumpAndSettle();
    expect(find.text('2 hours'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    await t.tap(find.text('2 hours'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('cannot go beyond the end of the event'),
      findsOneWidget,
    );
    // No database terminology in the primary explanation.
    expect(find.textContaining('embedding'), findsNothing);
  });

  testWidgets('Edit offers the retention options, preselects the current one '
      'and sends only a changed choice', (t) async {
    await start(t);
    auth.active = true;
    repo.records.add(person());
    await route(t, AppRoutes.guardian);
    await tapText(t, 'Test Person');
    // The profile shows the deletion deadline.
    await scrollToText(t, 'Data retention period');
    expect(find.textContaining('Data kept until'), findsOneWidget);
    await tapText(t, 'Edit');
    expect(find.byType(IndividualFormScreen), findsOneWidget);
    expect(repo.retentionOptionsRequests, 1);
    // Edit the name first (the form is a lazy list: the name field sits at
    // the top, the retention panel below the fold).
    await t.enterText(find.byType(TextFormField).first, 'Renamed Person');
    await scrollToText(t, 'Data retention period');
    final selector = find.byKey(const ValueKey('registration-period'));
    expect(
      t.state<FormFieldState<String>>(selector).value,
      'test-long',
    ); // current choice
    expect(find.textContaining('Counted from the original'), findsOneWidget);
    // Saving without touching retention sends no period at all.
    await tapText(t, 'Save Changes');
    expect(repo.lastSavedPeriodId, isNull);
    expect(repo.records.single.registrationPeriodId, 'test-long');
    // Now extend to a week from Edit.
    await tapText(t, 'Edit');
    await scrollToText(t, 'Data retention period');
    await t.tap(find.byKey(const ValueKey('registration-period')));
    await t.pumpAndSettle();
    await t.tap(find.text('7 days').last);
    await t.pumpAndSettle();
    await tapText(t, 'Save Changes');
    expect(repo.lastSavedPeriodId, 'test-week');
    expect(repo.records.single.registrationPeriodId, 'test-week');
  });

  testWidgets('Profile -> Edit -> shorter still-future period -> Save -> the '
      'profile shows the new deadline', (t) async {
    await start(t);
    auth.active = true;
    repo.records.add(person()); // current: test-long (48 h from the start)
    await route(t, AppRoutes.guardian);
    await tapText(t, 'Test Person');
    await scrollToText(t, 'Data retention period');
    final before = t.widget<Text>(find.textContaining('Data kept until')).data;
    await tapText(t, 'Edit');
    await scrollToText(t, 'Data retention period');
    await t.tap(find.byKey(const ValueKey('registration-period')));
    await t.pumpAndSettle();
    await t.tap(find.text('2 hours').last); // still ahead: allowed
    await t.pumpAndSettle();
    // The preview follows the selection (deadline counted from the start).
    expect(find.byKey(const ValueKey('retention-until')), findsOneWidget);
    await tapText(t, 'Save Changes');
    expect(repo.lastSavedPeriodId, 'test-short');
    // Back on the profile, refreshed from the repository.
    await scrollToText(t, 'Data retention period');
    final after = t.widget<Text>(find.textContaining('Data kept until')).data;
    expect(after, isNot(before));
    expect(repo.records.single.registrationPeriodId, 'test-short');
  });

  testWidgets('Options the backend rules out are shown disabled with the '
      'reason and cannot be selected', (t) async {
    await start(t);
    auth.active = true;
    repo.records.add(person());
    await route(t, AppRoutes.editIndividual, arguments: repo.records.single);
    await scrollToText(t, 'Data retention period');
    await t.tap(find.byKey(const ValueKey('registration-period')));
    await t.pumpAndSettle();
    // 1 hour already passed; 30 days would end after the event.
    expect(find.text('1 hours (already passed)'), findsOneWidget);
    expect(find.text('30 days (after the event ends)'), findsOneWidget);
    final passed = t.widget<DropdownMenuItem<String>>(
      find.ancestor(
        of: find.text('1 hours (already passed)'),
        matching: find.byType(DropdownMenuItem<String>),
      ),
    );
    expect(passed.enabled, isFalse);
    await t.tap(find.text('1 hours (already passed)'));
    await t.pumpAndSettle();
    // A disabled item does not change the selection; the menu stays open.
    expect(
      t
          .state<FormFieldState<String>>(
            find.byKey(const ValueKey('registration-period')),
          )
          .value,
      'test-long',
    );
  });

  testWidgets('A rejected retention change shows the backend reason', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.records.add(person());
    // Stale state / race: the backend rules out what the UI still offered.
    repo.rejectNextSave = const AppFailure('retentionPassed');
    await route(t, AppRoutes.editIndividual, arguments: repo.records.single);
    await scrollToText(t, 'Data retention period');
    await t.tap(find.byKey(const ValueKey('registration-period')));
    await t.pumpAndSettle();
    await t.tap(find.text('2 hours').last);
    await t.pumpAndSettle();
    await tapText(t, 'Save Changes');
    expect(find.byType(IndividualFormScreen), findsOneWidget);
    expect(find.textContaining('would already have ended'), findsOneWidget);
    expect(repo.records.single.registrationPeriodId, 'test-long');
    // Beyond the event boundary: the localized backend reason as well.
    repo.rejectNextSave = const AppFailure('retentionInvalid');
    await tapText(t, 'Save Changes');
    expect(find.textContaining('not available for this event'), findsOneWidget);
  });

  testWidgets('A failed retention-options load in Edit is shown with a '
      'retry, never hidden', (t) async {
    await start(t);
    auth.active = true;
    repo.records.add(person());
    repo.failNextRetentionOptions = true;
    await route(t, AppRoutes.editIndividual, arguments: repo.records.single);
    await scrollToText(t, 'Data retention period');
    expect(find.textContaining('not available for this event'), findsOneWidget);
    expect(find.byKey(const ValueKey('registration-period')), findsNothing);
    await tapText(t, 'Try Again');
    expect(find.byKey(const ValueKey('registration-period')), findsOneWidget);
    expect(repo.retentionOptionsRequests, 2);
  });

  testWidgets('Retention is not offered while the individual has an active '
      'case (edits are locked by the backend)', (t) async {
    await start(t);
    auth.active = true;
    repo.records.add(person());
    await repo.reportMissing('test-id');
    await route(t, AppRoutes.editIndividual, arguments: repo.records.single);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('registration-period')), findsNothing);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('Home ($locale) shows the authoritative Active event once, '
        'with its dates', (t) async {
      await start(t, locale: locale);
      auth.active = true;
      repo.event = ActiveEvent(
        id: 'E1',
        name: 'Boulevard Night',
        status: 'active',
        location: 'Riyadh',
        startsAt: DateTime.utc(2026, 10, 1),
        endsAt: DateTime.utc(2026, 10, 5),
      );
      await route(t, AppRoutes.guardian);
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('home-event')), findsOneWidget);
      expect(find.text('Boulevard Night'), findsOneWidget);
      expect(find.text('Riyadh'), findsOneWidget);
      // Dates are localized (Arabic uses Arabic-Indic digits).
      expect(
        find.textContaining(locale == 'ar' ? '٢٠٢٦' : '2026'),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('home-event-unavailable')),
        findsNothing,
      );
      expect(find.text('Radd Sprint 0 Development'), findsNothing);
    });
  }

  testWidgets('Home without an Active event says so and still works', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.failNextEvent = true;
    await route(t, AppRoutes.guardian);
    expect(
      find.byKey(const ValueKey('home-event-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-event')), findsNothing);
    expect(find.text('Register an Individual'), findsOneWidget);
  });
}
