/// M3 简报第 16.6 第 5 条：library 模式（默认构建，不传 AI_MODE）、不启动服务端，
/// 设备上走五个场景：课程内提问、自由提问、健康题、库外题、跟练中提问，全部即时返回。
///
/// 运行：flutter test integration_test/m3_library_test.dart -d emulator-5554
/// （宿主机不要起 server/；测试也用一个"一被创建就记一笔"的 aiClientProvider 证明 HTTP 客户端从未创建）
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/ai_client.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/answer_composer.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/training/training_page.dart';

import 'm2_training_test.dart' show FakeAudio;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump();
    // ignore: avoid_print
    print('M3SHOT $name');
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 20}) async {
    for (var i = 0; i < seconds * 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('超时未出现：$f');
  }

  Future<void> waitIdle(WidgetTester t) async {
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (t.widget<IconButton>(find.byKey(const Key('chat_send'))).onPressed != null) return;
    }
    throw TestFailure('发送按钮一直不可用');
  }

  /// 发一问，返回从点发送到回答入库的毫秒数。
  Future<int> askAndWait(WidgetTester t, AppDatabase db, String q) async {
    final before = (await db.select(db.aiMessages).get()).length;
    await waitIdle(t);
    await t.enterText(find.byKey(const Key('chat_input')), q);
    final sw = Stopwatch()..start();
    await t.tap(find.byKey(const Key('chat_send')));
    for (var i = 0; i < 200; i++) {
      await t.pump(const Duration(milliseconds: 10));
      expect(find.text('正在思考…'), findsNothing);
      if ((await db.select(db.aiMessages).get()).length >= before + 2) break;
    }
    sw.stop();
    expect((await db.select(db.aiMessages).get()).length, before + 2, reason: '回答未入库：$q');
    return sw.elapsedMilliseconds;
  }

  testWidgets('library 模式五个场景：课程内 / 自由提问 / 健康 / 库外 / 跟练中，零网络、即时返回', (t) async {
    expect(buildAiMode, AiMode.library, reason: '默认构建应为 library 模式');
    final db = AppDatabase(NativeDatabase.memory());
    var clientCreated = false;
    final c = ProviderContainer(overrides: [
      // M4：M1-M3 回归用例不启动同步调度与徽章弹窗，保持原有界面路径。
      appEffectsEnabledProvider.overrideWithValue(false),
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(FakeAudio()),
      aiClientProvider.overrideWith((ref) {
        clientCreated = true;
        return HttpAiClient();
      }),
    ]);
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    final now = DateTime.now();
    final birth = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 70));
    await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed_or_unknown',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const [],
        dailyMinutes: 10,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {},
      ),
      content: lib,
    );
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const PuppyTrainerApp()));
    await waitFor(t, find.byKey(const Key('home_goal_count_marker_intro')));
    final timings = <String, int>{};
    final marker = lib.skillById['marker_intro']!;

    // 1. 课程内提问
    await t.tap(find.byKey(const Key('home_goal_marker_intro')));
    await waitFor(t, find.byKey(const Key('skill_ask_coach')));
    await t.tap(find.byKey(const Key('skill_ask_coach')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    timings['课程内提问'] = await askAndWait(t, db, '响片按了它没反应');
    await waitFor(t, find.byKey(const Key('answer_tutorial_marker_intro')));
    expect(find.text(marker.tutorial.successCriteria), findsOneWidget);
    await shot(t, 'L1_course');
    var msgs = await db.select(db.aiMessages).get();
    expect(msgs.last.kind, 'normal');
    expect(msgs.last.citedContentIds, contains('marker_intro'));

    // 2. 自由提问（命中问题行为：只出名称与"开始诊断"）
    c.read(routerProvider).go('/coach/chat');
    await waitFor(t, find.byKey(const Key('chat_input')));
    timings['自由提问'] = await askAndWait(t, db, '我一出门它就哭');
    await waitFor(t, find.byKey(const Key('answer_diagnose_separation_crying')));
    for (final sol in lib.issueById['separation_crying']!.solutions) {
      expect(find.text(sol.summary), findsNothing);
    }
    await shot(t, 'L2_free');

    // 3. 健康题
    timings['健康题'] = await askAndWait(t, db, '它吐了两次还要练吗');
    await waitFor(t, find.text('涉及狗狗健康的问题，请尽快咨询兽医。训练上的问题我随时在。'));
    // 4. 库外题
    timings['库外题'] = await askAndWait(t, db, '怎么教狗握手');
    await waitFor(t, find.text('这个问题内容库暂时没有覆盖，建议咨询专业训犬师。'));
    await shot(t, 'L3_health_nohit');
    msgs = await db.select(db.aiMessages).get();
    expect(msgs.map((m) => m.kind).where((k) => k == 'guard_health').length, 1);
    expect(msgs.map((m) => m.kind).where((k) => k == 'guard_no_hit').length, 1);

    // 5. 跟练中提问：当前步骤原文在最前；返回后恢复
    c.read(routerProvider).go('/home');
    await waitFor(t, find.byKey(const Key('home_goal_marker_intro')));
    await t.tap(find.byKey(const Key('home_goal_marker_intro')));
    await waitFor(t, find.byKey(const Key('start_training')));
    await t.tap(find.byKey(const Key('start_training')));
    await waitFor(t, find.byKey(const Key('training_remaining')));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const Key('training_ask_coach')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    timings['跟练中提问'] = await askAndWait(t, db, '它老是做不好怎么办');
    await waitFor(t, find.text(tplCourseOutOfScope));
    expect(find.text(tplLabelCurrentStep), findsWidgets);
    expect(find.text(marker.stepsForPart(1).first.instruction), findsWidgets);
    await shot(t, 'L4_training');
    await t.pageBack();
    await waitFor(t, find.byKey(const Key('training_remaining')));
    await t.tap(find.byKey(const Key('training_quit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quit_confirm')));
    await waitFor(t, find.byKey(const Key('home_dog_name')));

    // ignore: avoid_print
    print('M3TIMING $timings');
    for (final e in timings.entries) {
      expect(e.value, lessThan(1500), reason: '${e.key} 应即时返回，实际 ${e.value} ms');
    }
    expect(clientCreated, isFalse, reason: 'library 模式不应创建 HTTP 客户端');

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    c.dispose();
    await db.close();
  });
}
