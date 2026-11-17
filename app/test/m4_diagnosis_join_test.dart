/// M4 简报第 9 节：诊断方案加入计划的规则（M3 决策第 2、5、8 条）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/repositories/ai_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';
import 'package:puppy_trainer/features/ai_coach/diagnosis_add_text.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  List<String> ids(DiagnosisWeekAddition r) => [for (final g in r.added) g.skillId];

  DiagnosisWeekAddition run(List<String> sol,
          {List<String> goals = const [], Set<String> mastered = const {}, int age = 10, int cap = 6}) =>
      addDiagnosisToWeek(
        solutionSkills: sol,
        currentGoalIds: goals,
        mastered: mastered,
        ageWeeks: age,
        skills: lib.skills,
        cap: cap,
      );

  group('五种分支', () {
    test('1. 已掌握 → 跳过（已掌握）', () {
      final r = run(['marker_intro'], mastered: {'marker_intro'});
      expect(r.added, isEmpty);
      expect(r.skipped.single.reason, DiagnosisSkipReason.mastered);
    });

    test('2. 已在本周目标 → 跳过（已在计划中）', () {
      final r = run(['marker_intro'], goals: ['marker_intro']);
      expect(r.added, isEmpty);
      expect(r.skipped.single.reason, DiagnosisSkipReason.alreadyInPlan);
    });

    test('3. 前置已掌握且周龄满足 → 加入 S（ai_diagnosis，target = stm + 1）', () {
      final r = run(['sit'], mastered: {'name_response', 'lure_follow'});
      expect(ids(r), ['sit']);
      expect(r.added.single.source, GoalSource.aiDiagnosis);
      expect(r.added.single.targetSessions, lib.skillById['sit']!.sessionsToMaster + 1);
      expect(r.foundations, isEmpty);
    });

    test('4. 前置未满足 → 加入前置链上当前可练的 P（可能多个），并给出"先练 P 为 S 打基础"', () {
      final r = run(['calm_settle'], age: 12); // calm_settle ← down ← sit ← name_response, lure_follow
      expect(ids(r), ['name_response', 'lure_follow']);
      expect(r.foundations.single.target, 'calm_settle');
      expect(r.foundations.single.via, ['name_response', 'lure_follow']);
      for (final g in r.added) {
        final s = lib.skillById[g.skillId]!;
        expect(s.minAgeWeeks, lessThanOrEqualTo(12));
        expect(s.prerequisites, isEmpty);
      }
    });

    test('4. P 已在目标中或已被本次加入不重复', () {
      final r = run(['sit', 'stay_short'], goals: ['name_response'], age: 12);
      expect(ids(r), ['lure_follow']);
      expect(r.foundations.map((f) => f.target), ['sit', 'stay_short']);
      expect(r.foundations.last.via, ['name_response', 'lure_follow']);
    });

    test('4. 链上只取"可练"的那一层：中间层已掌握时直接加更高一层', () {
      final r = run(['calm_settle'], mastered: {'name_response', 'lure_follow', 'sit'}, age: 12);
      expect(ids(r), ['down']);
    });

    test('5. S 周龄未到且前置链上无可练 → 跳过（X 周龄后再练）', () {
      final r = run(['stay_short'], mastered: {'name_response', 'lure_follow', 'sit'}, age: 10);
      expect(r.added, isEmpty);
      expect(r.skipped.single.reason, DiagnosisSkipReason.ageTooYoung);
      expect(r.skipped.single.untilWeeks, lib.skillById['stay_short']!.minAgeWeeks);
    });

    test('S 周龄未到但链上有可练 → 走第 4 步加前置', () {
      final r = run(['stay_short'], age: 10);
      expect(ids(r), ['name_response', 'lure_follow']);
    });

    test('库里没有的技能 → unknownSkill', () {
      expect(run(['nope']).skipped.single.reason, DiagnosisSkipReason.unknownSkill);
    });
  });

  test('上限 6：超出部分按方案顺序截断，说明为谁打基础', () {
    final r = run(['redirect_to_toy', 'sit'], goals: ['a', 'b', 'c', 'd', 'e'], age: 10);
    expect(ids(r), ['redirect_to_toy']);
    final capped = r.skipped.where((s) => s.reason == DiagnosisSkipReason.capReached).toList();
    expect(capped.map((s) => s.skillId), containsAll(['name_response', 'lure_follow', 'sit']));
    expect(capped.firstWhere((s) => s.skillId == 'name_response').forSkill, 'sit');
  });

  test('本周与下周一致：diagnosisPins 与空计划下的 addDiagnosisToWeek 结果相同；已掌握两边都跳过', () {
    for (final issue in lib.issues) {
      for (final sol in issue.solutions) {
        for (final age in [8, 10, 12, 16, 20]) {
          for (final mastered in [<String>{}, {'name_response', 'lure_follow', 'sit'}]) {
            final week = run(sol.skills, mastered: mastered, age: age);
            final pins = diagnosisPins(
                pending: sol.skills, mastered: mastered, ageWeeks: age, skills: lib.skills);
            expect([for (final g in pins) g.skillId], ids(week), reason: '${sol.key} @ $age');
            for (final g in pins) {
              expect(mastered.contains(g.skillId), isFalse);
            }
          }
        }
      }
    }
  });

  group('下周（nextWeekPlan）', () {
    test('诊断技能同一规则：前置未满足时下周加入其前置', () {
      final res = nextWeekPlan(
        thisWeek: const [],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 5),
        skills: lib.skills,
        issues: lib.issues,
        pendingDiagnosisSkills: const ['sit'],
      );
      expect(res.plan.goals.take(2).map((g) => g.skillId), ['name_response', 'lure_follow']);
      expect(res.plan.goals.take(2).every((g) => g.source == GoalSource.aiDiagnosis), isTrue);
    });

    test('下周目标上限 6：诊断 > downgrade > carryover，超出先去 carryover', () {
      final res = nextWeekPlan(
        thisWeek: const [
          GoalWeekStat(skillId: 'marker_intro', full: 1, partial: 0, none: 0),
          GoalWeekStat(skillId: 'potty_training', full: 0, partial: 1, none: 0),
          GoalWeekStat(skillId: 'crate_intro', full: 0, partial: 1, none: 0),
          GoalWeekStat(skillId: 'handling_body', full: 0, partial: 1, none: 0),
        ],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 30),
        skills: lib.skills,
        issues: lib.issues,
        pendingDiagnosisSkills: const ['redirect_to_toy', 'leash_intro', 'sit'],
      );
      final g = res.plan.goals;
      expect(g.length, 6);
      final diag = [for (final x in g) if (x.source == GoalSource.aiDiagnosis) x.skillId];
      expect(diag, ['redirect_to_toy', 'leash_intro', 'name_response', 'lure_follow']);
      expect([for (final x in g) if (x.source == GoalSource.carryover) x.skillId],
          ['marker_intro', 'potty_training']);
    });

    test('downgrade 优先于 carryover 保留', () {
      final down = lib.skillById['bite_inhibition']!;
      expect(down.downgradeTo, 'marker_intro');
      final res = nextWeekPlan(
        thisWeek: [
          const GoalWeekStat(skillId: 'potty_training', full: 0, partial: 1, none: 0),
          GoalWeekStat(skillId: down.id, full: 0, partial: 0, none: 2),
        ],
        input: const PlanInput(ageWeeks: 11, mastered: {}, concerns: [], dailyMinutes: 30),
        skills: lib.skills,
        issues: lib.issues,
        pendingDiagnosisSkills: const ['redirect_to_toy', 'leash_intro', 'crate_intro', 'handling_body', 'name_response'],
      );
      expect(res.plan.goals.length, 6);
      expect(res.plan.goals.where((g) => g.source == GoalSource.downgrade).map((g) => g.skillId),
          ['marker_intro']);
      expect(res.plan.goals.any((g) => g.skillId == 'potty_training'), isFalse);
    });
  });

  group('"扑人"用例（演示关键，按 2026-11-17 修订后的第 9 节）', () {
    final monday = DateTime(2026, 11, 16, 9);
    final birth = DateTime(2026, 9, 7); // 10 周

    Future<({List<String> before, List<String> after, DiagnosisWeekAddition r})> diagnose(
        int minutes, String resultKey) async {
      final db = memoryDb();
      await HouseholdRepository(db).ensureLocalUser();
      final o = await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: '豆豆',
          birthDate: birth,
          breedId: 'mixed',
          breedText: '混种 / 不确定',
          sex: Sex.male,
          homeDate: birth,
          concerns: const [],
          dailyMinutes: minutes,
          trainerCount: 1,
          livingEnv: LivingEnv.apartment,
          masteredSkills: const {},
        ),
        content: lib,
        now: monday,
      );
      final before = [for (final g in await PlanRepository(db).goals(o.planId)) g.skillId];
      final repo = AiRepository(db, clock: () => monday);
      final conv = await repo.newDiagnosisConversation(o.dogId, 'jumping_on_people');
      final sol = lib.issueById['jumping_on_people']!.solutions.firstWhere((s) => s.key == resultKey);
      final id = await repo.saveDiagnosisResult(
        conversationId: conv.id,
        dogId: o.dogId,
        issueId: 'jumping_on_people',
        resultKey: sol.key,
        solutionSkills: sol.skills,
      );
      final r = await repo.addToThisWeek(diagnosisResultId: id, content: lib);
      final after = [for (final g in await PlanRepository(db).goals(o.planId)) g.skillId];
      await db.close();
      return (before: before, after: after, r: r);
    }

    String name(String id) => lib.skillById[id]!.name;
    final keys = ['greeting_jumping', 'demand_jumping', 'fearful_jumping'];

    for (final m in [5, 10, 15, 30]) {
      for (final key in keys) {
        test('$m 分钟档 · $key：新增的技能都当前可练，且都在方案的前置链上', () async {
          final x = await diagnose(m, key);
          final sol = lib.issueById['jumping_on_people']!.solutions.firstWhere((s) => s.key == key).skills.toSet();
          Set<String> chain(String id) {
            final s = lib.skillById[id]!;
            return {id, for (final p in s.prerequisites) ...chain(p)};
          }

          final related = {for (final s in sol) ...chain(s)};
          for (final id in x.after.where((s) => !x.before.contains(s))) {
            final s = lib.skillById[id]!;
            expect(s.minAgeWeeks, lessThanOrEqualTo(10), reason: id);
            expect(s.prerequisites, isEmpty, reason: id);
            expect(related, contains(id), reason: '$id 与方案无关');
          }
        });
      }
    }

    test('5 分钟档：新增 lure_follow，弹窗写"先练跟随诱导，为坐下打基础"', () async {
      final x = await diagnose(5, 'greeting_jumping');
      expect(x.after.where((s) => !x.before.contains(s)), ['lure_follow']);
      final lines = foundationLines(x.r, name).map((l) => l.text).toList();
      expect(lines, contains('先练${name('lure_follow')}，为${name('sit')}打基础'));
      expect(lines, contains('本周计划里的${name('name_response')}正是在为${name('sit')}打基础，先把它们练好'));
    });

    for (final m in [10, 15, 30]) {
      test('$m 分钟档：基础技能已全在计划中 → 不新增，弹窗写明哪些目标在打基础与解锁条件', () async {
        final x = await diagnose(m, 'greeting_jumping');
        expect(x.after, x.before);
        final lines = foundationLines(x.r, name).map((l) => l.text).toList();
        expect(
            lines,
            contains('本周计划里的${name('name_response')}、${name('lure_follow')}'
                '正是在为${name('sit')}打基础，先把它们练好'));
        expect(lines, contains('${name('sit')}：掌握${name('name_response')}、${name('lure_follow')}后解锁'));
        expect(lines, contains('${name('stay_short')}：掌握${name('sit')}，且满 12 周龄后解锁'));
        expect(lines, contains('${name('calm_settle')}：掌握${name('down')}，且满 12 周龄后解锁'));
        expect(lines.where((l) => l.startsWith('先练')), isEmpty);
      });
    }
  });
}
