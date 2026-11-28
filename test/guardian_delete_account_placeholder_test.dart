import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_api.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

void main() {
  late TestAuth auth;
  late List<String> requests;
  late GuardianApi api;

  setUp(() {
    auth = TestAuth();
    requests = [];
    api = GuardianApi(
      token: () async => 'jwt',
      baseUrl: 'http://test',
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst('/v1', '');
        requests.add('${request.method} $path');
        final body = switch (path) {
          '/guardian' => {
            'full_name': 'Test Guardian',
            'email': 'guardian@example.test',
            'phone': '+966500000001',
          },
          '/event' => {'id': 'event', 'name': 'Test Event', 'status': 'active'},
          _ => <Object>[],
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    GuardianPushService.resetForTesting();
  });
  tearDown(() async {
    await auth.events.close();
    GuardianPushService.resetForTesting();
  });

  for (final (locale, label, message) in [
    ('en', 'Delete Account', 'Are you sure you want to delete your account?'),
    ('ar', 'حذف الحساب', 'هل أنت متأكد من رغبتك في حذف حسابك؟'),
  ]) {
    testWidgets('Delete Account is a visible, inert placeholder below Log Out '
        '($locale)', (t) async {
      await t.pumpWidget(
        AppServices(
          auth: auth,
          guardian: api,
          child: RaddApp(locale: Locale(locale)),
        ),
      );
      await t.pump(const Duration(milliseconds: 3800));
      await t.pumpAndSettle();
      auth.active = true;
      Navigator.of(t.element(find.byType(LanguageSelectionScreen)))
          .pushNamed(AppRoutes.guardian, arguments: 4);
      await t.pumpAndSettle();

      final s = AppLocalizations.of(
        t.element(find.byType(GuardianHomeScreen)),
      )!;
      expect(s.deleteAccount, label);
      expect(s.deleteAccountConfirm, message);
      final button = find.byKey(const ValueKey('guardian-delete-account'));
      await t.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await t.pumpAndSettle();
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text(label)),
        findsOneWidget,
      );
      final logout = find.widgetWithText(OutlinedButton, s.logout);
      expect(t.getTopLeft(button).dy, greaterThan(t.getTopLeft(logout).dy));
      expect(
        Directionality.of(t.element(button)),
        locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );

      requests.clear();
      final logins = auth.logins;
      await t.tap(button);
      await t.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text(message)),
        findsOneWidget,
      );
      final confirm = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, label),
      );
      expect(t.widget<FilledButton>(confirm).onPressed, isNotNull);
      await t.tap(confirm);
      await t.pumpAndSettle();
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(requests, isEmpty);
      expect(auth.active, isTrue);
      expect(auth.logins, logins);

      await t.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, s.cancel),
        ),
      );
      await t.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
      expect(requests, isEmpty);
      expect(auth.active, isTrue);
    });
  }
}
