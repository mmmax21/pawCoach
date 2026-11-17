/// 下行同步后的本地重算（M4 简报第 5.3 节）：DogSkillStatus、本周目标完成次数、Streak
/// 由每台客户端从同步来的记录各自重算（输入相同则结果相同），不入发件箱；
/// 之后判定徽章（颁发是真实写入，会同步）。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/skill_status_rebuild.dart';
import '../../domain/streak.dart';
import '../db/database.dart';
import '../repositories/badge_repository.dart';
import '../repositories/report_repository.dart' show decodeIdList;
import '../repositories/repositories.dart' show dateOnly, statusToDb;
import '../repositories/session_repository.dart' show scoreFromDb;

class DerivedState {
  DerivedState(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _clock;

  /// 重算当前狗的派生数据。[content] 为 null 时只重算 Streak。
  Future<void> recompute({ContentLibrary? content}) async {
    final dog = await (db.select(db.dogs)..limit(1)).getSingleOrNull();
    if (dog == null) return;
    await db.untracked(() async {
      final sessions = await (db.select(db.trainingSessions)..where((t) => t.dogId.equals(dog.id))).get();
      await _streak(dog.id, sessions);
      if (content != null) {
        await _statuses(dog, sessions, content);
        await _goalProgress(dog.id, sessions);
      }
    });
    db.notifyUpdates({
      TableUpdate.onTable(db.streaks),
      TableUpdate.onTable(db.dogSkillStatuses),
      TableUpdate.onTable(db.planGoals),
    });
    if (content != null) await BadgeRepository(db, clock: _clock).evaluate(dog.id, content.badges);
  }

  Future<void> _streak(String dogId, List<TrainingSession> sessions) async {
    final r = computeStreak(startedAt: [for (final s in sessions) DateTime.parse(s.startedAt)], today: _clock());
    await db.into(db.streaks).insertOnConflictUpdate(StreaksCompanion.insert(
          dogId: dogId,
          currentDays: Value(r.currentDays),
          longestDays: Value(r.longestDays),
          lastCheckinDate: Value(r.lastCheckinDate == null ? null : dateOnly(r.lastCheckinDate!)),
        ));
  }

  Future<void> _statuses(Dog dog, List<TrainingSession> sessions, ContentLibrary content) async {
    final reports = await (db.select(db.weeklyReports)..where((t) => t.dogId.equals(dog.id))).get();
    final reportMastered = <String, String>{};
    for (final r in reports..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
      try {
        final goals = (jsonDecode(r.summaryJson)['goals'] as List).cast<Map>();
        for (final g in goals) {
          if (g['outcome'] == 'mastered') reportMastered.putIfAbsent(g['skill_id'] as String, () => r.createdAt);
        }
      } catch (_) {}
    }
    final rebuilt = rebuildSkillStatuses(
      skills: content.skills,
      initialMastered: decodeIdList(dog.initialMastered).toSet(),
      dogCreatedAt: dog.createdAt,
      reportMastered: reportMastered,
      sessions: [
        for (final s in sessions)
          StatusSession(skillId: s.skillId, scriptPart: s.scriptPart, score: scoreFromDb(s.score)),
      ],
    );
    final current = {
      for (final r in await (db.select(db.dogSkillStatuses)..where((t) => t.dogId.equals(dog.id))).get())
        r.skillId: r,
    };
    for (final e in rebuilt.entries) {
      final cur = current[e.key];
      final v = e.value;
      final status = statusToDb(v.status);
      // 本机已判定为掌握的不降级（例如本机周报刚生成、周报记录还没推上去）。
      if (cur != null && cur.status == 'mastered' && status != 'mastered') continue;
      if (cur != null &&
          cur.status == status &&
          cur.fullSuccessCount == v.fullSuccessCount &&
          cur.failCount == v.failCount &&
          (status != 'mastered' || cur.masteredAt != null)) {
        continue;
      }
      await db.into(db.dogSkillStatuses).insertOnConflictUpdate(DogSkillStatusesCompanion.insert(
            dogId: dog.id,
            skillId: e.key,
            status: status,
            masteredAt: Value(cur?.masteredAt ?? v.masteredAt),
            fullSuccessCount: Value(v.fullSuccessCount),
            failCount: Value(v.failCount),
          ));
    }
  }

  /// 本周目标完成次数 = 该周（本地日历）该技能的正式脚本记录数（保底任务不计），与打卡时的增量写法一致。
  Future<void> _goalProgress(String dogId, List<TrainingSession> sessions) async {
    final plans = await (db.select(db.weeklyPlans)..where((t) => t.dogId.equals(dogId))).get();
    final count = <String, int>{};
    for (final s in sessions) {
      if (s.scriptPart == miniScriptPart) continue;
      final week = dateOnly(weekStartOf(DateTime.parse(s.startedAt).toLocal()));
      count['$week|${s.skillId}'] = (count['$week|${s.skillId}'] ?? 0) + 1;
    }
    for (final p in plans) {
      final goals = await (db.select(db.planGoals)..where((t) => t.planId.equals(p.id))).get();
      for (final g in goals) {
        final n = count['${p.weekStart}|${g.skillId}'] ?? 0;
        if (n == g.completedSessions) continue;
        await (db.update(db.planGoals)..where((t) => t.planId.equals(p.id) & t.skillId.equals(g.skillId)))
            .write(PlanGoalsCompanion(completedSessions: Value(n)));
      }
    }
  }
}
