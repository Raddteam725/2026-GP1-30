import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';
import 'package:radd/features/volunteer/presentation/volunteer_components.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'support/guardian_fakes.dart';
import 'volunteer_navigation_test.dart' show harness;

void main() {
  testWidgets(
    'Guardian dot clears on viewing without tapping and returns only for a new alert',
    (t) async {
      GuardianPushService.resetForTesting();
      final auth = TestAuth();
      final repo = TestRepository();
      addTearDown(auth.events.close);
      addTearDown(GuardianPushService.resetForTesting);
      GuardianNotification notification(String id) => GuardianNotification(
        id: id,
        foundReportId: 'FR-test',
        individualName: 'Person',
        status: 'identity_confirmed',
        read: false,
      );
      repo.notificationRecords.addAll([
        notification('first'),
        notification('second'),
      ]);
      await t.pumpWidget(
        AppServices(auth: auth, guardian: repo, child: const RaddApp()),
      );
      await t.pump(const Duration(milliseconds: 3800));
      await t.pumpAndSettle();
      auth.active = true;
      Navigator.of(t.element(find.byType(LanguageSelectionScreen)))
          .pushNamed(AppRoutes.guardian);
      await t.pumpAndSettle();
      final dot = find.byKey(const ValueKey('guardian-notification-dot'));
      expect(dot, findsOneWidget);
      await t.tap(find.byTooltip('Notifications'));
      await t.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(repo.notificationRecords.every((n) => n.read), isTrue);
      Navigator.of(t.element(find.byType(NotificationsScreen))).pop();
      await t.pumpAndSettle();
      expect(dot, findsNothing);
      GuardianPushRefresh.instance.ping();
      await t.pumpAndSettle();
      expect(dot, findsNothing);
      repo.notificationRecords.add(notification('new'));
      GuardianPushRefresh.instance.ping();
      await t.pumpAndSettle();
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
      expect(dot, findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Volunteer home and tab bells clear after viewing and return for a new alert',
    (t) async {
      final repo = MockVolunteerRepository();
      addTearDown(repo.dispose);
      const account = MockVolunteerRepository.account;
      await t.pumpWidget(
        harness(
          VolunteerWorkspace(
            account: account,
            repository: repo,
            onLogout: () async {},
          ),
          'en',
        ),
      );
      await t.pumpAndSettle();
      final homeDot = find.byKey(const ValueKey('volunteer-notification-dot'));
      expect(homeDot, findsOneWidget);
      await t.tap(find.byTooltip('Notifications').first);
      await t.pumpAndSettle();
      expect(
        repo.alertsFor(account.uid).every((a) => a.readAt != null),
        isTrue,
      );
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(homeDot, findsNothing);
      await t.tap(find.byKey(const ValueKey('radd-tab-1')));
      await t.pumpAndSettle();
      expect(
        t.widget<VolunteerBell>(find.byType(VolunteerBell)).hasAlerts,
        isFalse,
      );
      // A second Volunteer confirms a case this Volunteer joined: a real new
      // notification through the preview repository's existing workflow.
      const other = VolunteerAccount(
        uid: 'other-volunteer',
        name: LocalizedData('Other', 'آخر'),
        volunteerId: 'VOL-OTHER',
        active: true,
      );
      final item = repo.cases.singleWhere((c) => c.id == 'RD-8035');
      final report = await repo.submitFound(other);
      await repo.confirmMatch(other, report, item.person);
      await t.pumpAndSettle();
      expect(
        t.widget<VolunteerBell>(find.byType(VolunteerBell)).hasAlerts,
        isTrue,
      );
      await t.tap(find.byTooltip('Notifications').first);
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(
        t.widget<VolunteerBell>(find.byType(VolunteerBell)).hasAlerts,
        isFalse,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
