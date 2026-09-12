import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_spacing.dart';

/// Animated introduction, replaced by language selection after two seconds.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const logoAsset = 'assets/images/radd_logo.png';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _accent = _phase(0, 0.35);
  late final Animation<double> _logo = _phase(0.12, 0.65);
  late final Animation<double> _copy = _phase(0.4, 0.9);
  late final Animation<double> _footer = _phase(0.65, 1);

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigationTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.languageSelection);
      });
    });
  }

  Animation<double> _phase(double start, double end) => _entrance.drive(
    CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (!_entrance.isAnimating && !_entrance.isCompleted) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CustomPaint(painter: _SplashBackground()),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: AppSpacing.pagePadding,
                      child: Column(
                        children: [
                          const Spacer(flex: 3),
                          const Gap(AppSpacing.xl),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: (constraints.maxWidth * 0.5).clamp(
                                    140.0,
                                    200.0,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      FadeTransition(
                                        opacity: _logo,
                                        child: ScaleTransition(
                                          scale: _logo.drive(
                                            Tween(begin: 0.94, end: 1.0),
                                          ),
                                          child: Image.asset(
                                            SplashScreen.logoAsset,
                                            fit: BoxFit.contain,
                                            semanticLabel: 'Radd logo',
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 4,
                                        child: ExcludeSemantics(
                                          child: FadeTransition(
                                            opacity: _accent,
                                            child: Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: AppColors.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Gap(AppSpacing.sm),
                                FadeTransition(
                                  opacity: _copy,
                                  child: Column(
                                    children: [
                                      Text(
                                        'Radd',
                                        textAlign: TextAlign.center,
                                        style: text.headlineLarge?.copyWith(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      const Gap(AppSpacing.sm),
                                      Text(
                                        'Bringing People Back Together',
                                        textAlign: TextAlign.center,
                                        style: text.bodyMedium?.copyWith(
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(AppSpacing.xl),
                          const Spacer(flex: 3),
                          FadeTransition(
                            opacity: _footer,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 144,
                                  child: LinearProgressIndicator(
                                    // A visual waiting state, not progress from a background task.
                                    value: reducedMotion ? 0.4 : null,
                                    minHeight: 3,
                                    borderRadius: BorderRadius.circular(3),
                                    color: AppColors.secondary,
                                    backgroundColor: AppColors.secondary
                                        .withValues(alpha: 0.1),
                                    semanticsLabel: 'Loading',
                                  ),
                                ),
                                const Gap(AppSpacing.lg),
                                Text(
                                  'A safer tomorrow for every journey',
                                  textAlign: TextAlign.center,
                                  style: text.bodySmall?.copyWith(
                                    height: 1.5,
                                    color: AppColors.text.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(AppSpacing.xl),
                        ],
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

class _SplashBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.46;
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.12),
      radius,
      Paint()..color = AppColors.lightBlue.withValues(alpha: 0.045),
    );
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 0.73),
      radius * 0.9,
      Paint()..color = AppColors.secondary.withValues(alpha: 0.035),
    );
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 0.73),
      radius * 1.12,
      Paint()
        ..color = AppColors.lightBlue.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SplashBackground oldDelegate) => false;
}
