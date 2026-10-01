import 'package:shared_preferences/shared_preferences.dart';

/// Presentation memory only; never authorization or the notification history.
/// The push service serializes calls so concurrent callbacks cannot replay an ID.
abstract final class VolunteerNotificationMemory {
  static Future<bool> accept(String uid, String eventId, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'volunteer_handled_${uid}_$eventId';
    final seen = prefs.getStringList(key) ?? <String>[];
    if (seen.contains(id)) return false;
    return prefs.setStringList(key, [...seen, id]);
  }
}
