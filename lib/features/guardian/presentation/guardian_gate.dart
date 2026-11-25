import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/session_screen.dart';
import '../../auth/presentation/auth_screen.dart';
import '../data/guardian_push_service.dart';
import '../data/guardian_repository.dart';

class GuardianGate extends StatefulWidget {
  const GuardianGate({super.key, required this.child});
  final Widget child;
  @override
  State<GuardianGate> createState() => _GuardianGateState();
}

class _GuardianGateState extends State<GuardianGate> {
  @override
  void initState() {
    super.initState();
    GuardianPushRefresh.instance.addListener(_handleNotificationTap);
  }

  void _handleNotificationTap() {
    if (!mounted ||
        !_pushInitStarted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final caseId = GuardianPushRouter.consumePendingCaseId();
    final foundReportId = GuardianPushRouter.consumePendingFoundReportId();
    if (foundReportId != null && AppServices.of(context).auth.signedIn) {
      Navigator.of(context).pushNamed(AppRoutes.qrCode);
    }
    if (caseId != null && AppServices.of(context).auth.signedIn) {
      Navigator.of(context).pushNamed(AppRoutes.caseStatus, arguments: caseId);
    }
  }

  @override
  void dispose() {
    GuardianPushRefresh.instance.removeListener(_handleNotificationTap);
    super.dispose();
  }

  Future<GuardianProfile>? _profile;
  bool _pushInitStarted = false;
  bool _hadAuthenticatedSession = false;
  Future<GuardianProfile> _verifiedProfile() async {
    final services = AppServices.of(context);
    final identity = await services.auth.refreshIdentity();
    if (!identity.emailVerified) throw const AppFailure('emailVerification');
    return services.guardian.profile();
  }

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
          return _hadAuthenticatedSession
              ? const AuthScreen()
              : const SessionScreen();
        }
        _hadAuthenticatedSession = true;
        _profile ??= _verifiedProfile().timeout(const Duration(seconds: 30));
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
            final locale = Localizations.localeOf(context).languageCode;
            if (!_pushInitStarted) {
              _pushInitStarted = true;
              GuardianPushService.initialize(services.guardian, locale).then((
                _,
              ) {
                if (!mounted || !context.mounted) return;
                final caseId = GuardianPushRouter.consumePendingCaseId();
                final foundReportId =
                    GuardianPushRouter.consumePendingFoundReportId();
                if (foundReportId != null) {
                  Navigator.of(context).pushNamed(AppRoutes.qrCode);
                }
                if (caseId != null) {
                  Navigator.of(context)
                      .pushNamed(AppRoutes.caseStatus, arguments: caseId);
                }
              });
            } else {
              GuardianPushService.syncLocale(services.guardian, locale);
            }
            return widget.child;
          },
        );
      },
    );
  }
}
