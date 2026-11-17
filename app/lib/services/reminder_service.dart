/// 每日训练提醒（ST-7，M3 简报第 8 节）。本地通知，不接服务端推送。
///
/// 不依赖后台执行代码：通知内容在调度时就写死；App 每次打卡成功后
/// 取消待发通知并从明天起重新调度。所以"今天已打卡"时今天不会再弹。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/db/database.dart';
import '../data/repositories/reminder_repository.dart';
import '../domain/streak.dart' show localDateOf;

/// 一个家庭一只狗，预排 14 个独立通知。
const reminderNotificationId = 1001;
const reminderScheduleDays = 14;
const reminderTitle = '幼犬训练';
const reminderBody = '今天还没练，去看看本周目标';
const reminderChannelId = 'daily_reminder';
const reminderChannelName = '每日训练提醒';

/// 下一次提醒的本地时刻。今天已打卡或今天的时间已过 → 明天同一时刻。纯函数。
DateTime nextReminderAt({
  required DateTime now,
  required int hour,
  required int minute,
  required bool checkedInToday,
}) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day, hour, minute);
  if (!checkedInToday && today.isAfter(local)) return today;
  return DateTime(local.year, local.month, local.day + 1, hour, minute);
}

/// 通知后端抽象，测试 override 成假实现。
abstract class ReminderNotifier {
  Future<void> init({void Function()? onTap});

  /// Android 13+ 申请通知权限；返回是否已授权。
  Future<bool> requestPermission();
  Future<void> cancel(int id);

  /// 在 [firstAt]（本地时刻）弹一次。
  Future<void> scheduleDaily({required int id, required DateTime firstAt});
}

class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  late tz.Location _location;

  @override
  Future<void> init({void Function()? onTap}) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _location = _guessLocalLocation();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onTap?.call(),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> scheduleDaily({required int id, required DateTime firstAt}) async {
    final at = tz.TZDateTime(
        _location, firstAt.year, firstAt.month, firstAt.day, firstAt.hour, firstAt.minute);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      title: reminderTitle,
      body: reminderBody,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          reminderChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // 不申请精确闹钟权限；提醒允许几分钟误差。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// 没有引入 flutter_timezone（简报只允许 timezone），按当前 UTC 偏移选时区：
  /// +08:00 直接用 Asia/Shanghai；否则找一个当前偏移和缩写都一致的时区，找不到退回 UTC 偏移相同的任一时区。
  tz.Location _guessLocalLocation() => guessLocalTzLocation();
}

/// 本机时区（M4 养护通知复用）。调用前需 tzdata.initializeTimeZones()。
tz.Location guessLocalTzLocation() {
  {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    if (offset == const Duration(hours: 8)) return tz.getLocation('Asia/Shanghai');
    tz.Location? sameOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final zone = loc.timeZone(now.millisecondsSinceEpoch);
      if (zone.offset != offset) continue;
      if (zone.abbreviation == now.timeZoneName) return loc;
      sameOffset ??= loc;
    }
    return sameOffset ?? tz.UTC;
  }
}

class ReminderService {
  ReminderService({
    required this.db,
    required this.notifier,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final ReminderNotifier notifier;
  final DateTime Function() _clock;

  ReminderRepository get _repo => ReminderRepository(db);

  /// 今天（本地日历，M2 归日规则：按开始时间的本地日期）是否已有训练记录。
  Future<bool> checkedInToday(String dogId) async {
    final today = localDateOf(_clock());
    final rows = await (db.select(db.trainingSessions)..where((t) => t.dogId.equals(dogId)))
        .get();
    return rows.any((r) => localDateOf(DateTime.parse(r.startedAt)) == today);
  }

  /// 按当前设置与今天的打卡情况重新调度：先取消，开启时再从下一次时刻起每天调度。
  /// 返回下一次提醒时刻（关闭时为 null）。
  Future<DateTime?> refresh(String dogId) async {
    final c = await _repo.get(dogId);
    for (var i = 0; i < reminderScheduleDays; i++) {
      await notifier.cancel(reminderNotificationId + i);
    }
    if (!c.enabled) return null;
    final next = nextReminderAt(
      now: _clock(),
      hour: c.hour,
      minute: c.minute,
      checkedInToday: await checkedInToday(dogId),
    );
    for (var i = 0; i < reminderScheduleDays; i++) {
      final date = DateTime(next.year, next.month, next.day + i, next.hour, next.minute);
      await notifier.scheduleDaily(id: reminderNotificationId + i, firstAt: date);
    }
    return next;
  }

  /// 打卡成功后调用：取消今天的待发通知，从明天起重新调度。
  Future<DateTime?> onCheckin(String dogId) => refresh(dogId);

  /// 设置页保存。首次打开开关时申请通知权限；被拒绝仍保存设置，返回 granted=false 供界面提示。
  Future<({DateTime? next, bool granted})> update(String dogId, ReminderConfig c) async {
    final before = await _repo.get(dogId);
    var granted = true;
    if (c.enabled && !before.enabled) {
      try {
        granted = await notifier.requestPermission();
      } catch (e) {
        debugPrint('通知权限申请失败：$e');
        granted = false;
      }
    }
    await _repo.save(dogId, c, now: _clock());
    return (next: await refresh(dogId), granted: granted);
  }
}
