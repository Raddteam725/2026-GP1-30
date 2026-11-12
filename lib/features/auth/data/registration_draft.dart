import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local onboarding convenience only. Never stores credentials or grants
/// access; Firebase and the API independently authorize every protected action.
class RegistrationDraft {
  static String _key(String uid) => 'radd.registration.$uid';

  static Future<Map<String, dynamic>> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null) return {};
    try {
      final data = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final saved = DateTime.tryParse(data['savedAt'] as String? ?? '');
      if (saved == null ||
          DateTime.now().difference(saved) > const Duration(days: 7)) {
        await prefs.remove(_key(uid));
        return {};
      }
      return data;
    } catch (_) {
      return {};
    }
  }

  static Future<void> update(String uid, Map<String, dynamic> values) async {
    final data = await read(uid);
    data.addAll(values);
    data['savedAt'] = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(uid), jsonEncode(data))) {
      throw StateError('Onboarding draft could not be saved');
    }
  }

  static Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
