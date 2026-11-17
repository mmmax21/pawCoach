/// M3 界面：诊断页从选 issue 到结果页走通（escalate_if 在方案前、加入本周计划后首页立即出现），
/// 对话页流式回答 + 参考内容折叠区、固定话术、网络失败不入库。不调真实模型。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart' show AiMode;
import 'package:puppy_trainer/data/ai/fake_ai_client.dart';
import 'package:puppy_trainer/domain/answer_composer.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/diagnosis.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/plan_generator.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

void main() {
  late AppDatabase db;
  late ContentLibrary lib;
  late String planId;
  final fakeNow = DateTime(2026, 11, 16, 9);

  setUpAll(() async {
    lib = await loadRepoContent();
  });

  Future<void> seed(WidgetTester t) async {
    db = memoryDb();
    await t.runAsync(() async {
      await HouseholdRepository(db).ensureLocalUser();
      final r = await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: '豆豆',
          birthDate: DateTime(2026, 9, 7),
          breedId: 'mixed_or_unknown',
          breedText: '混种 / 不确定',
          sex: Sex.male,
          homeDate: DateTime(2026, 9, 7),
          concerns: const [],
          dailyMinutes: 10,
          trainerCount: 1,
          livingEnv: LivingEnv.apartment,
          masteredSkills: const {},
        ),
        content: lib,
        now: fakeNow,
      );
      planId = r.planId;
    });
  }

  var clientCreated = false;

  Future<void> pumpApp(WidgetTester t, FakeAiClient ai, {AiMode mode = AiMode.model}) async {
    clientCreated = false;
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
        clockProvider.overrideWithValue(() => fakeNow),
        aiModeProvider.overrideWithValue(mode),
        aiClientProvider.overrideWith((ref) {
          clientCreated = true;
          return ai;
        }),
        reminderNotifierProvider.overrideWithValue(FakeNotifier()),
      ],
      child: const PuppyTrainerApp(),
    ));
  }

  GoRouter router(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp))).read(routerProvider);

  Future<void> settle(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('超时未出现: $f');
  }

  Future<void> tapAndSettle(WidgetTester t, Finder tap, Finder wait) async {
    await t.ensureVisible(tap);
    await t.pump();
    await t.tap(tap);
    await settle(t, wait);
  }

  Future<void> teardownApp(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.runAsync(() => db.close());
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('诊断：选 issue → 逐题按钮 → 结果页（escalate_if 在前）→ 加入本周 → 首页立即出现', (t) async {
    await seed(t);
    final goals = await t.runAsync(() => PlanRepository(db).goals(planId));
    final goalIds = [for (final g in goals!) g.skillId];

    // 找一条"加入本周"会有新增的路径。
    final issue = lib.issueById['biting_hands']!;
    late List<int> path;
    late List<String> expectAdded;
    for (final p in allDiagnosisPaths(issue)) {
      final o = diagnosisNext(issue, p) as DiagnosisOutcome;
      final add = addDiagnosisToWeek(
        solutionSkills: o.solution.skills,
        currentGoalIds: goalIds,
        mastered: const {},
        ageWeeks: 10,
        skills: lib.skills,
      );
      if (add.added.isNotEmpty) {
        path = p;
        expectAdded = [for (final g in add.added) g.skillId];
        break;
      }
    }
    final outcome = diagnosisNext(issue, path) as DiagnosisOutcome;

    final ai = FakeAiClient();
    await pumpApp(t, ai);
    await settle(t, find.byKey(const Key('nav_coach')));
    for (final id in expectAdded) {
      expect(find.byKey(Key('home_goal_$id')), findsNothing);
    }
    await tapAndSettle(t, find.byKey(const Key('nav_coach')), find.byKey(const Key('coach_diagnosis_entry')));
    await tapAndSettle(t, find.byKey(const Key('coach_diagnosis_entry')), find.byKey(const Key('issue_biting_hands')));
    await tapAndSettle(t, find.byKey(const Key('issue_biting_hands')), find.byKey(const Key('diagnosis_question')));

    for (var i = 0; i < path.length; i++) {
      final last = i == path.length - 1;
      await tapAndSettle(
        t,
        find.byKey(Key('diagnosis_option_${path[i]}')),
        last ? find.byKey(const Key('diagnosis_result')) : find.byKey(const Key('diagnosis_question')),
      );
    }

    // escalate_if 原文完整展示，并且在方案（summary）之前。
    expect(find.text(outcome.solution.escalateIf), findsOneWidget);
    final escY = t.getTopLeft(find.byKey(const Key('diagnosis_escalate'))).dy;
    final sumY = t.getTopLeft(find.byKey(const Key('diagnosis_summary'))).dy;
    expect(escY, lessThan(sumY));
    expect(find.text(outcome.solution.summary), findsOneWidget);
    for (final m in outcome.solution.management) {
      expect(find.text(m), findsOneWidget);
    }
    // 诊断全程不调模型。
    expect(ai.calls, 0);

    await tapAndSettle(t, find.byKey(const Key('diagnosis_add_this_week')), find.byKey(const Key('diagnosis_add_result')));
    await t.tap(find.byKey(const Key('diagnosis_add_ok')));
    await t.pump();

    // 回首页：新增目标立即出现。
    router(t).go('/home');
    for (final id in expectAdded) {
      await settle(t, find.byKey(Key('home_goal_$id')));
    }

    // 诊断对话已入库（diagnosis_q / diagnosis_result）。
    final msgs = await t.runAsync(() => db.select(db.aiMessages).get());
    expect(msgs!.where((m) => m.kind == 'diagnosis_q').length, path.length);
    expect(msgs.where((m) => m.kind == 'diagnosis_result').length, 1);
    final results = await t.runAsync(() => db.select(db.diagnosisResults).get());
    expect(results!.single.addedToPlanId, planId);

    await teardownApp(t);
  });

  testWidgets('对话：流式回答、参考内容折叠区可展开并跳技能页；健康问题回固定话术', (t) async {
    await seed(t);
    final ai = FakeAiClient();
    await pumpApp(t, ai);
    await settle(t, find.byKey(const Key('nav_coach')));
    router(t).push('/coach/chat?skill=marker_intro');
    await settle(t, find.byKey(const Key('chat_input')));

    await t.enterText(find.byKey(const Key('chat_input')), '响片按了它没反应');
    await t.tap(find.byKey(const Key('chat_send')));
    await settle(t, find.byKey(const Key('chat_refs')));
    expect(ai.calls, 1);
    expect(ai.lastSystem, contains('<material id="marker_intro"'));
    expect(find.textContaining(FakeAiClient.defaultText), findsOneWidget);
    expect(find.textContaining('[ref'), findsNothing);

    await t.tap(find.byKey(const Key('chat_refs')));
    await settle(t, find.byKey(const Key('ref_marker_intro')));
    await t.pump(const Duration(milliseconds: 400)); // 展开动画走完
    await tapAndSettle(t, find.byKey(const Key('ref_marker_intro')), find.byKey(const Key('skill_ask_coach')));
    router(t).pop();
    await settle(t, find.byKey(const Key('chat_input')));

    await t.enterText(find.byKey(const Key('chat_input')), '它今天不吃饭还要练吗');
    await t.tap(find.byKey(const Key('chat_send')));
    await settle(t, find.text('涉及狗狗健康的问题，请尽快咨询兽医。训练上的问题我随时在。'));
    expect(ai.calls, 1, reason: '健康拦截不调模型');

    final msgs = await t.runAsync(() => db.select(db.aiMessages).get());
    expect(msgs!.map((m) => m.kind), ['normal', 'normal', 'normal', 'guard_health']);
    await teardownApp(t);
  });

  testWidgets('对话：网络失败显示"教练暂时联系不上，稍后再试"，消息不入库', (t) async {
    await seed(t);
    final ai = FakeAiClient(fail: true);
    await pumpApp(t, ai);
    await settle(t, find.byKey(const Key('nav_coach')));
    router(t).push('/coach/chat?skill=sit');
    await settle(t, find.byKey(const Key('chat_input')));

    await t.enterText(find.byKey(const Key('chat_input')), '坐下练了三天还是不坐');
    await t.tap(find.byKey(const Key('chat_send')));
    await settle(t, find.text('教练暂时联系不上，稍后再试'));
    expect(ai.calls, 1);
    final msgs = await t.runAsync(() => db.select(db.aiMessages).get());
    expect(msgs, isEmpty);
    // 问题还给输入框，方便重发。
    expect(find.text('坐下练了三天还是不坐'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('library 模式：课程内提问即时直出、按块渲染、看教程入口；不创建 HTTP 客户端、无"正在思考"', (t) async {
    await seed(t);
    final ai = FakeAiClient();
    await pumpApp(t, ai, mode: AiMode.library);
    await settle(t, find.byKey(const Key('nav_coach')));
    router(t).push('/coach/chat?skill=marker_intro');
    await settle(t, find.byKey(const Key('chat_input')));

    await t.enterText(find.byKey(const Key('chat_input')), '响片按了它没反应');
    await t.tap(find.byKey(const Key('chat_send')));
    await t.pump();
    expect(find.text('正在思考…'), findsNothing);
    await settle(t, find.byKey(const Key('answer_tutorial_marker_intro')));
    final skill = lib.skillById['marker_intro']!;
    expect(find.text(tplLabelSuccess), findsWidgets);
    expect(find.text(skill.tutorial.successCriteria), findsOneWidget);
    expect(find.text(skill.scoringHint), findsOneWidget);
    expect(ai.calls, 0);
    expect(clientCreated, isFalse, reason: 'library 模式不应创建 HTTP 客户端');

    // 存储：kind=normal，content 为纯文本快照，cited 为展示的条目
    final msgs = await t.runAsync(() => db.select(db.aiMessages).get());
    expect(msgs!.last.kind, 'normal');
    expect(msgs.last.content, contains(skill.tutorial.successCriteria));
    expect(msgs.last.citedContentIds, contains('marker_intro'));

    await tapAndSettle(t, find.byKey(const Key('answer_tutorial_marker_intro')), find.byKey(const Key('skill_ask_coach')));
    await teardownApp(t);
  });

  testWidgets('library 模式：自由提问命中问题行为 → 只出名称与"开始诊断"，点进诊断树；不出方案', (t) async {
    await seed(t);
    final ai = FakeAiClient();
    await pumpApp(t, ai, mode: AiMode.library);
    await settle(t, find.byKey(const Key('nav_coach')));
    router(t).push('/coach/chat');
    await settle(t, find.byKey(const Key('chat_input')));
    await t.enterText(find.byKey(const Key('chat_input')), '客人来就扑人');
    await t.tap(find.byKey(const Key('chat_send')));
    await settle(t, find.byKey(const Key('answer_diagnose_jumping_on_people')));
    for (final sol in lib.issueById['jumping_on_people']!.solutions) {
      expect(find.text(sol.summary), findsNothing);
      expect(find.text(sol.escalateIf), findsNothing);
    }
    await tapAndSettle(t, find.byKey(const Key('answer_diagnose_jumping_on_people')),
        find.byKey(const Key('diagnosis_question')));
    expect(ai.calls, 0);
    expect(clientCreated, isFalse);
    await teardownApp(t);
  });

  testWidgets('首页底部 Tab 与提醒设置入口；提醒页默认关闭、19:00', (t) async {
    await seed(t);
    await pumpApp(t, FakeAiClient());
    await settle(t, find.byKey(const Key('home_reminder')));
    await tapAndSettle(t, find.byKey(const Key('home_reminder')), find.byKey(const Key('reminder_switch')));
    expect(t.widget<SwitchListTile>(find.byKey(const Key('reminder_switch'))).value, isFalse);
    expect(find.text('19:00'), findsOneWidget);
    await teardownApp(t);
  });
}
