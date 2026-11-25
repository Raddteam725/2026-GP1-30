import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'onboarding_layout.dart';

class SplashLogoAnimation extends StatelessWidget {
  const SplashLogoAnimation({super.key, required this.progress});
  final Animation<double> progress;
  static const asset = OnboardingLayout.logoAsset;

  static const glassPhase = Interval(0.0, 0.20, curve: Curves.easeOutCubic);
  static const sweepPhase = Interval(0.22, 0.58, curve: Curves.easeInOutCubic);
  static const sweepFadeIn = Interval(0.22, 0.27, curve: Curves.easeOut);
  static const sweepFadeOut = Interval(0.57, 0.62, curve: Curves.easeIn);
  static const lightPhase = Interval(0.56, 0.63, curve: Curves.easeOut);
  static const personPhase = Interval(0.61, 0.72, curve: Curves.easeOutCubic);
  static const settled = 0.74;

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
              Opacity(
                key: const ValueKey('logo-radar'),
                opacity: radarOpacity,
                child: CustomPaint(
                  painter: RadarSweepPainter(
                    angle: finalAngle - 2 * math.pi * (1 - sweep.value),
                  ),
                ),
              ),
              FadeTransition(
                key: const ValueKey('logo-light'),
                opacity: light,
                child: _piece('light'),
              ),
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

class RadarSweepPainter extends CustomPainter {
  const RadarSweepPainter({required this.angle});
  final double angle;

  static const center = Offset(247.5, 224);
  static const radius = 106.0;
  static const sweepWidth = 1.35;
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
