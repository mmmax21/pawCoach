/// AI-5 主动干预的本地推送（M4 批次 B）。规则见 domain/nudges.dart。
///
/// 去重：已推过的触发键记在 [NudgeStore]（默认为应用文档目录下的一个 JSON 文件，不改数据库 schema）。
/// "连续 3 天无打卡"预排到未来时刻，每次打卡 / 同步后取消重排；降级建议在发现时立即推送一次。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db/database.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/repositories.dart' show PlanRepository;
import '../data/repositories/session_repository.dart' show scoreFromDb;
import '../domain/models.dart';
import '../domain/nudges.dart';
import '../domain/streak.dart' show localDateOf;
import 'care_reminder_service.dart' show CareNotifier;

abstract class NudgeStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> keys);
}

class MemoryNudgeStore implements NudgeStore {
  Set<String> keys = {};
  @override
  Future<Set<String>> load() async => {...keys};
  @override
  Future<void> save(Set<String> k) async => keys = {...k};
}

class FileNudgeStore implements NudgeStore {
  Future<File> _file() async => File(p.join((await getApplicationDocumentsDirectory()).path, 'ai5_nudges_sent.json'));

  @override
  Future<Set<String>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return {...(jsonDecode(await f.readAsString()) as List).cast<String>()};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Set<String> keys) async {
    // 只保留最近 200 条，避免无限增长。
    final list = keys.toList();
    final keep = list.length > 200 ? list.sublist(list.length - 200) : list;
    await (await _file()).writeAsString(jsonEncode(keep));
  }
}

class NudgeService {
  NudgeService({required this.db, required this.notifier, required this.store, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final CareNotifier notifier;
  final NudgeStore store;
  final DateTime Function() _clock;

  /// 重新判定并排期。返回本轮新排的推送（测试与可测性入口读取）。
  ///
  /// 受每日提醒开关控制（Fable 2026-11-17 裁定）：开关关闭时两类推送都不排，已排的全部取消，
  /// 并把尚未到点的"连续 3 天无打卡"从已推记录里移除，重新打开时按当前状态重排。
  Future<List<Nudge>> refresh(String dogId, ContentLibrary content) async {
    final now = _clock();
    final rows = await (db.select(db.trainingSessions)..where((t) => t.dogId.equals(dogId))).get();
    final sent = await store.load();
    final out = <Nudge>[];

    final enabled = (await ReminderRepository(db).get(dogId)).enabled;
    if (!enabled) {
      for (var id = nudgeRestartId; id <= nudgeIdMax; id++) {
        await notifier.cancel(id);
      }
      final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingleOrNull();
      if (dog != null) {
        final n = restartNudge(
          lastActiveDay: _lastActiveDay(rows, dog),
          now: now,
          miniSkillName: null,
        );
        // 只移除还没到点的预排（已经推过的不再补推）。
        final key = n.key;
        if (sent.contains(key) && _restartAt(_lastActiveDay(rows, dog)).isAfter(now)) {
          sent.remove(key);
          await store.save(sent);
        }
      }
      return out;
    }

    // 规则 1：降级建议，立即推一次。
    for (final n in downgradeNudges(
      sessions: [
        for (final r in rows)
          NudgeSession(
              skillId: r.skillId, scriptPart: r.scriptPart, score: scoreFromDb(r.score), startedAt: DateTime.parse(r.startedAt)),
      ],
      skills: content.skills,
    )) {
      if (sent.contains(n.key)) continue;
      await notifier.scheduleOnce(id: n.id, at: now.add(const Duration(seconds: 5)), title: n.title, body: n.body);
      sent.add(n.key);
      out.add(n);
    }

    // 规则 2：连续 3 天无打卡，预排。触发键 = 最近打卡日；有新打卡时键变化，取消旧的再排新的；
    // 键没变（已排过或已推过）就保持不动，不重复推。
    final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingleOrNull();
    if (dog != null) {
      final last = _lastActiveDay(rows, dog);
      final plan = await PlanRepository(db).activePlan(dogId);
      final mini = plan == null ? null : await PlanRepository(db).miniTask(plan.id);
      final n = restartNudge(
        lastActiveDay: last,
        now: now,
        miniSkillName: mini == null ? null : content.skillById[mini.skillId]?.name,
      );
      if (!sent.contains(n.key)) {
        await notifier.cancel(nudgeRestartId);
        await notifier.scheduleOnce(id: n.id, at: n.at!, title: n.title, body: n.body);
        sent.add(n.key);
        out.add(n);
      }
    }
    await store.save(sent);
    return out;
  }

  /// 最近一次打卡的本地日期；从未打卡用建档日。
  DateTime _lastActiveDay(List<TrainingSession> rows, Dog dog) {
    final days = [for (final r in rows) localDateOf(DateTime.parse(r.startedAt))]..sort();
    final d = days.isEmpty ? localDateOf(DateTime.parse(dog.createdAt)) : days.last;
    return DateTime(d.year, d.month, d.day);
  }

  /// 该最近打卡日对应的"连续 3 天无打卡"原定推送时刻（不做"已过则顺延"）。
  DateTime _restartAt(DateTime last) => DateTime(last.year, last.month, last.day + nudgeIdleDays + 1, nudgeRestartHour);
}
