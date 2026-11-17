/// 周报与下周计划的生成（WP-5 / WP-6）。
///
/// 汇总与规则都在 domain/ 的纯函数里，这里只负责读库、调纯函数、一次事务写回。
/// 幂等：同一 plan_id 只会有一份周报（weekly_reports.plan_id 唯一），
/// 同一只狗同一周只会有一份计划（weekly_plans (dog_id, week_start) 唯一）。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/plan_generator.dart';
import '../../domain/weekly_report.dart';
import '../db/database.dart';
import 'repositories.dart';
import 'session_repository.dart';

/// JSON 数组文本 → 字符串列表；格式错误返回空列表（不让一列脏数据挡住周报）。
List<String> decodeIdList(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final v = jsonDecode(json);
    if (v is List) return [for (final e in v) e.toString()];
  } catch (_) {}
  return const [];
}

class ReportGenerationResult {
  const ReportGenerationResult({
    required this.created,
    required this.reportId,
    required this.nextPlanId,
  });

  /// 本次调用是否真的新建了周报；false 表示已存在，直接返回已有的。
  final bool created;
  final String reportId;
  final String? nextPlanId;
}

class ReportRepository {
  ReportRepository(this.db);
  final AppDatabase db;

  Future<WeeklyReport?> byPlan(String planId) =>
      (db.select(db.weeklyReports)..where((t) => t.planId.equals(planId)))
          .getSingleOrNull();

  Future<WeeklyReport?> byId(String id) =>
      (db.select(db.weeklyReports)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<WeeklyReport>> allOf(String dogId) => (db.select(db.weeklyReports)
        ..where((t) => t.dogId.equals(dogId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

  /// 最近一份未读周报。
  Future<WeeklyReport?> latestUnread(String dogId) =>
      (db.select(db.weeklyReports)
            ..where((t) => t.dogId.equals(dogId) & t.readAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> markRead(String reportId, {DateTime? now}) =>
      (db.update(db.weeklyReports)
            ..where((t) => t.id.equals(reportId) & t.readAt.isNull()))
          .write(WeeklyReportsCompanion(
        readAt: Value((now ?? DateTime.now()).toUtc().toIso8601String()),
      ));

  /// 为 [planId] 生成周报，并按 WP-6 生成下周计划。幂等，可被 workmanager
  /// 与冷启动补跑两条路径重复调用。
  Future<ReportGenerationResult> generate({
    required String planId,
    required ContentLibrary content,
    DateTime? now,
  }) async {
    final existing = await byPlan(planId);
    if (existing != null) {
      return ReportGenerationResult(
        created: false,
        reportId: existing.id,
        nextPlanId: existing.nextPlanId,
      );
    }
    try {
      return await db.transaction(() => _generateInTransaction(
            planId: planId,
            content: content,
            now: (now ?? DateTime.now()).toLocal(),
          ));
    } catch (e) {
      // 另一条路径（另一个 isolate）抢先写入时，唯一约束会让本次事务失败；
      // 此时已有周报，按"已存在"返回，不算错误。
      final raced = await byPlan(planId);
      if (raced != null) {
        return ReportGenerationResult(
          created: false,
          reportId: raced.id,
          nextPlanId: raced.nextPlanId,
        );
      }
      rethrow;
    }
  }

  Future<ReportGenerationResult> _generateInTransaction({
    required String planId,
    required ContentLibrary content,
    required DateTime now,
  }) async {
    final plan = await (db.select(db.weeklyPlans)
          ..where((t) => t.id.equals(planId)))
        .getSingle();
    final dog = await (db.select(db.dogs)
          ..where((t) => t.id.equals(plan.dogId)))
        .getSingle();

    final goalRows = await (db.select(db.planGoals)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final sessionRows = await (db.select(db.trainingSessions)
          ..where((t) => t.dogId.equals(dog.id)))
        .get();

    final weekStart = parseDateOnly(plan.weekStart);
    final summary = summarizeWeek(
      weekStart: weekStart,
      goals: [
        for (final g in goalRows)
          ReportGoal(
            skillId: g.skillId,
            targetSessions: g.targetSessions,
            scoringHint: content.skillById[g.skillId]?.scoringHint ?? '',
          ),
      ],
      sessions: [
        for (final s in sessionRows)
          if (scoreFromDb(s.score) case final score?)
            ReportSession(
              skillId: s.skillId,
              scriptPart: s.scriptPart,
              startedAt: DateTime.parse(s.startedAt),
              score: score,
            ),
      ],
    );

    // 下周周一：正常是本周一 + 7 天；久未打开 App 补跑时直接落到"当前这一周"。
    final thisMonday = weekStartOf(now);
    final planned = weekStart.add(const Duration(days: 7));
    final nextWeekStart = planned.isAfter(thisMonday) ? planned : thisMonday;

    final statusRows = await (db.select(db.dogSkillStatuses)
          ..where((t) => t.dogId.equals(dog.id)))
        .get();
    final mastered = {
      for (final r in statusRows)
        if (r.status == 'mastered') r.skillId,
    };
    final concerns = [
      for (final c in await (db.select(db.dogConcerns)
            ..where((t) => t.dogId.equals(dog.id)))
          .get())
        c.issueId,
    ];

    final next = nextWeekPlan(
      thisWeek: [for (final g in summary.goals) g.toStat()],
      input: PlanInput(
        ageWeeks: ageWeeksOn(parseDateOnly(dog.birthDate), nextWeekStart),
        mastered: mastered,
        concerns: concerns,
        dailyMinutes: dog.dailyMinutes,
      ),
      skills: content.skills,
      issues: content.issues,
      regenerateNext: plan.regenerateNext,
      pendingDiagnosisSkills: decodeIdList(plan.pendingDiagnosisSkills),
    );

    final nowIso = now.toUtc().toIso8601String();

    // 新掌握的技能 → DogSkillStatus，并解锁前置已满足的后继技能。
    if (next.newlyMastered.isNotEmpty) {
      final all = {...mastered, ...next.newlyMastered};
      for (final id in next.newlyMastered) {
        await (db.update(db.dogSkillStatuses)
              ..where((t) => t.dogId.equals(dog.id) & t.skillId.equals(id)))
            .write(DogSkillStatusesCompanion(
          status: const Value('mastered'),
          masteredAt: Value(nowIso),
        ));
      }
      for (final r in statusRows) {
        if (r.status != 'locked') continue;
        final skill = content.skillById[r.skillId];
        if (skill == null) continue;
        if (skill.prerequisites.every(all.contains)) {
          await (db.update(db.dogSkillStatuses)
                ..where((t) =>
                    t.dogId.equals(dog.id) & t.skillId.equals(r.skillId)))
              .write(
                  const DogSkillStatusesCompanion(status: Value('available')));
        }
      }
    }

    // 旧计划完成；新计划 active，generated_by = system。
    await (db.update(db.weeklyPlans)..where((t) => t.id.equals(planId)))
        .write(const WeeklyPlansCompanion(status: Value('completed')));

    final nextPlanId = weeklyPlanId(dog.id, dateOnly(nextWeekStart));
    // M4：下周计划主键确定性。另一台设备已生成并同步过来时不重复生成（同一周只一份）。
    final nextExists = await (db.select(db.weeklyPlans)
          ..where((t) =>
              t.id.equals(nextPlanId) |
              (t.dogId.equals(dog.id) &
                  t.weekStart.equals(dateOnly(nextWeekStart)))))
        .getSingleOrNull();
    if (nextExists == null) {
      await db.into(db.weeklyPlans).insert(WeeklyPlansCompanion.insert(
            id: nextPlanId,
            dogId: dog.id,
            weekStart: dateOnly(nextWeekStart),
            generatedBy: 'system',
            status: 'active',
            createdAt: nowIso,
          ));
      for (var i = 0; i < next.plan.goals.length; i++) {
        final g = next.plan.goals[i];
        await db.into(db.planGoals).insert(PlanGoalsCompanion.insert(
              planId: nextPlanId,
              skillId: g.skillId,
              position: i,
              targetSessions: g.targetSessions,
              source: sourceToDb(g.source),
            ));
      }
      final mt = next.plan.miniTask;
      if (mt != null) {
        await db.into(db.dailyMiniTasks).insert(DailyMiniTasksCompanion.insert(
              planId: nextPlanId,
              skillId: mt.skillId,
              scriptPart: mt.scriptPart,
            ));
      }
    }

    final reportId = weeklyReportId(planId);
    await db.into(db.weeklyReports).insert(WeeklyReportsCompanion.insert(
          id: reportId,
          dogId: dog.id,
          planId: planId,
          summaryJson: jsonEncode(summary.toJson()),
          aiComment: summary.comment,
          nextPlanId: Value(nextExists?.id ?? nextPlanId),
          createdAt: nowIso,
        ));

    return ReportGenerationResult(
      created: true,
      reportId: reportId,
      nextPlanId: nextExists?.id ?? nextPlanId,
    );
  }
}
