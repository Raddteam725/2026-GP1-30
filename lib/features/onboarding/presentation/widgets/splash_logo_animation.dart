import 'package:flutter/material.dart';

import 'onboarding_layout.dart';

/// Each mask reveals only its piece of the supplied transparent official logo.
class SplashLogoAnimation extends StatelessWidget {
  const SplashLogoAnimation({super.key, required this.progress});
  final Animation<double> progress;
  static const asset = OnboardingLayout.logoAsset;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Radd logo',
    image: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          if (progress.value >= 0.66) {
            return Image.asset(asset, fit: BoxFit.contain);
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              _piece('light', 0.02, 0.18, const Offset(0, 0.06)),
              _piece('person', 0.24, 0.40, const Offset(0, 0.06)),
              _piece('glass', 0.46, 0.62, const Offset(0.04, 0)),
            ],
          );
        },
      ),
    ),
  );
  Widget _piece(String part, double start, double end, Offset offset) {
    final phase = progress.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
    Widget piece = ClipPath(
      clipper: _LogoRegion(part),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
    if (part == 'glass') {
      piece = RotationTransition(
        turns: phase.drive(Tween(begin: -0.025, end: 0.0)),
        child: piece,
      );
    }
    return FadeTransition(
      key: ValueKey('logo-$part'),
      opacity: phase,
      child: SlideTransition(
        position: phase.drive(Tween(begin: offset, end: Offset.zero)),
        child: ScaleTransition(
          scale: phase.drive(
            Tween(begin: part == 'glass' ? 0.9 : 0.96, end: 1.0),
          ),
          child: piece,
        ),
      ),
    );
  }
}

/// Masks follow transparent gaps around the 500 x 500 source. The light's
/// trapezoid excludes the ring ends, unlike the old rectangular crop.
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
