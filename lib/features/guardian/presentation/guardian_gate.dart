import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/session_screen.dart';
import '../../auth/presentation/auth_screen.dart';
import '../data/guardian_push_service.dart';
import '../data/guardian_repository.dart';

/// Deep links remain protected; failed authorization returns to session recovery.
class GuardianGate extends StatefulWidget {
  const GuardianGate({super.key, required this.child});
  final Widget child;
  @override
  State<GuardianGate> createState() => _GuardianGateState();
}

class _GuardianGateState extends State<GuardianGate> {
  Future<GuardianProfile>? _profile;
  bool _pushInitStarted = false;
  bool _hadAuthenticatedSession = false;
  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return StreamBuilder<bool>(
      stream: services.auth.changes,
      initialData: services.auth.signedIn,
      builder: (context, auth) {
        if (auth.data != true) {
          _profile = null;
          _pushInitStarted = false;
          // A session ending must not start onboarding and race the explicit
          // logout route. A cold unauthenticated deep link still uses startup.
          return _hadAuthenticatedSession
              ? const AuthScreen()
              : const SessionScreen();
        }
        _hadAuthenticatedSession = true;
        _profile ??= services.guardian.profile().timeout(
          const Duration(seconds: 30),
        );
        return FutureBuilder<GuardianProfile>(
          future: _profile,
          builder: (context, profile) {
            if (profile.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profile.hasError) {
              return const SessionScreen(expectedRole: 'guardian');
            }
            // Authenticated with a complete Guardian profile: normal
            // application state is now available, so this is the right
            // moment to (idempotently) set up push and act on a
            // notification tap that brought the Guardian here. Neither
            // ever blocks or replaces rendering `widget.child` below --
            // both are fire-and-forget.
            final locale = Localizations.localeOf(context).languageCode;
            if (!_pushInitStarted) {
              _pushInitStarted = true;
              GuardianPushService.initialize(services.guardian, locale).then((
                _,
              ) {
                if (!mounted || !context.mounted) return;
                final caseId = GuardianPushRouter.consumePendingCaseId();
                if (caseId != null) {
                  Navigator.of(context)
                      .pushNamed(AppRoutes.caseStatus, arguments: caseId);
                }
              });
            } else {
              // Push was already set up earlier in this session; this later
              // build (e.g. a fresh /guardian/* route push, since GuardianGate
              // is re-instantiated on every one) is the "next opportunity" to
              // notice the Guardian changed Radd's language since then, and
              // keep this installation's push language in sync -- without a
              // restart, logout, or token rotation. Fire-and-forget, like
              // initialize() above; never blocks or replaces widget.child.
              GuardianPushService.syncLocale(services.guardian, locale);
            }
            return widget.child;
          },
        );
      },
    );
  }
}
