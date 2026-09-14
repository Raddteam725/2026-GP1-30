import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.58;
    final outline = Paint()
      ..color = AppColors.lightBlue.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.49),
      radius,
      outline,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.49),
      radius * 0.83,
      outline,
    );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.04),
      radius * 0.55,
      Paint()..color = AppColors.lightBlue.withValues(alpha: 0.035),
    );
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.94),
      radius * 0.65,
      Paint()..color = AppColors.secondary.withValues(alpha: 0.025),
    );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.25),
      4,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(OnboardingBackground oldDelegate) => false;
}
