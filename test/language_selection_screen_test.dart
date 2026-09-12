import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:radd/features/onboarding/presentation/widgets/onboarding_selection_card.dart';

void main() {
  Future<void> openLanguage(WidgetTester tester) async {
    await tester.pumpWidget(const RaddApp(locale: Locale('en')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  OnboardingSelectionCard languageCard(WidgetTester tester, String label) =>
      tester
          .widgetList<OnboardingSelectionCard>(
            find.byType(OnboardingSelectionCard),
          )
          .singleWhere((card) => card.label == label);

  testWidgets('Language changes selected state, direction, text and font', (
    tester,
  ) async {
    await openLanguage(tester);
    expect(languageCard(tester, 'English').selected, isTrue);
    expect(languageCard(tester, 'العربية').selected, isFalse);
    var context = tester.element(find.byType(LanguageSelectionScreen));
    expect(Directionality.of(context), TextDirection.ltr);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(LanguageSelectionScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context).languageCode, 'ar');
    expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Tajawal');
    expect(
      find.text(AppLocalizations.of(context)!.chooseLanguage),
      findsOneWidget,
    );
    expect(languageCard(tester, 'English').selected, isFalse);
    expect(languageCard(tester, 'العربية').selected, isTrue);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(LanguageSelectionScreen));
    expect(Directionality.of(context), TextDirection.ltr);
    expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(languageCard(tester, 'English').selected, isTrue);
    expect(languageCard(tester, 'العربية').selected, isFalse);
  });

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Continue opens Role Selection in $language; both roles respond',
      (tester) async {
        await openLanguage(tester);
        if (language == 'ar') {
          await tester.tap(find.text('العربية'));
          await tester.pumpAndSettle();
        }
        var context = tester.element(find.byType(LanguageSelectionScreen));
        final strings = AppLocalizations.of(context)!;
        expect(find.text(strings.continueLabel).hitTestable(), findsOneWidget);
        await tester.tap(find.text(strings.continueLabel));
        await tester.pumpAndSettle();
        context = tester.element(find.byType(RoleSelectionScreen));
        expect(ModalRoute.of(context)!.settings.name, AppRoutes.roleSelection);
        expect(
          Directionality.of(context),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        final guardian = find.byKey(const ValueKey('guardian-role'));
        final volunteer = find.byKey(const ValueKey('volunteer-role'));
        expect(
          tester.widget<OnboardingSelectionCard>(guardian).selected,
          isFalse,
        );
        expect(
          tester.widget<OnboardingSelectionCard>(volunteer).selected,
          isFalse,
        );
        await tester.tap(guardian);
        await tester.pump();
        expect(
          tester.widget<OnboardingSelectionCard>(guardian).selected,
          isTrue,
        );
        expect(
          find.text(strings.selectedRole(strings.guardianRole)),
          findsOneWidget,
        );
        await tester.tap(volunteer);
        await tester.pump();
        expect(
          tester.widget<OnboardingSelectionCard>(guardian).selected,
          isFalse,
        );
        expect(
          tester.widget<OnboardingSelectionCard>(volunteer).selected,
          isTrue,
        );
        expect(
          find.text(strings.selectedRole(strings.volunteerRole)),
          findsOneWidget,
        );
        expect(find.byType(OnboardingSelectionCard), findsNWidgets(2));
        expect(
          find.textContaining(
            RegExp('Admin|Sign Up|مسؤول|إنشاء حساب', caseSensitive: false),
          ),
          findsNothing,
        );
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        context = tester.element(find.byType(LanguageSelectionScreen));
        expect(Localizations.localeOf(context).languageCode, language);
        expect(Navigator.of(context).canPop(), isFalse);
        expect(find.byType(SplashScreen), findsNothing);
      },
    );
  }

  for (final size in [
    const Size(360, 800),
    const Size(320, 568),
    const Size(600, 960),
  ]) {
    testWidgets('Onboarding remains usable with large text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openLanguage(tester);
      await tester.scrollUntilVisible(find.text('Continue'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final volunteer = find.byKey(const ValueKey('volunteer-role'));
      await tester.scrollUntilVisible(volunteer, 200);
      await tester.pumpAndSettle();
      await tester.tap(volunteer);
      await tester.pump();
      expect(
        tester.widget<OnboardingSelectionCard>(volunteer).selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Removing splash cancels delayed navigation', (tester) async {
    await tester.pumpWidget(const RaddApp(locale: Locale('en')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
