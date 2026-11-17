/// M3 设备端联调（Android 模拟器）。
///
/// 前置：宿主机起服务端 `cd server && FAKE_UPSTREAM=1 .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000`
/// （没有 API key 时用假上游；有 key 时去掉 FAKE_UPSTREAM 即走真实模型），
/// 并预先授予通知权限：`adb shell pm grant com.puppytrainer.puppy_trainer android.permission.POST_NOTIFICATIONS`。
///
/// 运行：flutter test integration_test/m3_ai_coach_test.dart -d emulator-5554
/// 截图：测试在关键页面打印 `M3SHOT <name>` 并停留 2 秒，宿主机脚本据此 `adb exec-out screencap`
/// （不引入 flutter_driver，依赖白名单见简报第 3 节）。
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/ai_client.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart' show AiMode;
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/diagnosis.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';
import 'package:puppy_trainer/features/ai_coach/diagnosis_page.dart';
import 'package:puppy_trainer/features/training/training_page.dart';
import 'package:puppy_trainer/services/reminder_service.dart';

import 'm2_training_test.dart' show FakeAudio;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 打印截图标记并停留 2 秒（真实时间），宿主机脚本在这段时间里截屏。
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

  /// 等上一问彻底结束（发送按钮恢复可点）再发下一问。
  Future<void> waitIdle(WidgetTester t) async {
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      final b = t.widget<IconButton>(find.byKey(const Key('chat_send')));
      if (b.onPressed != null) return;
    }
    throw TestFailure('发送按钮一直不可用');
  }

  Future<({ProviderContainer c, AppDatabase db})> boot(WidgetTester t,
      {AiClient? ai}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [
      // M4：M1-M3 回归用例不启动同步调度与徽章弹窗，保持原有界面路径。
      appEffectsEnabledProvider.overrideWithValue(false),
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(FakeAudio()),
      // 本文件验证 model 模式（经服务端）；library 模式见 m3_library_test.dart。
      aiModeProvider.overrideWithValue(AiMode.model),
      if (ai != null) aiClientProvider.overrideWithValue(ai),
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
        concerns: const ['biting_hands'],
        dailyMinutes: 10,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {},
      ),
      content: lib,
    );
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const PuppyTrainerApp()));
    await waitFor(t, find.byKey(const Key('home_goal_count_marker_intro')));
    return (c: c, db: db);
  }

  Future<void> shutdown(WidgetTester t, ({ProviderContainer c, AppDatabase db}) s) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    s.c.dispose();
    await s.db.close();
  }

  testWidgets('课程内提问：技能页"问教练" → 经本地服务端流式回答 → 参考内容 → 健康问题固定话术', (t) async {
    final s = await boot(t);
    await shot(t, '01_home');
    await t.tap(find.byKey(const Key('home_goal_marker_intro')));
    await waitFor(t, find.byKey(const Key('skill_ask_coach')));
    await t.tap(find.byKey(const Key('skill_ask_coach')));
    await waitFor(t, find.byKey(const Key('chat_input')));

    await t.enterText(find.byKey(const Key('chat_input')), '响片按了它没反应');
    await t.tap(find.byKey(const Key('chat_send')));
    await waitFor(t, find.byKey(const Key('chat_refs')), seconds: 30);
    await t.tap(find.byKey(const Key('chat_refs')));
    await t.pumpAndSettle();
    await shot(t, '02_course_qa_refs');

    final msgs = await s.db.select(s.db.aiMessages).get();
    expect(msgs.length, 2);
    expect(msgs[1].kind, 'normal');
    final cited = jsonDecode(msgs[1].citedContentIds) as List;
    expect(cited, contains('marker_intro'));
    expect(msgs[1].content, isNot(contains('[ref')));

    await waitIdle(t);
    await t.enterText(find.byKey(const Key('chat_input')), '它吐了两次还要练吗');
    await t.tap(find.byKey(const Key('chat_send')));
    try {
      await waitFor(t, find.text('涉及狗狗健康的问题，请尽快咨询兽医。训练上的问题我随时在。'));
    } catch (_) {
      final all = await s.db.select(s.db.aiMessages).get();
      // ignore: avoid_print
      print('M3DBG ${all.map((m) => '${m.role}/${m.kind}/${m.content}').toList()}');
      await shot(t, '03x_guard_missing');
      rethrow;
    }
    // 课程内提问总带技能上下文，按简报第 5 节不会判无命中；库外问题在"自由提问"（无上下文）里验证。
    await waitIdle(t);
    s.c.read(routerProvider).go('/coach/chat');
    await waitFor(t, find.byKey(const Key('chat_input')));
    await t.enterText(find.byKey(const Key('chat_input')), '怎么教狗握手');
    await t.tap(find.byKey(const Key('chat_send')));
    await waitFor(t, find.text('这个问题内容库暂时没有覆盖，建议咨询专业训犬师。'));
    await shot(t, '03_guards');
    final kinds = [for (final m in await s.db.select(s.db.aiMessages).get()) m.kind];
    expect((await s.db.select(s.db.aiConversations).get()).length, 2); // 课程对话 + 自由提问对话
    expect(kinds.where((k) => k == 'guard_health').length, 1);
    expect(kinds.where((k) => k == 'guard_no_hit').length, 1);
    await shutdown(t, s);
  });

  testWidgets('跟练中问教练：进入时暂停，返回后恢复，倒计时不丢', (t) async {
    final s = await boot(t);
    await t.tap(find.byKey(const Key('home_goal_marker_intro')));
    await waitFor(t, find.byKey(const Key('start_training')));
    await t.tap(find.byKey(const Key('start_training')));
    await waitFor(t, find.byKey(const Key('training_remaining')));
    await t.pump(const Duration(seconds: 2));
    int remaining() => int.parse(t.widget<Text>(find.byKey(const Key('training_remaining'))).data!);
    final before = remaining();

    await t.tap(find.byKey(const Key('training_ask_coach')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    // 在对话页停留 4 秒（真实时间）
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await shot(t, '04_training_ask_coach');
    await t.pageBack();
    await waitFor(t, find.byKey(const Key('training_remaining')));
    await t.pump(const Duration(milliseconds: 300));
    final after = remaining();
    expect((after - before).abs(), lessThanOrEqualTo(1),
        reason: '对话页停留期间应暂停：before=$before after=$after');
    // 恢复运行：继续倒数
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(remaining(), lessThan(after));
    // 退出跟练（不写记录）
    await t.tap(find.byKey(const Key('training_quit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quit_confirm')));
    await waitFor(t, find.byKey(const Key('home_dog_name')));
    await shutdown(t, s);
  });

  testWidgets('诊断：选 issue → 追问按钮 → 结果页 → 加入本周 → 首页立即出现', (t) async {
    final s = await boot(t);
    await t.tap(find.byKey(const Key('nav_coach')));
    await waitFor(t, find.byKey(const Key('coach_diagnosis_entry')));
    await shot(t, '05_coach_home');
    // 选一条"加入本周"确实会新增目标的路径（新建档的幼犬很多方案前置未满足）。
    final lib = await s.c.read(contentLibraryProvider.future);
    final dog0 = (await DogRepository(s.db).currentDog())!;
    final plan0 = (await PlanRepository(s.db).activePlan(dog0.id))!;
    final goal0 = [for (final g in await PlanRepository(s.db).goals(plan0.id)) g.skillId];
    late Issue issue;
    late List<int> path;
    search:
    for (final i in lib.issues) {
      for (final p in allDiagnosisPaths(i)) {
        final o = diagnosisNext(i, p) as DiagnosisOutcome;
        final add = addDiagnosisToWeek(
            solutionSkills: o.solution.skills, currentGoalIds: goal0, mastered: const {}, ageWeeks: 10, skills: lib.skills);
        if (add.added.isNotEmpty) {
          issue = i;
          path = p;
          break search;
        }
      }
    }
    await t.tap(find.byKey(const Key('coach_diagnosis_entry')));
    await waitFor(t, find.byKey(Key('issue_${issue.id}')));
    await t.scrollUntilVisible(
      find.byKey(Key('issue_${issue.id}')),
      200,
      scrollable: find
          .descendant(of: find.byType(DiagnosisPage), matching: find.byType(Scrollable))
          .first,
    );
    await t.tap(find.byKey(Key('issue_${issue.id}')));
    await waitFor(t, find.byKey(const Key('diagnosis_question')));
    await shot(t, '06_diagnosis_question');
    for (final option in path) {
      await waitFor(t, find.byKey(Key('diagnosis_option_$option')));
      await t.tap(find.byKey(Key('diagnosis_option_$option')));
      for (var k = 0; k < 10; k++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }
    await waitFor(t, find.byKey(const Key('diagnosis_result')));
    expect(find.byKey(const Key('diagnosis_escalate_text')), findsOneWidget);
    await shot(t, '07_diagnosis_result');

    final before = {for (final g in await PlanRepository(s.db).goals((await PlanRepository(s.db).activePlan((await DogRepository(s.db).currentDog())!.id))!.id)) g.skillId};
    await t.scrollUntilVisible(
      find.byKey(const Key('diagnosis_add_this_week')),
      300,
      scrollable: find.descendant(
          of: find.byKey(const Key('diagnosis_result')), matching: find.byType(Scrollable)).first,
    );
    await t.tap(find.byKey(const Key('diagnosis_add_this_week')));
    await waitFor(t, find.byKey(const Key('diagnosis_add_result')));
    await shot(t, '08_add_this_week');
    await t.tap(find.byKey(const Key('diagnosis_add_ok')));
    await t.pumpAndSettle();

    final dog = (await DogRepository(s.db).currentDog())!;
    final plan = (await PlanRepository(s.db).activePlan(dog.id))!;
    final added = [
      for (final g in await PlanRepository(s.db).goals(plan.id))
        if (!before.contains(g.skillId)) g,
    ];
    expect(added, isNotEmpty);
    expect(added.every((g) => g.source == 'ai_diagnosis'), isTrue);

    s.c.read(routerProvider).go('/home');
    for (final g in added) {
      await waitFor(t, find.byKey(Key('home_goal_${g.skillId}')));
    }
    await t.scrollUntilVisible(find.byKey(Key('home_goal_${added.last.skillId}')), 200);
    await shot(t, '09_home_after_add');
    await shutdown(t, s);
  });

  testWidgets('提醒：打开开关 → 已调度每日通知；打卡后改到明天', (t) async {
    final s = await boot(t);
    await t.tap(find.byKey(const Key('home_reminder')));
    await waitFor(t, find.byKey(const Key('reminder_switch')));
    await t.tap(find.byKey(const Key('reminder_switch')));
    await waitFor(t, find.byKey(const Key('reminder_next')));
    await shot(t, '10_reminder');
    final pending = await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
    expect(pending.map((p) => p.id), contains(reminderNotificationId));
    expect(pending.firstWhere((p) => p.id == reminderNotificationId).body, reminderBody);

    final dog = (await DogRepository(s.db).currentDog())!;
    // 模拟打卡后的调用（记录页保存后会调 onCheckin），下一次应在明天。
    await s.db.into(s.db.trainingSessions).insert(TrainingSessionsCompanion.insert(
          id: 'ses_it',
          dogId: dog.id,
          userId: HouseholdRepository.localUserId,
          skillId: 'marker_intro',
          scriptPart: 0,
          startedAt: DateTime.now().toUtc().toIso8601String(),
          endedAt: DateTime.now().toUtc().toIso8601String(),
          durationSec: 60,
          score: 'full',
        ));
    final next = await s.c.read(reminderServiceProvider).onCheckin(dog.id);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect((next!.year, next.month, next.day), (tomorrow.year, tomorrow.month, tomorrow.day));
    expect((await FlutterLocalNotificationsPlugin().pendingNotificationRequests())
        .where((p) => p.id == reminderNotificationId), hasLength(1));

    // 关闭：取消
    await t.tap(find.byKey(const Key('reminder_switch')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect((await FlutterLocalNotificationsPlugin().pendingNotificationRequests())
        .where((p) => p.id == reminderNotificationId), isEmpty);
    await shutdown(t, s);
  });

  testWidgets('网络断开：对话页显示"教练暂时联系不上，稍后再试"，消息不入库', (t) async {
    // 指向一个没人监听的端口，模拟服务端不可达。
    final s = await boot(t, ai: HttpAiClient(baseUrl: 'http://10.0.2.2:9'));
    s.c.read(routerProvider).push('/coach/chat?skill=sit');
    await waitFor(t, find.byKey(const Key('chat_input')));
    await t.enterText(find.byKey(const Key('chat_input')), '坐下练了三天狗还是不坐怎么办');
    await t.tap(find.byKey(const Key('chat_send')));
    await waitFor(t, find.text('教练暂时联系不上，稍后再试'), seconds: 20);
    await shot(t, '11_offline');
    expect(await s.db.select(s.db.aiMessages).get(), isEmpty);
    await shutdown(t, s);
  });
}
