// Explicit manual UI fixture only. Production always starts at lib/main.dart.
import 'package:flutter/material.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';

import 'support/guardian_fakes.dart';

void main() {
  if (!const bool.fromEnvironment('RADD_UI_TEST')) {
    throw StateError(
      'Use lib/main.dart for the real app. UI tests require RADD_UI_TEST=true.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  final auth = TestAuth()..active = true;
  runApp(
    AppServices(
      auth: auth,
      guardian: TestRepository(),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'UI TEST - NO CLOUD',
          location: BannerLocation.topEnd,
          child: RaddApp(locale: Locale('en')),
        ),
      ),
    ),
  );
}
