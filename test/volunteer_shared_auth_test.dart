import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
      'Volunteer uses shared login, validation and password reset in $language',
      (tester) async {
        final auth = TestAuth();
        addTearDown(auth.events.close);
        await tester.pumpWidget(
          AppServices(
            auth: auth,
            guardian: TestRepository(),
            child: RaddApp(locale: Locale(language)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 3800));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(LanguageSelectionScreen)))
            .pushNamed(AppRoutes.volunteerLogin);
        await tester.pumpAndSettle();
        expect(
          tester.widget<AuthScreen>(find.byType(AuthScreen)).volunteer,
          isTrue,
        );
        final s = AppLocalizations.of(tester.element(find.byType(AuthScreen)))!;
        final forgot = find.text(s.forgotPassword);
        await tester.ensureVisible(forgot);
        await tester.tap(forgot);
        await tester.pumpAndSettle();
        expect(
          tester.widget<AuthScreen>(find.byType(AuthScreen).last).mode,
          AuthMode.reset,
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'volunteer@example.test',
        );
        final send = find.text(s.sendReset);
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(auth.resetRequests, ['volunteer@example.test']);
        expect(find.text(s.resetSent), findsOneWidget);
      },
    );
  }

  testWidgets('Account role wins over Volunteer login selection', (
    tester,
  ) async {
    final auth = TestAuth();
    addTearDown(auth.events.close);
    // TestRepository resolves a real backend-role response shape of Guardian.
    await tester.pumpWidget(
      AppServices(
        auth: auth,
        guardian: TestRepository(),
        child: const RaddApp(locale: Locale('en')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 3800));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(LanguageSelectionScreen)))
        .pushNamed(AppRoutes.volunteerLogin);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'guardian@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'ValidPass1!');
    await tester.ensureVisible(find.text('Log In').last);
    await tester.tap(find.text('Log In').last);
    await tester.pumpAndSettle();
    expect(auth.logins, 1);
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
  });
}
