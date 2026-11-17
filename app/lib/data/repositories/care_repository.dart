/// 疫苗 / 驱虫日历（CR-1，M4 简报第 8 节）。
library;

import 'package:drift/drift.dart';

import '../../domain/care_calendar.dart';
import '../../domain/models.dart';
import '../db/database.dart';
import 'repositories.dart' show dateOnly, parseDateOnly;

class CareRepository {
  CareRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _clock;

  String _now() => _clock().toUtc().toIso8601String();

  Stream<List<CareReminder>> watch(String dogId) => (db.select(db.careReminders)
        ..where((t) => t.dogId.equals(dogId) & t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate), (t) => OrderingTerm.asc(t.id)]))
      .watch();

  Future<List<CareReminder>> all(String dogId) => (db.select(db.careReminders)
        ..where((t) => t.dogId.equals(dogId) & t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate), (t) => OrderingTerm.asc(t.id)]))
      .get();

  /// 建档完成、升级后首次启动、修改出生日期后调用：补齐缺的默认条目，
  /// 只重算 source = default 且未完成、未跳过的条目的到期日。幂等。返回 (新增, 改期) 条数。
  Future<({int inserted, int updated})> syncDefaults(Dog dog, CareCalendar calendar) async {
    final expanded = expandCareCalendar(
      dogId: dog.id,
      birthDate: parseDateOnly(dog.birthDate),
      calendar: calendar,
    );
    final rows = await (db.select(db.careReminders)..where((t) => t.dogId.equals(dog.id))).get();
    final plan = planCareRegeneration(
      expanded: expanded,
      existing: [
        for (final r in rows)
          CareExisting(
            id: r.id,
            source: r.source,
            done: r.doneAt != null,
            skipped: r.skipped,
            dueDate: parseDateOnly(r.dueDate),
          ),
      ],
    );
    if (plan.insert.isEmpty && plan.update.isEmpty) return (inserted: 0, updated: 0);
    await db.transaction(() async {
      for (final e in plan.insert) {
        await db.into(db.careReminders).insert(
              CareRemindersCompanion.insert(
                id: e.id,
                dogId: dog.id,
                templateId: Value(e.templateId),
                type: e.type,
                title: e.title,
                note: Value(e.note),
                dueDate: dateOnly(e.dueDate),
                source: 'default',
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final e in plan.update) {
        await (db.update(db.careReminders)..where((t) => t.id.equals(e.id)))
            .write(CareRemindersCompanion(dueDate: Value(dateOnly(e.dueDate))));
      }
    });
    return (inserted: plan.insert.length, updated: plan.update.length);
  }

  Future<void> markDone(String id) => (db.update(db.careReminders)..where((t) => t.id.equals(id)))
      .write(CareRemindersCompanion(doneAt: Value(_now()), skipped: const Value(false)));

  Future<void> skip(String id) => (db.update(db.careReminders)..where((t) => t.id.equals(id)))
      .write(const CareRemindersCompanion(skipped: Value(true), doneAt: Value(null)));

  /// 撤销完成 / 跳过。
  Future<void> reopen(String id) => (db.update(db.careReminders)..where((t) => t.id.equals(id)))
      .write(const CareRemindersCompanion(skipped: Value(false), doneAt: Value(null)));

  /// 改日期：视为用户条目（source = user），修改出生日期时不再动它。
  Future<void> changeDate(String id, DateTime date) =>
      (db.update(db.careReminders)..where((t) => t.id.equals(id))).write(CareRemindersCompanion(
        dueDate: Value(dateOnly(date)),
        source: const Value('user'),
      ));

  /// 手动新增一条（template_id 为空，source = user）。
  Future<String> addManual({
    required String dogId,
    required String type,
    required String title,
    String note = '',
    required DateTime dueDate,
  }) async {
    final id = 'care_u_${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}';
    await db.into(db.careReminders).insert(CareRemindersCompanion.insert(
          id: id,
          dogId: dogId,
          type: type,
          title: title,
          note: Value(note),
          dueDate: dateOnly(dueDate),
          source: 'user',
        ));
    return id;
  }

  /// 删除用户手动新增的条目（软删除，随同步传播）。默认条目只能完成或跳过。
  Future<void> deleteManual(String id) => (db.update(db.careReminders)
        ..where((t) => t.id.equals(id) & t.templateId.isNull()))
      .write(const CareRemindersCompanion(deleted: Value(true)));
}
