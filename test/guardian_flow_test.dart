import 'support/guardian_fakes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/auth/presentation/form_validation.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/individual_form_screen.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/guardian/presentation/case_widgets.dart';
import 'package:radd/features/guardian/presentation/guardian_qr_screen.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/guardian/presentation/guided_report_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

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
    final base = find.text(text);
    final f = base.last;
    if (base.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        base,
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

  // Scrolls a lazily-built list until `text` is realized, without tapping it
  // -- for assertions on long FeaturePage screens where the target sits below
  // the fold and a plain find.text would see nothing yet (not "not present").
  Future<void> scrollToText(
    WidgetTester t,
    String text, {
    double delta = 200,
  }) async {
    final base = find.text(text);
    if (base.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        base,
        delta,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await t.pumpAndSettle();
    }
  }

  test('Password policy rejects each missing requirement', () {
    for (final password in [
      'Short1!',
      'lowercase1!',
      'UPPERCASE1!',
      'NoNumbers!',
      'NoSpecial12',
      '        ',
    ]) {
      expect(FormValidation.strongPassword(password), isFalse);
    }
    expect(FormValidation.strongPassword('ValidPass1!'), isTrue);
  });
  testWidgets(
    'Login validates without authentication; reset and privacy routes exist',
    (t) async {
      await start(t);
      await route(t, AppRoutes.auth);
      await tapText(t, 'Log In');
      expect(find.text('This field is required.'), findsNWidgets(2));
      expect(auth.logins, 0);
      await tapText(t, 'Forgot Password?');
      expect(find.text('Send Reset Instructions'), findsOneWidget);
      await tapText(t, 'Send Reset Instructions');
      expect(find.text('This field is required.'), findsOneWidget);
    },
  );
  testWidgets('Registration requires strong password and both confirmations', (
    t,
  ) async {
    await start(t);
    await route(t, AppRoutes.createAccount);
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Test Guardian');
    await t.enterText(fields.at(1), 'test@example.test');
    await t.enterText(fields.at(2), '+966500000001');
    await t.enterText(fields.at(3), 'ValidPass1!');
    await tapText(t, 'Create Account');
    expect(find.text('Both confirmations are required.'), findsOneWidget);
    expect(auth.registrations, 0);
    await t.ensureVisible(find.byType(CheckboxListTile).first);
    await t.tap(find.byType(CheckboxListTile).first);
    await t.pumpAndSettle();
    await tapText(t, 'Create Account');
    expect(auth.registrations, 0);
    await tapText(t, 'Privacy Notice');
    expect(find.byType(PrivacyScreen), findsOneWidget);
    Navigator.pop(t.element(find.byType(PrivacyScreen)));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(CheckboxListTile).last);
    await t.tap(find.byType(CheckboxListTile).last);
    await t.pumpAndSettle();
    await tapText(t, 'Create Account');
    expect(auth.registrations, 1);
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    expect(find.text('No individuals registered yet'), findsOneWidget);
    expect(repo.records, isEmpty);
  });
  testWidgets('Protected route refuses an unauthenticated session', (t) async {
    await start(t);
    await route(t, AppRoutes.guardian);
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.byType(GuardianHomeScreen), findsNothing);
  });
  testWidgets(
    'Individual validation requires photograph and no gallery action exists',
    (t) async {
      await start(t);
      auth.active = true;
      await route(t, AppRoutes.addIndividual);
      expect(find.byType(IndividualFormScreen), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp('Gallery|Library|Choose file', caseSensitive: false),
        ),
        findsNothing,
      );
      await tapText(t, 'Save');
      expect(find.text('Take a photo before saving.'), findsOneWidget);
      expect(repo.records, isEmpty);
      final s = AppLocalizations.of(
        t.element(find.byType(IndividualFormScreen)),
      )!;
      for (final v in ['-1', 'abc', '131', '1.5']) {
        expect(FormValidation.age(v, s), isNotNull);
      }
      expect(FormValidation.age('0', s), isNull);
      expect(FormValidation.name('   ', s), isNotNull);
    },
  );
  testWidgets(
    'Other relationship requires a custom description before saving',
    (t) async {
      await start(t);
      auth.active = true;
      await route(t, AppRoutes.addIndividual);
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), 'Test Person');
      await t.enterText(fields.at(1), '9');
      await tapText(t, 'Female');
      expect(find.text('Specify relationship'), findsNothing);
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Other').last);
      await t.pumpAndSettle();
      // Selecting Other immediately reveals the required custom-text field.
      expect(find.text('Specify relationship'), findsWidgets);
      await t.enterText(find.byType(TextFormField).at(2), 'Family friend');
      await tapText(t, 'Save');
      // The relationship is now satisfied; only the still-missing photo blocks saving.
      expect(find.text('Take a photo before saving.'), findsOneWidget);
      expect(repo.records, isEmpty);
    },
  );
  testWidgets('Logout clears protected history and keeps locale', (t) async {
    await start(t, locale: 'ar');
    auth.active = true;
    await route(t, AppRoutes.guardian);
    await tapText(t, 'الملف الشخصي');
    await tapText(t, 'تسجيل الخروج');
    await tapText(t, 'إلغاء');
    expect(auth.active, isTrue);
    await tapText(t, 'تسجيل الخروج');
    await tapText(t, 'تسجيل الخروج');
    expect(auth.active, isFalse);
    expect(find.byType(AuthScreen), findsOneWidget);
    final context = t.element(find.byType(AuthScreen));
    expect(Navigator.of(context).canPop(), isFalse);
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('Edit updates the list and deletion requires confirmation', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.records.add(
      const Individual(
        id: 'test-id',
        fullName: 'Test Person',
        age: 7,
        gender: 'female',
        relationship: 'child',
      ),
    );
    await route(t, AppRoutes.guardian);
    await tapText(t, 'Test Person');
    await tapText(t, 'Edit');
    await t.enterText(find.byType(TextFormField).first, 'Updated Person');
    await tapText(t, 'Save Changes');
    expect(find.text('Updated Person'), findsNWidgets(2));
    expect(repo.records.single.fullName, 'Updated Person');
    await tapText(t, 'Delete Individual');
    await tapText(t, 'Cancel');
    expect(repo.records, hasLength(1));
    await tapText(t, 'Delete Individual');
    await tapText(t, 'Delete');
    expect(repo.records, isEmpty);
    expect(find.text('No individuals registered yet'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'An expired photo hides Report Missing until a new photo is captured',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'test-id',
          fullName: 'Test Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
          photoExpired: true,
        ),
      );
      await route(t, AppRoutes.guardian);
      await tapText(t, 'Test Person');
      await scrollToText(t, 'Update Photo');
      expect(find.text('Report Missing'), findsNothing);
      expect(find.text('Update Photo'), findsOneWidget);
      await tapText(t, 'Update Photo');
      expect(find.byType(IndividualFormScreen), findsOneWidget);
      // The fake's own save() never carries photoExpired forward from an
      // edit, standing in for a freshly captured photo restarting the
      // 24-hour window server-side.
      await t.enterText(find.byType(TextFormField).first, 'Test Person');
      await tapText(t, 'Save Changes');
      await scrollToText(t, 'Report Missing');
      expect(find.text('Report Missing'), findsOneWidget);
      expect(find.text('Update Photo'), findsNothing);
    },
  );
  testWidgets('Language remains accessible from the authenticated profile', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.guardian);
    await tapText(t, 'Profile');
    await tapText(t, 'Language');
    await tapText(t, 'العربية');
    await tapText(t, 'متابعة');
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    expect(
      Directionality.of(t.element(find.byType(GuardianHomeScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets(
    'Five Guardian tabs remain visible and QR/Cases open real screens',
    (t) async {
      await start(t);
      auth.active = true;
      await route(t, AppRoutes.guardian);
      for (final label in [
        'Home',
        'My Individuals',
        'QR Code',
        'Cases',
        'Profile',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tapText(t, 'QR Code');
      expect(find.byType(GuardianQrScreen), findsOneWidget);
      // The account-level QR exists even with no active case at all.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.text(
          'You have no active cases right now. Your Guardian QR remains valid for verification.',
        ),
        findsOneWidget,
      );
      Navigator.pop(t.element(find.byType(GuardianQrScreen)));
      await t.pumpAndSettle();
      await tapText(t, 'Cases');
      expect(find.byType(CasesScreen), findsOneWidget);
      expect(find.text('No cases yet'), findsOneWidget);
      expect(
        find.text('This feature will be available in a later sprint.'),
        findsNothing,
      );
      expect(repo.records, isEmpty);
    },
  );
  testWidgets('Notification bell opens real notifications, not a placeholder', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.records.add(
      const Individual(
        id: 'test-id',
        fullName: 'Test Person',
        age: 7,
        gender: 'female',
        relationship: 'child',
      ),
    );
    await route(t, AppRoutes.guardian);
    expect(find.text('No notifications yet'), findsNothing);
    await t.tap(find.byIcon(Icons.notifications_none));
    await t.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('No notifications yet'), findsOneWidget);
    Navigator.pop(t.element(find.byType(NotificationsScreen)));
    await t.pumpAndSettle();
    await tapText(t, 'Test Person');
    await tapText(t, 'Report Missing');
    await tapText(t, 'Confirm');
    await t.pumpAndSettle();
    expect(repo.caseRecords, hasLength(1));
    expect(find.byType(GuidedReportScreen), findsOneWidget);
    Navigator.pop(t.element(find.byType(GuidedReportScreen)));
    await t.pumpAndSettle();
    // The profile now carries the Active Case indicator with the real id.
    expect(find.text('Active Case'), findsWidgets);
    expect(find.textContaining('RD-TEST'), findsWidgets);
  });
  testWidgets(
    'Guided Assistant is required and refuses the back button until submitted',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'test-id',
          fullName: 'Test Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
      );
      await route(t, AppRoutes.guardian);
      await tapText(t, 'Test Person');
      await tapText(t, 'Report Missing');
      await tapText(t, 'Confirm');
      await t.pumpAndSettle();
      expect(find.byType(GuidedReportScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(GuidedReportScreen), findsOneWidget);
      expect(
        find.text(
          'Please finish the required questions before leaving this screen.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('Refresh on the Cases list never passes a Future to setState', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.cases);
    expect(find.byType(CasesScreen), findsOneWidget);
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  for (final destination in [AppRoutes.guardian, AppRoutes.cases]) {
    testWidgets('Guardian event refreshes $destination immediately', (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'live-test',
          fullName: 'Event Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
      );
      await route(t, destination);
      expect(find.text('Report Received'), findsNothing);
      await repo.reportMissing('live-test');
      GuardianPushRefresh.instance.ping();
      await t.pumpAndSettle();
      await scrollToText(t, 'Report Received');
      expect(find.text('Report Received'), findsWidgets);
      final value = repo.caseRecords.single;
      repo.caseRecords[0] = MissingCase(
        id: value.id,
        individualId: value.individualId,
        name: value.name,
        age: value.age,
        status: 'search_in_progress',
        eventId: value.eventId,
        createdAt: value.createdAt,
        stages: value.stages,
      );
      GuardianPushRefresh.instance.acceptPush({
        'role': 'guardian',
        'case_id': value.id,
        'status': 'search_in_progress',
      });
      await t.pumpAndSettle();
      await scrollToText(t, 'Search in Progress');
      expect(find.text('Search in Progress'), findsWidgets);
      expect(find.text('Report Received'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Refresh on Notifications never passes a Future to setState', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.notifications);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'A foreground push refreshes Notifications without a manual refresh',
    (t) async {
      await start(t);
      auth.active = true;
      await route(t, AppRoutes.notifications);
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      // The push payload itself is never trusted for data -- this only
      // stands in for "a push arrived", exactly like GuardianPushService's
      // real onMessage listener does; the screen must go re-fetch itself.
      repo.notificationRecords.add(
        GuardianNotification(
          id: 'n1',
          caseId: 'RD-1',
          status: 'report_received',
          read: false,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      GuardianPushRefresh.instance.ping();
      await t.pumpAndSettle();
      expect(find.text('No notifications yet'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Refresh on Case Status never passes a Future to setState', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.records.add(
      const Individual(
        id: 'test-id',
        fullName: 'Test Person',
        age: 7,
        gender: 'female',
        relationship: 'child',
      ),
    );
    final case1 = await repo.reportMissing('test-id');
    await route(t, AppRoutes.caseStatus, arguments: case1.id);
    expect(find.byType(CaseStatusScreen), findsOneWidget);
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // Dispose the screen so its background status-poll timer is cancelled
    // before the test ends (an outstanding Timer otherwise fails teardown).
    Navigator.pop(t.element(find.byType(CaseStatusScreen)));
    await t.pumpAndSettle();
  });
  testWidgets(
    'Case Status reflects a Volunteer-driven change without a manual refresh',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'test-id',
          fullName: 'Test Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
      );
      final case1 = await repo.reportMissing('test-id');
      await route(t, AppRoutes.caseStatus, arguments: case1.id);
      expect(find.byType(CaseStatusScreen), findsOneWidget);
      expect(find.text('Report Received'), findsWidgets);
      // The Guardian never taps refresh here -- this mutation stands in for
      // a Volunteer selecting "Start Search" from their own device.
      repo.caseRecords
        ..removeWhere((c) => c.id == case1.id)
        ..add(
          MissingCase(
            id: case1.id,
            individualId: case1.individualId,
            name: case1.name,
            age: case1.age,
            status: 'search_in_progress',
            eventId: case1.eventId,
            createdAt: case1.createdAt,
            updatedAt: DateTime.now().toUtc(),
            stages: {
              ...case1.stages,
              'search_in_progress': DateTime.now().toUtc().toIso8601String(),
            },
          ),
        );
      await t.pump(const Duration(seconds: 31));
      await t.pump();
      expect(find.text('Search in Progress'), findsWidgets);
      Navigator.pop(t.element(find.byType(CaseStatusScreen)));
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'A foreground push refreshes Case Status without waiting for the poll',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'test-id',
          fullName: 'Test Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
      );
      final case1 = await repo.reportMissing('test-id');
      await route(t, AppRoutes.caseStatus, arguments: case1.id);
      expect(find.text('Report Received'), findsWidgets);
      repo.caseRecords
        ..removeWhere((c) => c.id == case1.id)
        ..add(
          MissingCase(
            id: case1.id,
            individualId: case1.individualId,
            name: case1.name,
            age: case1.age,
            status: 'search_in_progress',
            eventId: case1.eventId,
            createdAt: case1.createdAt,
            updatedAt: DateTime.now().toUtc(),
            stages: {
              ...case1.stages,
              'search_in_progress': DateTime.now().toUtc().toIso8601String(),
            },
          ),
        );
      final before = repo.caseFetches;
      GuardianPushRefresh.instance.acceptPush({
        'role': 'guardian',
        'case_id': 'other',
        'status': 'search_in_progress',
      });
      await t.pumpAndSettle();
      expect(repo.caseFetches, before);
      repo.failNextMissingCase = true;
      GuardianPushRefresh.instance.acceptPush({
        'role': 'guardian',
        'case_id': case1.id,
        'status': 'search_in_progress',
      });
      await t.pumpAndSettle();
      expect(find.text('Report Received'), findsWidgets);
      GuardianPushRefresh.instance.didChangeAppLifecycleState(
        AppLifecycleState.resumed,
      );
      await t.pumpAndSettle();
      expect(find.text('Search in Progress'), findsWidgets);
      Navigator.pop(t.element(find.byType(CaseStatusScreen)));
      await t.pumpAndSettle();
    },
  );

  testWidgets('Individual Profile refetches after a relevant status event', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.records.add(
      const Individual(
        id: 'test-id',
        fullName: 'Test Person',
        age: 7,
        gender: 'female',
        relationship: 'child',
      ),
    );
    final value = await repo.reportMissing('test-id');
    await route(t, AppRoutes.individual, arguments: 'test-id');
    final before = repo.caseFetches;
    GuardianPushRefresh.instance.acceptPush({
      'role': 'guardian',
      'case_id': 'other',
      'status': 'resolved',
    });
    await t.pumpAndSettle();
    expect(repo.caseFetches, before);
    repo.caseRecords[0] = MissingCase(
      id: value.id,
      individualId: value.individualId,
      name: value.name,
      age: value.age,
      status: 'search_in_progress',
      eventId: value.eventId,
      createdAt: value.createdAt,
      stages: value.stages,
    );
    GuardianPushRefresh.instance.acceptPush({
      'role': 'guardian',
      'case_id': value.id,
      'status': 'search_in_progress',
    });
    await t.pumpAndSettle();
    expect(repo.caseFetches, before + 1);
    await scrollToText(t, 'Active Case');
    expect(
      t
          .widget<ReportMissingAction>(find.byType(ReportMissingAction))
          .activeCase!
          .status,
      'search_in_progress',
    );
    await repo.resolveCase(value.id);
    GuardianPushRefresh.instance.acceptPush({
      'role': 'guardian',
      'case_id': value.id,
      'status': 'resolved',
    });
    await t.pumpAndSettle();
    expect(find.text('Active Case'), findsNothing);
    expect(
      t
          .widget<ReportMissingAction>(find.byType(ReportMissingAction))
          .activeCase,
      isNull,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Refresh on the QR screen never passes a Future to setState', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    await route(t, AppRoutes.qrCode);
    expect(find.byType(GuardianQrScreen), findsOneWidget);
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('Active case locks the individual profile until resolved', (
    t,
  ) async {
    await start(t);
    auth.active = true;
    repo.records.add(
      const Individual(
        id: 'test-id',
        fullName: 'Test Person',
        age: 7,
        gender: 'female',
        relationship: 'child',
      ),
    );
    await route(t, AppRoutes.guardian);
    await tapText(t, 'Test Person');
    expect(find.text('Edit'), findsOneWidget);
    await tapText(t, 'Report Missing');
    await tapText(t, 'Confirm');
    await t.pumpAndSettle();
    Navigator.pop(t.element(find.byType(GuidedReportScreen)));
    await t.pumpAndSettle();
    // Locked: no Edit action; Delete disabled; explicit notice shown.
    // (find.text alone can't prove absence on a lazily-built list -- scroll
    // to a known-present anchor first so the whole section is realized.)
    await scrollToText(t, 'Delete Individual');
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Report Missing'), findsNothing);
    expect(
      find.text(
        'Editing and deletion are unavailable while an active case exists for this individual.',
      ),
      findsOneWidget,
    );
    final deleteButton = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Delete Individual'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(deleteButton.onPressed, isNull);
    expect(find.textContaining('#RD-TEST1'), findsWidgets);
    await tapText(t, 'Active Case');
    await t.pumpAndSettle();
    expect(find.byType(CaseStatusScreen), findsOneWidget);
    await scrollToText(t, 'Cancel Report');
    expect(find.text('Resolve Report'), findsWidgets);
    expect(find.text('Cancel Report'), findsWidgets);
    await tapText(t, 'Resolve Report');
    await tapText(t, 'Resolve Report');
    await t.pumpAndSettle();
    await scrollToText(t, 'Resolved', delta: -200);
    expect(find.text('Resolved'), findsWidgets);
    expect(find.text('Resolve Report'), findsNothing);
    expect(find.text('Cancel Report'), findsNothing);
    Navigator.pop(t.element(find.byType(CaseStatusScreen)));
    await t.pumpAndSettle();
    // Unlocked again: profile management resumes on the terminal case.
    expect(find.text('Edit'), findsOneWidget);
    await scrollToText(t, 'Report Missing');
    expect(find.text('Report Missing'), findsWidgets);
  });
  testWidgets('Forgot Password performs the real reset request and shows one '
      'confirmation regardless of whether the account exists', (t) async {
    await start(t);
    await route(t, AppRoutes.forgotPassword);
    await t.enterText(find.byType(TextFormField).first, 'someone@example.test');
    await tapText(t, 'Send Reset Instructions');
    // The request actually reached the authentication service...
    expect(auth.resetRequests, ['someone@example.test']);
    // ...and the confirmation never reveals whether that email is registered.
    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.text(
        'If an account exists for this email, password reset instructions will be sent.',
      ),
      findsOneWidget,
    );
    expect(find.text('Send Reset Instructions'), findsNothing);
    await tapText(t, 'Send again');
    expect(find.text('Send Reset Instructions'), findsOneWidget);
    await tapText(t, 'Send Reset Instructions');
    expect(auth.resetRequests, hasLength(2));
    await tapText(t, 'Back to Log In');
    expect(find.byType(AuthScreen), findsNothing);
  });
  testWidgets(
    'Home shows compact individual cards whose state control reports or '
    'tracks the real case',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'test-id',
          fullName: 'Test Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
      );
      await route(t, AppRoutes.guardian);
      expect(find.text('Age: 7'), findsOneWidget);
      expect(find.text('Active Case'), findsNothing);
      await tapText(t, 'Report Missing');
      await tapText(t, 'Confirm');
      await t.pumpAndSettle();
      expect(repo.caseRecords, hasLength(1));
      Navigator.pop(t.element(find.byType(GuidedReportScreen)));
      await t.pumpAndSettle();
      // The card now carries the Active Case chip; the Home "Active Cases"
      // section lists the real case with its id and Track Status action.
      expect(find.text('Report Missing'), findsNothing);
      expect(find.text('Active Case'), findsWidgets);
      await scrollToText(t, 'Track Status');
      expect(find.textContaining('#RD-TEST1'), findsWidgets);
      await tapText(t, 'Track Status');
      expect(find.byType(CaseStatusScreen), findsOneWidget);
      Navigator.pop(t.element(find.byType(CaseStatusScreen)));
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'Cases screen keeps closed cases out of the active count, as history',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.addAll([
        const Individual(
          id: 'a',
          fullName: 'Person A',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
        const Individual(
          id: 'b',
          fullName: 'Person B',
          age: 9,
          gender: 'male',
          relationship: 'child',
        ),
      ]);
      await repo.reportMissing('a');
      final closed = await repo.reportMissing('b');
      await repo.cancelCase(closed.id);
      await route(t, AppRoutes.cases);
      expect(find.text('ACTIVE CASES'), findsOneWidget);
      expect(find.text('CASE HISTORY'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Report Received'), findsOneWidget);
    },
  );
  testWidgets(
    'QR screen shows the account QR with the selected active case context '
    'and its case-specific identifier',
    (t) async {
      await start(t);
      auth.active = true;
      repo.records.add(
        const Individual(
          id: 'test-id',
          fullName: 'Test Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        ),
      );
      final case1 = await repo.reportMissing('test-id');
      await route(t, AppRoutes.qrCode);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Test Person'), findsWidgets);
      expect(find.text('Stage 1: Report Received'), findsOneWidget);
      await scrollToText(
        t,
        'This QR code verifies that your authenticated Guardian account is associated with this case.',
      );
      expect(
        find.text(
          'This QR code verifies that your authenticated Guardian account is associated with this case.',
        ),
        findsOneWidget,
      );
      await tapText(t, 'Show Case Identifier');
      expect(find.text('ACTIVE CASE IDENTIFIER'), findsOneWidget);
      expect(find.textContaining(case1.id), findsWidgets);
      await tapText(t, 'Close');
      expect(find.text('ACTIVE CASE IDENTIFIER'), findsNothing);
    },
  );
  for (final locale in ['en', 'ar']) {
    testWidgets(
      'Guardian forms scroll without overflow at large text in $locale',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await start(t, locale: locale);
        await route(t, AppRoutes.createAccount);
        final s = AppLocalizations.of(t.element(find.byType(AuthScreen)))!;
        await tapText(t, s.createAccount);
        expect(t.takeException(), isNull);
      },
    );
  }
}
