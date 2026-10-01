import '../../../core/localization/generated/app_localizations.dart';
import '../../../shared/saudi_phone.dart';

abstract final class FormValidation {
  static String? required(String? value, AppLocalizations s) =>
      value == null || value.trim().isEmpty ? s.requiredField : null;
  static String? name(String? v, AppLocalizations s) =>
      required(v, s) ?? (v!.trim().length > 120 ? s.invalidName : null);
  static String? email(String? v, AppLocalizations s) =>
      required(v, s) ??
      (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!.trim())
          ? s.invalidEmail
          : null);

  /// Saudi Arabian phone numbers in any common form (see
  /// lib/shared/saudi_phone.dart); the API sends the canonical form.
  static String? phone(String? v, AppLocalizations s) =>
      required(v, s) ??
      (normalizeSaudiPhone(v) == null ? s.invalidPhone : null);
  static bool strongPassword(String v) =>
      v.length >= 8 &&
      RegExp('[A-Z]').hasMatch(v) &&
      RegExp('[a-z]').hasMatch(v) &&
      RegExp('[0-9]').hasMatch(v) &&
      RegExp(r'[^A-Za-z0-9\s]').hasMatch(v);
  static String? password(String? v, AppLocalizations s) =>
      required(v, s) ?? (!strongPassword(v!) ? s.passwordHelp : null);
  static String? age(String? v, AppLocalizations s) {
    final n = int.tryParse(v?.trim() ?? '');
    return n == null || n < 0 || n > 130 ? s.invalidAge : null;
  }
}
