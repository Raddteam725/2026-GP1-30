import 'dart:async';

import '../../../../app/app_services.dart';
import '../../../../app/radd_app.dart';
import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/onboarding_layout.dart';
import '../widgets/onboarding_background.dart';
import '../widgets/splash_logo_animation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.autoNavigate = true});
  final bool autoNavigate;
  static const logoAsset = OnboardingLayout.logoAsset;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: OnboardingLayout.splashDuration,
  );
  late final Animation<double> _title = _phase(0.70, 0.79);
  late final Animation<double> _subtitle = _phase(0.79, 0.87);
  late final Animation<double> _footer = _phase(0.88, 0.96);
  Timer? _navigationTimer;
  // Set once the splash sequence has played out; navigation then happens as
  // soon as application startup has also finished (immediately if it has).
  bool _sequenceDone = false;
  Animation<double> _phase(double start, double end) => _entrance.drive(
    CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
  );
  @override
  void initState() {
    super.initState();
    // The sequence's clock starts only when the app's first frame has really
    // been rasterized -- the same moment Android dismisses its launch window
    // -- so the clean t=0 frame is what the user sees first and the whole
    // animation plays in view. Starting any earlier would let it run,
    // unseen, behind the native launch screen.
    AppStartupScope.splashStartOf(context).then((_) {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context) &&
          !_entrance.isAnimating &&
          !_entrance.isCompleted) {
        _entrance.forward();
      }
      if (!widget.autoNavigate) return;
      _navigationTimer = Timer(OnboardingLayout.splashDuration, () {
        _sequenceDone = true;
        _navigateIfReady();
      });
    });
  }

  /// This splash is the single, continuous branded start of the app: it is
  /// on screen from the first Flutter frame and stays -- without restarting
  /// -- until both its own sequence and startup (Firebase, services) are
  /// done. Startup completing later simply triggers this again via
  /// didChangeDependencies.
  void _navigateIfReady() {
    if (!mounted || !_sequenceDone || AppStartupScope.pendingOf(context)) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _sequenceDone = false; // Navigate exactly once.
    Navigator.of(context).pushReplacementNamed(
      AppServices.maybeOf(context) == null
          ? AppRoutes.languageSelection
          : AppRoutes.session,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _entrance.value = 1;
    if (_sequenceDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateIfReady());
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
    final s = AppLocalizations.of(context)!;
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
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: OnboardingLayout.contentWidth + 48,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: OnboardingLayout.pagePadding,
                          ),
                          child: Column(
                            children: [
                              const Spacer(flex: 3),
                              const SizedBox(height: 32),
                              SizedBox.square(
                                dimension: 176,
                                child: SplashLogoAnimation(progress: _entrance),
                              ),
                              const SizedBox(height: 24),
                              FadeTransition(
                                opacity: _title,
                                child: Text(
                                  s.appTitle,
                                  textAlign: TextAlign.center,
                                  style: text.headlineLarge?.copyWith(
                                    fontSize: 32,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FadeTransition(
                                opacity: _subtitle,
                                child: Text(
                                  s.brandTagline,
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Spacer(flex: 3),
                              FadeTransition(
                                opacity: _footer,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 112,
                                      child: LinearProgressIndicator(
                                        value:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? 0.4
                                            : null,
                                        minHeight: 3,
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.lightBlue
                                            .withValues(alpha: 0.15),
                                        semanticsLabel: s.loading,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      s.splashSupport,
                                      textAlign: TextAlign.center,
                                      style: text.bodySmall?.copyWith(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: AppColors.text.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
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
