import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/profile_repository.dart';
import 'package:puppy_trainer/data/repositories/report_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/weekly_report.dart';
import 'package:puppy_trainer/features/home/home_providers.dart';
import 'package:puppy_trainer/features/home/plan_view.dart';
import 'package:puppy_trainer/services/weekly_job.dart';

import 'helpers.dart';

/// M2：打卡写库、连续天数、周报与下周计划幂等、ON-7 规则、迁移。
void main() {
  late ContentLibrary lib;

  setUpAll(() async {
    lib = await loadRepoContent();
  });

  // 周一 2026-11-16，狗 10 周龄，10 分钟档，3 个目标：
  // marker_intro / name_response / redirect_to_toy（M1 简报第 4 节用例 1）。
  final monday = DateTime(2026, 11, 16, 9);
  final birth = DateTime(2026, 9, 7); // 2026-11-16 时 10 周

  Future<({AppDatabase db, String dogId, String planId})> setup({
    List<String> concerns = const ['biting_hands'],
    Set<String> mastered = const {},
    DateTime? now,
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
        concerns: concerns,
        dailyMinutes: 10,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: mastered,
      ),
      content: lib,
      now: now ?? monday,
    );
    return (db: db, dogId: r.dogId, planId: r.planId);
  }

  SessionDraft draft(String dogId, String skill, DateTime at,
          {int part = 1, List<int> skipped = const [], int clicks = 0}) =>
      SessionDraft(
        dogId: dogId,
        userId: HouseholdRepository.localUserId,
        skillId: skill,
        scriptPart: part,
        startedAt: at,
        endedAt: at.add(const Duration(minutes: 3)),
        durationSec: 180,
        clickerCount: clicks,
        skippedSteps: skipped,
      );

  Future<void> practice(AppDatabase db, String dogId, String skill,
      DateTime at, Score score,
      {int part = 1, DateTime? now}) async {
    await SessionRepository(db).save(
      draft: draft(dogId, skill, at, part: part),
      score: score,
      now: now ?? at,
    );
  }

  group('建档：保底任务写 part 0（M2 简报第 7 节）', () {
    test('DailyMiniTask.script_part == 0', () async {
      final s = await setup(mastered: {'lure_follow'});
      final mt = await PlanRepository(s.db).miniTask(s.planId);
      expect(mt, isNotNull);
      expect(mt!.scriptPart, miniScriptPart);
      final view = await _planView(s.db, lib, s.planId);
      expect(view.miniTask!.minutes,
          lib.skillById[mt.skillId]!.miniDurationMinutes);
      await s.db.close();
    });
  });

  group('打卡与连续天数（RC-2 / ST-1）', () {
    test('保存一次记录：写 TrainingSession、目标 +1、Streak = 1', () async {
      final s = await setup();
      final res = await SessionRepository(s.db).save(
        draft: draft(s.dogId, 'marker_intro', DateTime(2026, 11, 16, 10),
            clicks: 7),
        score: Score.partial,
        noteText: '今天狗很兴奋',
        now: DateTime(2026, 11, 16, 10, 5),
      );
      expect(res.countedToGoal, isTrue);
      expect(res.currentStreak, 1);

      final rows = await SessionRepository(s.db).sessionsOf(s.dogId);
      expect(rows.length, 1);
      expect(rows.single.score, 'partial');
      expect(rows.single.clickerCount, 7);
      expect(rows.single.durationSec, 180);
      expect(rows.single.userId, HouseholdRepository.localUserId);
      expect(rows.single.noteText, '今天狗很兴奋');
      expect(DateTime.parse(rows.single.startedAt).isUtc, isTrue);

      final goals = await PlanRepository(s.db).goals(s.planId);
      expect(goals.firstWhere((g) => g.skillId == 'marker_intro').completedSessions, 1);
      expect(goals.firstWhere((g) => g.skillId == 'name_response').completedSessions, 0);

      final streak = await SessionRepository(s.db).streakOf(s.dogId);
      expect(streak!.currentDays, 1);
      expect(streak.longestDays, 1);
      expect(streak.lastCheckinDate, '2026-11-16');
      await s.db.close();
    });

    test('一天多次只计一次打卡，但目标完成次数每次都 +1', () async {
      final s = await setup();
      for (final h in [8, 12, 20]) {
        await practice(s.db, s.dogId, 'marker_intro',
            DateTime(2026, 11, 16, h), Score.full);
      }
      final streak = await SessionRepository(s.db).streakOf(s.dogId);
      expect(streak!.currentDays, 1);
      final goals = await PlanRepository(s.db).goals(s.planId);
      expect(goals.firstWhere((g) => g.skillId == 'marker_intro').completedSessions, 3);
      await s.db.close();
    });

    test('连续三天：Streak 3；断一天后回来：当前 1，最长 3', () async {
      final s = await setup();
      for (final d in [16, 17, 18]) {
        await practice(s.db, s.dogId, 'marker_intro',
            DateTime(2026, 11, d, 10), Score.full);
      }
      var st = await SessionRepository(s.db).streakOf(s.dogId);
      expect([st!.currentDays, st.longestDays], [3, 3]);
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 20, 10), Score.full);
      st = await SessionRepository(s.db).streakOf(s.dogId);
      expect([st!.currentDays, st.longestDays], [1, 3]);
      await s.db.close();
    });

    test('保底任务（part 0）打卡但不计入目标进度', () async {
      final s = await setup();
      final res = await SessionRepository(s.db).save(
        draft: draft(s.dogId, 'marker_intro', DateTime(2026, 11, 16, 10),
            part: miniScriptPart),
        score: Score.full,
        now: DateTime(2026, 11, 16, 10, 5),
      );
      expect(res.countedToGoal, isFalse);
      expect(res.currentStreak, 1);
      final goals = await PlanRepository(s.db).goals(s.planId);
      expect(goals.every((g) => g.completedSessions == 0), isTrue);
      final rows = await SessionRepository(s.db).sessionsOf(s.dogId);
      expect(rows.single.scriptPart, 0);
      // 保底不动 full_success_count。
      final st = await DogRepository(s.db).skillStatuses(s.dogId);
      expect(st.firstWhere((r) => r.skillId == 'marker_intro').fullSuccessCount, 0);
      await s.db.close();
    });

    test('非本周目标的技能打卡：记录写入，目标进度不变', () async {
      final s = await setup();
      final res = await SessionRepository(s.db).save(
        draft: draft(s.dogId, 'leash_intro', DateTime(2026, 11, 16, 10)),
        score: Score.full,
        now: DateTime(2026, 11, 16, 10, 5),
      );
      expect(res.countedToGoal, isFalse);
      expect(res.currentStreak, 1);
      await s.db.close();
    });

    test('跳过的步骤写进备注（TR-6）', () async {
      final s = await setup();
      await SessionRepository(s.db).save(
        draft: draft(s.dogId, 'marker_intro', DateTime(2026, 11, 16, 10),
            skipped: [2, 4]),
        score: Score.full,
        noteText: '狗累了',
        now: DateTime(2026, 11, 16, 10, 5),
      );
      final row = (await SessionRepository(s.db).sessionsOf(s.dogId)).single;
      expect(row.noteText, contains('跳过步骤：2、4'));
      expect(row.noteText, contains('狗累了'));
      expect(jsonDecode(row.skippedSteps), [2, 4]);
      await s.db.close();
    });

    test('composeSessionNote：无跳过原样；无备注只有跳过', () {
      expect(composeSessionNote(const [], ' hi '), 'hi');
      expect(composeSessionNote(const [], null), '');
      expect(composeSessionNote(const [3], null), '跳过步骤：3');
    });

    test('技能状态：available → in_progress；full / none 计数', () async {
      final s = await setup();
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 16, 10), Score.full);
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 17, 10), Score.none);
      final st = (await DogRepository(s.db).skillStatuses(s.dogId))
          .firstWhere((r) => r.skillId == 'marker_intro');
      expect(st.status, 'in_progress');
      expect(st.fullSuccessCount, 1);
      expect(st.failCount, 1);
      await s.db.close();
    });

    test('首页进度：目标 completed 之和 / target 之和，保底不计，超额封顶', () async {
      final s = await setup();
      for (var i = 0; i < 5; i++) {
        await practice(s.db, s.dogId, 'marker_intro',
            DateTime(2026, 11, 16, 8 + i), Score.full);
      }
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 17, 10), Score.full, part: miniScriptPart);
      final view = await _planView(s.db, lib, s.planId);
      final p = weekProgress(view);
      // marker_intro 目标 3，做了 5 次封顶 3；其余两个目标共 6；总 9。
      expect(p.completed, 3);
      expect(p.target, 9);
      await s.db.close();
    });
  });

  group('周报与下周计划：幂等（WP-5 / WP-6）', () {
    Future<AppDatabase> weekWithPractice(
        {required List<(String, Score, int)> sessions}) async {
      final s = await setup();
      for (final (skill, score, day) in sessions) {
        await practice(s.db, s.dogId, skill, DateTime(2026, 11, day, 10), score);
      }
      return s.db;
    }

    test('同一 plan_id 跑两次只生成一份周报、一份下周计划', () async {
      final s = await setup();
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 16, 10), Score.full);
      final repo = ReportRepository(s.db);
      final at = DateTime(2026, 11, 22, 21, 30);
      final a = await repo.generate(planId: s.planId, content: lib, now: at);
      final b = await repo.generate(planId: s.planId, content: lib, now: at);
      expect(a.created, isTrue);
      expect(b.created, isFalse);
      expect(b.reportId, a.reportId);
      expect(b.nextPlanId, a.nextPlanId);
      expect((await s.db.select(s.db.weeklyReports).get()).length, 1);
      final plans = await s.db.select(s.db.weeklyPlans).get();
      expect(plans.length, 2);
      expect(plans.where((p) => p.status == 'active').length, 1);
      expect(plans.firstWhere((p) => p.id == s.planId).status, 'completed');
      await s.db.close();
    });

    test('workmanager 与冷启动补跑两条路径：先后调用只生成一份', () async {
      final s = await setup();
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 16, 10), Score.full);
      // 路径 1：周日 21:00 的周期任务。
      final first = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 11, 22, 21, 1));
      expect(first.length, 1);
      // 路径 2：周一早上冷启动补跑。
      final second = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 11, 23, 8));
      expect(second, isEmpty);
      // 再来一次（用户反复打开 App）。
      final third = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 11, 23, 9));
      expect(third, isEmpty);
      expect((await s.db.select(s.db.weeklyReports).get()).length, 1);
      final plans = await s.db.select(s.db.weeklyPlans).get();
      expect(plans.length, 2);
      expect(plans.where((p) => p.status == 'active').length, 1);
      await s.db.close();
    });

    test('两条路径反过来：先冷启动补跑，后 workmanager，同样只有一份', () async {
      final s = await setup();
      final a = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 11, 23, 8));
      final b = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 11, 23, 8, 0, 5));
      expect(a.length, 1);
      expect(b, isEmpty);
      expect((await s.db.select(s.db.weeklyReports).get()).length, 1);
      await s.db.close();
    });

    test('并发调用（两个 isolate 同时跑）：唯一约束兜底，仍只有一份', () async {
      final s = await setup();
      final repo = ReportRepository(s.db);
      final at = DateTime(2026, 11, 23, 8);
      final results = await Future.wait([
        repo.generate(planId: s.planId, content: lib, now: at),
        repo.generate(planId: s.planId, content: lib, now: at),
        repo.generate(planId: s.planId, content: lib, now: at),
      ]);
      expect(results.where((r) => r.created).length, 1);
      expect(results.map((r) => r.reportId).toSet().length, 1);
      expect((await s.db.select(s.db.weeklyReports).get()).length, 1);
      expect((await s.db.select(s.db.weeklyPlans).get()).length, 2);
      await s.db.close();
    });

    test('周日 21:00 之前不生成；本周计划之后才有周报', () async {
      final s = await setup();
      final r = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 11, 22, 20, 59));
      expect(r, isEmpty);
      expect((await s.db.select(s.db.weeklyReports).get()), isEmpty);
      await s.db.close();
    });

    test('数据库层面：同一 plan_id 插入第二份周报被唯一约束拒绝', () async {
      final s = await setup();
      Future<void> insert(String id) => s.db.into(s.db.weeklyReports).insert(
          WeeklyReportsCompanion.insert(
            id: id,
            dogId: s.dogId,
            planId: s.planId,
            summaryJson: '{}',
            aiComment: '',
            createdAt: 'x',
          ));
      await insert('r1');
      await expectLater(insert('r2'), throwsA(isA<SqliteException>()));
      await s.db.close();
    });

    test('数据库层面：同一只狗同一周第二份计划被唯一约束拒绝', () async {
      final s = await setup();
      await expectLater(
          s.db.into(s.db.weeklyPlans).insert(WeeklyPlansCompanion.insert(
                id: 'dup',
                dogId: s.dogId,
                weekStart: '2026-11-16',
                generatedBy: 'system',
                status: 'active',
                createdAt: 'x',
              )),
          throwsA(isA<SqliteException>()));
      await s.db.close();
    });

    test('久未打开：跨多周补跑，一周一份周报，最终活动计划落在当前周', () async {
      final s = await setup();
      final ids = await runWeeklyReportJob(
          db: s.db, content: lib, now: DateTime(2026, 12, 9, 8)); // 第 4 周的周三
      expect(ids.length, greaterThanOrEqualTo(1));
      final plans = await s.db.select(s.db.weeklyPlans).get();
      final active = plans.where((p) => p.status == 'active').toList();
      expect(active.length, 1);
      expect(active.single.weekStart, '2026-12-07');
      // 每个 (dog, week_start) 只有一份。
      expect(plans.map((p) => p.weekStart).toSet().length, plans.length);
      await s.db.close();
    });

    test('周报内容：完成次数、评分、outcome、comment 与 summary_json 结构', () async {
      final db = await weekWithPractice(sessions: [
        ('marker_intro', Score.full, 16),
        ('marker_intro', Score.full, 17),
        ('name_response', Score.none, 17),
        ('name_response', Score.none, 18),
      ]);
      final plan = await (db.select(db.weeklyPlans)).getSingle();
      final res = await ReportRepository(db).generate(
          planId: plan.id, content: lib, now: DateTime(2026, 11, 22, 22));
      final rep = (await ReportRepository(db).byId(res.reportId))!;
      final j = (jsonDecode(rep.summaryJson) as Map).cast<String, Object?>();
      final summary = WeeklySummary.fromJson(j);
      expect(j['week_start'], '2026-11-16');
      expect(summary.checkinDays, 3);
      expect(summary.sessionsTotal, 4);
      final mi = summary.goals.firstWhere((g) => g.skillId == 'marker_intro');
      expect(mi.outcome, GoalOutcome.mastered);
      expect([mi.completed, mi.full], [2, 2]);
      final nr = summary.goals.firstWhere((g) => g.skillId == 'name_response');
      expect(nr.outcome, GoalOutcome.downgrade);
      // comment 取评分最低的技能（name_response）的 scoring_hint。
      expect(summary.comment, lib.skillById['name_response']!.scoringHint);
      expect(rep.aiComment, summary.comment);
      expect(rep.readAt, isNull);
      await db.close();
    });

    test('下周计划写库：mastered 技能置 mastered 且不进下周；降级目标 source=downgrade', () async {
      final s = await setup();
      // name_response 两次 none → 降级到 downgrade_to；marker_intro 两次 full → mastered。
      for (final (skill, score, day) in [
        ('marker_intro', Score.full, 16),
        ('marker_intro', Score.full, 17),
        ('name_response', Score.none, 17),
        ('name_response', Score.none, 18),
      ]) {
        await practice(s.db, s.dogId, skill, DateTime(2026, 11, day, 10), score);
      }
      final res = await ReportRepository(s.db).generate(
          planId: s.planId, content: lib, now: DateTime(2026, 11, 22, 22));
      final goals = await PlanRepository(s.db).goals(res.nextPlanId!);
      final ids = goals.map((g) => g.skillId).toList();
      expect(ids, isNot(contains('marker_intro')));
      final st = (await DogRepository(s.db).skillStatuses(s.dogId))
          .firstWhere((r) => r.skillId == 'marker_intro');
      expect(st.status, 'mastered');
      expect(st.masteredAt, isNotNull);
      final next = (await s.db.select(s.db.weeklyPlans).get())
          .firstWhere((p) => p.id == res.nextPlanId);
      expect(next.weekStart, '2026-11-23');
      expect(next.generatedBy, 'system');
      expect(next.status, 'active');
      // 保底任务：part 0，且不再是已掌握之外的东西。
      final mt = await PlanRepository(s.db).miniTask(res.nextPlanId!);
      expect(mt!.scriptPart, 0);
      await s.db.close();
    });

    test('regenerate_next 为 true：下周全新生成，不走 WP-6', () async {
      final s = await setup();
      for (final d in [16, 17]) {
        await practice(s.db, s.dogId, 'marker_intro',
            DateTime(2026, 11, d, 10), Score.full);
      }
      await (s.db.update(s.db.weeklyPlans)..where((t) => t.id.equals(s.planId)))
          .write(const WeeklyPlansCompanion(regenerateNext: Value(true)));
      final res = await ReportRepository(s.db).generate(
          planId: s.planId, content: lib, now: DateTime(2026, 11, 22, 22));
      final goals = await PlanRepository(s.db).goals(res.nextPlanId!);
      // 全新生成时不应用 mastered 判定：marker_intro 仍未掌握，仍是基础保障排第一。
      expect(goals.first.skillId, 'marker_intro');
      expect(goals.every((g) => g.source != 'carryover' && g.source != 'downgrade'),
          isTrue);
      final st = (await DogRepository(s.db).skillStatuses(s.dogId))
          .firstWhere((r) => r.skillId == 'marker_intro');
      expect(st.status, isNot('mastered'));
      await s.db.close();
    });

    test('未读周报：生成后 latestUnread 返回，markRead 后消失', () async {
      final s = await setup();
      final res = await ReportRepository(s.db).generate(
          planId: s.planId, content: lib, now: DateTime(2026, 11, 23, 8));
      final repo = ReportRepository(s.db);
      expect((await repo.latestUnread(s.dogId))?.id, res.reportId);
      await repo.markRead(res.reportId, now: DateTime(2026, 11, 23, 9));
      expect(await repo.latestUnread(s.dogId), isNull);
      await s.db.close();
    });

    test('本周零记录：周报 comment 为固定文案，下周全部 carryover', () async {
      final s = await setup();
      final res = await ReportRepository(s.db).generate(
          planId: s.planId, content: lib, now: DateTime(2026, 11, 23, 8));
      final rep = (await ReportRepository(s.db).byId(res.reportId))!;
      expect(rep.aiComment, emptyWeekComment);
      final prev = await PlanRepository(s.db).goals(s.planId);
      final next = await PlanRepository(s.db).goals(res.nextPlanId!);
      expect(next.map((g) => g.skillId).toList(),
          prev.map((g) => g.skillId).toList());
      expect(next.every((g) => g.source == 'carryover'), isTrue);
      await s.db.close();
    });
  });

  group('ON-7 档案修改（M2 简报第 8 节）', () {
    DogProfileEdit editOf(Dog d, List<String> concerns,
            {String? name,
            DateTime? birthDate,
            int? minutes,
            Sex? sex,
            int? trainers}) =>
        DogProfileEdit(
          name: name ?? d.name,
          birthDate: birthDate ?? parseDateOnly(d.birthDate),
          breedId: d.breedId,
          breedText: d.breedText,
          sex: sex ?? sexFromDb(d.sex),
          homeDate: parseDateOnly(d.homeDate),
          livingEnv: envFromDb(d.livingEnv),
          dailyMinutes: minutes ?? d.dailyMinutes,
          trainerCount: trainers ?? d.trainerCount,
          concerns: concerns,
        );

    test('本周无记录：改每日时长后立即重生成本周计划', () async {
      final s = await setup();
      final dog = (await DogRepository(s.db).currentDog())!;
      expect((await PlanRepository(s.db).goals(s.planId)).length, 3);
      final effect = await ProfileRepository(s.db).save(
        dogId: s.dogId,
        edit: editOf(dog, ['biting_hands'], minutes: 30),
        content: lib,
        now: DateTime(2026, 11, 17, 9),
      );
      expect(effect, PlanEffect.regeneratedNow);
      expect((await PlanRepository(s.db).goals(s.planId)).length, 4);
      final plans = await s.db.select(s.db.weeklyPlans).get();
      expect(plans.length, 1); // 原地覆盖，不新增计划
      expect(plans.single.regenerateNext, isFalse);
      await s.db.close();
    });

    test('本周无记录：改出生日期后按新周龄重生成', () async {
      final s = await setup();
      final dog = (await DogRepository(s.db).currentDog())!;
      // 改成 7 周龄 → 没有可安排的技能。
      final effect = await ProfileRepository(s.db).save(
        dogId: s.dogId,
        edit: editOf(dog, ['biting_hands'], birthDate: DateTime(2026, 9, 28)),
        content: lib,
        now: DateTime(2026, 11, 17, 9),
      );
      expect(effect, PlanEffect.regeneratedNow);
      expect(await PlanRepository(s.db).goals(s.planId), isEmpty);
      expect(await PlanRepository(s.db).miniTask(s.planId), isNull);
      await s.db.close();
    });

    test('本周无记录：改困扰后重生成，且 DogConcern 同步更新', () async {
      final s = await setup(concerns: const []);
      final dog = (await DogRepository(s.db).currentDog())!;
      final effect = await ProfileRepository(s.db).save(
        dogId: s.dogId,
        edit: editOf(dog, ['potty_accidents', 'chewing_furniture']),
        content: lib,
        now: DateTime(2026, 11, 17, 9),
      );
      expect(effect, PlanEffect.regeneratedNow);
      final cs = await DogRepository(s.db).concerns(s.dogId);
      expect(cs.map((c) => c.issueId).toSet(),
          {'potty_accidents', 'chewing_furniture'});
      final goals = await PlanRepository(s.db).goals(s.planId);
      expect(goals.any((g) => g.source == 'concern'), isTrue);
      await s.db.close();
    });

    test('本周已有记录：不动本周计划，标记 regenerate_next', () async {
      final s = await setup();
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 16, 10), Score.full);
      final before = await PlanRepository(s.db).goals(s.planId);
      final dog = (await DogRepository(s.db).currentDog())!;
      final effect = await ProfileRepository(s.db).save(
        dogId: s.dogId,
        edit: editOf(dog, ['biting_hands'], minutes: 30),
        content: lib,
        now: DateTime(2026, 11, 17, 9),
      );
      expect(effect, PlanEffect.markedForNextWeek);
      final after = await PlanRepository(s.db).goals(s.planId);
      expect(after.map((g) => (g.skillId, g.completedSessions)).toList(),
          before.map((g) => (g.skillId, g.completedSessions)).toList()
            ..[0] = ('marker_intro', 1));
      final plan = (await s.db.select(s.db.weeklyPlans).get()).single;
      expect(plan.regenerateNext, isTrue);
      final d2 = (await DogRepository(s.db).currentDog())!;
      expect(d2.dailyMinutes, 30); // Dog 本身已更新
      await s.db.close();
    });

    test('改名字 / 性别 / 训练人数：只更新 Dog，不触发计划变化', () async {
      final s = await setup();
      await practice(s.db, s.dogId, 'marker_intro',
          DateTime(2026, 11, 16, 10), Score.full);
      final dog = (await DogRepository(s.db).currentDog())!;
      final effect = await ProfileRepository(s.db).save(
        dogId: s.dogId,
        edit: editOf(dog, ['biting_hands'],
            name: '球球', sex: Sex.female, trainers: 3),
        content: lib,
        now: DateTime(2026, 11, 17, 9),
      );
      expect(effect, PlanEffect.none);
      final d2 = (await DogRepository(s.db).currentDog())!;
      expect([d2.name, d2.sex, d2.trainerCount], ['球球', 'female', 3]);
      expect((await s.db.select(s.db.weeklyPlans).get()).single.regenerateNext,
          isFalse);
      await s.db.close();
    });

    test('改口令：只更新 DogCue，不动计划', () async {
      final s = await setup();
      await ProfileRepository(s.db).updateCue(
        dogId: s.dogId,
        skillId: 'sit',
        cueWord: '坐好',
        gestureText: '手掌向下压',
        now: DateTime(2026, 11, 17, 9),
      );
      final cues = await ProfileRepository(s.db).cues(s.dogId);
      final sit = cues.firstWhere((c) => c.skillId == 'sit');
      expect([sit.cueWord, sit.gestureText], ['坐好', '手掌向下压']);
      expect(cues.length, 18);
      await s.db.close();
    });

    test('planAffectingChanged：困扰顺序不同不算变化', () async {
      final s = await setup(concerns: const ['biting_hands', 'potty_accidents']);
      final dog = (await DogRepository(s.db).currentDog())!;
      expect(
          planAffectingChanged(
            before: dog,
            concernsBefore: const ['biting_hands', 'potty_accidents'],
            after: editOf(dog, ['potty_accidents', 'biting_hands']),
          ),
          isFalse);
      await s.db.close();
    });
  });

  group('M1 → M2 数据库迁移', () {
    test('schema 1 的库升级到 2：新表可用，保底任务 script_part 归 0', () async {
      // 用 NativeDatabase.memory 建一个"M1 形态"的库：先建全 M2 schema，
      // 再还原成 M1（删 M2 表、删 regenerate_next 列、保底写 1），user_version 置 1。
      final executor = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 0');
      });
      final db = AppDatabase(executor);
      await db.customSelect('SELECT 1').get(); // 触发 onCreate
      await db.customStatement('DROP TABLE training_sessions');
      await db.customStatement('DROP TABLE streaks');
      await db.customStatement('DROP TABLE weekly_reports');
      await db.customStatement(
          'ALTER TABLE weekly_plans DROP COLUMN regenerate_next');
      await db.customStatement(
          "INSERT INTO daily_mini_tasks (plan_id, skill_id, script_part) VALUES ('p1','sit',1)");
      await db.customStatement('PRAGMA user_version = 1');
      // 按 drift 的迁移入口手动走一遍 onUpgrade。
      final strategy = db.migration;
      await db.transaction(() async {
        await strategy.onUpgrade(Migrator(db), 1, 2);
      });
      final cols = await db.customSelect('PRAGMA table_info(weekly_plans)').get();
      expect(cols.map((c) => c.read<String>('name')), contains('regenerate_next'));
      final mt = await db.select(db.dailyMiniTasks).get();
      expect(mt.single.scriptPart, 0);
      await db.into(db.streaks).insert(StreaksCompanion.insert(dogId: 'd'));
      expect((await db.select(db.streaks).get()).length, 1);
      await db.close();
    });
  });
}

Future<PlanView> _planView(AppDatabase db, ContentLibrary lib, String planId) async {
  final repo = PlanRepository(db);
  final plan = await (db.select(db.weeklyPlans)
        ..where((t) => t.id.equals(planId)))
      .getSingle();
  final goals = await repo.goals(planId);
  final mini = await repo.miniTask(planId);
  return PlanView(
    plan: plan,
    goals: [
      for (final g in goals)
        GoalView(
          skill: lib.skillById[g.skillId]!,
          targetSessions: g.targetSessions,
          completedSessions: g.completedSessions,
          source: g.source,
        ),
    ],
    miniTask: mini == null
        ? null
        : MiniTaskView(
            skill: lib.skillById[mini.skillId]!, scriptPart: mini.scriptPart),
  );
}
