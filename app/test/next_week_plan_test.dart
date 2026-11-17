import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';

import 'helpers.dart';

/// M2 简报第 11 节 nextWeekPlan() 六个用例，用内容库 v1.1 真实数据跑。
void main() {
  late ContentLibrary lib;

  setUpAll(() async {
    lib = await loadRepoContent();
  });

  GoalWeekStat stat(String id, {int full = 0, int partial = 0, int none = 0}) =>
      GoalWeekStat(skillId: id, full: full, partial: partial, none: none);

  // 12 周龄、已掌握基础技能，10 分钟档（3 个目标）。
  PlanInput input({Set<String>? mastered, List<String> concerns = const []}) =>
      PlanInput(
        ageWeeks: 13,
        mastered: mastered ??
            const {'name_response', 'lure_follow', 'marker_intro'},
        concerns: concerns,
        dailyMinutes: 10,
      );

  NextWeekResult run(
    List<GoalWeekStat> week, {
    PlanInput? inp,
    bool regenerateNext = false,
  }) =>
      nextWeekPlan(
        thisWeek: week,
        input: inp ?? input(),
        skills: lib.skills,
        issues: lib.issues,
        regenerateNext: regenerateNext,
      );

  List<String> ids(NextWeekResult r) =>
      r.plan.goals.map((g) => g.skillId).toList();

  GeneratedGoal goal(NextWeekResult r, String id) =>
      r.plan.goals.firstWhere((g) => g.skillId == id);

  group('简报第 11 节：nextWeekPlan 六个用例', () {
    test('1. sit 两次 full → 下周无 sit，mastered，down 进入候选', () {
      // 候选池里只剩 sit 的后继，down 才排得进前 3；其余难度 1-2 的技能都已掌握。
      const base = {
        'name_response',
        'lure_follow',
        'marker_intro',
        'redirect_to_toy',
        'leash_intro',
        'bite_inhibition',
        'crate_intro',
        'handling_body',
        'potty_training',
      };
      final inp = input(mastered: base);

      // 对照：sit 没掌握时，down（前置 sit）不是候选。
      final before = generateWeeklyPlan(
          input: inp, skills: lib.skills, issues: lib.issues);
      expect(before.goals.map((g) => g.skillId), isNot(contains('down')));

      final r = run([stat('sit', full: 2)], inp: inp);
      expect(r.outcomes['sit'], GoalOutcome.mastered);
      expect(r.newlyMastered, {'sit'});
      expect(ids(r), isNot(contains('sit')));
      expect(ids(r), contains('down'));
    });

    test('2. sit 两次 none → 下周出现 lure_follow（source downgrade）', () {
      // lure_follow 已掌握时降级目标也要保留：降级优先于"已掌握"。
      final r = run([stat('sit', none: 2)],
          inp: input(mastered: const {'name_response', 'marker_intro'}));
      expect(r.outcomes['sit'], GoalOutcome.downgrade);
      expect(ids(r), contains('lure_follow'));
      expect(goal(r, 'lure_follow').source, GoalSource.downgrade);
      expect(ids(r), isNot(contains('sit')));
    });

    test('3. crate_intro 两次 none（downgrade_to 为 null）→ 保留 crate_intro（carryover）', () {
      expect(lib.skillById['crate_intro']!.downgradeTo, isNull);
      final r = run([stat('crate_intro', none: 2)]);
      expect(r.outcomes['crate_intro'], GoalOutcome.downgrade);
      expect(ids(r), contains('crate_intro'));
      expect(goal(r, 'crate_intro').source, GoalSource.carryover);
    });

    test('4. 一次 full 一次 none → carryover', () {
      final r = run([stat('sit', full: 1, none: 1)]);
      expect(r.outcomes['sit'], GoalOutcome.carryover);
      expect(ids(r).first, 'sit');
      expect(goal(r, 'sit').source, GoalSource.carryover);
      expect(r.newlyMastered, isEmpty);
    });

    test('5. 本周零记录 → 全部 carryover', () {
      final week = [
        stat('sit'),
        stat('redirect_to_toy'),
        stat('potty_training'),
      ];
      final r = run(week);
      for (final g in week) {
        expect(r.outcomes[g.skillId], GoalOutcome.carryover);
        expect(goal(r, g.skillId).source, GoalSource.carryover);
      }
      expect(ids(r), ['sit', 'redirect_to_toy', 'potty_training']);
      expect(r.newlyMastered, isEmpty);
    });

    test('6. regenerateNext → 全新生成（等同 generateWeeklyPlan，忽略本周统计）', () {
      final inp = input();
      final fresh = generateWeeklyPlan(
          input: inp, skills: lib.skills, issues: lib.issues);
      final r = run([stat('sit', full: 2), stat('down', none: 2)],
          inp: inp, regenerateNext: true);
      expect(r.outcomes, isEmpty);
      expect(r.newlyMastered, isEmpty);
      expect(ids(r), fresh.goals.map((g) => g.skillId).toList());
      expect(r.plan.miniTask?.skillId, fresh.miniTask?.skillId);
    });
  });

  group('规则细节', () {
    test('目标顺序：carryover / downgrade 排前，补足的技能排后', () {
      final r = run([
        stat('sit', none: 2), // → lure_follow (downgrade)
        stat('redirect_to_toy', partial: 1), // carryover
      ], inp: input(mastered: const {'name_response', 'marker_intro'}));
      final g = r.plan.goals;
      expect(g[0].skillId, 'lure_follow');
      expect(g[0].source, GoalSource.downgrade);
      expect(g[1].skillId, 'redirect_to_toy');
      expect(g[1].source, GoalSource.carryover);
    });

    test('carryover + downgrade 已 ≥ N：不补也不裁', () {
      final week = [
        stat('sit'),
        stat('redirect_to_toy'),
        stat('potty_training'),
        stat('crate_intro'),
      ]; // 4 个 carryover，10 分钟档 N = 3
      final r = run(week);
      expect(ids(r), ['sit', 'redirect_to_toy', 'potty_training', 'crate_intro']);
    });

    test('下周目标去重：降级目标与另一个 carryover 重复只出现一次', () {
      final r = run([
        stat('sit', none: 2), // → lure_follow
        stat('lure_follow'), // carryover lure_follow
      ], inp: input(mastered: const {'name_response', 'marker_intro'}));
      expect(ids(r).where((i) => i == 'lure_follow').length, 1);
    });

    test('mastered 优先于 downgrade：full ≥ 2 且 none ≥ 2 判掌握', () {
      expect(judgeGoalOutcome(full: 2, none: 2), GoalOutcome.mastered);
      expect(judgeGoalOutcome(full: 1, none: 2), GoalOutcome.downgrade);
      expect(judgeGoalOutcome(full: 1, none: 1), GoalOutcome.carryover);
      expect(judgeGoalOutcome(full: 0, none: 0), GoalOutcome.carryover);
    });

    test('保底任务：用新 mastered 重算，且一律取 mini_script（part 0）', () {
      final r = run([stat('sit', full: 2)]);
      expect(r.plan.miniTask, isNotNull);
      expect(r.plan.miniTask!.scriptPart, miniScriptPart);
      // 已掌握里难度最低的：lure_follow / marker_intro / name_response 都是 1，按 id 排第一。
      expect(r.plan.miniTask!.skillId, 'lure_follow');
    });

    test('新周龄决定可补入的技能：周龄不足的不补', () {
      final r = run([],
          inp: PlanInput(
            ageWeeks: 8,
            mastered: const {},
            concerns: const [],
            dailyMinutes: 10,
          ));
      for (final g in r.plan.goals) {
        expect(lib.skillById[g.skillId]!.minAgeWeeks, lessThanOrEqualTo(8));
      }
    });
  });

  group('M1 规则不被 pinned/excluded 参数破坏', () {
    test('不传 pinned / excluded 时与 M1 结果一致', () {
      final a = generateWeeklyPlan(
          input: input(), skills: lib.skills, issues: lib.issues);
      final b = generateWeeklyPlan(
          input: input(),
          skills: lib.skills,
          issues: lib.issues,
          pinned: const [],
          excluded: const {});
      expect(a.goals.map((g) => g.skillId), b.goals.map((g) => g.skillId));
    });
  });
}
