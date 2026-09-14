import 'package:flutter/material.dart';

import 'app_locale_scope.dart';
import 'app_services.dart';
import 'app_startup.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../shared/widgets/feature_page.dart';
import '../shared/widgets/primary_button.dart';

/// Omit locale to follow the device language, with English as fallback.
class RaddApp extends StatefulWidget {
  const RaddApp({
    super.key,
    this.locale,
    this.onLocaleChanged,
    this.initialize,
  });
  final Locale? locale;
  final Future<void> Function(Locale)? onLocaleChanged;
  final Future<AppStartupData> Function()? initialize;
  @override
  State<RaddApp> createState() => _RaddAppState();
}

class _RaddAppState extends State<RaddApp> {
  late Locale? _locale = widget.locale;
  final _navigatorKey = GlobalKey<NavigatorState>();
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
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: AppTheme.light(const Locale('en')),
        builder: (context, child) => Theme(
          data: AppTheme.light(Localizations.localeOf(context)),
          child: widget.initialize != null && _startup == null
              ? _initializationFailed
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
                    : const SplashScreen(autoNavigate: false)
              : child!,
        ),
        initialRoute: AppRoutes.root,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    final startup = _startup;
    return startup == null
        ? app
        : AppServices(
            auth: startup.auth,
            guardian: startup.guardian,
            child: app,
          );
  }
}
