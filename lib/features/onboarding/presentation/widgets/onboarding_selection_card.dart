import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_layout.dart';

class OnboardingSelectionCard extends StatelessWidget {
  const OnboardingSelectionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontFamily,
    this.subtitle,
    this.icon,
    this.isRole = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? fontFamily;
  final String? subtitle;
  final IconData? icon;
  final bool isRole;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    selected: isRole ? null : selected,
    button: true,
    inMutuallyExclusiveGroup: !isRole,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: selected
            ? AppColors.secondary.withValues(alpha: 0.055)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OnboardingLayout.radius),
          side: BorderSide(
            color: selected
                ? AppColors.secondary
                : AppColors.border.withValues(alpha: 0.75),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(OnboardingLayout.cardPadding),
            child: Row(
              crossAxisAlignment: isRole
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    width: OnboardingLayout.iconSize,
                    height: OnboardingLayout.iconSize,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: selected ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontFamily: fontFamily,
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: isRole ? 13 : 12,
                                height: 1.5,
                                color: selected && !isRole
                                    ? AppColors.secondary
                                    : AppColors.text.withValues(alpha: 0.75),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: EdgeInsets.only(top: isRole ? 8 : 0),
                  child: Icon(
                    selected
                        ? Icons.check_circle_outline
                        : isRole
                        ? Icons.arrow_forward_ios
                        : Icons.radio_button_unchecked,
                    textDirection: Directionality.of(context),
                    size: OnboardingLayout.controlSize,
                    color: selected || isRole
                        ? AppColors.primary
                        : AppColors.text.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
