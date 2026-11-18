/// 在线模式：AI 助理训犬师（工具、业务规则、Agent 循环、确认卡片、离线兜底）。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/agent_client.dart';
import 'package:puppy_trainer/data/ai/ai_client.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/ai/coach_agent.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/ai_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/domain/ai_guard.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/ai_coach/agent_widgets.dart';

import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

final fakeNow = DateTime(2026, 11, 16, 9); // 狗 2026-09-07 出生 → 10 周

/// 按剧本回复的模型；记录每次请求。
class ScriptedAgentClient implements AgentClient {
  ScriptedAgentClient(this.script, {this.fail = false});
  final List<AgentTurn> script;
  final bool fail;
  final requests = <List<Map<String, dynamic>>>[];
  int _i = 0;

  @override
  Future<AgentTurn> turn({
    required String system,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    if (fail) throw AiClientException('boom');
    requests.add([for (final m in messages) Map<String, dynamic>.from(m)]);
    final t = script[_i < script.length ? _i : script.length - 1];
    _i++;
    return t;
  }
}

AgentTurn toolTurn(List<(String, Map<String, dynamic>)> calls, {String text = ''}) => AgentTurn(
      stopReason: 'tool_use',
      content: [
        if (text.isNotEmpty) {'type': 'text', 'text': text},
        for (final (i, c) in calls.indexed) {'type': 'tool_use', 'id': 't${c.$1}_$i', 'name': c.$1, 'input': c.$2},
      ],
    );

AgentTurn answerTurn(String text) => AgentTurn(stopReason: 'end_turn', content: [
      {'type': 'thinking', 'thinking': '', 'signature': 'sig'}, // 不认识的块原样带回，不影响解析
      {'type': 'text', 'text': text},
    ]);

Future<({AppDatabase db, String dogId})> seedDb(ContentLibrary lib) async {
  final db = memoryDb();
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
  return (db: db, dogId: r.dogId);
}

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  group('工具与业务规则', () {
    late AppDatabase db;
    late String dogId;
    late AgentToolbox box;
    setUp(() async {
      final s = await seedDb(lib);
      db = s.db;
      dogId = s.dogId;
      box = AgentToolbox(db: db, library: lib, dogId: dogId, clock: () => fakeNow);
    });
    tearDown(() => db.close());

    test('狗档案、本周计划、训练记录', () async {
      final p = jsonDecode(await box.run('get_dog_profile', {})) as Map;
      expect(p['name'], '豆豆');
      expect(p['age_weeks'], 10);
      final plan = jsonDecode(await box.run('get_week_plan', {})) as Map;
      expect((plan['goals'] as List), isNotEmpty);

      final goal = (plan['goals'] as List).first as Map;
      final user = await (db.select(db.users)).getSingle();
      for (var i = 0; i < 2; i++) {
        await SessionRepository(db).save(
          draft: SessionDraft(
            dogId: dogId,
            userId: user.id,
            skillId: goal['skill_id'] as String,
            scriptPart: 1,
            startedAt: fakeNow.subtract(Duration(hours: 3 - i)),
            endedAt: fakeNow.subtract(Duration(hours: 3 - i, minutes: -3)),
            durationSec: 180,
            clickerCount: 4,
            skippedSteps: const [],
          ),
          score: Score.none,
          noteText: '',
          videoPath: null,
          now: fakeNow.subtract(Duration(hours: 2 - i)),
        );
      }
      final h = jsonDecode(await box.run('get_training_history', {'skill_id': goal['skill_id']})) as Map;
      final sessions = h['sessions'] as List;
      expect(sessions, hasLength(2));
      expect((sessions.first as Map)['score'], '没做到');
    });

    test('能不能练：周龄未到 / 前置未掌握都写明原因', () async {
      final r = jsonDecode(await box.run('check_skill_eligibility', {'skill_id': 'recall_outdoor'})) as Map;
      expect(r['can_train_now'], isFalse);
      expect((r['reasons'] as List).join(), anyOf(contains('周龄未到'), contains('前置技能未掌握')));
    });

    test('提议加入计划：可练的生成卡片；已在计划的拒绝；前置没掌握自动改为前置', () async {
      final plan = jsonDecode(await box.run('get_week_plan', {})) as Map;
      final inPlan = [for (final g in plan['goals'] as List) (g as Map)['skill_id'] as String];

      final dup = jsonDecode(await box.run('propose_plan_change', {'skill_id': inPlan.first, 'reason': 'x'})) as Map;
      expect(dup['ok'], isFalse);
      expect((dup['reasons'] as List).join(), contains('已在本周计划'));
      expect(box.actions, isEmpty);

      // 找一个规则允许、但不在计划里的技能
      String? free;
      for (final s in lib.skills) {
        if (inPlan.contains(s.id)) continue;
        final e = jsonDecode(await box.run('check_skill_eligibility', {'skill_id': s.id})) as Map;
        if (e['can_train_now'] == true) {
          free = s.id;
          break;
        }
      }
      expect(free, isNotNull);
      final ok = jsonDecode(await box.run('propose_plan_change', {'skill_id': free, 'reason': '打基础'})) as Map;
      expect(ok['ok'], isTrue);
      expect(box.actions.single.type, AgentActionType.addToPlan);
      expect(box.actions.single.skillIds, [free]);
      // 只是卡片：计划没有变
      final after = jsonDecode(await box.run('get_week_plan', {})) as Map;
      expect((after['goals'] as List).length, inPlan.length);
    });

    test('确认卡片时按同一规则再校验后写入', () async {
      final plan = jsonDecode(await box.run('get_week_plan', {})) as Map;
      final inPlan = [for (final g in plan['goals'] as List) (g as Map)['skill_id'] as String];
      final repo = AiRepository(db, clock: () => fakeNow);
      final r1 = await repo.addSkillsToThisWeek(dogId: dogId, skillIds: [inPlan.first], content: lib);
      expect(r1.added, isEmpty); // 已在计划
      final active = await PlanRepository(db).activePlan(dogId);
      final before = (await PlanRepository(db).goals(active!.id)).length;
      String? free;
      for (final s in lib.skills) {
        if (inPlan.contains(s.id)) continue;
        final e = jsonDecode(await box.run('check_skill_eligibility', {'skill_id': s.id})) as Map;
        if (e['can_train_now'] == true) {
          free = s.id;
          break;
        }
      }
      final r2 = await repo.addSkillsToThisWeek(dogId: dogId, skillIds: [free!], content: lib);
      expect(r2.added.single.skillId, free);
      expect((await PlanRepository(db).goals(active.id)).length, before + 1);
    });

    test('检索内容库：返回资料原文并记为出处；没找到时说明', () async {
      final r = await box.run('search_library', {'query': '坐下练了三天还是不坐'});
      expect(r, contains('<material id="sit"'));
      expect(box.materialIds, contains('sit'));
      final none = jsonDecode(await box.run('search_library', {'query': '怎么教狗握手'})) as Map;
      expect(none['found'], isFalse);
    });

    test('参数错误抛出（Agent 会把它作为 is_error 的工具结果交回模型）', () async {
      expect(() => box.run('propose_plan_change', {'skill_id': 'no_such', 'reason': ''}), throwsArgumentError);
      expect(() => box.run('rm_rf', {}), throwsArgumentError);
    });
  });

  group('Agent 循环', () {
    late AppDatabase db;
    late String dogId;
    setUp(() async {
      final s = await seedDb(lib);
      db = s.db;
      dogId = s.dogId;
    });
    tearDown(() => db.close());

    CoachAgent agentWith(AgentClient c) => CoachAgent(
          library: lib,
          client: c,
          toolbox: AgentToolbox(db: db, library: lib, dogId: dogId, clock: () => fakeNow),
        );

    test('查档案与内容库 → 提议加入计划 → 回答：过程、卡片、出处都保留', () async {
      final c = ScriptedAgentClient([
        toolTurn([('get_dog_profile', {}), ('search_library', {'query': '坐下学不会'})], text: '我先看看'),
        toolTurn([('check_skill_eligibility', {'skill_id': 'lure_follow'})]),
        answerTurn('豆豆 10 周，先把跟随零食练熟 [ref: sit]。'),
      ]);
      final events = await agentWith(c).ask(question: '坐下老学不会，要不要凶它').toList();
      final steps = [for (final e in events) if (e is AgentStep) e.label];
      expect(steps, ['查看狗狗档案', '检索训练内容库', '按规则检查能不能练']);
      final done = events.last as AgentDone;
      final parts = AgentMessageParts.parse(done.answer.text);
      expect(parts.text, '豆豆 10 周，先把跟随零食练熟。');
      expect(parts.trace, ['查看狗狗档案', '检索训练内容库', '按规则检查能不能练']);
      expect(done.answer.cited, ['sit']);
      expect(done.answer.kind, AiMessageKind.normal);
      // 第二轮请求带上了第一轮的 assistant 块与工具结果
      final second = c.requests[1];
      expect(second[second.length - 2]['role'], 'assistant');
      final results = second.last['content'] as List;
      expect([for (final r in results) (r as Map)['type']], ['tool_result', 'tool_result']);
    });

    test('健康问题：固定话术，不调用模型', () async {
      final c = ScriptedAgentClient([answerTurn('不应调用')]);
      final events = await agentWith(c).ask(question: '它吐了两次还要练吗').toList();
      final done = events.single as AgentDone;
      expect(done.answer.kind, AiMessageKind.guardHealth);
      expect(done.answer.text, healthGuardReply);
      expect(c.requests, isEmpty);
    });

    test('工具出错时把错误交回模型，由模型调整', () async {
      final c = ScriptedAgentClient([
        toolTurn([('propose_plan_change', {'skill_id': 'no_such', 'reason': 'x'})]),
        answerTurn('好的'),
      ]);
      await agentWith(c).ask(question: '加个技能').toList();
      final result = (c.requests[1].last['content'] as List).single as Map;
      expect(result['is_error'], isTrue);
    });

    test('最多 6 轮工具调用，不会无限循环', () async {
      final c = ScriptedAgentClient([toolTurn([('get_week_plan', {})])]);
      final events = await agentWith(c).ask(question: '看看计划').toList();
      expect(c.requests.length, agentMaxRounds);
      expect(events.last, isA<AgentDone>());
    });

    test('卡片与过程编码在正文里，可以完整解析回来', () {
      const parts = AgentMessageParts('先练基础\n第二行', ['查看狗狗档案'], [
        AgentAction(AgentActionType.addToPlan, skillIds: ['lure_follow', 'sit'], note: '打基础'),
        AgentAction(AgentActionType.referVet, note: '拉肚子'),
      ]);
      final back = AgentMessageParts.parse(parts.encode());
      expect(back.text, '先练基础\n第二行');
      expect(back.trace, ['查看狗狗档案']);
      expect(back.actions.first.skillIds, ['lure_follow', 'sit']);
      expect(back.actions.first.note, '打基础');
      expect(back.actions.last.type, AgentActionType.referVet);
      expect(AgentMessageParts.parse('普通回答').isAgent, isFalse);
    });
  });

  group('对话页', () {
    late AppDatabase db;
    late String dogId;

    Future<void> pumpApp(WidgetTester t, AgentClient agent, {bool online = true}) async {
      await t.runAsync(() async {
        final s = await seedDb(lib);
        db = s.db;
        dogId = s.dogId;
      });
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
          clockProvider.overrideWithValue(() => fakeNow),
          aiModeProvider.overrideWithValue(AiMode.library),
          aiOnlineProvider.overrideWith((ref) => AiOnlineController(initial: online)),
          agentClientProvider.overrideWithValue(agent),
          reminderNotifierProvider.overrideWithValue(FakeNotifier()),
          appEffectsEnabledProvider.overrideWithValue(false),
        ],
        child: const PuppyTrainerApp(),
      ));
    }

    GoRouter router(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp))).read(routerProvider);

    Future<void> settle(WidgetTester t, Finder f) async {
      for (var i = 0; i < 400; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await t.pump();
        if (f.evaluate().isNotEmpty) return;
      }
      throw TestFailure('超时：$f');
    }

    Future<void> teardown(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.runAsync(() => db.close());
    }

    Future<void> ask(WidgetTester t, String q) async {
      await settle(t, find.byKey(const Key('nav_coach'))); // 首页加载完再进对话页
      router(t).push('/coach/chat');
      await settle(t, find.byKey(const Key('chat_input')));
      await t.enterText(find.byKey(const Key('chat_input')), q);
      await t.tap(find.byKey(const Key('chat_send')));
    }

    testWidgets('在线：显示查看过的信息与确认卡片，点确认后计划里出现该技能', (t) async {
      final agent = ScriptedAgentClient([
        toolTurn([('get_dog_profile', {}), ('get_training_history', {})]),
        toolTurn([('propose_plan_change', {'skill_id': 'handling_body', 'reason': '为剪指甲打基础'})]),
        answerTurn('可以先练全身触摸脱敏，点下面的卡片确认后就会加入本周计划。'),
      ]);
      await pumpApp(t, agent);
      await ask(t, '剪指甲它就躲');
      await settle(t, find.byKey(const Key('agent_trace')));
      expect(find.text('查看狗狗档案'), findsOneWidget);
      expect(find.byKey(const Key('ai_mode_toggle')), findsOneWidget);

      final confirm = find.byKey(const Key('agent_action_confirm'));
      await settle(t, confirm);
      // 规则允许时才可点
      for (var i = 0; i < 50 && t.widget<FilledButton>(confirm).onPressed == null; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await t.pump();
      }
      await t.tap(confirm);
      await settle(t, find.byKey(const Key('agent_action_done')));
      final goals = await t.runAsync(() async {
        final plan = await PlanRepository(db).activePlan(dogId);
        return [for (final g in await PlanRepository(db).goals(plan!.id)) g.skillId];
      });
      expect(goals, contains('handling_body'));
      await teardown(t);
    });

    testWidgets('在线服务连不上：自动改用离线模式回答并提示', (t) async {
      await pumpApp(t, ScriptedAgentClient(const [], fail: true));
      await ask(t, '坐下练了三天狗还是不坐怎么办');
      await settle(t, find.byKey(const Key('chat_fell_back')));
      expect(find.text(AgentStrings.fellBack), findsOneWidget);
      // 离线直出的回答（内容库原文）照常出现
      await settle(t, find.text('坐下'));
      await teardown(t);
    });
  });
}
