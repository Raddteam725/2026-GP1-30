import 'package:flutter/material.dart';

import '../../../../app/app_locale_scope.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/onboarding_layout.dart';
import '../widgets/onboarding_selection_card.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key, this.returnToCaller = false});
  final bool returnToCaller;
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final localeState = AppLocaleScope.of(context);
    final selected = Localizations.localeOf(context).languageCode;
    return OnboardingPage(
      title: strings.chooseLanguage,
      showBack: returnToCaller,
      subtitle: strings.languageHint,
      content: Column(
        children: [
          OnboardingSelectionCard(
            label: 'English',
            icon: Icons.language,
            subtitle: selected == 'en'
                ? strings.currentSelection
                : strings.englishLanguage,
            selected: selected == 'en',
            fontFamily: 'Inter',
            onTap: () => localeState.setLocale(const Locale('en')),
          ),
          const SizedBox(height: OnboardingLayout.cardGap),
          OnboardingSelectionCard(
            label: 'العربية',
            icon: Icons.language,
            subtitle: selected == 'ar'
                ? strings.currentSelection
                : strings.arabicLanguage,
            selected: selected == 'ar',
            fontFamily: 'Tajawal',
            onTap: () => localeState.setLocale(const Locale('ar')),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: OnboardingLayout.buttonHeight,
            ),
            child: PrimaryButton(
              label: strings.continueLabel,
              onPressed: () => returnToCaller
                  ? Navigator.of(context).pop()
                  : Navigator.of(context).pushNamed(AppRoutes.roleSelection),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.brandFooter,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.5,
              color: AppColors.text.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
