import 'package:flutter/material.dart';

import '../../features/volunteer/presentation/volunteer_entry.dart';

import '../../features/onboarding/presentation/screens/role_selection_screen.dart';

import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/language_selection_screen.dart';
import '../localization/generated/app_localizations.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) =>
      MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => switch (settings.name) {
          AppRoutes.volunteer => const VolunteerEntry(),
          AppRoutes.root => const SplashScreen(),
          AppRoutes.languageSelection => const LanguageSelectionScreen(),
          AppRoutes.roleSelection => const RoleSelectionScreen(),
          _ => Scaffold(
            body: SafeArea(
              child: Center(
                child: Text(AppLocalizations.of(context)!.pageNotFound),
              ),
            ),
          ),
        },
      );
}
