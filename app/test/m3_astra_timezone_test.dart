import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:puppy_trainer/services/reminder_service.dart';

class CapturePlugin implements FlutterLocalNotificationsPlugin {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  tz.TZDateTime? scheduled;
  DateTimeComponents? matching;
  @override
  Future<bool?> initialize({required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async => true;
  @override
  Future<void> zonedSchedule({required int id, required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title, String? body, String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async { scheduled = scheduledDate; matching = matchDateTimeComponents; }
}

void main() {
  test('local reminder keeps wall-clock time and instant outside UTC+8', () async {
    final plugin = CapturePlugin();
    final notifier = LocalReminderNotifier(plugin);
    await notifier.init();
    final now = DateTime.now();
    final expected = DateTime(now.year, now.month, now.day, 19, 23);
    await notifier.scheduleDaily(id: 1001, firstAt: expected);
    expect(plugin.matching, isNull);
    expect(plugin.scheduled!.hour, 19);
    expect(plugin.scheduled!.minute, 23);
    expect(plugin.scheduled!.millisecondsSinceEpoch, expected.millisecondsSinceEpoch);
  });
}
