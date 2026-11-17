/// 狗档案修改（ON-7）：改字段、改口令、按规则决定是否重新生成本周计划。
library;

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/plan_generator.dart';
import '../db/database.dart';
import 'repositories.dart';

/// 档案页能改的全部字段。
class DogProfileEdit {
  const DogProfileEdit({
    required this.name,
    required this.birthDate,
    required this.breedId,
    required this.breedText,
    required this.sex,
    required this.homeDate,
    required this.livingEnv,
    required this.dailyMinutes,
    required this.trainerCount,
    required this.concerns,
  });

  final String name;
  final DateTime birthDate;
  final String breedId;
  final String breedText;
  final Sex sex;
  final DateTime homeDate;
  final LivingEnv livingEnv;
  final int dailyMinutes;
  final int trainerCount;
  final List<String> concerns;
}

/// 保存档案后，对计划做了什么。
enum PlanEffect {
  /// 没有触发计划变化。
  none,

  /// 本周尚无记录，已用 M1 生成器重生成本周计划。
  regeneratedNow,

  /// 本周已有记录，本周不动，已标记下周全新生成。
  markedForNextWeek,
}

/// 哪些字段会触发计划变化：出生日期、困扰、每日时长（M2 简报第 8 节）。
bool planAffectingChanged({
  required Dog before,
  required List<String> concernsBefore,
  required DogProfileEdit after,
}) {
  final b = {...concernsBefore};
  final a = {...after.concerns};
  return before.birthDate != dateOnly(after.birthDate) ||
      before.dailyMinutes != after.dailyMinutes ||
      b.length != a.length ||
      !b.containsAll(a);
}

class ProfileRepository {
  ProfileRepository(this.db);
  final AppDatabase db;

  Future<List<DogCue>> cues(String dogId) =>
      (db.select(db.dogCues)..where((t) => t.dogId.equals(dogId))).get();

  Future<void> updateCue({
    required String dogId,
    required String skillId,
    required String cueWord,
    required String gestureText,
    DateTime? now,
  }) async {
    await (db.update(db.dogCues)
          ..where((t) => t.dogId.equals(dogId) & t.skillId.equals(skillId)))
        .write(DogCuesCompanion(
      cueWord: Value(cueWord),
      gestureText: Value(gestureText),
      updatedAt: Value((now ?? DateTime.now()).toUtc().toIso8601String()),
    ));
  }

  /// 保存档案。全部写入在一个事务里。
  Future<PlanEffect> save({
    required String dogId,
    required DogProfileEdit edit,
    required ContentLibrary content,
    DateTime? now,
  }) async {
    final nowLocal = (now ?? DateTime.now()).toLocal();
    final nowIso = nowLocal.toUtc().toIso8601String();

    return db.transaction(() async {
      final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId)))
          .getSingle();
      final before = [
        for (final c in await (db.select(db.dogConcerns)
              ..where((t) => t.dogId.equals(dogId)))
            .get())
          c.issueId,
      ];
      final affecting =
          planAffectingChanged(before: dog, concernsBefore: before, after: edit);

      await (db.update(db.dogs)..where((t) => t.id.equals(dogId))).write(
        DogsCompanion(
          name: Value(edit.name),
          birthDate: Value(dateOnly(edit.birthDate)),
          breedId: Value(edit.breedId),
          breedText: Value(edit.breedText),
          sex: Value(sexToDb(edit.sex)),
          homeDate: Value(dateOnly(edit.homeDate)),
          livingEnv: Value(envToDb(edit.livingEnv)),
          dailyMinutes: Value(edit.dailyMinutes),
          trainerCount: Value(edit.trainerCount),
          updatedAt: Value(nowIso),
        ),
      );

      if (!affecting) return PlanEffect.none;

      await (db.delete(db.dogConcerns)..where((t) => t.dogId.equals(dogId))).go();
      for (final c in edit.concerns) {
        await db.into(db.dogConcerns).insert(DogConcernsCompanion.insert(
              dogId: dogId,
              issueId: c,
              createdAt: nowIso,
            ));
      }

      final plan = await (db.select(db.weeklyPlans)
            ..where((t) => t.dogId.equals(dogId) & t.status.equals('active'))
            ..orderBy([(t) => OrderingTerm.desc(t.weekStart)])
            ..limit(1))
          .getSingleOrNull();
      if (plan == null) return PlanEffect.none;

      final thisMonday = weekStartOf(nowLocal);
      final planIsThisWeek = plan.weekStart == dateOnly(thisMonday);
      final hasSessions = await _hasSessionsInWeek(dogId, thisMonday);

      if (planIsThisWeek && !hasSessions) {
        await _regenerateInPlace(
          plan: plan,
          dogId: dogId,
          edit: edit,
          content: content,
          now: nowLocal,
        );
        return PlanEffect.regeneratedNow;
      }

      // 本周已有记录（或活动计划不是本周的，等补跑）：不动当前计划，标记下周全新生成。
      await (db.update(db.weeklyPlans)..where((t) => t.id.equals(plan.id)))
          .write(const WeeklyPlansCompanion(regenerateNext: Value(true)));
      return PlanEffect.markedForNextWeek;
    });
  }

  Future<bool> _hasSessionsInWeek(String dogId, DateTime monday) async {
    final start = DateTime.utc(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 7));
    final rows = await (db.select(db.trainingSessions)
          ..where((t) => t.dogId.equals(dogId)))
        .get();
    return rows.any((r) {
      final l = DateTime.parse(r.startedAt).toLocal();
      final d = DateTime.utc(l.year, l.month, l.day);
      return !d.isBefore(start) && d.isBefore(end);
    });
  }

  /// 覆盖当前计划的 PlanGoal 与 DailyMiniTask，计划 id 与 week_start 不变。
  Future<void> _regenerateInPlace({
    required WeeklyPlan plan,
    required String dogId,
    required DogProfileEdit edit,
    required ContentLibrary content,
    required DateTime now,
  }) async {
    final statusRows = await (db.select(db.dogSkillStatuses)
          ..where((t) => t.dogId.equals(dogId)))
        .get();
    final generated = generateWeeklyPlan(
      input: PlanInput(
        ageWeeks: ageWeeksOn(edit.birthDate, now),
        mastered: {
          for (final r in statusRows)
            if (r.status == 'mastered') r.skillId,
        },
        concerns: edit.concerns,
        dailyMinutes: edit.dailyMinutes,
      ),
      skills: content.skills,
      issues: content.issues,
    );
    await (db.delete(db.planGoals)..where((t) => t.planId.equals(plan.id))).go();
    await (db.delete(db.dailyMiniTasks)..where((t) => t.planId.equals(plan.id)))
        .go();
    for (var i = 0; i < generated.goals.length; i++) {
      final g = generated.goals[i];
      await db.into(db.planGoals).insert(PlanGoalsCompanion.insert(
            planId: plan.id,
            skillId: g.skillId,
            position: i,
            targetSessions: g.targetSessions,
            source: sourceToDb(g.source),
          ));
    }
    final mt = generated.miniTask;
    if (mt != null) {
      await db.into(db.dailyMiniTasks).insert(DailyMiniTasksCompanion.insert(
            planId: plan.id,
            skillId: mt.skillId,
            scriptPart: mt.scriptPart,
          ));
    }
    // 本周重生成后清掉可能残留的 regenerate_next（已经是全新生成）。
    await (db.update(db.weeklyPlans)..where((t) => t.id.equals(plan.id)))
        .write(const WeeklyPlansCompanion(regenerateNext: Value(false)));
  }
}
