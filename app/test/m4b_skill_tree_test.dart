/// M4 批次 B · ST-3 技能树可视化：布局纯函数 + 页面四态 / 连线 / 点击进详情。
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/skill_tree_layout.dart';
import 'package:puppy_trainer/features/home/skill_detail_page.dart';

import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

Skill fake(String id, List<String> pre) {
  final base = _proto!;
  return Skill(
    id: id,
    name: id,
    category: base.category,
    minAgeWeeks: 8,
    maxAgeWeeks: 52,
    prerequisites: pre,
    difficulty: 1,
    defaultCue: '',
    defaultGesture: '',
    sessionsToMaster: 1,
    scriptParts: 1,
    tutorial: base.tutorial,
    script: const [],
    miniScript: const [],
    scoringHint: '',
    downgradeTo: null,
    sources: const [],
  );
}

Skill? _proto;

void main() {
  late ContentLibrary lib;
  setUpAll(() async {
    lib = await loadRepoContent();
    _proto = lib.skills.first;
  });

  group('布局（纯函数，结构取内容库 prerequisites）', () {
    test('内容库 18 个技能全部有位置；列 = 最长前置链；每条连线从左到右', () {
      final l = layoutSkillTree(lib.skills);
      expect(l.nodes.length, lib.skills.length);
      for (final s in lib.skills) {
        final p = l.nodes[s.id]!;
        if (s.prerequisites.isEmpty) expect(p.column, 0, reason: s.id);
        for (final pre in s.prerequisites) {
          expect(l.nodes[pre]!.column, lessThan(p.column), reason: '$pre → ${s.id}');
        }
        expect(p.x, inExclusiveRange(0, 1));
        expect(p.y, inExclusiveRange(0, 1));
      }
      final edgeCount = lib.skills.fold<int>(0, (a, s) => a + s.prerequisites.length);
      expect(l.edges.length, edgeCount);
      // 至少一个技能的列数 = 1 + 其最深前置的列数（最长链，不是最短）
      expect(l.nodes['recall_outdoor']!.column, l.nodes['stay_short']!.column + 1);
    });

    test('同列节点不重叠、行距一致', () {
      final l = layoutSkillTree(lib.skills);
      final byCol = <int, List<TreeNodePos>>{};
      for (final p in l.nodes.values) {
        byCol.putIfAbsent(p.column, () => []).add(p);
      }
      for (final col in byCol.values) {
        final ys = col.map((p) => p.y).toList()..sort();
        for (var i = 1; i < ys.length; i++) {
          expect(ys[i] - ys[i - 1], closeTo(1 / l.maxRows, 1e-9));
        }
      }
    });

    test('重心排序减少交叉：比初始顺序不更差；孤立技能排在列尾', () {
      final sorted = layoutSkillTree(lib.skills);
      final unsorted = layoutSkillTree(lib.skills, sweeps: 0);
      expect(countCrossings(sorted), lessThanOrEqualTo(countCrossings(unsorted)));
      final col0 = sorted.nodes.values.where((p) => p.column == 0).toList()..sort((a, b) => a.row.compareTo(b.row));
      final hasChildren = {for (final s in lib.skills) ...s.prerequisites};
      var seenIsolated = false;
      for (final p in col0) {
        final iso = !hasChildren.contains(p.skillId);
        if (seenIsolated) expect(iso, isTrue, reason: '${p.skillId} 排在孤立技能之后');
        if (iso) seenIsolated = true;
      }
    });

    test('不写死技能：任意合成的依赖图也能布局；环不死循环', () {
      final l = layoutSkillTree([fake('a', []), fake('b', ['a']), fake('c', ['b', 'a']), fake('d', [])]);
      expect(l.columns, 3);
      expect(l.nodes['c']!.column, 2);
      final cyc = layoutSkillTree([fake('x', ['y']), fake('y', ['x'])]);
      expect(cyc.nodes.length, 2);
    });

    test('节点短名去掉括号补充说明，取自内容库名称', () {
      expect(skillShortName('户外召回（长绳）'), '户外召回');
      expect(skillShortName('坐下'), '坐下');
      for (final s in lib.skills) {
        expect(s.name.startsWith(skillShortName(s.name)), isTrue);
      }
    });
  });

  testWidgets('技能树页：18 个节点四态着色、图例计数、点节点进技能详情；竖屏一屏内放得下', (t) async {
    final db = memoryDb();
    await t.runAsync(() async {
      await HouseholdRepository(db).ensureLocalUser();
      await OnboardingRepository(db).complete(
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
          masteredSkills: const {'marker_intro', 'name_response'},
        ),
        content: lib,
        now: DateTime(2026, 11, 16, 9),
      );
      await (db.update(db.dogSkillStatuses)..where((s) => s.skillId.equals('lure_follow')))
          .write(const DogSkillStatusesCompanion(status: Value('in_progress')));
    });
    // emulator-5554（Pixel，1080x2400 @ 2.625）竖屏的逻辑尺寸
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 16, 9)),
      reminderNotifierProvider.overrideWithValue(FakeNotifier()),
      appEffectsEnabledProvider.overrideWithValue(false),
    ], child: const PuppyTrainerApp()));
    Future<void> settle(Finder f) async {
      for (var i = 0; i < 300; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump();
        if (f.evaluate().isNotEmpty) return;
      }
      throw TestFailure('超时：$f');
    }

    await settle(find.byKey(const Key('nav_skills')));
    await t.tap(find.byKey(const Key('nav_skills')));
    // 2026-11-18 起默认是"成长路径"：先看路径分区，再切到"全图"验证原来的依赖树
    await settle(find.byKey(const Key('skill_tree_path')));
    expect(find.text('现在可以练'), findsOneWidget);
    expect(find.byKey(const Key('skill_tree_lure_follow')), findsOneWidget);
    await t.tap(find.byKey(const Key('skill_tree_view_graph')));
    await settle(find.byKey(const Key('skill_tree_canvas')));
    final canvas = t.getRect(find.byKey(const Key('skill_tree_canvas')));
    for (final s in lib.skills) {
      final f = find.byKey(Key('skill_tree_${s.id}'));
      expect(f, findsOneWidget, reason: s.id);
      final r = t.getRect(f);
      expect(canvas.contains(r.topLeft) && canvas.contains(r.bottomRight), isTrue, reason: '${s.id} 超出一屏');
      expect(r.height, greaterThanOrEqualTo(36));
    }
    expect(t.takeException(), isNull); // 无溢出
    expect(find.text('已掌握 2'), findsOneWidget);
    expect(find.text('进行中 1'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    expect(find.byIcon(Icons.lock), findsWidgets);
    await t.tap(find.byKey(const Key('skill_tree_sit')));
    await settle(find.byType(SkillDetailPage));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 200));
    await t.runAsync(() => db.close());
  });
}
