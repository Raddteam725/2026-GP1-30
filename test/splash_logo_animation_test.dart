import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/onboarding/presentation/widgets/splash_logo_animation.dart';

void main() {
  testWidgets('Original logo assembles light then person then glass', (
    tester,
  ) async {
    Future<void> at(double progress) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 180,
            child: SplashLogoAnimation(
              progress: AlwaysStoppedAnimation(progress),
            ),
          ),
        ),
      ),
    );
    double opacity(String part) => tester
        .widget<FadeTransition>(find.byKey(ValueKey('logo-$part')))
        .opacity
        .value;
    await at(0.15);
    expect(opacity('light'), greaterThan(0));
    expect(opacity('person'), 0);
    expect(opacity('glass'), 0);
    await at(0.35);
    expect(opacity('light'), 1);
    expect(opacity('person'), greaterThan(0));
    expect(opacity('glass'), 0);
    await at(0.58);
    expect(opacity('person'), 1);
    expect(opacity('glass'), greaterThan(0));
    await at(0.7);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage(SplashLogoAnimation.asset),
    );
    expect(tester.takeException(), isNull);
  });
}
