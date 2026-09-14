import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_service.dart';
import '../features/guardian/data/guardian_api.dart';
import '../features/guardian/data/guardian_repository.dart';
import '../firebase_options.dart';

class AppStartupData {
  const AppStartupData({
    required this.auth,
    required this.guardian,
    required this.locale,
    required this.saveLocale,
  });
  final AuthService auth;
  final GuardianRepository guardian;
  final Locale locale;
  final Future<void> Function(Locale) saveLocale;
}

/// Called after the first Flutter frame, never before runApp.
Future<AppStartupData> initializeApp() async {
  Future<T> step<T>(String name, Future<T> Function() action) async {
    debugPrint('Radd startup: $name begin');
    try {
      final result = await action().timeout(const Duration(seconds: 15));
      debugPrint('Radd startup: $name ready');
      return result;
    } catch (error) {
      // No account identifiers, passwords, tokens or error payloads.
      debugPrint('Radd startup: $name failed (${error.runtimeType})');
      rethrow;
    }
  }

  await step(
    'Firebase',
    () =>
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  await step(
    'orientation',
    () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  final preferences = await step('preferences', SharedPreferences.getInstance);
  final auth = FirebaseAuth.instance;
  return AppStartupData(
    auth: FirebaseAuthService(auth),
    guardian: GuardianApi(
      token: () => auth.currentUser?.getIdToken() ?? Future.value(null),
    ),
    locale: Locale(
      (preferences.getString('language') ??
                  preferences.getString('radd.language')) ==
              'ar'
          ? 'ar'
          : 'en',
    ),
    saveLocale: (locale) async {
      final saved = await preferences.setString(
        'language',
        locale.languageCode,
      );
      if (!saved) throw StateError('Locale preference could not be saved');
    },
  );
}
