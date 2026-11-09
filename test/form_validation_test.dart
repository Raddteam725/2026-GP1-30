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
      ' (05) 012.345-67 ': '+966501234567',
      '+٩٦٦٥٠١٢٣٤٥٦٧': '+966501234567',
    }.entries) {
      expect(normalizeSaudiPhone(entry.key), entry.value, reason: entry.key);
      expect(FormValidation.phone(entry.key, s), isNull, reason: entry.key);
    }
    for (final bad in [
      '0412345678',
      '0112345678',
      '+966412345678',
      '+966112345678',
      '٠٤١٢٣٤٥٦٧٨',
      '966612345678',
      '٠٥١٢٣٤٥٦٧٨٩',
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
    expect(normalizeSaudiPhone(null), isNull);
    for (final locale in ['en', 'ar']) {
      final localized = lookupAppLocalizations(Locale(locale));
      expect(FormValidation.phone('0412345678', localized), localized.invalidPhone);
    }
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

  test('Password confirmation must exactly match the password', () {
    expect(
      FormValidation.confirmPassword('', 'ValidPass1#', s),
      s.requiredField,
    );
    expect(
      FormValidation.confirmPassword(null, 'ValidPass1#', s),
      s.requiredField,
    );
    expect(
      FormValidation.confirmPassword('ValidPass1!', 'ValidPass1#', s),
      s.passwordMismatch,
    );
    expect(
      FormValidation.confirmPassword('ValidPass1# ', 'ValidPass1#', s),
      s.passwordMismatch,
    );
    expect(
      FormValidation.confirmPassword('ValidPass1#', 'ValidPass1#', s),
      isNull,
    );
  });
}
