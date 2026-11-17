import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/onboarding/onboarding_controller.dart';

import 'helpers.dart';

void main() {
  test('ON-2 counts a dog name by user-visible characters', () {
    final form = OnboardingForm.initial(DateTime(2026, 11, 16)).copyWith(
        dogName: '🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶', breedId: 'corgi', sex: Sex.male);
    expect(form.step1Valid, isTrue);
    expect(form.copyWith(dogName: '').step1Valid, isFalse);
    expect(form.copyWith(dogName: '   ').step1Valid, isFalse);
    expect(form.copyWith(dogName: '一二三四五六七八九十').step1Valid, isTrue);
    expect(form.copyWith(dogName: '一二三四五六七八九十一').step1Valid, isFalse);
  });

  test('WP-2 uses local calendar date at 8-week boundary before 08:00',
      () async {
    final db = memoryDb();
    final content = await loadRepoContent(db: db);
    await HouseholdRepository(db).ensureLocalUser();
    final now = DateTime(2026, 11, 16, 0, 30);
    await OnboardingRepository(db).complete(
        form: OnboardingResult(
            dogName: '测试',
            birthDate: DateTime(2026, 9, 21),
            breedId: 'corgi',
            breedText: '柯基',
            sex: Sex.male,
            homeDate: DateTime(2026, 11, 16),
            concerns: [],
            dailyMinutes: 10,
            trainerCount: 1,
            livingEnv: LivingEnv.apartment,
            masteredSkills: {}),
        content: content,
        now: now);
    expect((await db.select(db.planGoals).get()).length, 3);
    expect(
        (await db.select(db.weeklyPlans).get()).single.weekStart, '2026-11-16');
    await db.close();
  });
  // BUG-M1-003 在 M2 由内容库 v1.1 的 mini_script 解决（Fable 决策第 8 条）：
  // 原来这里断言多段技能的保底任务取 part 1 且 330/315/330 秒超过 5 分钟；
  // 现在断言保底任务取 mini_script（script_part == 0）且 ≤300 秒。
  test('WP-1 multipart mini task uses mini_script (part 0) and stays within 5 minutes',
      () async {
    final db = memoryDb();
    try {
      final lib = await loadRepoContent(db: db);
      for (final entry in {
        'stay_long': 220,
        'alone_time': 210,
        'loose_leash': 240,
        'handling_body': 175
      }.entries) {
        final plan = generateWeeklyPlan(
            input: PlanInput(
                ageWeeks: 52,
                mastered: {entry.key},
                concerns: [],
                dailyMinutes: 10),
            skills: lib.skills,
            issues: lib.issues);
        expect(plan.miniTask!.skillId, entry.key);
        expect(plan.miniTask!.scriptPart, 0);
        final skill = lib.skillById[entry.key]!;
        expect(skill.scriptParts, 2);
        expect(skill.partDurationSec(0), entry.value);
        expect(skill.partDurationSec(0), lessThanOrEqualTo(300));
        expect(skill.partDurationMinutes(0), lessThanOrEqualTo(5));
        debugPrint(
            'ASTRA mini ${entry.key} part=0 seconds=${skill.partDurationSec(0)}');
      }
    } finally {
      await db.close();
    }
  });
}
