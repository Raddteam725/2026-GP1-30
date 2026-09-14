import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../auth/presentation/session_screen.dart';
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
  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return StreamBuilder<bool>(
      stream: services.auth.changes,
      initialData: services.auth.signedIn,
      builder: (context, auth) {
        if (auth.data != true) {
          _profile = null;
          return const SessionScreen();
        }
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
            return widget.child;
          },
        );
      },
    );
  }
}
