import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/guardian/presentation/guardian_qr_screen.dart';
import 'package:radd/features/guardian/presentation/notifications_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';

import 'support/guardian_fakes.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final status in ['identity_confirmed', 'reunited']) {
      for (final foreground in [false, true]) {
        testWidgets(
          '$locale $status found notification opens verification (push=$foreground)',
          (t) async {
            GuardianPushService.resetForTesting();
            final auth = TestAuth();
            final repo = TestRepository();
            addTearDown(auth.events.close);
            addTearDown(GuardianPushService.resetForTesting);
            repo.notificationRecords.add(
              GuardianNotification.fromJson({
                'id': 'FR-test-$status',
                'found_report_id': 'FR-test',
                'individual_name': 'Test Person',
                'status': status,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              }),
            );
            repo.foundReports = const [
              GuardianFoundReport(
                id: 'FR-test',
                status: 'identity_confirmed',
                individualName: 'Test Person',
                verificationCode: '123456',
              ),
            ];
            await t.pumpWidget(
              AppServices(
                auth: auth,
                guardian: repo,
                child: RaddApp(locale: Locale(locale)),
              ),
            );
            await t.pump(const Duration(milliseconds: 3800));
            await t.pumpAndSettle();
            auth.active = true;
            Navigator.of(t.element(find.byType(LanguageSelectionScreen)))
                .pushNamed(
                  foreground ? AppRoutes.guardian : AppRoutes.notifications,
                );
            await t.pumpAndSettle();
            if (foreground) {
              GuardianPushService.debugReceive(
                RemoteMessage(
                  data: {
                    'role': 'guardian',
                    'kind': 'found_report',
                    'status': status,
                    'found_report_id': 'FR-test',
                    'notification_id': 'FR-test-$status',
                  },
                ),
              );
              await t.pumpAndSettle();
            }
            final s = AppLocalizations.of(
              t.element(
                find.byType(
                  foreground ? GuardianHomeScreen : NotificationsScreen,
                ),
              ),
            )!;
            final text = status == 'reunited'
                ? s.foundReportReunitedNotification('Test Person')
                : s.foundReportIdentifiedNotification('Test Person');
            expect(find.text(text), findsOneWidget);
            await t.tap(
              foreground ? find.text(s.qrCode).last : find.text(text),
            );
            await t.pumpAndSettle();
            expect(find.byType(GuardianQrScreen), findsOneWidget);
            expect(repo.verificationRequests, greaterThan(0));
            if (!foreground) {
              expect(repo.notificationRecords.single.read, isTrue);
            }
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
