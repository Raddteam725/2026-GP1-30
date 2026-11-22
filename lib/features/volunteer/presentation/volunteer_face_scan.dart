import 'package:flutter/material.dart';

import 'volunteer_components.dart';

/// Visual feedback while the backend matches the captured face. It only
/// shows that work is in progress; it does not depict real processing stages
/// or progress. Honors the platform "reduce motion" setting.
class FaceScanView extends StatefulWidget {
  const FaceScanView({
    super.key,
    required this.image,
    this.width = 220,
    this.height = 264,
  });
  final Widget image;
  final double width, height;
  @override
  State<FaceScanView> createState() => _FaceScanViewState();
}

class _FaceScanViewState extends State<FaceScanView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scan.stop();
    } else if (!_scan.isAnimating) {
      _scan.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width + 24,
        height: widget.height + 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.image,
                    // Slight tint so the scan line reads on light photos.
                    const ColoredBox(color: Color(0x14000000)),
                    if (!still)
                      AnimatedBuilder(
                        animation: _scan,
                        builder: (context, _) {
                          final t = Curves.easeInOut.transform(_scan.value);
                          return Align(
                            alignment: Alignment(0, -1 + 2 * t),
                            child: const _ScanLine(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _CornerPainter(volunteerTeal)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    width: double.infinity,
    child: Stack(
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                volunteerTeal.withValues(alpha: 0),
                volunteerTeal.withValues(alpha: .22),
                volunteerTeal.withValues(alpha: 0),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Container(height: 2, color: volunteerTeal.withValues(alpha: .9)),
      ],
    ),
  );
}

/// Four face-detection style corner brackets around the photograph.
class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 2.0, arm = 34.0, r = 14.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final l = inset,
        t = inset,
        rt = size.width - inset,
        b = size.height - inset;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * arm)
          ..lineTo(x, y + dy * r)
          ..arcToPoint(
            Offset(x + dx * r, y),
            radius: const Radius.circular(r),
            clockwise: dx * dy > 0,
          )
          ..lineTo(x + dx * arm, y),
        paint,
      );
    }

    corner(l, t, 1, 1);
    corner(rt, t, -1, 1);
    corner(l, b, 1, -1);
    corner(rt, b, -1, -1);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
