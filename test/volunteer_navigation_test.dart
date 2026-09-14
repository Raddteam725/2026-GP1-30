import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_locale_scope.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/theme/app_theme.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';
import 'package:radd/features/volunteer/presentation/volunteer_entry.dart';

Widget harness(Widget child, String language) => AppLocaleScope(
  locale: Locale(language),
  setLocale: (_) {},
  child: MaterialApp(
    locale: Locale(language),
    theme: AppTheme.light(Locale(language)),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);
Future<void> press(WidgetTester tester, String label) async {
  final buttons = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  if (buttons.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      buttons,
      160,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final target = buttons.last;
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'Volunteer tabs and both badge states fit small screens in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MockVolunteerRepository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          harness(
            VolunteerWorkspace(
              account: MockVolunteerRepository.account,
              repository: repo,
              onLogout: () async {},
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 1; i < 5; i++) {
          await tester.tap(find.byType(NavigationDestination).at(i));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(
          harness(
            const Scaffold(
              body: SingleChildScrollView(
                child: VolunteerBadgeCard(
                  account: MockVolunteerRepository.inactiveAccount,
                ),
              ),
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining(language == 'ar' ? 'غير نشط' : 'Inactive'),
          findsOneWidget,
        );
      },
    );
    testWidgets(
      'Initial details update in place and Cases has categories without search in $language',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MockVolunteerRepository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          harness(
            VolunteerWorkspace(
              account: MockVolunteerRepository.account,
              repository: repo,
              onLogout: () async {},
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final s = AppLocalizations.of(
          tester.element(find.byType(VolunteerWorkspace)),
        )!;
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.textContaining(s.vAvailable), findsOneWidget);
        expect(find.textContaining(s.vMyCases), findsOneWidget);
        await tester.tap(
          find.text(language == 'ar' ? 'عمر حسن' : 'Omar Hassan'),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(s.vPendingDetails), 200);
        expect(find.text(s.vPendingDetails), findsOneWidget);
        expect(find.text(s.vLastSeen), findsNothing);
        repo.receiveGuardianDetails(
          'RD-8042',
          MockVolunteerRepository.updatedInformation,
        );
        await tester.pumpAndSettle();
        expect(find.text(s.vPendingDetails), findsNothing);
        await tester.scrollUntilVisible(find.text(s.vClothing), 200);
        expect(find.text(s.vClothing), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Confirm dialog cancel does not match; alternative verification gates handover in $language',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MockVolunteerRepository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          harness(
            VolunteerWorkspace(
              account: MockVolunteerRepository.account,
              repository: repo,
              onLogout: () async {},
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final s = AppLocalizations.of(
          tester.element(find.byType(VolunteerWorkspace)),
        )!;
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pumpAndSettle();
        await press(tester, s.vOpenCamera);
        await press(tester, s.vPreviewCapture);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(s.vViewDetails).first);
        await tester.tap(find.text(s.vViewDetails).first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(s.vConfirmMatch), 300);
        await press(tester, s.vConfirmMatch);
        expect(find.byType(AlertDialog), findsOneWidget);
        await press(tester, s.vCancel);
        expect(repo.cases.first.status, CaseStatus.reportReceived);
        await press(tester, s.vConfirmMatch);
        await press(tester, s.vConfirmMatch);
        expect(repo.cases.first.status, CaseStatus.matchConfirmed);
        expect(find.text(s.vGuardianContact), findsOneWidget);
        await tester.scrollUntilVisible(find.text(s.vProceedVerification), 300);
        await press(tester, s.vProceedVerification);
        await tester.scrollUntilVisible(find.text(s.vUseIdentifier), 250);
        await press(tester, s.vUseIdentifier);
        await tester.enterText(find.byType(TextFormField), 'wrong');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await press(tester, s.vVerify);
        expect(find.text(s.vVerificationFailed), findsWidgets);
        expect(
          repo.cases.first.status,
          CaseStatus.awaitingGuardianVerification,
        );
        await tester.scrollUntilVisible(find.text(s.vUseIdentifier), 250);
        await press(tester, s.vUseIdentifier);
        await tester.enterText(find.byType(TextFormField), 'RD-8042');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await press(tester, s.vVerify);
        await tester.scrollUntilVisible(find.text(s.vContinueHandover), 250);
        await press(tester, s.vContinueHandover);
        await press(tester, s.vConfirmHandover);
        await press(tester, s.vConfirmHandover);
        expect(repo.cases.first.status, CaseStatus.reunited);
        expect(
          repo.cases.first.handedOverBy,
          MockVolunteerRepository.account.uid,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('Login validates required fields in $language', (tester) async {
      await tester.pumpWidget(harness(const VolunteerEntry(), language));
      await tester.pumpAndSettle();
      final s = AppLocalizations.of(
        tester.element(find.byType(VolunteerEntry)),
      )!;
      await press(tester, s.vLogin);
      expect(find.text(s.vRequired), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
