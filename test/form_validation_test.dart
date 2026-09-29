import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/auth/presentation/form_validation.dart';
import 'package:radd/shared/saudi_phone.dart';

/// Sprint-0 scope: the current release supports Saudi Arabian phone numbers.
/// Any common way of writing one is accepted and normalized to the canonical
/// international form, identically to the backend (normalize_saudi_phone).
/// The password policy is the documented one: 8+ characters with upper,
/// lower, digit and symbol.
void main() {
  final s = lookupAppLocalizations(const Locale('en'));
  test('Saudi numbers in any common form normalize to one canonical form', () {
    for (final entry in {
      '+966501234567': '+966501234567',
      '0501234567': '+966501234567',
      '00966 50 123 4567': '+966501234567',
      '966-50-123-4567': '+966501234567',
      '٠٥٠١٢٣٤٥٦٧': '+966501234567', // Arabic-Indic digits
      '+966112345678': '+966112345678', // landline
      ' 0112345678 ': '+966112345678',
    }.entries) {
      expect(normalizeSaudiPhone(entry.key), entry.value, reason: entry.key);
      expect(FormValidation.phone(entry.key, s), isNull, reason: entry.key);
    }
    for (final bad in [
      '+201234567890', // another country
      '+9665123456789', // too long
      '05123', // too short
      '+96601234567', // national number cannot start with 0
      'abc',
      '',
    ]) {
      expect(normalizeSaudiPhone(bad), isNull, reason: bad);
      expect(FormValidation.phone(bad, s), isNotNull, reason: bad);
    }
    expect(FormValidation.phone('abc', s), s.invalidPhone);
  });

  test('Password policy: at least 8 with upper, lower, number and symbol', () {
    expect(FormValidation.password('ValidPass1#', s), isNull);
    expect(FormValidation.password('Short1#A', s), isNull); // exactly 8
    for (final weak in [
      'Sh1#abc', // 7 characters
      'nouppercase1#',
      'NOLOWERCASE1#',
      'NoNumber##',
      'NoSymbol12',
    ]) {
      expect(FormValidation.password(weak, s), s.passwordHelp, reason: weak);
    }
  });
}
