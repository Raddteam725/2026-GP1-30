import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/theme/app_theme.dart';
import 'package:radd/shared/widgets/widgets.dart';

void main() {
  for (final language in ['en', 'ar', 'fr']) {
    testWidgets('$language resolves direction and typography', (tester) async {
      await tester.pumpWidget(RaddApp(locale: Locale(language)));
      // Splash keeps an indeterminate loading animation running.
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(find.byType(Scaffold));
      expect(
        Directionality.of(context),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(
        Theme.of(context).textTheme.bodyMedium!.fontFamily,
        language == 'ar' ? 'Tajawal' : 'Inter',
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  Widget harness(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(const Locale('en')),
    home: Scaffold(body: child),
  );

  testWidgets('Password visibility preserves entered text', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(PasswordInput(label: 'Password', controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'sample-password');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
    expect(controller.text, 'sample-password');
  });

  testWidgets('Loading buttons prevent duplicate actions at 360 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      harness(
        Column(
          children: [
            PrimaryButton(
              label: 'Continue',
              isLoading: true,
              onPressed: () => calls++,
            ),
            SecondaryButton(
              label: 'Back',
              isLoading: true,
              onPressed: () => calls++,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(OutlinedButton));
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
