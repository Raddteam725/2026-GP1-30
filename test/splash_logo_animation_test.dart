import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/onboarding/presentation/widgets/splash_logo_animation.dart';

void main() {
  testWidgets('Logo tells SEARCH -> FIND -> RADD: glass enters, beam sweeps a full '
      'turn without the person, stops in the logo direction, then the person '
      'appears and the official logo settles', (tester) async {
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
    double fade(String part) => tester
        .widget<FadeTransition>(find.byKey(ValueKey('logo-$part')))
        .opacity
        .value;
    double radarOpacity() => tester
        .widget<Opacity>(find.byKey(const ValueKey('logo-radar')))
        .opacity;
    double radarAngle() =>
        (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byKey(const ValueKey('logo-radar')),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter
                as RadarSweepPainter)
            .angle;

    // 1. Clean start, then only the magnifying glass is entering.
    await at(0.0);
    expect(fade('glass'), 0);
    expect(radarOpacity(), 0);
    expect(fade('person'), 0);
    expect(fade('light'), 0);
    await at(0.10);
    expect(fade('glass'), greaterThan(0));
    expect(radarOpacity(), 0);
    expect(fade('person'), 0);

    // 2. The glass has settled; the radar beam is searching -- still no person.
    await at(0.40);
    expect(fade('glass'), 1);
    expect(radarOpacity(), 1);
    expect(fade('person'), 0);
    expect(fade('light'), 0);
    final midSweep = radarAngle();
    expect(midSweep, greaterThan(SplashLogoAnimation.finalAngle - 2 * math.pi));
    expect(midSweep, lessThan(SplashLogoAnimation.finalAngle));

    // 3. One full turn later the beam stops exactly in the logo's direction.
    await at(0.58);
    expect(radarAngle(), closeTo(SplashLogoAnimation.finalAngle, 1e-9));
    expect(fade('person'), 0);

    // 4. The real beam takes over and the person is revealed inside it.
    await at(0.66);
    expect(fade('light'), 1);
    expect(fade('person'), greaterThan(0));
    expect(radarOpacity(), 0);

    // 5. The official logo, unchanged.
    await at(0.75);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage(SplashLogoAnimation.asset),
    );
    // No radar left behind, and nothing else painted around the logo (no
    // rings, no pulses) -- the plain asset alone.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is RadarSweepPainter,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
