import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';
import 'package:radd/features/volunteer/presentation/volunteer_components.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

import 'volunteer_navigation_test.dart' show harness, press;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'Manual review is secondary inside Report and supports filtering in $language',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
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
        expect(find.text(s.vManualReview), findsNothing);
        await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
        await tester.pumpAndSettle();

        final ai = find.ancestor(
          of: find.text(s.vOpenCamera),
          matching: find.byType(VolunteerAction),
        );
        final manual = find.ancestor(
          of: find.text(s.vManualReview),
          matching: find.byType(VolunteerAction),
        );
        expect(tester.widget<VolunteerAction>(ai).secondary, isFalse);
        expect(tester.widget<VolunteerAction>(manual).secondary, isTrue);
        expect(
          tester.getTopLeft(manual).dy,
          greaterThan(tester.getTopLeft(ai).dy),
        );
        await press(tester, s.vManualReview);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'no-such-person');
        await tester.pumpAndSettle();
        expect(find.text(s.vNoResults), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, s.vClearFilters));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, s.vFemale));
        await tester.pumpAndSettle();
        for (final male in repo.reviewableProfiles.where(
          (p) => p.gender == Gender.male,
        )) {
          expect(find.text(male.name.inLanguage(language)), findsNothing);
        }
        await tester.tap(find.widgetWithText(TextButton, s.vClearFilters));
        await tester.pumpAndSettle();
        final person = repo.reviewableProfiles.first;
        await tester.enterText(find.byType(TextField), person.name.en);
        await tester.pumpAndSettle();
        await press(tester, s.vViewDetails);
        expect(find.text(s.vConfirmIdentity), findsOneWidget);
        expect(find.text(s.vGuardianName), findsNothing);
        expect(find.text(person.guardian.phone!), findsNothing);
        expect(repo.cases.first.confirmedBy, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
