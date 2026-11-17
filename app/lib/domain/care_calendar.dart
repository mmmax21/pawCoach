/// 疫苗 / 驱虫默认日历（CR-1，M4 简报第 8 节）。纯函数，无 IO，不依赖 Flutter。
library;

import 'models.dart';

/// 由默认日历展开出的一条养护条目（标题、说明为内容库原文）。
class CareEntry {
  const CareEntry({
    required this.id,
    required this.templateId,
    required this.seq,
    required this.type,
    required this.title,
    required this.note,
    required this.dueDate,
  });

  /// 确定性主键：careReminderId(dogId, templateId, seq)。
  final String id;
  final String templateId;

  /// 同一模板的第几次（一次性项恒为 0）。
  final int seq;
  final String type;
  final String title;
  final String note;

  /// 纯日期（UTC 00:00）。
  final DateTime dueDate;

  @override
  String toString() => 'CareEntry($id, ${dueDate.toIso8601String().substring(0, 10)})';
}

/// CareReminder 确定性主键：同一只狗、同一模板、同一序号在任何设备上都相同。
String careReminderId(String dogId, String templateId, int seq) => 'care_${dogId}_${templateId}_$seq';

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// 出生日期 + 周数 → 纯日期。
DateTime careDateForWeek(DateTime birthDate, int week) =>
    _dateOnly(birthDate).add(Duration(days: week * 7));

/// 按出生日期展开默认日历：
/// - 一次性项：week_from 与 week_to 的中点周（向下取整）；
/// - 重复项：从 week_from 起每 every_weeks 周一次，不超过 week_to；
/// - milestones 不生成条目。
/// 已过期的照常生成（由调用方归入"待确认"），按到期日、模板顺序排序。
List<CareEntry> expandCareCalendar({
  required String dogId,
  required DateTime birthDate,
  required CareCalendar calendar,
}) {
  final out = <CareEntry>[];
  for (final item in calendar.items) {
    final every = item.repeatEveryWeeks;
    final weeks = <int>[];
    if (every == null || every <= 0) {
      weeks.add((item.weekFrom + item.weekTo) ~/ 2);
    } else {
      for (var w = item.weekFrom; w <= item.weekTo; w += every) {
        weeks.add(w);
      }
    }
    for (var i = 0; i < weeks.length; i++) {
      out.add(CareEntry(
        id: careReminderId(dogId, item.id, i),
        templateId: item.id,
        seq: i,
        type: item.type,
        title: item.title,
        note: item.note,
        dueDate: careDateForWeek(birthDate, weeks[i]),
      ));
    }
  }
  final order = {for (var i = 0; i < calendar.items.length; i++) calendar.items[i].id: i};
  out.sort((a, b) {
    final c = a.dueDate.compareTo(b.dueDate);
    if (c != 0) return c;
    final t = order[a.templateId]!.compareTo(order[b.templateId]!);
    return t != 0 ? t : a.seq.compareTo(b.seq);
  });
  return out;
}

/// 现有条目的最小视图（用于重算判断）。
class CareExisting {
  const CareExisting({
    required this.id,
    required this.source,
    required this.done,
    required this.skipped,
    required this.dueDate,
  });
  final String id;

  /// default | user
  final String source;
  final bool done;
  final bool skipped;
  final DateTime dueDate;
}

class CareRegenPlan {
  const CareRegenPlan({required this.insert, required this.update});

  /// 还不存在的默认条目。
  final List<CareEntry> insert;

  /// 需要改到期日的默认条目（source = default、未完成、未跳过、日期变了）。
  final List<CareEntry> update;
}

/// 建档 / 升级 / 修改出生日期时的重算：只动 source = default 且未完成、未跳过的条目；
/// 用户改过日期（source = user）、已完成、已跳过的不动。
CareRegenPlan planCareRegeneration({
  required List<CareEntry> expanded,
  required List<CareExisting> existing,
}) {
  final byId = {for (final e in existing) e.id: e};
  final insert = <CareEntry>[];
  final update = <CareEntry>[];
  for (final e in expanded) {
    final cur = byId[e.id];
    if (cur == null) {
      insert.add(e);
    } else if (cur.source == 'default' && !cur.done && !cur.skipped && cur.dueDate != e.dueDate) {
      update.add(e);
    }
  }
  return CareRegenPlan(insert: insert, update: update);
}

enum CareGroup { overdue, upcoming, later, done }

/// "即将到期"的窗口（天）。简报未规定，取 30 天，交接单注明。
const careUpcomingDays = 30;

/// 养护页分组：已完成或已跳过 → 已完成；到期日早于今天 → 待确认；
/// 30 天内（含今天）→ 即将到期；其余 → 以后。
CareGroup careGroupOf({
  required DateTime dueDate,
  required bool done,
  required bool skipped,
  required DateTime today,
}) {
  if (done || skipped) return CareGroup.done;
  final t = _dateOnly(today);
  final d = _dateOnly(dueDate);
  if (d.isBefore(t)) return CareGroup.overdue;
  if (d.difference(t).inDays <= careUpcomingDays) return CareGroup.upcoming;
  return CareGroup.later;
}

/// 推送只预排未来 60 天内的条目。
const careNotifyHorizonDays = 60;

/// 养护通知 ID 区间 2000–2999，与每日提醒 1001–1014 不冲突。
const careNotificationIdBase = 2000;
const careNotificationIdMax = 2999;

class CareNotificationPlan {
  const CareNotificationPlan({required this.id, required this.at, required this.reminderId});
  final int id;
  final DateTime at;
  final String reminderId;
}

/// 本地通知排期：到期日当天 09:00（本地）；只排未完成、未跳过、未删除、
/// 09:00 尚未过去、且在 [now] 起 60 天内的条目。过期条目不推送。
/// [items] 为 (id, dueDate, done, skipped) 。ID 按到期日顺序从 2000 分配。
List<CareNotificationPlan> planCareNotifications({
  required List<({String id, DateTime dueDate, bool done, bool skipped})> items,
  required DateTime now,
}) {
  final horizon = now.add(const Duration(days: careNotifyHorizonDays));
  final candidates = [
    for (final i in items)
      if (!i.done && !i.skipped)
        (id: i.id, at: DateTime(i.dueDate.year, i.dueDate.month, i.dueDate.day, 9)),
  ]..sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final out = <CareNotificationPlan>[];
  for (final c in candidates) {
    if (!c.at.isAfter(now) || c.at.isAfter(horizon)) continue;
    final nid = careNotificationIdBase + out.length;
    if (nid > careNotificationIdMax) break;
    out.add(CareNotificationPlan(id: nid, at: c.at, reminderId: c.id));
  }
  return out;
}
