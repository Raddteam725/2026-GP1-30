import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/coalesced_refresh.dart';
import 'package:radd/features/guardian/data/guardian_api.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/presentation/cases_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_components.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/shared/widgets/feature_page.dart';

import 'support/guardian_fakes.dart';

const _png = [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84,
  120, 156, 99, 96, 0, 2, 0, 0, 5, 0, 1, 165, 246, 69, 64, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130,
];

class _Backend {
  final requests = <String>[];
  final failing = <String>{};
  int status = 200;
  static const count = 6;

  int calls(String request) => requests.where((r) => r == request).length;
  int get photos => requests.where((r) => r.endsWith('/photo')).length;

  static http.Response json(Object value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json'},
  );

  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/v1', '');
    final key = '${request.method} $path';
    requests.add(key);
    if (status != 200) return http.Response('{}', status);
    if (failing.contains(key)) return http.Response('{}', 500);
    switch (path) {
      case '/guardian':
        return json({
          'full_name': 'Test Guardian',
          'email': 'guardian@example.test',
          'phone': '+966500000001',
        });
      case '/individuals':
        return json([
          for (var i = 1; i <= count; i++)
            {
              'id': 'p$i',
              'full_name': 'Person $i',
              'age': 7,
              'gender': 'female',
              'relationship': 'child',
              'active_case_id': 'RD-$i',
              'photo_expired': false,
            },
        ]);
      case '/cases':
        return json([
          for (var i = 1; i <= count; i++)
            {
              'id': 'RD-$i',
              'individual_id': 'p$i',
              'individual_name': 'Person $i',
              'age': 7,
              'status': 'report_received',
              'event_id': 'event',
              'created_at': '2026-11-01T08:00:00Z',
              'updated_at': '2026-11-01T08:00:00Z',
              'stage_timestamps': {'report_received': '2026-11-01T08:00:00Z'},
            },
        ]);
      case '/notifications':
        return json([]);
      case '/notifications/read-all':
        return http.Response('', 204);
      case '/event':
        return json({'id': 'event', 'name': 'Test Event', 'status': 'active'});
      case '/guardian/found-reports':
        return json([]);
      case '/guardian/verification':
        return json({
          'payload': 'radd:guardian-verification:v1:test:${requests.length}',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        });
    }
    if (path.endsWith('/photo')) return http.Response.bytes(_png, 200);
    return http.Response('{}', 404);
  });
}

void main() {
  late TestAuth auth;
  late _Backend backend;
  late GuardianApi api;

  setUp(() {
    auth = TestAuth();
    backend = _Backend();
    api = GuardianApi(
      token: () async => 'jwt',
      account: () => auth.active ? auth.uid : null,
      baseUrl: 'http://test',
      client: backend.client,
    );
    GuardianPushService.resetForTesting();
  });
  tearDown(() async {
    await auth.events.close();
    GuardianPushService.resetForTesting();
  });

  Future<void> openHome(WidgetTester t) async {
    await t.pumpWidget(
      AppServices(
        auth: auth,
        guardian: api,
        child: const RaddApp(locale: Locale('en')),
      ),
    );
    await t.pump(const Duration(milliseconds: 3800));
    await t.pumpAndSettle();
    auth.active = true;
    Navigator.of(t.element(find.byType(LanguageSelectionScreen)))
        .pushNamed(AppRoutes.guardian);
    await t.pumpAndSettle();
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    backend.requests.clear();
  }

  Future<void> tab(WidgetTester t, String label, {bool settle = true}) async {
    await t.tap(
      find.descendant(
        of: find.byType(GuardianNavigation),
        matching: find.text(label),
      ),
    );
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
  }

  Finder spinnerIn(Type screen) => find.descendant(
    of: find.byType(screen),
    matching: find.byType(CircularProgressIndicator),
  );

  void report(String name, Map<String, int> values) =>
      debugPrint('MEASURE $name ${jsonEncode(values)}');

  testWidgets('Returning from Notifications refreshes only what it can change '
      'and downloads no photographs', (t) async {
    await openHome(t);
    await t.tap(find.byTooltip('Notifications'));
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(NotificationsScreen))).pop();
    await t.pump();
    final spinners = spinnerIn(GuardianHomeScreen).evaluate().length;
    await t.pumpAndSettle();
    final values = {
      'total': backend.requests.length,
      'photos': backend.photos,
      'individuals': backend.calls('GET /individuals'),
      'event': backend.calls('GET /event'),
      'cases': backend.calls('GET /cases'),
      'spinners': spinners,
    };
    report('notifications-roundtrip', values);
    expect(values['photos'], 0);
    expect(values['individuals'], 0);
    expect(values['event'], 0);
    expect(values['cases'], 1);
    expect(values['spinners'], 0);
    expect(find.text('Person 1'), findsWidgets);
  });

  testWidgets('Switching tabs keeps Cases mounted with its scroll position, '
      'shows no spinner and does not refetch while fresh', (t) async {
    await openHome(t);
    await tab(t, 'Cases');
    final scrollable = find
        .descendant(
          of: find.byType(CasesScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await t.drag(scrollable, const Offset(0, -400));
    await t.pumpAndSettle();
    final offset = t.state<ScrollableState>(scrollable).position.pixels;
    backend.requests.clear();
    await tab(t, 'Home');
    await tab(t, 'Cases', settle: false);
    final spinners = spinnerIn(CasesScreen).evaluate().length;
    await t.pumpAndSettle();
    final restored = t.state<ScrollableState>(scrollable).position.pixels;
    await tab(t, 'Home');
    final values = {
      'total': backend.requests.length,
      'cases': backend.calls('GET /cases'),
      'photos': backend.photos,
      'spinners': spinners,
      'scrollKept': restored == offset && offset > 0 ? 1 : 0,
    };
    report('tab-switching-revisit', values);
    expect(values['cases'], 0);
    expect(values['photos'], 0);
    expect(values['spinners'], 0);
    expect(values['scrollKept'], 1);
  });

  testWidgets('A revisited tab revalidates silently once its data is stale', (
    t,
  ) async {
    await openHome(t);
    await tab(t, 'Cases');
    await tab(t, 'Home');
    guardianRevisitFreshness = Duration.zero;
    addTearDown(() => guardianRevisitFreshness = const Duration(seconds: 15));
    backend.requests.clear();
    await tab(t, 'Cases', settle: false);
    expect(spinnerIn(CasesScreen), findsNothing);
    await t.pumpAndSettle();
    expect(backend.calls('GET /cases'), 1);
    expect(backend.photos, 0);
  });

  testWidgets('A hidden QR tab never requests credentials and a new code is '
      'generated each time it is shown', (t) async {
    await openHome(t);
    await tab(t, 'QR Code');
    final first = backend.calls('POST /guardian/verification');
    await tab(t, 'Home');
    await t.pump(const Duration(minutes: 6));
    await t.pumpAndSettle();
    final whileHidden = backend.calls('POST /guardian/verification');
    await tab(t, 'QR Code');
    final shownAgain = backend.calls('POST /guardian/verification');
    await tab(t, 'Home');
    report('qr-visibility', {
      'firstShow': first,
      'afterHidden6min': whileHidden,
      'secondShow': shownAgain,
    });
    expect(first, 1);
    expect(whileHidden, 1);
    expect(shownAgain, 2);
  });

  testWidgets('One push event fetches the case list once even with retained '
      'tabs listening', (t) async {
    await openHome(t);
    await tab(t, 'Cases');
    await tab(t, 'QR Code');
    await tab(t, 'Home');
    backend.requests.clear();
    GuardianPushRefresh.instance.ping();
    await t.pumpAndSettle();
    report('push-event', {
      'cases': backend.calls('GET /cases'),
      'total': backend.requests.length,
    });
    expect(backend.calls('GET /cases'), 1);
    expect(backend.photos, 0);
  });

  testWidgets('A failed refresh keeps valid content and offers retry', (
    t,
  ) async {
    await openHome(t);
    backend.failing.add('GET /cases');
    GuardianPushRefresh.instance.ping();
    await t.pumpAndSettle();
    expect(find.text('Person 1'), findsWidgets);
    expect(find.byType(ErrorNotice), findsNothing);

    await t.tap(find.byTooltip('Notifications'));
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(NotificationsScreen))).pop();
    await t.pumpAndSettle();
    expect(find.byType(ErrorNotice), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Test Event'), findsOneWidget);

    backend.failing.clear();
    await t.tap(find.text('Try Again'));
    await t.pumpAndSettle();
    expect(find.byType(ErrorNotice), findsNothing);
    expect(find.text('Person 1'), findsWidgets);
  });

  testWidgets('Lost authorization during a refresh removes protected content', (
    t,
  ) async {
    await openHome(t);
    backend.status = 403;
    GuardianPushRefresh.instance.ping();
    await t.pumpAndSettle();
    expect(find.text('Person 1'), findsNothing);
    expect(find.text('Test'), findsNothing);
    expect(find.byType(ErrorNotice), findsOneWidget);
  });
}
