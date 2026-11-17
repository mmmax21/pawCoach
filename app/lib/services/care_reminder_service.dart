/// 养护到期本地推送（CR-1，M4 简报第 8 节）。
///
/// 到期日当天 09:00；只预排未来 60 天内、未完成、未跳过的条目；过期条目不推送。
/// 通知 ID 2000–2999（每日提醒是 1001–1014）。启动、编辑、同步后整体重排。
library;

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/db/database.dart';
import '../data/repositories/repositories.dart' show parseDateOnly;
import '../domain/care_calendar.dart';
import 'reminder_service.dart' show guessLocalTzLocation;

const careChannelId = 'care_reminder';
const careChannelName = '疫苗与驱虫提醒';

abstract class CareNotifier {
  Future<void> cancel(int id);

  /// 在本地时刻 [at] 弹一次，标题 / 正文为条目原文。
  Future<void> scheduleOnce({required int id, required DateTime at, required String title, required String body});
}

class LocalCareNotifier implements CareNotifier {
  LocalCareNotifier([FlutterLocalNotificationsPlugin? plugin, this.channelId = careChannelId, this.channelName = careChannelName])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  final String channelId;
  final String channelName;
  tz.Location? _location;

  tz.Location get _loc {
    if (_location == null) {
      tzdata.initializeTimeZones();
      _location = guessLocalTzLocation();
    }
    return _location!;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> scheduleOnce({required int id, required DateTime at, required String title, required String body}) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime(_loc, at.year, at.month, at.day, at.hour, at.minute, at.second),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(channelId, channelName,
              importance: Importance.defaultImportance, priority: Priority.defaultPriority),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
}

class CareReminderService {
  CareReminderService({required this.db, required this.notifier, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final CareNotifier notifier;
  final DateTime Function() _clock;

  /// 上一轮排过的 ID；首轮把整个 2000–2999 区间里可能残留的都取消（只取消实际用到的上限）。
  Set<int>? _scheduled;

  /// 整体重排。返回本轮排期（测试与可测性入口读取）。
  Future<List<CareNotificationPlan>> refresh(String dogId) async {
    final rows = await (db.select(db.careReminders)
          ..where((t) => t.dogId.equals(dogId) & t.deleted.equals(false)))
        .get();
    final plans = planCareNotifications(
      items: [
        for (final r in rows)
          (id: r.id, dueDate: parseDateOnly(r.dueDate), done: r.doneAt != null, skipped: r.skipped),
      ],
      now: _clock(),
    );
    final previous = _scheduled ??
        {for (var i = careNotificationIdBase; i < careNotificationIdBase + 100; i++) i};
    for (final id in previous) {
      await notifier.cancel(id);
    }
    final byId = {for (final r in rows) r.id: r};
    for (final p in plans) {
      final r = byId[p.reminderId]!;
      await notifier.scheduleOnce(id: p.id, at: p.at, title: r.title, body: r.note);
    }
    _scheduled = {for (final p in plans) p.id};
    return plans;
  }
}
