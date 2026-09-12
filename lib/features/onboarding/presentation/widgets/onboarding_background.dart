import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.46;
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.12),
      radius,
      Paint()..color = AppColors.lightBlue.withValues(alpha: 0.045),
    );
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 0.73),
      radius * 0.9,
      Paint()..color = AppColors.secondary.withValues(alpha: 0.035),
    );
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 0.73),
      radius * 1.12,
      Paint()
        ..color = AppColors.lightBlue.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(OnboardingBackground oldDelegate) => false;
}
