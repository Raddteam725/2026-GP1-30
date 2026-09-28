import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radd/features/volunteer/data/volunteer_notification_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Handled foreground event survives reopen/login; new events still present',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await VolunteerNotificationMemory.accept('one', 'event', 'case-new'),
        isTrue,
      );
      for (var session = 0; session < 3; session++) {
        expect(
          await VolunteerNotificationMemory.accept('one', 'event', 'case-new'),
          isFalse,
        );
      }
      expect(
        await VolunteerNotificationMemory.accept(
          'one',
          'event',
          'case-cancelled',
        ),
        isTrue,
      );
      expect(
        await VolunteerNotificationMemory.accept('two', 'event', 'case-new'),
        isTrue,
      );
    },
  );
}
