import 'package:flutter/material.dart';

import 'app_locale_scope.dart';
import 'app_services.dart';
import 'app_startup.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../shared/widgets/feature_page.dart';
import '../shared/widgets/primary_button.dart';

/// Whether application startup (Firebase, preferences, services) is still in
/// progress. Always present above the navigator, so the splash can wait for
/// it without the widget tree being rebuilt when services become available.
class AppStartupScope extends InheritedWidget {
  const AppStartupScope({
    super.key,
    required this.pending,
    required this.splashStart,
    required super.child,
  });
  final bool pending;

  /// Completes when the splash sequence may start its clock. The production
  /// app (see main.dart) ties this to the first frame actually being
  /// rasterized -- the moment Android dismisses its launch window -- so the
  /// animation never runs unseen behind it; tests and fixtures start at once.
  final Future<void> splashStart;
  static bool pendingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStartupScope>()?.pending ??
      false;
  static Future<void> splashStartOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppStartupScope>()?.splashStart ??
      Future<void>.value();
  @override
  bool updateShouldNotify(AppStartupScope oldWidget) =>
      pending != oldWidget.pending;
}

/// Omit locale to follow the device language, with English as fallback.
class RaddApp extends StatefulWidget {
  const RaddApp({
    super.key,
    this.locale,
    this.onLocaleChanged,
    this.initialize,
    this.waitForFirstFrame = false,
  });
  final Locale? locale;
  final Future<void> Function(Locale)? onLocaleChanged;
  final Future<AppStartupData> Function()? initialize;

  /// Start the splash sequence only once the first frame has been rasterized
  /// (the real app); off by default because that engine signal never arrives
  /// under flutter_test.
  final bool waitForFirstFrame;
  @override
  State<RaddApp> createState() => _RaddAppState();
}

class _RaddAppState extends State<RaddApp> {
  late Locale? _locale = widget.locale;
  final _navigatorKey = GlobalKey<NavigatorState>();
  // The MaterialApp is re-parented under AppServices once startup completes;
  // this key lets Flutter move the existing element instead of rebuilding
  // the whole app, so the splash animation that is already playing keeps
  // playing -- one continuous splash, never a restart.
  final _appKey = GlobalKey();
  late final Future<void> _splashStart = widget.waitForFirstFrame
      ? WidgetsBinding.instance.waitUntilFirstFrameRasterized
      : Future<void>.value();
  AppStartupData? _startup;
  bool _initializationFailed = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint('Radd startup: first Flutter frame rendered');
        _initialize();
      });
    }
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _initializationFailed = false;
    });
    try {
      final result = await widget.initialize!().timeout(
        const Duration(seconds: 45),
      );
      if (!mounted) return;
      setState(() {
        _startup = result;
        _locale = result.locale;
      });
    } catch (error) {
      debugPrint('Radd startup: showing recovery (${error.runtimeType})');
      if (mounted) setState(() => _initializationFailed = true);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void didUpdateWidget(RaddApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale) _locale = widget.locale;
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        widget.initialize != null && _startup == null && !_initializationFailed;
    final app = AppLocaleScope(
      locale: _locale,
      setLocale: (locale) async {
        setState(() => _locale = locale);
        try {
          await (widget.onLocaleChanged ?? _startup?.saveLocale)?.call(locale);
        } catch (_) {
          final context = _navigatorKey.currentContext;
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.serviceError),
              ),
            );
          }
        }
      },
      child: MaterialApp(
        key: _appKey,
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: AppTheme.light(const Locale('en')),
        // The navigator's own root Splash is the FIRST branded frame and the
        // ONLY splash: while startup is pending it simply keeps playing and
        // waits (see SplashScreen) instead of a second splash replacing it.
        builder: (context, child) => Theme(
          data: AppTheme.light(Localizations.localeOf(context)),
          child:
              widget.initialize != null &&
                  _startup == null &&
                  _initializationFailed
              ? FeaturePage(
                  title: AppLocalizations.of(context)!.startupFailed,
                  children: [
                    Text(AppLocalizations.of(context)!.startupFailedHint),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: AppLocalizations.of(context)!.retry,
                      onPressed: _initialize,
                    ),
                  ],
                )
              : child!,
        ),
        initialRoute: AppRoutes.root,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    final startup = _startup;
    return AppStartupScope(
      pending: pending,
      splashStart: _splashStart,
      child: startup == null
          ? app
          : AppServices(
              auth: startup.auth,
              guardian: startup.guardian,
              child: app,
            ),
    );
  }
}
