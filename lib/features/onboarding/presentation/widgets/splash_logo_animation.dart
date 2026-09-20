import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'onboarding_layout.dart';

/// SEARCH → FIND → RADD, told with the official logo's own pieces.
///
/// 1. The magnifying glass enters from above and settles.
/// 2. A yellow radar beam appears inside the glass and sweeps one full turn,
///    searching -- the person is not there yet.
/// 3. The sweep stops in the logo's own beam direction (straight down) and
///    hands over to the real beam of the logo.
/// 4. The person is revealed inside the beam (fade + subtle scale).
/// 5. The pieces are exactly the official composition; the plain logo asset
///    takes over for the rest of the splash. No rings, pulses or bounces.
///
/// Every piece is a masked region of the one transparent official logo, so the
/// final frame is pixel-identical to the asset.
class SplashLogoAnimation extends StatelessWidget {
  const SplashLogoAnimation({super.key, required this.progress});
  final Animation<double> progress;
  static const asset = OnboardingLayout.logoAsset;

  // Phases of the overall splash progress (see OnboardingLayout.splashDuration).
  static const glassPhase = Interval(0.0, 0.20, curve: Curves.easeOutCubic);
  static const sweepPhase = Interval(0.22, 0.58, curve: Curves.easeInOutCubic);
  static const sweepFadeIn = Interval(0.22, 0.27, curve: Curves.easeOut);
  static const sweepFadeOut = Interval(0.57, 0.62, curve: Curves.easeIn);
  static const lightPhase = Interval(0.56, 0.63, curve: Curves.easeOut);
  static const personPhase = Interval(0.61, 0.72, curve: Curves.easeOutCubic);
  static const settled = 0.74;

  /// The logo's beam points straight down; the sweep ends exactly there
  /// after one clockwise turn.
  static const finalAngle = math.pi / 2;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Radd logo',
    image: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          if (progress.value >= settled) {
            return Image.asset(asset, fit: BoxFit.contain);
          }
          final glass = progress.drive(CurveTween(curve: glassPhase));
          final sweep = progress.drive(CurveTween(curve: sweepPhase));
          final light = progress.drive(CurveTween(curve: lightPhase));
          final person = progress.drive(CurveTween(curve: personPhase));
          final radarOpacity =
              progress.drive(CurveTween(curve: sweepFadeIn)).value *
              (1 - progress.drive(CurveTween(curve: sweepFadeOut)).value);
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. The magnifying glass enters from above and settles.
              FadeTransition(
                key: const ValueKey('logo-glass'),
                opacity: glass,
                child: SlideTransition(
                  position: glass.drive(
                    Tween(begin: const Offset(0, -0.35), end: Offset.zero),
                  ),
                  child: _piece('glass'),
                ),
              ),
              // 2-3. The radar beam searches inside the glass, one full
              // turn, and stops in the logo's beam direction.
              Opacity(
                key: const ValueKey('logo-radar'),
                opacity: radarOpacity,
                child: CustomPaint(
                  painter: RadarSweepPainter(
                    angle: finalAngle - 2 * math.pi * (1 - sweep.value),
                  ),
                ),
              ),
              // 3. The real beam of the logo takes over where the sweep stops.
              FadeTransition(
                key: const ValueKey('logo-light'),
                opacity: light,
                child: _piece('light'),
              ),
              // 4. The person is found inside the beam.
              FadeTransition(
                key: const ValueKey('logo-person'),
                opacity: person,
                child: ScaleTransition(
                  scale: person.drive(Tween(begin: 0.92, end: 1.0)),
                  alignment: const Alignment(0, -0.05),
                  child: _piece('person'),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _piece(String part) => ClipPath(
    clipper: _LogoRegion(part),
    child: Image.asset(asset, fit: BoxFit.contain),
  );
}

/// The searching beam: a yellow wedge (the logo's own beam colour) rotating
/// about the magnifying glass's centre, clipped to the inside of the ring.
/// [angle] is the direction of the wedge's leading edge in radians, screen
/// convention (0 = right, pi/2 = down), in the logo's 500x500 space.
class RadarSweepPainter extends CustomPainter {
  const RadarSweepPainter({required this.angle});
  final double angle;

  // Ring geometry measured on the 500x500 asset.
  static const center = Offset(247.5, 224);
  static const radius = 106.0;
  static const sweepWidth = 1.35; // radians: a broad, soft search cone
  static const beam = Color(0xFFFEAD1D);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 500;
    canvas.save();
    canvas.scale(scale, size.height / 500);
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // Leading edge at 0 rad (brightest), trailing off behind it.
    final wedge = Path()
      ..moveTo(0, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        -sweepWidth,
        sweepWidth,
        false,
      )
      ..close();
    canvas.drawPath(
      wedge,
      Paint()
        ..shader = SweepGradient(
          startAngle: -sweepWidth,
          endAngle: 0,
          colors: [beam.withValues(alpha: 0), beam.withValues(alpha: .85)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(radius, 0),
      Paint()
        ..color = beam
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(RadarSweepPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

/// Masks follow transparent gaps around the 500 x 500 source. The light's
/// trapezoid excludes the ring ends, unlike a rectangular crop would.
class _LogoRegion extends CustomClipper<Path> {
  const _LogoRegion(this.part);
  final String part;
  @override
  Path getClip(Size size) {
    final person = Path()
      ..addOval(Rect.fromLTWH(231, 170, 35, 35))
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(219, 204, 277, 262),
          const Radius.circular(14),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(231, 249, 246, 315),
          const Radius.circular(7),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(249, 249, 264, 315),
          const Radius.circular(7),
        ),
      );
    final lightArea = Path()
      ..moveTo(225, 254)
      ..lineTo(274, 254)
      ..lineTo(330, 427)
      ..lineTo(166, 427)
      ..close();
    final light = Path.combine(PathOperation.difference, lightArea, person);
    final region = switch (part) {
      'person' => person,
      'light' => light,
      _ => Path.combine(
        PathOperation.difference,
        Path()..addRect(const Rect.fromLTWH(0, 0, 500, 500)),
        Path.combine(PathOperation.union, person, light),
      ),
    };
    return region.transform(
      Matrix4.diagonal3Values(size.width / 500, size.height / 500, 1).storage,
    );
  }

  @override
  bool shouldReclip(_LogoRegion oldClipper) => part != oldClipper.part;
}
