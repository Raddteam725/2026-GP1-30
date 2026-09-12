import 'package:flutter/material.dart';

/// Session locale owned by RaddApp; no persistence or external state.
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.locale,
    required this.setLocale,
    required super.child,
  });
  final Locale? locale;
  final ValueChanged<Locale> setLocale;
  static AppLocaleScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()!;
  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) =>
      locale != oldWidget.locale;
}
