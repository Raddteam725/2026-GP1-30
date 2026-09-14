import 'package:flutter/widgets.dart';

import '../features/auth/data/auth_service.dart';
import '../features/guardian/data/guardian_repository.dart';

class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.auth,
    required this.guardian,
    required super.child,
  });
  final AuthService auth;
  final GuardianRepository guardian;
  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>()!;
  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>();
  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      auth != oldWidget.auth || guardian != oldWidget.guardian;
}
