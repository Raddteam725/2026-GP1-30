import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../guardian/data/guardian_push_service.dart';
import '../../guardian/data/guardian_repository.dart';

/// Resolves identity, then the server-owned role, then the role's profile.
/// Locale is deliberately not an input to authentication or authorization.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, this.expectedRole});
  final String? expectedRole;
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _loading = true;
  bool _leaving = false;
  String? _failure;
  String? _role;
  int _revision = 0;
  StreamSubscription<bool>? _authEvents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authEvents != null) return;
    final auth = AppServices.of(context).auth;
    _authEvents = auth.changes.listen(
      (signedIn) {
        if (!signedIn && mounted) _onboarding();
      },
      onError: (Object error) {
        if (!mounted || _leaving) return;
        _revision++;
        setState(() {
          _loading = false;
          _failure = 'service';
        });
        debugPrint('Radd session: auth stream failed (${error.runtimeType})');
      },
    );
    _resolve();
  }

  void _onboarding() {
    if (_leaving) return;
    _leaving = true;
    _revision++;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.languageSelection, (_) => false);
  }

  Future<void> _resolve() async {
    final revision = ++_revision;
    final services = AppServices.of(context);
    setState(() {
      _loading = true;
      _failure = null;
      _role = null;
    });
    try {
      final signedIn = await services.auth.restoreSession().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted || revision != _revision) return;
      if (!signedIn) {
        _onboarding();
        return;
      }
      final role = await services.guardian.accountRole().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted || revision != _revision) return;
      if (widget.expectedRole != null && widget.expectedRole != role) {
        throw const AppFailure('role');
      }
      if (role == 'guardian') {
        // Do not enter a protected destination until its real profile is valid.
        await services.guardian.profile().timeout(const Duration(seconds: 30));
        if (!mounted || revision != _revision) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.guardian, (_) => false);
        return;
      }
      if (role != 'volunteer') throw const AppFailure('role');
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.volunteer, (_) => false);
    } catch (error) {
      if (!mounted || revision != _revision) return;
      final code = error is AppFailure ? error.code : 'service';
      if (code == 'notFound' && widget.expectedRole == 'guardian') {
        Navigator.of(context).pushReplacementNamed(AppRoutes.completeProfile);
        return;
      }
      setState(() {
        _failure = code;
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    if (_loading) return;
    final services = AppServices.of(context);
    setState(() => _loading = true);
    try {
      // Must happen before signing out -- it needs this account's still-valid
      // ID token to authorize removing this installation's own registration.
      // A no-op if this was never a Guardian session with push set up; never
      // throws, so it can't turn a normal sign-out into a failed one.
      await GuardianPushService.handleLogout(services.guardian);
      await services.auth.logout();
      if (mounted) _onboarding();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = 'service';
        });
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    _authEvents?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FeaturePage(
      title: _loading ? s.restoringSession : s.sessionRecovery,
      children: [
        if (_loading) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
          Text(s.restoringSessionHint, textAlign: TextAlign.center),
        ] else ...[
          Text(
            _role == 'volunteer'
                ? s.volunteerUnavailable
                : _failure == 'notFound'
                ? s.missingProfileRecovery
                : _failure == 'unauthorized'
                ? s.expiredSessionRecovery
                : _failure == 'role'
                ? s.roleRecovery
                : s.sessionUnavailable,
          ),
          const SizedBox(height: 24),
          if (_role == null) PrimaryButton(label: s.retry, onPressed: _resolve),
          if (_failure == 'notFound')
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.completeProfile),
              child: Text(s.completeGuardianProfile),
            ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false),
            child: Text(s.returnToRoles),
          ),
          TextButton(onPressed: _signOut, child: Text(s.logout)),
        ],
      ],
    );
  }
}
