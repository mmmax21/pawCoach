import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = memoryDb();
  });

  /// 内容库加载、建库都是真实 IO（文件 + sqlite），在 flutter_test 的
  /// fake-async 里不会推进，必须用 runAsync 让真实事件循环跑起来。
  Future<void> pumpUntil(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('超时未出现: $finder');
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contentSourceProvider
              .overrideWithValue(FileContentSource(repoContentDir())),
        ],
        child: const PuppyTrainerApp(),
      ),
    );
    await pumpUntil(tester, find.textContaining('建档 1/3'));
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }

  /// 先卸载整棵树再结束测试，让 drift 流关闭时的零时长 Timer 得以执行，
  /// 否则 flutter_test 会报 "A Timer is still pending"。
  /// 这些 Timer 建在 fake-async 区，要用带时长的 pump 推进，再在真实
  /// 事件循环里关库。
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => db.close());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('三步建档走通，数据库里存在 1 个 Dog 和 1 个 WeeklyPlan',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);

    await pump(tester);
    // 无狗 → 自动进入建档
    expect(find.textContaining('建档 1/3'), findsOneWidget);

    // 第一步
    await tester.enterText(find.byKey(const Key('dog_name')), '豆豆');
    await tester.pump();
    await tapText(tester, '公');
    await tester.enterText(find.byKey(const Key('breed_search')), '柯基');
    await tester.pump();
    await tapKey(tester, 'breed_corgi');
    await tapKey(tester, 'onboarding_next');
    expect(find.textContaining('建档 2/3'), findsOneWidget);

    // 第二步：选 1 个困扰
    await tapKey(tester, 'concern_biting_hands');
    expect(find.text('已选 1 / 3'), findsOneWidget);
    await tapKey(tester, 'onboarding_next');
    expect(find.textContaining('建档 3/3'), findsOneWidget);

    // 第三步
    await tapText(tester, '10 分钟');
    await tapText(tester, '1');
    await tapText(tester, '公寓');
    await tapKey(tester, 'onboarding_next');
    await pumpUntil(tester, find.text('你的首周计划'));

    // 预览页
    expect(find.text('你的首周计划'), findsOneWidget);
    await pumpUntil(tester, find.text('本周目标'));

    final dogs = await db.select(db.dogs).get();
    expect(dogs.length, 1);
    expect(dogs.single.name, '豆豆');
    expect(dogs.single.breedId, 'corgi');
    final plans = await db.select(db.weeklyPlans).get();
    expect(plans.length, 1);
    final goals = await db.select(db.planGoals).get();
    expect(goals.length, 3); // 10 分钟 → 3
    expect((await db.select(db.dailyMiniTasks).get()).length, 1);
    expect((await db.select(db.dogCues).get()).length, 18);
    expect((await db.select(db.dogSkillStatuses).get()).length, 18);
    expect((await db.select(db.households).get()).length, 1);
    expect((await db.select(db.householdMembers).get()).single.role, 'creator');
    expect((await db.select(db.dogConcerns).get()).single.issueId,
        'biting_hands');

    // 进首页
    await tapKey(tester, 'go_home');
    await pumpUntil(tester, find.byKey(const Key('home_mini_task')));
    expect(find.byKey(const Key('home_dog_name')), findsOneWidget);
    expect(find.byKey(const Key('home_mini_task')), findsOneWidget);
    expect(find.text('0 / 3'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('困扰最多选 3 项', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);

    await pump(tester);
    await tester.enterText(find.byKey(const Key('dog_name')), '小白');
    await tester.pump();
    await tapText(tester, '母');
    await tapKey(tester, 'breed_$mixedBreedIdForTest');
    await tapKey(tester, 'onboarding_next');

    await tapKey(tester, 'concern_biting_hands');
    await tapKey(tester, 'concern_potty_accidents');
    await tapKey(tester, 'concern_chewing_furniture');
    await tapKey(tester, 'concern_not_coming');
    expect(find.text('已选 3 / 3'), findsOneWidget);
    expect(find.text('最多选 3 项'), findsOneWidget);
    await unmount(tester);
  });
}

const mixedBreedIdForTest = 'mixed_or_unknown';
