import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/presentation/volunteer_consent_screen.dart';

import 'volunteer_navigation_test.dart' show harness;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'Explicit localized consent and full documents before workspace ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var accepted = false, childBuilds = 0, logouts = 0, posts = 0;
        var requiredPrivacy = 'draft-2026-09';
        final repo = ApiVolunteerRepository(
          token: () async => 'test',
          baseUrl: 'http://test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/consent')) {
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), {
                'accepted': true,
                'terms_version': 'draft-2026-09',
                'privacy_version': 'draft-2026-09',
              });
              posts++;
              accepted = true;
              return http.Response('{}', 200);
            }
            expect(request.url.path, '/v1/volunteer');
            return http.Response(
              jsonEncode({
                'uid': 'test',
                'full_name': 'Volunteer',
                'volunteer_id': 'V-test',
                'active': true,
                'assigned': true,
                'event_id': 'test-event',
                'consent_current': accepted,
                'required_terms_version': 'draft-2026-09',
                'required_privacy_version': requiredPrivacy,
              }),
              200,
            );
          }),
        );
        addTearDown(repo.dispose);
        await repo.loadProfile();
        Widget gate() => harness(
          VolunteerConsentGate(
            repository: repo,
            onLogout: () async {
              logouts++;
            },
            childBuilder: (_) {
              childBuilds++;
              return const Scaffold(body: Text('authorized-workspace'));
            },
          ),
          language,
        );
        await tester.pumpWidget(gate());
        await tester.pumpAndSettle();
        final s = AppLocalizations.of(
          tester.element(find.byType(VolunteerConsentScreen)),
        )!;
        expect(find.text(s.vConsentTitle), findsOneWidget);
        expect(childBuilds, 0);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );
        final button = find.byKey(const Key('volunteer-consent-continue'));
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        for (final title in [s.vTermsTitle, s.vPrivacyTitle]) {
          await tester.ensureVisible(find.text(title));
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
          expect(find.byType(VolunteerPolicyScreen), findsOneWidget);
          expect(find.text(s.vDevelopmentPolicy), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        expect(posts, 0);
        await tester.ensureVisible(find.text(s.vConsentNotNow));
        await tester.tap(find.text(s.vConsentNotNow));
        await tester.pumpAndSettle();
        expect(logouts, 1);
        expect(childBuilds, 0);
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.text('authorized-workspace'), findsOneWidget);
        // Restart: only authoritative server acceptance allows the child to mount.
        await tester.pumpWidget(const SizedBox());
        await repo.loadProfile();
        await tester.pumpWidget(gate());
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerConsentScreen), findsNothing);
        expect(posts, 1);
        // A future version cannot be accepted against the old bundled document.
        accepted = false;
        requiredPrivacy = 'future-version';
        await repo.loadProfile();
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerConsentScreen), findsOneWidget);
        expect(find.text(s.vConsentUnavailable), findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(find.text('authorized-workspace'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('Repository fails closed on missing consent and does not request event data', () async {
    final paths = <String>[];
    final repo = ApiVolunteerRepository(
      token: () async => 'test',
      baseUrl: 'http://test',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({
            'uid': 'test',
            'full_name': 'Volunteer',
            'volunteer_id': 'V-test',
            'active': true,
            'assigned': true,
            'event_id': 'test-event',
          }),
          200,
        );
      }),
    );
    addTearDown(repo.dispose);
    await repo.loadProfile();
    expect(repo.consentCurrent, isFalse);
    await expectLater(
      repo.registerDevice('token', 'en', null),
      throwsStateError,
    );
    expect(paths, ['/v1/volunteer']);
  });
}
