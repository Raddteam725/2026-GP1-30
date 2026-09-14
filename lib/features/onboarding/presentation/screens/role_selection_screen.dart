import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_spacing.dart';
import '../widgets/onboarding_background.dart';
import '../widgets/onboarding_selection_card.dart';

enum OnboardingRole { guardian, volunteer }

/// Keeps role choice local until the approved account-access flow is added.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  OnboardingRole? _selectedRole;
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CustomPaint(painter: OnboardingBackground()),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: Padding(
                        padding: AppSpacing.pagePadding,
                        child: Column(
                          children: [
                            const Gap(AppSpacing.lg),
                            SizedBox.square(
                              dimension: 112,
                              child: Stack(
                                children: [
                                  Image.asset(
                                    'assets/images/radd_logo.png',
                                    semanticLabel: strings.appTitle,
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 0,
                                    child: ExcludeSemantics(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(AppSpacing.xl),
                            Text(
                              strings.chooseRole,
                              textAlign: TextAlign.center,
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Gap(AppSpacing.xl),
                            OnboardingSelectionCard(
                              key: const ValueKey('guardian-role'),
                              label: strings.guardianRole,
                              selected:
                                  _selectedRole == OnboardingRole.guardian,
                              onTap: () => setState(
                                () => _selectedRole = OnboardingRole.guardian,
                              ),
                            ),
                            const Gap(AppSpacing.md),
                            OnboardingSelectionCard(
                              key: const ValueKey('volunteer-role'),
                              label: strings.volunteerRole,
                              selected:
                                  _selectedRole == OnboardingRole.volunteer,
                              onTap: () => setState(
                                () => _selectedRole = OnboardingRole.volunteer,
                              ),
                            ),
                            const Gap(AppSpacing.lg),
                            if (_selectedRole != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  strings.selectedRole(
                                    _selectedRole == OnboardingRole.guardian
                                        ? strings.guardianRole
                                        : strings.volunteerRole,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium,
                                ),
                              ),
                            if (_selectedRole == OnboardingRole.volunteer)
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.volunteer),
                                child: Text(strings.continueLabel),
                              ),
                            const Spacer(),
                            const Gap(AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
