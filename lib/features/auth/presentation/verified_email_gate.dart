import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../data/auth_service.dart';
import '../data/registration_draft.dart';
import 'email_verification_screen.dart';
import 'session_screen.dart';

/// Prevent deep links from presenting remaining onboarding to an unverified
/// account. The API independently enforces verification before profile writes.
class VerifiedEmailGate extends StatefulWidget {
  const VerifiedEmailGate({super.key, required this.child});
  final Widget child;
  @override
  State<VerifiedEmailGate> createState() => _VerifiedEmailGateState();
}

class _VerifiedEmailGateState extends State<VerifiedEmailGate> {
  Future<AuthIdentity>? _identity;
  String? _pendingEmail;

  Future<AuthIdentity> _loadIdentity() async {
    final identity = await AppServices.of(context).auth.refreshIdentity();
    try {
      _pendingEmail =
          (await RegistrationDraft.read(identity.uid))['pendingEmail']
              as String?;
    } catch (_) {}
    return identity;
  }

  @override
  Widget build(BuildContext context) {
    _identity ??= _loadIdentity();
    return FutureBuilder<AuthIdentity>(
      future: _identity,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SessionScreen(expectedRole: 'guardian');
        }
        if (snapshot.data?.emailVerified != true ||
            (_pendingEmail != null &&
                snapshot.data?.email.toLowerCase() !=
                    _pendingEmail!.toLowerCase())) {
          return const EmailVerificationScreen();
        }
        return widget.child;
      },
    );
  }
}
