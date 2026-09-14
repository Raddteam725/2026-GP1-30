import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_background.dart';

/// Shared onboarding measurements in logical pixels, independent of device size.
abstract final class OnboardingLayout {
  static const pagePadding = 24.0;
  static const contentWidth = 400.0;
  static const radius = 16.0;
  static const cardPadding = 16.0;
  static const iconSize = 40.0;
  static const controlSize = 24.0;
  static const sectionGap = 32.0;
  static const cardGap = 16.0;
  static const buttonHeight = 52.0;
  static const logoAsset = 'assets/images/radd_logo_transparent.png';
  static const splashDuration = Duration(milliseconds: 3800);
}

/// Language and role screens share the same header, content and footer anchors.
/// On small screens/large text the intrinsic content scrolls; tall screens cap
/// the composition height so whitespace never expands without a bound.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    this.footer,
    this.showBack = false,
  });
  final String title;
  final String subtitle;
  final Widget content;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFD),
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
            child: LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: OnboardingLayout.contentWidth + 48,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: OnboardingLayout.pagePadding,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight.clamp(0, 840),
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 48,
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: showBack
                                          ? const BackButton()
                                          : null,
                                    ),
                                  ),
                                  Center(
                                    child: Image.asset(
                                      OnboardingLayout.logoAsset,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Radd logo',
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: text.headlineSmall?.copyWith(
                                      fontSize: 24,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    subtitle,
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium?.copyWith(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: AppColors.text.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: OnboardingLayout.sectionGap,
                                  ),
                                  content,
                                  const SizedBox(
                                    height: OnboardingLayout.sectionGap,
                                  ),
                                  const Spacer(),
                                  ?footer,
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
