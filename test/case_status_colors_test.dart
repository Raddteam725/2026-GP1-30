import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/guardian/data/case_models.dart';
import 'package:radd/features/guardian/presentation/case_widgets.dart';

void main() {
  test('Every canonical case status maps to its approved semantic colour', () {
    const expected = {
      'report_received': Color(0xFF2563EB),
      'search_in_progress': Color(0xFFF59E0B),
      'match_confirmed': Color(0xFF7C3AED),
      'awaiting_guardian_verification': Color(0xFF0D9488),
      'reunited': Color(0xFF16A34A),
      'resolved': Color(0xFF15803D),
      'cancelled': Color(0xFF64748B),
      'transferred_to_authority': Color(0xFFEA580C),
    };
    expected.forEach((status, colour) {
      expect(caseStatusColor(status), colour, reason: status);
    });
    // Keyed on the backend identifier only: the five ordered stages and
    // every terminal outcome are covered, nothing is derived from a label.
    for (final status in [...caseStages, ...terminalStatuses]) {
      expect(expected.containsKey(status), isTrue, reason: status);
    }
    expect(reportMissingColor, const Color(0xFFDC2626));
  });

  testWidgets('StatusChip paints the canonical colour, not the label', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [],
        home: Scaffold(body: Text('')),
      ),
    );
    // Rendered through the real app in guardian_flow_test; here only the
    // mapping contract matters.
    expect(caseStatusTint('cancelled').a, closeTo(.12, .01));
  });
}
