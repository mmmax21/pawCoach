/// M3 简报第 10 节：加入计划单测（本周去重 / 前置未满足跳过 / 上限 6；
/// 下周 pending_diagnosis_skills 排最前）、提醒单测、AI 对话仓库、迁移。
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/ai_repository.dart';
import 'package:puppy_trainer/data/repositories/reminder_repository.dart';
import 'package:puppy_trainer/data/repositories/report_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';
import 'package:puppy_trainer/services/reminder_service.dart';

import 'helpers.dart';

class FakeNotifier implements ReminderNotifier {
  final scheduled = <({int id, DateTime firstAt})>[];
  final cancelled = <int>[];
  int permissionRequests = 0;
  bool grant = true;

  @override
  Future<void> init({void Function()? onTap}) async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> scheduleDaily({required int id, required DateTime firstAt}) async =>
      scheduled.add((id: id, firstAt: firstAt));
}

void main() {
  late ContentLibrary lib;
  setUpAll(() async {
    lib = await loadRepoContent();
  });

  final monday = DateTime(2026, 11, 16, 9);
  final birth = DateTime(2026, 9, 7); // 10 周

  Future<({AppDatabase db, String dogId, String planId})> setup({
    Set<String> mastered = const {},
    int dailyMinutes = 10,
  }) async {
    final db = memoryDb();
    await HouseholdRepository(db).ensureLocalUser();
    final r = await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const [],
        dailyMinutes: dailyMinutes,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: mastered,
      ),
      content: lib,
      now: monday,
    );
    return (db: db, dogId: r.dogId, planId: r.planId);
  }

  group('addDiagnosisToWeek（纯函数）', () {
    test('本周追加去重：已在目标中的跳过', () {
      final r = addDiagnosisToWeek(
        solutionSkills: ['marker_intro', 'name_response'],
        currentGoalIds: ['marker_intro'],
        mastered: {},
        ageWeeks: 10,
        skills: lib.skills,
      );
      expect(r.added.map((g) => g.skillId), ['name_response']);
      expect(r.skipped.single.reason, DiagnosisSkipReason.alreadyInPlan);
    });

    test('前置未满足：M4 起改为加入其当前可练的前置（M3 决策第 8 条）', () {
      final sit = lib.skillById['sit']!;
      expect(sit.prerequisites, isNotEmpty);
      final r = addDiagnosisToWeek(
        solutionSkills: ['sit'],
        currentGoalIds: [],
        mastered: {},
        ageWeeks: 10,
        skills: lib.skills,
      );
      expect(r.added.map((g) => g.skillId), sit.prerequisites);
      expect(r.foundations.single.target, 'sit');
      expect(r.skipped, isEmpty);
    });

    test('追加的目标：source = ai_diagnosis，target = sessions_to_master + 1', () {
      final r = addDiagnosisToWeek(
        solutionSkills: ['name_response'],
        currentGoalIds: [],
        mastered: {},
        ageWeeks: 10,
        skills: lib.skills,
      );
      final g = r.added.single;
      expect(g.source, GoalSource.aiDiagnosis);
      expect(g.targetSessions, lib.skillById['name_response']!.sessionsToMaster + 1);
    });

    test('本周目标上限 6', () {
      final noPrereq = [
        for (final s in lib.skills)
          if (s.prerequisites.isEmpty) s.id,
      ];
      expect(noPrereq.length, greaterThanOrEqualTo(4));
      final r = addDiagnosisToWeek(
        solutionSkills: noPrereq,
        currentGoalIds: ['a', 'b', 'c', 'd'],
        mastered: {},
        ageWeeks: 10,
        skills: lib.skills,
      );
      expect(r.added.length, 2);
      expect(r.skipped.where((s) => s.reason == DiagnosisSkipReason.capReached), isNotEmpty);
    });
  });

  group('nextWeekPlan + pending_diagnosis_skills', () {
    test('诊断技能排最前，source = ai_diagnosis，排在 carryover 之前', () {
      final res = nextWeekPlan(
        thisWeek: const [
          GoalWeekStat(skillId: 'marker_intro', full: 1, partial: 1, none: 0),
        ],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 10),
        skills: lib.skills,
        issues: lib.issues,
        pendingDiagnosisSkills: const ['redirect_to_toy'],
      );
      expect(res.plan.goals.first.skillId, 'redirect_to_toy');
      expect(res.plan.goals.first.source, GoalSource.aiDiagnosis);
      expect(res.plan.goals[1].skillId, 'marker_intro');
      expect(res.plan.goals[1].source, GoalSource.carryover);
    });

    test('诊断技能与 carryover 重复时只出现一次（按诊断来源）', () {
      final res = nextWeekPlan(
        thisWeek: const [GoalWeekStat(skillId: 'marker_intro', full: 0, partial: 1, none: 0)],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 10),
        skills: lib.skills,
        issues: lib.issues,
        pendingDiagnosisSkills: const ['marker_intro'],
      );
      expect(res.plan.goals.where((g) => g.skillId == 'marker_intro').length, 1);
      expect(res.plan.goals.first.source, GoalSource.aiDiagnosis);
    });

    test('已掌握（含本周新掌握）或前置未满足的诊断技能不放入', () {
      final res = nextWeekPlan(
        thisWeek: const [GoalWeekStat(skillId: 'marker_intro', full: 2, partial: 0, none: 0)],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 10),
        skills: lib.skills,
        issues: lib.issues,
        pendingDiagnosisSkills: const ['marker_intro', 'stay_long'],
      );
      // M4 第 9 节：已掌握的跳过；前置未满足的改为加入其当前可练的前置（stay_long ← stay_short ← sit ← …）。
      final diag = [
        for (final g in res.plan.goals)
          if (g.source == GoalSource.aiDiagnosis) g.skillId
      ];
      expect(diag, isNot(contains('marker_intro')));
      expect(diag, isNot(contains('stay_long')));
      expect(diag, ['name_response', 'lure_follow']);
    });

    test('regenerateNext 时诊断技能也排最前', () {
      final res = nextWeekPlan(
        thisWeek: const [],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 10),
        skills: lib.skills,
        issues: lib.issues,
        regenerateNext: true,
        pendingDiagnosisSkills: const ['redirect_to_toy'],
      );
      expect(res.plan.goals.first.skillId, 'redirect_to_toy');
      expect(res.plan.goals.first.source, GoalSource.aiDiagnosis);
    });
  });

  group('AiRepository：诊断加入计划（写库）', () {
    test('加入本周：追加 PlanGoal，added_to_plan_id = 当前计划；重复加入不重复写', () async {
      final s = await setup();
      final repo = AiRepository(s.db, clock: () => monday);
      final conv = await repo.newDiagnosisConversation(s.dogId, 'biting_hands');
      final before = await PlanRepository(s.db).goals(s.planId);
      final resultId = await repo.saveDiagnosisResult(
        conversationId: conv.id,
        dogId: s.dogId,
        issueId: 'biting_hands',
        resultKey: 'x',
        solutionSkills: ['redirect_to_toy', 'calm_settle', 'marker_intro'],
      );
      final r1 = await repo.addToThisWeek(diagnosisResultId: resultId, content: lib);
      final after = await PlanRepository(s.db).goals(s.planId);
      expect(after.length, before.length + r1.added.length);
      for (final g in r1.added) {
        final row = after.firstWhere((x) => x.skillId == g.skillId);
        expect(row.source, 'ai_diagnosis');
        expect(row.position, greaterThanOrEqualTo(before.length));
      }
      expect((await repo.diagnosisResult(resultId))!.addedToPlanId, s.planId);

      final r2 = await repo.addToThisWeek(diagnosisResultId: resultId, content: lib);
      expect(r2.added, isEmpty);
      expect((await PlanRepository(s.db).goals(s.planId)).length, after.length);
      await s.db.close();
    });

    test('加入下周：写 pending_diagnosis_skills，周报生成的下周计划排最前', () async {
      final s = await setup();
      final repo = AiRepository(s.db, clock: () => monday);
      final conv = await repo.newDiagnosisConversation(s.dogId, 'biting_hands');
      final resultId = await repo.saveDiagnosisResult(
        conversationId: conv.id,
        dogId: s.dogId,
        issueId: 'biting_hands',
        resultKey: 'x',
        solutionSkills: ['redirect_to_toy'],
      );
      final merged = await repo.addToNextWeek(diagnosisResultId: resultId);
      expect(merged, ['redirect_to_toy']);
      final plan = await PlanRepository(s.db).activePlan(s.dogId);
      expect(jsonDecode(plan!.pendingDiagnosisSkills), ['redirect_to_toy']);
      expect((await repo.diagnosisResult(resultId))!.addedToPlanId, isNull);

      final gen = await ReportRepository(s.db).generate(
        planId: s.planId,
        content: lib,
        now: DateTime(2026, 11, 22, 21, 30),
      );
      final next = await PlanRepository(s.db).goals(gen.nextPlanId!);
      expect(next.first.skillId, 'redirect_to_toy');
      expect(next.first.source, 'ai_diagnosis');
      await s.db.close();
    });
  });

  group('AiRepository：对话', () {
    test('课程内提问按 (dog, skill) 复用同一个对话', () async {
      final s = await setup();
      final repo = AiRepository(s.db, clock: () => monday);
      final a = await repo.courseConversation(s.dogId, 'sit');
      final b = await repo.courseConversation(s.dogId, 'sit');
      final c = await repo.courseConversation(s.dogId, 'down');
      expect(a.id, b.id);
      expect(c.id, isNot(a.id));
      await s.db.close();
    });

    test('addExchange 按序入库；recentTurns 只带普通问答、最多 10 条', () async {
      final s = await setup();
      var t = monday;
      final repo = AiRepository(s.db, clock: () => t = t.add(const Duration(seconds: 1)));
      final conv = await repo.courseConversation(s.dogId, 'sit');
      for (var i = 0; i < 7; i++) {
        await repo.addExchange(
          conversationId: conv.id,
          question: 'q$i',
          answer: CoachAnswer(
            text: 'a$i',
            cited: const ['sit'],
            kind: i == 3 ? AiMessageKind.guardHealth : AiMessageKind.normal,
            modelCalled: i != 3,
          ),
        );
      }
      final msgs = await repo.messages(conv.id);
      expect(msgs.length, 14);
      expect(msgs[0].content, 'q0');
      expect(msgs[1].content, 'a0');
      expect(jsonDecode(msgs[1].citedContentIds), ['sit']);
      expect(msgs[7].kind, 'guard_health');
      final turns = await repo.recentTurns(conv.id);
      expect(turns.length, 10);
      expect(turns.map((x) => x.content), isNot(contains('q3')));
      expect(turns.last.content, 'a6');
      await s.db.close();
    });

    test('dogBrief：最近 3 次评分（新的在前）', () async {
      final s = await setup();
      final sessions = SessionRepository(s.db);
      for (final (i, sc) in [Score.none, Score.partial, Score.full, Score.none].indexed) {
        final at = monday.add(Duration(hours: i + 1));
        await sessions.save(
          draft: SessionDraft(
            dogId: s.dogId,
            userId: HouseholdRepository.localUserId,
            skillId: 'marker_intro',
            scriptPart: 1,
            startedAt: at,
            endedAt: at.add(const Duration(minutes: 2)),
            durationSec: 120,
            clickerCount: 0,
            skippedSteps: const [],
          ),
          score: sc,
          now: at,
        );
      }
      final brief = await AiRepository(s.db, clock: () => monday)
          .dogBrief(dogId: s.dogId, content: lib, skillId: 'marker_intro', currentStep: 2);
      expect(brief.recentScores, [Score.none, Score.full, Score.partial]);
      expect(brief.ageWeeks, 10);
      expect(brief.currentStep, 2);
      await s.db.close();
    });
  });

  group('提醒（ST-7）', () {
    test('nextReminderAt', () {
      final morning = DateTime(2026, 11, 16, 9);
      expect(nextReminderAt(now: morning, hour: 19, minute: 0, checkedInToday: false),
          DateTime(2026, 11, 16, 19));
      expect(nextReminderAt(now: morning, hour: 19, minute: 0, checkedInToday: true),
          DateTime(2026, 11, 17, 19));
      expect(nextReminderAt(now: DateTime(2026, 11, 16, 20), hour: 19, minute: 0, checkedInToday: false),
          DateTime(2026, 11, 17, 19));
      // 月底跨月
      expect(nextReminderAt(now: DateTime(2026, 11, 30, 20), hour: 7, minute: 30, checkedInToday: false),
          DateTime(2026, 12, 1, 7, 30));
    });

    test('默认关闭、19:00；关闭时只取消不调度', () async {
      final s = await setup();
      expect((await ReminderRepository(s.db).get(s.dogId)).enabled, isFalse);
      expect((await ReminderRepository(s.db).get(s.dogId)).hour, 19);
      final n = FakeNotifier();
      final svc = ReminderService(db: s.db, notifier: n, clock: () => monday);
      expect(await svc.refresh(s.dogId), isNull);
      expect(n.cancelled, List.generate(14, (i) => reminderNotificationId + i));
      expect(n.scheduled, isEmpty);
      await s.db.close();
    });

    test('首次打开开关申请权限并调度今天 19:00；已打卡当天取消、改调明天', () async {
      final s = await setup();
      final n = FakeNotifier();
      var now = DateTime(2026, 11, 16, 10);
      final svc = ReminderService(db: s.db, notifier: n, clock: () => now);
      final r = await svc.update(s.dogId, const ReminderConfig(enabled: true, hour: 19, minute: 0));
      expect(n.permissionRequests, 1);
      expect(r.granted, isTrue);
      expect(n.scheduled.take(14).map((e) => (e.id, e.firstAt)).toList(),
          List.generate(14, (i) => (1001 + i, DateTime(2026, 11, 16 + i, 19))));

      // 打卡
      now = DateTime(2026, 11, 16, 12);
      await SessionRepository(s.db).save(
        draft: SessionDraft(
          dogId: s.dogId,
          userId: HouseholdRepository.localUserId,
          skillId: 'marker_intro',
          scriptPart: 0,
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 2)),
          durationSec: 120,
          clickerCount: 0,
          skippedSteps: const [],
        ),
        score: Score.full,
        now: now,
      );
      final cancelsBefore = n.cancelled.length;
      final next = await svc.onCheckin(s.dogId);
      expect(n.cancelled.length, cancelsBefore + 14);
      expect(next, DateTime(2026, 11, 17, 19));
      expect(n.scheduled.skip(14).map((e) => (e.id, e.firstAt)).toList(),
          List.generate(14, (i) => (1001 + i, DateTime(2026, 11, 17 + i, 19))));
      await s.db.close();
    });

    test('改时间后重新调度，不再重复申请权限', () async {
      final s = await setup();
      final n = FakeNotifier();
      final svc = ReminderService(db: s.db, notifier: n, clock: () => DateTime(2026, 11, 16, 10));
      await svc.update(s.dogId, const ReminderConfig(enabled: true, hour: 19, minute: 0));
      await svc.update(s.dogId, const ReminderConfig(enabled: true, hour: 8, minute: 15));
      expect(n.permissionRequests, 1);
      expect(n.scheduled.skip(14).map((e) => (e.id, e.firstAt)).toList(),
          List.generate(14, (i) => (1001 + i, DateTime(2026, 11, 17 + i, 8, 15))));
      final saved = await ReminderRepository(s.db).get(s.dogId);
      expect((saved.hour, saved.minute), (8, 15));
      // 关闭：只取消
      final scheduledCount = n.scheduled.length;
      await svc.update(s.dogId, const ReminderConfig(enabled: false, hour: 8, minute: 15));
      expect(n.scheduled.length, scheduledCount);
      expect(n.cancelled.sublist(n.cancelled.length - 14), List.generate(14, (i) => 1001 + i));
      await s.db.close();
    });

    test('权限被拒仍保存设置，返回 granted=false', () async {
      final s = await setup();
      final n = FakeNotifier()..grant = false;
      final svc = ReminderService(db: s.db, notifier: n, clock: () => DateTime(2026, 11, 16, 10));
      final r = await svc.update(s.dogId, const ReminderConfig(enabled: true, hour: 19, minute: 0));
      expect(r.granted, isFalse);
      expect((await ReminderRepository(s.db).get(s.dogId)).enabled, isTrue);
      await s.db.close();
    });
  });

  for (final from in [1, 2]) {
  test('迁移：schema $from 升级到 3，新表新列可用、旧数据保留', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // onCreate 建全 v3
    for (final t in ['ai_conversations', 'ai_messages', 'diagnosis_results', 'reminder_settings', 'content_ai_lexicons']) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('ALTER TABLE weekly_plans DROP COLUMN pending_diagnosis_skills');
    await db.customStatement(
        "INSERT INTO weekly_plans (id, dog_id, week_start, generated_by, status, created_at) VALUES ('p1','d1','2026-11-16','system','active','x')");
    if (from == 1) {
      for (final table in ['training_sessions', 'streaks', 'weekly_reports']) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('ALTER TABLE weekly_plans DROP COLUMN regenerate_next');
    }
    await db.transaction(() async {
      await db.migration.onUpgrade(Migrator(db), from, 3);
    });
    final plan = await db.select(db.weeklyPlans).getSingle();
    expect(plan.pendingDiagnosisSkills, '[]');
    expect(await db.select(db.reminderSettings).get(), isEmpty);
    expect(await db.select(db.aiConversations).get(), isEmpty);
    await db.close();
  });

  }

  test('迁移：schemaVersion 3 的新表与新列可用（M2 库升级由 onUpgrade from < 3 处理）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, greaterThanOrEqualTo(3)); // M4 起为 4，迁移见 m4_migration_test.dart
    await db.customSelect('SELECT pending_diagnosis_skills FROM weekly_plans').get();
    for (final t in ['ai_conversations', 'ai_messages', 'diagnosis_results', 'reminder_settings', 'content_ai_lexicons']) {
      await db.customSelect('SELECT * FROM $t').get();
    }
    await db.close();
  });
}
