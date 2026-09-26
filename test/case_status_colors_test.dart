import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/guardian/data/case_models.dart';
import 'package:radd/features/guardian/presentation/case_widgets.dart';

/// The ONE Guardian case-status colour contract (case_widgets.dart):
/// canonical backend status -> exact colour, identical on every screen and
/// in both languages; "Report Missing" is an action colour, not a status.
void main() {
  const expected = {
    'report_received': Color(0xFF2563EB),
    'search_in_progress': Color(0xFFF59E0B),
    'match_confirmed': Color(0xFF7C3AED),
    'awaiting_guardian_verification': Color(0xFF0D9488),
    'reunited': Color(0xFF16A34A),
    'resolved': Color(0xFF16A34A),
    'cancelled': Color(0xFF64748B),
    'transferred_to_authority': Color(0xFFEA580C),
  };

  test('Every canonical case status maps to exactly its required colour', () {
    expected.forEach((status, colour) {
      expect(caseStatusColor(status), colour, reason: status);
    });
    // Nothing more, nothing less: the five ordered stages and every
    // terminal outcome, keyed on the backend identifier only.
    expect(caseStatusColors.keys.toSet(), {...caseStages, ...terminalStatuses});
    expect(caseStatusColors.keys.toSet(), expected.keys.toSet());
  });

  test('Reunited and Resolved intentionally share #16A34A', () {
    expect(caseStatusColor('reunited'), const Color(0xFF16A34A));
    expect(caseStatusColor('resolved'), caseStatusColor('reunited'));
  });

  test('Report Missing stays a red ACTION colour, never a status colour', () {
    expect(reportMissingColor, const Color(0xFFDC2626));
    expect(caseStatusColors.containsKey('report_missing'), isFalse);
    expect(caseStatusColors.values, isNot(contains(reportMissingColor)));
    // "Active Case" is not a canonical status either: no colour of its own.
    expect(caseStatusColors.containsKey('active'), isFalse);
    expect(caseStatusColors.containsKey('active_case'), isFalse);
  });

  test('An unknown status degrades to the muted colour, never a wrong one', () {
    expect(caseStatusColor('something_new'), mutedText);
    expect(caseStatusTint('cancelled').a, closeTo(.12, .01));
  });

  // The chip's status dot: the circular DecoratedBox (the chip's own tinted
  // background is a rectangle-shaped DecoratedBox too).
  Color chipDot(WidgetTester t) {
    final dot = t
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(StatusChip),
            matching: find.byType(DecoratedBox),
          ),
        )
        .firstWhere(
          (box) => (box.decoration as BoxDecoration).shape == BoxShape.circle,
        );
    return (dot.decoration as BoxDecoration).color!;
  }

  Color chipText(WidgetTester t) => t
      .widget<Text>(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.byType(Text),
        ),
      )
      .style!
      .color!;

  for (final status in expected.keys) {
    testWidgets('StatusChip paints $status from the canonical status in '
        'Arabic and English alike', (t) async {
      final seen = <String, Color>{};
      final labels = <String, String>{};
      for (final locale in ['ar', 'en']) {
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Center(child: StatusChip(status: status)),
            ),
          ),
        );
        await t.pumpAndSettle();
        seen[locale] = chipDot(t);
        expect(chipText(t), seen[locale]);
        labels[locale] = t
            .widget<Text>(
              find.descendant(
                of: find.byType(StatusChip),
                matching: find.byType(Text),
              ),
            )
            .data!;
      }
      // Different words, identical colour: colour comes from the identifier.
      expect(labels['ar'], isNot(labels['en']));
      expect(seen['ar'], expected[status]);
      expect(seen['en'], expected[status]);
    });
  }
}
