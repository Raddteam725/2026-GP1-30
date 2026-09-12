import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_spacing.dart';

class OnboardingSelectionCard extends StatelessWidget {
  const OnboardingSelectionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontFamily,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    selected: selected,
    button: true,
    inMutuallyExclusiveGroup: true,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: selected
            ? AppColors.secondary.withValues(alpha: 0.055)
            : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.secondary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: fontFamily,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
                const Gap.horizontal(AppSpacing.md),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? AppColors.secondary : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
