import 'package:flutter/material.dart';

import '../../features/volunteer/presentation/volunteer_entry.dart';

import '../../app/app_services.dart';
import '../../features/auth/presentation/session_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/guardian/data/guardian_repository.dart';
import '../../features/guardian/presentation/guardian_gate.dart';
import '../../features/guardian/presentation/guardian_home_screen.dart';
import '../../features/guardian/presentation/individual_form_screen.dart';
import '../../features/guardian/presentation/individual_profile_screen.dart';
import '../../features/guardian/presentation/edit_guardian_profile_screen.dart';
import '../../features/guardian/presentation/camera_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/language_selection_screen.dart';
import '../localization/generated/app_localizations.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
  ) => MaterialPageRoute<dynamic>(
    settings: settings,
    builder: (context) {
      final screen = switch (settings.name) {
        AppRoutes.root => const SplashScreen(),
        AppRoutes.languageSelection => LanguageSelectionScreen(
          returnToCaller: settings.arguments == true,
        ),
        AppRoutes.roleSelection => const RoleSelectionScreen(),
        AppRoutes.session => SessionScreen(
          expectedRole: settings.arguments is String
              ? settings.arguments as String
              : null,
        ),
        AppRoutes.volunteerLogin ||
        AppRoutes.volunteer => const VolunteerEntry(),
        AppRoutes.completeProfile => const AuthScreen(
          mode: AuthMode.completeProfile,
        ),
        AppRoutes.auth => const AuthScreen(),
        AppRoutes.createAccount => const AuthScreen(mode: AuthMode.register),
        AppRoutes.forgotPassword => const AuthScreen(mode: AuthMode.reset),
        AppRoutes.privacy => const PrivacyScreen(),
        AppRoutes.guardian => GuardianHomeScreen(
          initialTab:
              settings.arguments is int &&
                  [0, 1, 4].contains(settings.arguments)
              ? settings.arguments as int
              : 0,
        ),
        AppRoutes.addIndividual => const IndividualFormScreen(),
        AppRoutes.individual when settings.arguments is String =>
          IndividualProfileScreen(id: settings.arguments as String),
        AppRoutes.editIndividual when settings.arguments is Individual =>
          IndividualFormScreen(individual: settings.arguments as Individual),
        AppRoutes.editGuardianProfile
            when settings.arguments is GuardianProfile =>
          EditGuardianProfileScreen(
            profile: settings.arguments as GuardianProfile,
          ),
        AppRoutes.camera => const CameraScreen(),
        _ => Scaffold(
          body: SafeArea(
            child: Center(
              child: Text(AppLocalizations.of(context)!.pageNotFound),
            ),
          ),
        ),
      };
      if (settings.name?.startsWith('/guardian') == true) {
        if (AppServices.maybeOf(context) == null) return const AuthScreen();
        return GuardianGate(child: screen);
      }
      return screen;
    },
  );
}
