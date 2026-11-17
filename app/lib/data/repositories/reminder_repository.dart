/// 每日提醒设置（ST-7，M3 简报第 4、8 节）。默认关闭，默认 19:00。
library;

import 'package:drift/drift.dart';

import '../db/database.dart';

const defaultReminderHour = 19;
const defaultReminderMinute = 0;

class ReminderConfig {
  const ReminderConfig({required this.enabled, required this.hour, required this.minute});
  const ReminderConfig.defaults()
      : enabled = false,
        hour = defaultReminderHour,
        minute = defaultReminderMinute;
  final bool enabled;
  final int hour;
  final int minute;
}

class ReminderRepository {
  ReminderRepository(this.db);
  final AppDatabase db;

  Future<ReminderConfig> get(String dogId) async {
    final row = await (db.select(db.reminderSettings)..where((t) => t.dogId.equals(dogId)))
        .getSingleOrNull();
    if (row == null) return const ReminderConfig.defaults();
    return ReminderConfig(enabled: row.enabled, hour: row.hour, minute: row.minute);
  }

  Future<void> save(String dogId, ReminderConfig c, {DateTime? now}) async {
    if (c.hour < 0 || c.hour > 23 || c.minute < 0 || c.minute > 59) {
      throw ArgumentError('时间不合法：${c.hour}:${c.minute}');
    }
    await db.into(db.reminderSettings).insertOnConflictUpdate(ReminderSettingsCompanion.insert(
          dogId: dogId,
          enabled: Value(c.enabled),
          hour: Value(c.hour),
          minute: Value(c.minute),
          updatedAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
        ));
  }
}
