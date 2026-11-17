/// 训练记录与连续打卡（RC-1 / RC-2 / RC-3 / ST-1）。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/streak.dart';
import '../db/database.dart';
import 'repositories.dart';

/// 跟练结束、尚未评分的一次记录草稿。评分在记录页补齐后才写库。
class SessionDraft {
  const SessionDraft({
    required this.dogId,
    required this.userId,
    required this.skillId,
    required this.scriptPart,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.clickerCount,
    required this.skippedSteps,
  });

  final String dogId;
  final String userId;
  final String skillId;

  /// 0 表示 mini_script。
  final int scriptPart;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final int clickerCount;

  /// 被跳过的步骤编号（ScriptStep.step）。
  final List<int> skippedSteps;
}

class SaveSessionResult {
  const SaveSessionResult({
    required this.sessionId,
    required this.currentStreak,
    required this.countedToGoal,
  });
  final String sessionId;
  final int currentStreak;

  /// 本次记录是否计入了本周某个目标的完成次数（保底任务和非目标技能不计）。
  final bool countedToGoal;
}

/// 把"跳过了哪些步骤"写进备注文字（TR-6）。没有跳过时原样返回用户输入。
String composeSessionNote(List<int> skippedSteps, String? userText) {
  final text = (userText ?? '').trim();
  if (skippedSteps.isEmpty) return text;
  final line = '跳过步骤：${skippedSteps.join('、')}';
  return text.isEmpty ? line : '$line\n$text';
}

String scoreToDb(Score s) => switch (s) {
      Score.full => 'full',
      Score.partial => 'partial',
      Score.none => 'none',
    };

Score? scoreFromDb(String? s) => switch (s) {
      'full' => Score.full,
      'partial' => Score.partial,
      'none' => Score.none,
      _ => null,
    };

class SessionRepository {
  SessionRepository(this.db);
  final AppDatabase db;

  /// 写入一次训练记录，并在同一事务里：累加本周目标完成次数、更新技能状态、
  /// 重算并写入 Streak。保底任务（scriptPart == 0）不计入目标进度（简报第 10 节）。
  Future<SaveSessionResult> save({
    required SessionDraft draft,
    required Score score,
    String? noteText,
    String? videoPath,
    DateTime? now,
  }) async {
    final nowLocal = (now ?? DateTime.now()).toLocal();
    final id = 'ses_${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}';
    var counted = false;
    var streakDays = 0;

    await db.transaction(() async {
      final note = composeSessionNote(draft.skippedSteps, noteText);
      await db.into(db.trainingSessions).insert(TrainingSessionsCompanion.insert(
            id: id,
            dogId: draft.dogId,
            userId: draft.userId,
            skillId: draft.skillId,
            scriptPart: draft.scriptPart,
            startedAt: draft.startedAt.toUtc().toIso8601String(),
            endedAt: draft.endedAt.toUtc().toIso8601String(),
            durationSec: draft.durationSec,
            score: scoreToDb(score),
            noteText: Value(note.isEmpty ? null : note),
            noteVideoUrl: Value(videoPath),
            skippedSteps: Value(jsonEncode(draft.skippedSteps)),
            clickerCount: Value(draft.clickerCount),
          ));

      // 目标进度：按"这次练习开始那天所在的周"找计划。
      if (draft.scriptPart != miniScriptPart) {
        final week = dateOnly(weekStartOf(draft.startedAt.toLocal()));
        final plan = await (db.select(db.weeklyPlans)
              ..where((t) => t.dogId.equals(draft.dogId) & t.weekStart.equals(week)))
            .getSingleOrNull();
        if (plan != null) {
          final goal = await (db.select(db.planGoals)
                ..where((t) =>
                    t.planId.equals(plan.id) & t.skillId.equals(draft.skillId)))
              .getSingleOrNull();
          if (goal != null) {
            await (db.update(db.planGoals)
                  ..where((t) =>
                      t.planId.equals(plan.id) & t.skillId.equals(draft.skillId)))
                .write(PlanGoalsCompanion(
              completedSessions: Value(goal.completedSessions + 1),
            ));
            counted = true;
          }
        }
      }

      // 技能状态：available → in_progress；完全做到 / 没做到计数（只统计正式脚本）。
      final st = await (db.select(db.dogSkillStatuses)
            ..where((t) =>
                t.dogId.equals(draft.dogId) & t.skillId.equals(draft.skillId)))
          .getSingleOrNull();
      if (st != null) {
        var status = st.status;
        if (status == 'available') status = 'in_progress';
        var full = st.fullSuccessCount;
        var fail = st.failCount;
        if (draft.scriptPart != miniScriptPart) {
          if (score == Score.full) full++;
          if (score == Score.none) fail++;
        }
        await (db.update(db.dogSkillStatuses)
              ..where((t) =>
                  t.dogId.equals(draft.dogId) & t.skillId.equals(draft.skillId)))
            .write(DogSkillStatusesCompanion(
          status: Value(status),
          fullSuccessCount: Value(full),
          failCount: Value(fail),
        ));
      }

      streakDays = (await _recomputeStreak(draft.dogId, nowLocal)).currentDays;
    });

    return SaveSessionResult(
      sessionId: id,
      currentStreak: streakDays,
      countedToGoal: counted,
    );
  }

  /// 扫描该狗全部记录重算 Streak 并写表。只在写记录时调用，首页读 Streak 表。
  Future<StreakResult> _recomputeStreak(String dogId, DateTime now) async {
    final rows = await (db.selectOnly(db.trainingSessions)
          ..addColumns([db.trainingSessions.startedAt])
          ..where(db.trainingSessions.dogId.equals(dogId)))
        .get();
    final starts = [
      for (final r in rows)
        DateTime.parse(r.read(db.trainingSessions.startedAt)!),
    ];
    final result = computeStreak(startedAt: starts, today: now);
    await db.into(db.streaks).insertOnConflictUpdate(StreaksCompanion.insert(
          dogId: dogId,
          currentDays: Value(result.currentDays),
          longestDays: Value(result.longestDays),
          lastCheckinDate: Value(
              result.lastCheckinDate == null ? null : dateOnly(result.lastCheckinDate!)),
        ));
    return result;
  }

  Future<Streak?> streakOf(String dogId) => (db.select(db.streaks)
        ..where((t) => t.dogId.equals(dogId)))
      .getSingleOrNull();

  Future<List<TrainingSession>> sessionsOf(String dogId) =>
      (db.select(db.trainingSessions)
            ..where((t) => t.dogId.equals(dogId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// 某一周（本地日历）内是否已有记录。[weekStart] 为周一的纯日期。
  Future<bool> hasSessionsInWeek(String dogId, DateTime weekStart) async {
    final rows = await sessionsOf(dogId);
    final start = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return rows.any((r) {
      final d = localDateOf(DateTime.parse(r.startedAt));
      return !d.isBefore(start) && d.isBefore(end);
    });
  }
}
