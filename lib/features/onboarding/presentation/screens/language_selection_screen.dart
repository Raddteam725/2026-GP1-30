import 'package:flutter/material.dart';

import '../../../../app/app_locale_scope.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../widgets/onboarding_background.dart';
import '../widgets/onboarding_selection_card.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_spacing.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Applies the chosen language immediately and continues through AppRouter.
class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final strings = AppLocalizations.of(context)!;
    final localeState = AppLocaleScope.of(context);
    final selectedLanguage = Localizations.localeOf(context).languageCode;
    return Scaffold(
      body: Directionality(
        textDirection: Directionality.of(context),
        child: Stack(
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
                              const Gap(AppSpacing.xl),
                              const Spacer(),
                              SizedBox.square(
                                dimension: 112,
                                child: Stack(
                                  children: [
                                    Image.asset(
                                      'assets/images/radd_logo.png',
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Radd logo',
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
                                strings.chooseLanguage,
                                textAlign: TextAlign.center,
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  height: 1.3,
                                ),
                              ),
                              const Gap(AppSpacing.xl),
                              OnboardingSelectionCard(
                                label: 'English',
                                selected: selectedLanguage == 'en',
                                onTap: () =>
                                    localeState.setLocale(const Locale('en')),
                                fontFamily: 'Inter',
                              ),
                              const Gap(AppSpacing.md),
                              OnboardingSelectionCard(
                                label: 'العربية',
                                selected: selectedLanguage == 'ar',
                                onTap: () =>
                                    localeState.setLocale(const Locale('ar')),
                                fontFamily: 'Tajawal',
                              ),
                              const Gap(AppSpacing.xl),
                              const Spacer(flex: 3),
                              // Role selection is registered in the existing routing layer.
                              PrimaryButton(
                                label: strings.continueLabel,
                                onPressed: () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.roleSelection),
                              ),
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
      ),
    );
  }
}
