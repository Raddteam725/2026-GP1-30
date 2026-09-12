import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) =>
      MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => switch (settings.name) {
          // Blank until the first approved screen is supplied.
          AppRoutes.root => const Scaffold(body: SizedBox.expand()),
          _ => Scaffold(
            body: SafeArea(
              child: Center(
                child: Text(AppLocalizations.of(context)!.pageNotFound),
              ),
            ),
          ),
        },
      );
}
