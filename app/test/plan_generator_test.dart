import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary lib;

  setUpAll(() async {
    lib = await loadRepoContent();
  });

  List<String> goalsOf(PlanInput input) => generateWeeklyPlan(
        input: input,
        skills: lib.skills,
        issues: lib.issues,
      ).goals.map((g) => g.skillId).toList();

  group('简报第 4 节 4 个用例', () {
    test('8 周，无掌握，困扰 biting_hands，10 分钟', () {
      expect(
        goalsOf(const PlanInput(
          ageWeeks: 8,
          mastered: {},
          concerns: ['biting_hands'],
          dailyMinutes: 10,
        )),
        ['marker_intro', 'name_response', 'redirect_to_toy'],
      );
    });

    test('12 周，掌握 4 项，困扰 potty_accidents，15 分钟', () {
      expect(
        goalsOf(const PlanInput(
          ageWeeks: 12,
          mastered: {'name_response', 'lure_follow', 'marker_intro', 'sit'},
          concerns: ['potty_accidents'],
          dailyMinutes: 15,
        )),
        ['crate_intro', 'potty_training', 'redirect_to_toy'],
      );
    });

    test('20 周，掌握 8 项，困扰 leash_pulling，30 分钟', () {
      expect(
        goalsOf(const PlanInput(
          ageWeeks: 20,
          mastered: {
            'name_response',
            'lure_follow',
            'marker_intro',
            'sit',
            'down',
            'stay_short',
            'leash_intro',
            'recall_indoor',
          },
          concerns: ['leash_pulling'],
          dailyMinutes: 30,
        )),
        ['calm_settle', 'loose_leash', 'redirect_to_toy', 'bite_inhibition'],
      );
    });

    test('8 周，无掌握，无困扰，5 分钟', () {
      expect(
        goalsOf(const PlanInput(
          ageWeeks: 8,
          mastered: {},
          concerns: [],
          dailyMinutes: 5,
        )),
        ['marker_intro', 'name_response'],
      );
    });
  });

  group('第 9 节补充用例', () {
    test('候选为空（周龄不够）：目标为空，保底为空', () {
      final plan = generateWeeklyPlan(
        input: const PlanInput(
          ageWeeks: 7,
          mastered: {},
          concerns: ['biting_hands'],
          dailyMinutes: 10,
        ),
        skills: lib.skills,
        issues: lib.issues,
      );
      expect(plan.goals, isEmpty);
      expect(plan.miniTask, isNull);
      expect(plan.isEmpty, isTrue);
    });

    test('全部掌握：目标为空，保底取 mastered 中难度最低 id 最小', () {
      final all = lib.skills.map((s) => s.id).toSet();
      final plan = generateWeeklyPlan(
        input: PlanInput(
          ageWeeks: 52,
          mastered: all,
          concerns: const [],
          dailyMinutes: 30,
        ),
        skills: lib.skills,
        issues: lib.issues,
      );
      expect(plan.goals, isEmpty);
      // difficulty 1 的技能：leash_intro, lure_follow, marker_intro,
      // name_response, redirect_to_toy, sit → 字典序最小 leash_intro
      expect(plan.miniTask?.skillId, 'leash_intro');
      // M2 起保底任务读 mini_script，script_part = 0。
      expect(plan.miniTask?.scriptPart, 0);
    });

    test('困扰技能前置未满足时被跳过', () {
      // leash_pulling 的方案技能含 loose_leash（前置 leash_intro, name_response）。
      // 16 周、只掌握 name_response，loose_leash 前置不满足，不应出现。
      final goals = goalsOf(const PlanInput(
        ageWeeks: 16,
        mastered: {'name_response'},
        concerns: ['leash_pulling'],
        dailyMinutes: 30,
      ));
      expect(goals, isNot(contains('loose_leash')));
      expect(goals, isNot(contains('calm_settle')));
      // sit 也是困扰技能，但前置 lure_follow 未掌握，同样被跳过
      expect(goals, isNot(contains('sit')));
      // 基础保障 marker_intro 在首位；前置满足的困扰技能 lure_follow、leash_intro
      // 紧随其后（同为 difficulty 1，按 min_age_weeks 8 < 10 排序）
      expect(goals, ['marker_intro', 'lure_follow', 'leash_intro', 'redirect_to_toy']);
    });
  });

  group('其他规则', () {
    test('目标数按 daily_minutes 映射', () {
      expect(goalCountFor(5), 2);
      expect(goalCountFor(10), 3);
      expect(goalCountFor(15), 3);
      expect(goalCountFor(30), 4);
      expect(() => goalCountFor(20), throwsArgumentError);
    });

    test('困扰选满 3 项时目标数不超 N', () {
      for (final minutes in [5, 10, 15, 30]) {
        final goals = goalsOf(PlanInput(
          ageWeeks: 12,
          mastered: const {},
          concerns: const ['biting_hands', 'potty_accidents', 'chewing_furniture'],
          dailyMinutes: minutes,
        ));
        expect(goals.length, lessThanOrEqualTo(goalCountFor(minutes)));
      }
    });

    test('target_sessions = sessions_to_master + 1，source 填写正确', () {
      final plan = generateWeeklyPlan(
        input: const PlanInput(
          ageWeeks: 8,
          mastered: {},
          concerns: ['biting_hands'],
          dailyMinutes: 10,
        ),
        skills: lib.skills,
        issues: lib.issues,
      );
      for (final g in plan.goals) {
        expect(g.targetSessions, lib.skillById[g.skillId]!.sessionsToMaster + 1);
      }
      expect(plan.goals[0].source, GoalSource.age); // marker_intro 基础保障
      expect(plan.goals[1].source, GoalSource.age); // name_response 基础保障
      expect(plan.goals[2].source, GoalSource.concern); // redirect_to_toy
    });

    test('保底任务：mastered 非空时取其中难度最低', () {
      final plan = generateWeeklyPlan(
        input: const PlanInput(
          ageWeeks: 12,
          mastered: {'name_response', 'lure_follow', 'marker_intro', 'sit'},
          concerns: ['potty_accidents'],
          dailyMinutes: 15,
        ),
        skills: lib.skills,
        issues: lib.issues,
      );
      expect(plan.miniTask?.skillId, 'lure_follow');
    });

    test('保底任务：mastered 为空时取目标中难度最低', () {
      final plan = generateWeeklyPlan(
        input: const PlanInput(
          ageWeeks: 8,
          mastered: {},
          concerns: [],
          dailyMinutes: 5,
        ),
        skills: lib.skills,
        issues: lib.issues,
      );
      expect(plan.miniTask?.skillId, 'marker_intro');
    });

    test('53 周建档仍能生成计划', () {
      final goals = goalsOf(const PlanInput(
        ageWeeks: 53,
        mastered: {},
        concerns: [],
        dailyMinutes: 30,
      ));
      expect(goals.length, 4);
      expect(goals.take(2), ['marker_intro', 'name_response']);
    });
  });

  group('deriveSkillStatuses', () {
    test('mastered / available / locked', () {
      final st = deriveSkillStatuses(
        skills: lib.skills,
        mastered: {'name_response', 'lure_follow'},
      );
      expect(st['name_response'], SkillStatus.mastered);
      expect(st['sit'], SkillStatus.available);
      expect(st['down'], SkillStatus.locked);
      expect(st['marker_intro'], SkillStatus.available);
    });
  });
}
