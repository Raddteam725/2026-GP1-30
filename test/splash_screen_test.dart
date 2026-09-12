import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/core/theme/app_theme.dart';
import 'package:radd/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

void main() {
  testWidgets('Root displays the logo then replaces splash after two seconds', (
    tester,
  ) async {
    await tester.pumpWidget(const RaddApp(locale: Locale('en')));
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(SplashScreen)))!.settings.name,
      AppRoutes.root,
    );
    expect(find.text('Radd'), findsOneWidget);
    expect(find.text('Bringing People Back Together'), findsOneWidget);
    expect(find.text('A safer tomorrow for every journey'), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage(SplashScreen.logoAsset),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    final languageContext = tester.element(
      find.byType(LanguageSelectionScreen),
    );
    expect(
      ModalRoute.of(languageContext)!.settings.name,
      AppRoutes.languageSelection,
    );
    expect(Navigator.of(languageContext).canPop(), isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 800),
    const Size(320, 568),
    const Size(600, 960),
  ]) {
    testWidgets('Responsive splash at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(const Locale('en')),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: const SplashScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.4,
      );
      await tester.ensureVisible(
        find.text('A safer tomorrow for every journey'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Entrance is staggered and loading remains animated', (
    tester,
  ) async {
    await tester.pumpWidget(const RaddApp(locale: Locale('en')));
    final fade = find
        .ancestor(of: find.text('Radd'), matching: find.byType(FadeTransition))
        .first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.widget<FadeTransition>(fade).opacity.value, greaterThan(0));
    expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
