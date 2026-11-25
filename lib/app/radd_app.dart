import 'package:flutter/material.dart';

import 'app_locale_scope.dart';
import 'app_services.dart';
import 'app_startup.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../features/guardian/presentation/guardian_notice_host.dart';
import '../shared/widgets/feature_page.dart';
import '../shared/widgets/primary_button.dart';

class AppStartupScope extends InheritedWidget {
  const AppStartupScope({
    super.key,
    required this.pending,
    required this.splashStart,
    required super.child,
  });
  final bool pending;

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

  final bool waitForFirstFrame;
  @override
  State<RaddApp> createState() => _RaddAppState();
}

class _RaddAppState extends State<RaddApp> {
  late Locale? _locale = widget.locale;
  final _navigatorKey = GlobalKey<NavigatorState>();
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
              : GuardianNoticeHost(navigatorKey: _navigatorKey, child: child!),
        ),
        navigatorObservers: [GuardianNoticeHost.routeObserver],
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
