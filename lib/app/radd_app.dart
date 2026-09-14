import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale_scope.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/app_theme.dart';

/// Omit locale to follow the device language, with English as fallback.
class RaddApp extends StatefulWidget {
  const RaddApp({super.key, this.locale});
  final Locale? locale;
  @override
  State<RaddApp> createState() => _RaddAppState();
}

class _RaddAppState extends State<RaddApp> {
  late Locale? _locale = widget.locale;
  @override
  void didUpdateWidget(RaddApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale) _locale = widget.locale;
  }

  @override
  Widget build(BuildContext context) => AppLocaleScope(
    locale: _locale,
    setLocale: (locale) async {
      setState(() => _locale = locale);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('radd.language', locale.languageCode);
    },
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
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
    ),
  );
}
