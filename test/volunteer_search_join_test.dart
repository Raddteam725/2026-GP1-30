import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';
import 'package:radd/features/volunteer/presentation/volunteer_components.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('Start becomes Join for a second participant in $language', (
      tester,
    ) async {
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
      await tester.tap(find.byKey(const ValueKey('radd-tab-1')));
      await tester.pumpAndSettle();
      final item = repo.cases.first;
      final card = find.byKey(ValueKey('case-${item.id}'));
      final start = find.descendant(
        of: card,
        matching: find.text(s.vStartSearch),
      );
      expect(start, findsOneWidget);
      final startAction = tester.widget<VolunteerAction>(
        find.ancestor(of: start, matching: find.byType(VolunteerAction)),
      );
      expect(startAction.secondary, isFalse);
      const other = VolunteerAccount(
        uid: 'other-test-volunteer',
        name: LocalizedData('Other', 'آخر'),
        volunteerId: 'V-OTHER',
        active: true,
      );
      await repo.startSearch(other, item);
      await tester.pumpAndSettle();
      final join = find.descendant(
        of: card,
        matching: find.text(s.vJoinSearch),
      );
      expect(join, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(s.vStartSearch)),
        findsNothing,
      );
      final joinAction = tester.widget<VolunteerAction>(
        find.ancestor(of: join, matching: find.byType(VolunteerAction)),
      );
      expect(joinAction.secondary, isFalse);
      await Scrollable.ensureVisible(tester.element(join), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(join);
      await tester.pumpAndSettle();
      expect(item.status, CaseStatus.searchInProgress);
      expect(
        item.joinedBy,
        containsAll([other.uid, MockVolunteerRepository.account.uid]),
      );
      expect(
        repo.availableFor(MockVolunteerRepository.account.uid).contains(item),
        isFalse,
      );
      expect(repo.myCases(MockVolunteerRepository.account.uid), contains(item));
      expect(card, findsNothing);
      await tester.tap(find.byKey(const ValueKey("my-cases")));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(s.vJoinSearch)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
