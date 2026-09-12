import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static String fontFamily(Locale locale) =>
      locale.languageCode == 'ar' ? 'Tajawal' : 'Inter';
  // Refine screen-specific sizes against approved Stitch references.
  static TextTheme textTheme(Locale locale) =>
      ThemeData.light().textTheme.apply(
        fontFamily: fontFamily(locale),
        fontFamilyFallback: const ['Inter', 'Tajawal'],
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      );
}
