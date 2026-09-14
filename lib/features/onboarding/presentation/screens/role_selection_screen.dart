import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../widgets/onboarding_layout.dart';
import '../widgets/onboarding_selection_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return OnboardingPage(
      title: s.joinRadd,
      subtitle: s.roleHint,
      showBack: Navigator.of(context).canPop(),
      content: Column(
        children: [
          OnboardingSelectionCard(
            key: const ValueKey('guardian-role'),
            label: s.guardianRole,
            icon: Icons.shield_outlined,
            subtitle: s.guardianDescription,
            isRole: true,
            selected: false,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.auth),
          ),
          const SizedBox(height: OnboardingLayout.cardGap),
          OnboardingSelectionCard(
            key: const ValueKey('volunteer-role'),
            label: s.volunteerRole,
            icon: Icons.badge_outlined,
            subtitle: s.volunteerDescription,
            isRole: true,
            selected: false,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.volunteerLogin),
          ),
        ],
      ),
    );
  }
}
