import 'package:flutter/material.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/app_theme.dart';

/// Omit locale to follow the device language, with English as fallback.
class RaddApp extends StatelessWidget {
  const RaddApp({super.key, this.locale});
  final Locale? locale;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    theme: AppTheme.light(const Locale('en')),
    builder: (context, child) => Theme(
      data: AppTheme.light(Localizations.localeOf(context)),
      child: child!,
    ),
    initialRoute: AppRoutes.root,
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
