/// M4 批次 B 界面：M3-D6"不是这个问题？"、常见错误折叠、RC-5 两种视图。
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/diagnosis.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

void main() {
  late ContentLibrary lib;
  late AppDatabase db;
  late String dogId;
  final fakeNow = DateTime(2026, 11, 17, 9);
  setUpAll(() async => lib = await loadRepoContent());

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
      dogId = r.dogId;
    });
  }

  Future<void> pumpApp(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
      clockProvider.overrideWithValue(() => fakeNow),
      reminderNotifierProvider.overrideWithValue(FakeNotifier()),
      appEffectsEnabledProvider.overrideWithValue(false),
    ], child: const PuppyTrainerApp()));
  }

  GoRouter router(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp))).read(routerProvider);

  Future<void> settle(WidgetTester t, Finder f) async {
    for (var i = 0; i < 400; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
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

  testWidgets('M3-D6：诊断结果页顶部"不是这个问题？"返回问题列表', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_coach')));
    final issue = lib.issueById['jumping_on_people']!;
    final path = allDiagnosisPaths(issue).first;
    router(t).go('/coach/diagnosis?issue=${issue.id}');
    for (final i in path) {
      await settle(t, find.byKey(Key('diagnosis_option_$i')));
      await t.tap(find.byKey(Key('diagnosis_option_$i')));
      await t.pump();
    }
    await settle(t, find.byKey(const Key('diagnosis_not_this')));
    // 在结果页顶部（第一屏可见、位于方案标题之上）
    final top = t.getTopLeft(find.byKey(const Key('diagnosis_not_this'))).dy;
    expect(top, lessThan(t.getTopLeft(find.byKey(const Key('diagnosis_escalate'))).dy));
    expect(find.text('不是这个问题？'), findsOneWidget);
    await t.tap(find.byKey(const Key('diagnosis_not_this')));
    await settle(t, find.byKey(Key('issue_${lib.issues.first.id}')));
    expect(find.byKey(const Key('diagnosis_result')), findsNothing);
    await teardown(t);
  });

  testWidgets('AI 直出回答：【常见错误】默认折叠，标题显示条数，展开为内容库原文', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_coach')));
    final sit = lib.skillById['sit']!;
    router(t).push('/coach/chat?skill=sit');
    await settle(t, find.byKey(const Key('chat_input')));
    await t.enterText(find.byKey(const Key('chat_input')), '坐下总是做不好');
    await t.tap(find.byKey(const Key('chat_send')));
    await settle(t, find.byKey(const Key('answer_mistakes_fold')));
    expect(find.text('【常见错误】（${sit.tutorial.commonMistakes.length} 条）'), findsOneWidget);
    // 默认折叠：原文不在界面上
    expect(find.text(sit.tutorial.commonMistakes.first), findsNothing);
    await t.ensureVisible(find.byKey(const Key('answer_mistakes_fold')));
    await t.tap(find.text('【常见错误】（${sit.tutorial.commonMistakes.length} 条）'));
    await t.pumpAndSettle();
    for (final m in sit.tutorial.commonMistakes) {
      expect(find.text(m), findsOneWidget, reason: m);
    }
    // 入库快照不变（仍包含全部常见错误原文）
    final msgs = await t.runAsync(() => db.select(db.aiMessages).get());
    final answer = msgs!.lastWhere((m) => m.role == 'assistant').content;
    for (final m in sit.tutorial.commonMistakes) {
      expect(answer, contains(m));
    }
    await teardown(t);
  });

  testWidgets('RC-5：训练记录按日期 / 按技能两种视图', (t) async {
    await seed(t);
    await t.runAsync(() async {
      for (final (id, skill, at, score) in [
        ('s1', 'marker_intro', '2026-11-15T02:00:00.000Z', 'full'),
        ('s2', 'name_response', '2026-11-16T02:00:00.000Z', 'partial'),
        ('s3', 'marker_intro', '2026-11-16T03:00:00.000Z', 'full'),
        ('s4', 'marker_intro', '2026-11-17T00:30:00.000Z', 'none'),
      ]) {
        await db.into(db.trainingSessions).insert(TrainingSessionsCompanion.insert(
              id: id, dogId: dogId, userId: 'local_user', skillId: skill, scriptPart: 1,
              startedAt: at, endedAt: at, durationSec: 60, score: score, noteVideoUrl: const Value(null)));
      }
    });
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_records')));
    router(t).go('/records');
    await settle(t, find.byKey(const Key('sessions_view')));
    // 按日期（默认）：3 个日期组，最近的在最上
    expect(find.text('11月17日 · 1 次'), findsOneWidget);
    expect(find.text('11月16日 · 2 次'), findsOneWidget);
    expect(find.text('11月15日 · 1 次'), findsOneWidget);
    expect(t.getTopLeft(find.text('11月17日 · 1 次')).dy, lessThan(t.getTopLeft(find.text('11月15日 · 1 次')).dy));
    // 按技能
    await t.tap(find.text('按技能'));
    await t.pumpAndSettle();
    final marker = lib.skillById['marker_intro']!.name;
    final name = lib.skillById['name_response']!.name;
    expect(find.text('$marker · 3 次（完全做到 2 次）'), findsOneWidget);
    expect(find.text('$name · 1 次（完全做到 0 次）'), findsOneWidget);
    // 组内按时间倒序：s4 在 s1 上方
    expect(t.getTopLeft(find.byKey(const Key('session_s4'))).dy, lessThan(t.getTopLeft(find.byKey(const Key('session_s1'))).dy));
    // 最近练过的技能排前
    expect(t.getTopLeft(find.byKey(const Key('sessions_skill_marker_intro'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('sessions_skill_name_response'))).dy));
    await teardown(t);
  });
}
