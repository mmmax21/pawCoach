import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'helpers.dart';

/// M2 首页 / 周报页 / 狗档案页的界面行为：
/// 完成次数与连续天数来自真实数据、跨周后首页显示新一周与周报入口、
/// 档案改动的提示文案。时钟用固定的假时钟，不依赖真实日期。
void main() {
  late AppDatabase db;
  late ContentLibrary lib;
  late DateTime fakeNow;
  late String dogId;
  late String planId;

  setUpAll(() async {
    lib = await loadRepoContent();
  });

  /// 真实 IO（建库、写库）必须在 runAsync 里跑，否则 fake-async 区里 await 会死锁。
  /// 建档：周一 2026-11-16 09:00，狗 10 周龄，10 分钟档，3 个目标。
  Future<void> seed(WidgetTester t,
      {DateTime? birth, String name = '豆豆'}) async {
    db = memoryDb();
    fakeNow = DateTime(2026, 11, 16, 9);
    await t.runAsync(() async {
      await HouseholdRepository(db).ensureLocalUser();
      final r = await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: name,
          birthDate: birth ?? DateTime(2026, 9, 7),
          breedId: 'mixed_or_unknown',
          breedText: '混种 / 不确定',
          sex: Sex.male,
          homeDate: birth ?? DateTime(2026, 9, 7),
          concerns: const [],
          dailyMinutes: 10,
          trainerCount: 1,
          livingEnv: LivingEnv.apartment,
          masteredSkills: const {},
        ),
        content: lib,
        now: fakeNow,
      );
      dogId = r.dogId;
      planId = r.planId;
    });
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        contentSourceProvider
            .overrideWithValue(FileContentSource(repoContentDir())),
        clockProvider.overrideWithValue(() => fakeNow),
      ],
      child: const PuppyTrainerApp(),
    ));
  }

  Future<void> settle(WidgetTester tester, Finder f,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('超时未出现: $f');
  }

  /// drift 的查询流用 Timer 延迟清缓存：测试结束前必须先卸载界面再关库，
  /// 否则 flutter_test 会报"Timer 仍在挂起"。
  Future<void> teardownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => db.close());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> real(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }

  String textOf(WidgetTester t, String key) =>
      t.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('首页：初始为 0 天、0 / 9；打卡后实时变为 1 天、1 / 9，保底不计进度', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('home_streak')));
    await settle(t, find.byKey(const Key('home_week_progress_text')));
    expect(textOf(t, 'home_streak'), '0');
    expect(textOf(t, 'home_week_progress_text'), '0 / 9');
    expect(textOf(t, 'home_goal_count_marker_intro'), '0 / 3');
    expect(find.text('约 3 分钟'), findsOneWidget); // marker_intro mini_script 150 秒

    // 在首页开着的时候写一条记录：界面应自动刷新，不需要重进页面。
    await t.runAsync(() => SessionRepository(db).save(
          draft: SessionDraft(
            dogId: dogId,
            userId: HouseholdRepository.localUserId,
            skillId: 'marker_intro',
            scriptPart: 1,
            startedAt: fakeNow,
            endedAt: fakeNow.add(const Duration(minutes: 4)),
            durationSec: 240,
            clickerCount: 3,
            skippedSteps: const [],
          ),
          score: Score.full,
          now: fakeNow,
        ));
    await real(t);
    await real(t);
    expect(textOf(t, 'home_streak'), '1');
    expect(textOf(t, 'home_goal_count_marker_intro'), '1 / 3');
    expect(textOf(t, 'home_week_progress_text'), '1 / 9');

    // 保底任务打卡：连续天数不变（同一天），进度不变。
    await t.runAsync(() => SessionRepository(db).save(
          draft: SessionDraft(
            dogId: dogId,
            userId: HouseholdRepository.localUserId,
            skillId: 'marker_intro',
            scriptPart: miniScriptPart,
            startedAt: fakeNow.add(const Duration(hours: 5)),
            endedAt: fakeNow.add(const Duration(hours: 5, minutes: 3)),
            durationSec: 150,
            clickerCount: 0,
            skippedSteps: const [],
          ),
          score: Score.partial,
          now: fakeNow,
        ));
    await real(t);
    await real(t);
    expect(textOf(t, 'home_streak'), '1');
    expect(textOf(t, 'home_week_progress_text'), '1 / 9');
    await teardownApp(t);
  });

  testWidgets('跨周后冷启动：补跑生成周报，首页显示新一周与"上周周报已生成"入口',
      (t) async {
    await seed(t);
    await t.runAsync(() => SessionRepository(db).save(
          draft: SessionDraft(
            dogId: dogId,
            userId: HouseholdRepository.localUserId,
            skillId: 'marker_intro',
            scriptPart: 1,
            startedAt: DateTime(2026, 11, 17, 10),
            endedAt: DateTime(2026, 11, 17, 10, 4),
            durationSec: 240,
            clickerCount: 2,
            skippedSteps: const [],
          ),
          score: Score.full,
          now: DateTime(2026, 11, 17, 10),
        ));
    // 下周一早上 App 才被打开。
    fakeNow = DateTime(2026, 11, 23, 8);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('home_report_banner')));
    await settle(t, find.byKey(const Key('home_week_progress_text')));
    expect(find.text('上周周报已生成'), findsOneWidget);
    // 首页显示的是新一周的计划：目标进度归零。
    expect(textOf(t, 'home_week_progress_text'), '0 / 9');
    final plans = await t.runAsync(() => db.select(db.weeklyPlans).get());
    expect(plans!.map((p) => p.weekStart).toSet(),
        {'2026-11-16', '2026-11-23'});
    expect(plans.where((p) => p.status == 'active').single.weekStart,
        '2026-11-23');

    // 点进周报页：打卡 1 天、marker_intro 完成 1 / 3，评分汇总、下周计划预览。
    await t.tap(find.byKey(const Key('home_report_banner')));
    await settle(t, find.byKey(const Key('report_checkin_days')));
    expect(textOf(t, 'report_checkin_days'), '1');
    expect(textOf(t, 'report_sessions'), '1');
    expect(find.byKey(const Key('report_goal_marker_intro')), findsOneWidget);
    expect(find.textContaining('完全做到 1 · 部分做到 0 · 没做到 0'),
        findsOneWidget);
    expect(textOf(t, 'report_outcome_marker_intro'), '下周继续练');
    expect(find.byKey(const Key('report_comment')), findsOneWidget);
    expect(find.text('下周计划预览'), findsOneWidget);

    // 打开过即已读：回首页入口消失。
    await real(t);
    await t.tap(find.byKey(const Key('report_home')));
    await settle(t, find.byKey(const Key('home_dog_name')));
    await real(t);
    await real(t);
    expect(find.byKey(const Key('home_report_banner')), findsNothing);
    await teardownApp(t);
  });

  testWidgets('本周零记录跨周：周报 comment 为固定文案', (t) async {
    await seed(t);
    fakeNow = DateTime(2026, 11, 23, 8);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('home_report_banner')));
    await t.tap(find.byKey(const Key('home_report_banner')));
    await settle(t, find.byKey(const Key('report_comment')));
    expect(textOf(t, 'report_comment'), '这周还没开始，下周从保底任务做起');
    expect(textOf(t, 'report_checkin_days'), '0');
    await teardownApp(t);
  });

  testWidgets('狗档案页：改名只更新 Dog；改每日时长（本周无记录）重生成并提示', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('home_profile')));
    await t.tap(find.byKey(const Key('home_profile')));
    await settle(t, find.byKey(const Key('profile_name')));
    // 口令表在页面底部：滚动到可见后断言存在，且第一条是内容库的默认口令。
    await t.scrollUntilVisible(find.byKey(const Key('cue_sit')), 400,
        scrollable: find.byType(Scrollable).first);
    await real(t);
    expect(find.byKey(const Key('cue_sit')), findsOneWidget);
    expect(find.text('坐下：${lib.skillById['sit']!.defaultCue}'),
        findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('profile_name')), -400,
        scrollable: find.byType(Scrollable).first);

    await t.enterText(find.byKey(const Key('profile_name')), '球球');
    await t.pump();
    await t.tap(find.byKey(const Key('profile_save')));
    await real(t);
    await real(t);
    expect(find.text('已保存'), findsOneWidget);
    final dog = await t.runAsync(() => DogRepository(db).currentDog());
    expect(dog!.name, '球球');
    // SnackBar 是排队显示的：先让上一条消失，否则新的提示还在队列里。
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));

    // 改每日时长 30 分钟 → 4 个目标，本周已重生成。
    await t.ensureVisible(find.text('30 分钟'));
    await t.tap(find.text('30 分钟'));
    await t.pump();
    await t.tap(find.byKey(const Key('profile_save')));
    await real(t);
    await real(t);
    // SnackBar 排队展示：前一条"已保存"走完，第二条才出现。
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(seconds: 5));
      if (find.text('已保存，本周计划已按新信息重新生成').evaluate().isNotEmpty) break;
    }
    expect(find.text('已保存，本周计划已按新信息重新生成'), findsOneWidget);
    final goals =
        await t.runAsync(() => PlanRepository(db).goals(planId));
    expect(goals!.length, 4);
    await teardownApp(t);
  });

  testWidgets('狗档案页：本周已有记录时改每日时长，提示下周重新生成，本周计划不变', (t) async {
    await seed(t);
    await t.runAsync(() => SessionRepository(db).save(
          draft: SessionDraft(
            dogId: dogId,
            userId: HouseholdRepository.localUserId,
            skillId: 'marker_intro',
            scriptPart: 1,
            startedAt: fakeNow,
            endedAt: fakeNow.add(const Duration(minutes: 3)),
            durationSec: 180,
            clickerCount: 0,
            skippedSteps: const [],
          ),
          score: Score.full,
          now: fakeNow,
        ));
    await pumpApp(t);
    await settle(t, find.byKey(const Key('home_profile')));
    await t.tap(find.byKey(const Key('home_profile')));
    await settle(t, find.byKey(const Key('profile_name')));
    await t.ensureVisible(find.text('30 分钟'));
    await t.tap(find.text('30 分钟'));
    await t.pump();
    await t.tap(find.byKey(const Key('profile_save')));
    await real(t);
    await real(t);
    expect(find.textContaining('本周已有训练记录，本周计划不变'), findsOneWidget);
    final goals = await t.runAsync(() => PlanRepository(db).goals(planId));
    expect(goals!.length, 3);
    expect(goals.first.completedSessions, 1);
    await teardownApp(t);
  });

  testWidgets('空计划（7 周龄）：首页与预览都有"去狗档案"入口', (t) async {
    await seed(t, birth: DateTime(2026, 9, 28), name: '小小');
    await pumpApp(t);
    await settle(t, find.byKey(const Key('empty_plan_profile')));
    expect(find.textContaining('去狗档案调整信息'), findsOneWidget);
    await t.tap(find.byKey(const Key('empty_plan_profile')));
    await settle(t, find.byKey(const Key('profile_name')));
    expect(find.text('狗档案'), findsOneWidget);
    await teardownApp(t);
  });
}
