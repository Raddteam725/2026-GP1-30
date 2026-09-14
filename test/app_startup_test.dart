import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_startup.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

void main() {
  AppStartupData ready(TestAuth auth) => AppStartupData(
    auth: auth,
    guardian: TestRepository(),
    locale: const Locale('en'),
    saveLocale: (_) async {},
  );

  testWidgets('First frame renders Splash before initialization completes', (
    t,
  ) async {
    final pending = Completer<AppStartupData>();
    await t.pumpWidget(RaddApp(initialize: () => pending.future));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFF9FBFD),
    );
    await t.pump(const Duration(seconds: 5));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    await t.pumpWidget(const SizedBox());
    final auth = TestAuth();
    pending.complete(ready(auth));
    await t.pump();
    await auth.events.close();
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Initialization exception renders visible retry and can recover',
    (t) async {
      final auth = TestAuth();
      var attempts = 0;
      await t.pumpWidget(
        RaddApp(
          initialize: () async {
            if (++attempts == 1) throw StateError('initialization failed');
            return ready(auth);
          },
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Unable to start Radd'), findsOneWidget);
      await t.tap(find.text('Try Again'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 3800));
      await t.pumpAndSettle();
      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await auth.events.close();
    },
  );

  testWidgets('Never-completing initialization times out to visible recovery', (
    t,
  ) async {
    await t.pumpWidget(
      RaddApp(initialize: () => Completer<AppStartupData>().future),
    );
    await t.pump(const Duration(seconds: 45));
    await t.pumpAndSettle();
    expect(find.text('Unable to start Radd'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
