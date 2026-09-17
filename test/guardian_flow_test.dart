import 'support/guardian_fakes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/auth/presentation/form_validation.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/individual_form_screen.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_qr_screen.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/guardian/presentation/guided_report_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

void main() {
  late TestAuth auth;
  late TestRepository repo;
  setUp(() {
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
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    final context = t.element(find.byType(LanguageSelectionScreen));
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
        relationship: 'daughter',
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
      expect(
        find.text('No cases are awaiting Guardian verification.'),
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
        relationship: 'daughter',
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
    Navigator.pop(t.element(find.byType(GuidedReportScreen)));
    await t.pumpAndSettle();
    expect(find.textContaining('Active case'), findsOneWidget);
  });
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
