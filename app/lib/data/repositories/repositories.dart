/// 狗 / 家庭 / 计划仓库。建档完成后一次事务写入全部记录（M1 简报第 6 节"完成"）。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/plan_generator.dart';
import '../db/database.dart';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

String dateOnly(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

DateTime parseDateOnly(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// M4 确定性主键（简报 5.3）：同一事实在两台设备上生成同一主键。
/// `WeeklyPlan.id = plan_{dog_id}_{week_start}`。
String weeklyPlanId(String dogId, String weekStart) => 'plan_${dogId}_$weekStart';

/// `WeeklyReport.id = rep_{plan_id}`。
String weeklyReportId(String planId) => 'rep_$planId';

String _newId(String prefix) {
  final t = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
  return '${prefix}_$t';
}

/// 建档表单的最终结果。
class OnboardingResult {
  const OnboardingResult({
    required this.dogName,
    required this.birthDate,
    required this.breedId,
    required this.breedText,
    required this.sex,
    required this.homeDate,
    required this.concerns,
    required this.dailyMinutes,
    required this.trainerCount,
    required this.livingEnv,
    required this.masteredSkills,
  });

  final String dogName;
  final DateTime birthDate;
  final String breedId;
  final String breedText;
  final Sex sex;
  final DateTime homeDate;
  final List<String> concerns;
  final int dailyMinutes;
  final int trainerCount;
  final LivingEnv livingEnv;
  final Set<String> masteredSkills;
}

String sexToDb(Sex s) => s == Sex.male ? 'male' : 'female';
Sex sexFromDb(String s) => s == 'male' ? Sex.male : Sex.female;
String envToDb(LivingEnv e) =>
    e == LivingEnv.apartment ? 'apartment' : 'house_with_yard';
LivingEnv envFromDb(String s) =>
    s == 'apartment' ? LivingEnv.apartment : LivingEnv.houseWithYard;
String statusToDb(SkillStatus s) => switch (s) {
      SkillStatus.locked => 'locked',
      SkillStatus.available => 'available',
      SkillStatus.inProgress => 'in_progress',
      SkillStatus.mastered => 'mastered',
    };
String sourceToDb(GoalSource s) => switch (s) {
      GoalSource.age => 'age',
      GoalSource.concern => 'concern',
      GoalSource.carryover => 'carryover',
      GoalSource.downgrade => 'downgrade',
      GoalSource.aiDiagnosis => 'ai_diagnosis',
      GoalSource.manual => 'manual',
    };

class HouseholdRepository {
  HouseholdRepository(this.db);
  final AppDatabase db;

  /// 本机当前用户（M1 无登录，固定一个本地用户）。
  static const localUserId = 'local_user';

  Future<void> ensureLocalUser() async {
    final existing = await (db.select(db.users)
          ..where((t) => t.id.equals(localUserId)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.users).insert(UsersCompanion.insert(
            id: localUserId,
            nickname: '我',
            createdAt: _nowIso(),
          ));
    }
  }
}

class DogRepository {
  DogRepository(this.db);
  final AppDatabase db;

  Future<Dog?> currentDog() async {
    return (db.select(db.dogs)..limit(1)).getSingleOrNull();
  }

  Stream<Dog?> watchCurrentDog() {
    return (db.select(db.dogs)..limit(1)).watchSingleOrNull();
  }

  Future<List<DogSkillStatuse>> skillStatuses(String dogId) =>
      (db.select(db.dogSkillStatuses)..where((t) => t.dogId.equals(dogId)))
          .get();

  Future<List<DogConcern>> concerns(String dogId) =>
      (db.select(db.dogConcerns)..where((t) => t.dogId.equals(dogId))).get();
}

class PlanRepository {
  PlanRepository(this.db);
  final AppDatabase db;

  Future<WeeklyPlan?> activePlan(String dogId) {
    return (db.select(db.weeklyPlans)
          ..where((t) => t.dogId.equals(dogId) & t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm.desc(t.weekStart)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<WeeklyPlan?> watchActivePlan(String dogId) {
    return (db.select(db.weeklyPlans)
          ..where((t) => t.dogId.equals(dogId) & t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm.desc(t.weekStart)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<PlanGoal>> goals(String planId) => (db.select(db.planGoals)
        ..where((t) => t.planId.equals(planId))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]))
      .get();

  Future<DailyMiniTask?> miniTask(String planId) =>
      (db.select(db.dailyMiniTasks)..where((t) => t.planId.equals(planId)))
          .getSingleOrNull();
}

/// 建档完成：一次事务写入 Household、Member、Dog、Concern、SkillStatus、Cue、
/// WeeklyPlan、PlanGoal、DailyMiniTask。返回 (dogId, planId)。
class OnboardingRepository {
  OnboardingRepository(this.db);
  final AppDatabase db;

  Future<({String dogId, String planId})> complete({
    required OnboardingResult form,
    required ContentLibrary content,
    DateTime? now,
  }) async {
    final localNow = (now ?? DateTime.now()).toLocal();
    final nowUtc = localNow.toUtc();
    final nowIso = nowUtc.toIso8601String();
    final userId = HouseholdRepository.localUserId;
    final householdId = _newId('hh');
    final dogId = _newId('dog');
    final weekStart = dateOnly(weekStartOf(localNow));
    final planId = weeklyPlanId(dogId, weekStart);

    final ageWeeks = ageWeeksOn(form.birthDate, localNow);
    final plan = generateWeeklyPlan(
      input: PlanInput(
        ageWeeks: ageWeeks,
        mastered: form.masteredSkills,
        concerns: form.concerns,
        dailyMinutes: form.dailyMinutes,
      ),
      skills: content.skills,
      issues: content.issues,
    );
    final statuses = deriveSkillStatuses(
      skills: content.skills,
      mastered: form.masteredSkills,
    );

    await db.transaction(() async {
      await db.into(db.households).insert(HouseholdsCompanion.insert(
            id: householdId,
            name: '${form.dogName}的家',
            creatorUserId: userId,
            createdAt: nowIso,
          ));
      await db
          .into(db.householdMembers)
          .insert(HouseholdMembersCompanion.insert(
            householdId: householdId,
            userId: userId,
            role: 'creator',
            joinedAt: nowIso,
          ));
      await db.into(db.dogs).insert(DogsCompanion.insert(
            id: dogId,
            householdId: householdId,
            name: form.dogName,
            birthDate: dateOnly(form.birthDate),
            breedId: form.breedId,
            breedText: form.breedText,
            sex: sexToDb(form.sex),
            homeDate: dateOnly(form.homeDate),
            livingEnv: envToDb(form.livingEnv),
            dailyMinutes: form.dailyMinutes,
            trainerCount: form.trainerCount,
            createdAt: nowIso,
            updatedAt: nowIso,
            initialMastered: Value(jsonEncode(form.masteredSkills.toList()..sort())),
          ));
      for (final c in form.concerns) {
        await db.into(db.dogConcerns).insert(DogConcernsCompanion.insert(
              dogId: dogId,
              issueId: c,
              createdAt: nowIso,
            ));
      }
      for (final s in content.skills) {
        final st = statuses[s.id]!;
        await db.into(db.dogSkillStatuses).insert(
              DogSkillStatusesCompanion.insert(
                dogId: dogId,
                skillId: s.id,
                status: statusToDb(st),
                masteredAt: Value(st == SkillStatus.mastered ? nowIso : null),
              ),
            );
        await db.into(db.dogCues).insert(DogCuesCompanion.insert(
              dogId: dogId,
              skillId: s.id,
              cueWord: s.defaultCue,
              gestureText: s.defaultGesture,
              updatedAt: nowIso,
            ));
      }
      await db.into(db.weeklyPlans).insert(WeeklyPlansCompanion.insert(
            id: planId,
            dogId: dogId,
            weekStart: weekStart,
            generatedBy: 'system',
            status: 'active',
            createdAt: nowIso,
          ));
      for (var i = 0; i < plan.goals.length; i++) {
        final g = plan.goals[i];
        await db.into(db.planGoals).insert(PlanGoalsCompanion.insert(
              planId: planId,
              skillId: g.skillId,
              position: i,
              targetSessions: g.targetSessions,
              source: sourceToDb(g.source),
            ));
      }
      final mt = plan.miniTask;
      if (mt != null) {
        await db.into(db.dailyMiniTasks).insert(DailyMiniTasksCompanion.insert(
              planId: planId,
              skillId: mt.skillId,
              scriptPart: mt.scriptPart,
            ));
      }
      await db.delete(db.onboardingDrafts).go();
    });

    return (dogId: dogId, planId: planId);
  }

  // ---- ON-6 断点续接（P1）----

  Future<void> saveDraft(Map<String, Object?> json) async {
    await db.into(db.onboardingDrafts).insertOnConflictUpdate(
          OnboardingDraftsCompanion.insert(
            id: const Value(1),
            json: jsonEncode(json),
            updatedAt: _nowIso(),
          ),
        );
  }

  Future<Map<String, Object?>?> loadDraft() async {
    final row = await (db.select(db.onboardingDrafts)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    return (jsonDecode(row.json) as Map).cast<String, Object?>();
  }

  Future<void> clearDraft() => db.delete(db.onboardingDrafts).go();
}
