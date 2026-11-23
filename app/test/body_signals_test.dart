/// 狗的状态（身体信号，内容库 v1.6）：规则判定、存储、练前检查页面、视频结果、实时快照、AI 助理工具。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/coach_agent.dart';
import 'package:puppy_trainer/data/body/body_api.dart';
import 'package:puppy_trainer/data/repositories/body_repository.dart';
import 'package:puppy_trainer/data/repositories/video_repository.dart';
import 'package:puppy_trainer/data/video/live_client.dart';
import 'package:puppy_trainer/domain/body_signals.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/video_checks.dart';
import 'package:puppy_trainer/features/body/body_check_page.dart';
import 'package:puppy_trainer/features/body/body_strings.dart';
import 'package:puppy_trainer/features/video/video_check_page.dart';

import 'helpers.dart';

BodySummary summary(Map<String, int> counts, {int usable = 40, double? motion, String kind = 'video'}) => BodySummary(
      usable: usable,
      motionMean: motion,
      kind: kind,
      signals: [
        for (final e in counts.entries)
          for (var i = 0; i < e.value; i++) (id: e.key, start: i * 5.0, end: i * 5.0 + 1),
      ],
    );

class FakeBodyApi implements BodyCheckApi {
  FakeBodyApi(this.result);
  BodySummary result;
  int calls = 0;
  @override
  Future<BodySummary> check(String filePath) async {
    calls++;
    return result;
  }
}

class FakePicker implements BodyMediaPicker {
  @override
  Future<String?> pick(BodyMediaSource source) async => '/tmp/fake.mp4';
}

void main() {
  late ContentLibrary lib;
  late BodySignalsConfig cfg;
  setUpAll(() async {
    lib = await loadRepoContent();
    cfg = lib.bodySignals!;
  });

  group('内容库 v1.6 body_signals.yaml', () {
    test('解析：9 种信号、规则引用存在、兴奋时推荐的技能存在', () {
      expect(lib.version, 'v1.6');
      expect(cfg.signals.length, 9);
      expect(lib.skillById[cfg.calmDownSkill], isNotNull);
      for (final id in [...cfg.stopCountOf, ...cfg.referralSignals]) {
        expect(cfg.signals.containsKey(id), isTrue);
      }
      expect(cfg.sources, isNotEmpty);
    });

    test('数据库缓存读回与解析一致', () async {
      final db = memoryDb();
      await loadRepoContent(db: db);
      final again = await loadRepoContent(db: db);
      expect(again.bodySignals!.signals.keys, cfg.signals.keys);
      expect(again.bodySignals!.stopAdvice, cfg.stopAdvice);
      await db.close();
    });
  });

  group('判定', () {
    test('看不清 / 有压力信号 / 兴奋 / 平静', () {
      expect(assessBody(summary({}, usable: 3), cfg).state, BodyState.unclear);
      expect(assessBody(summary({'tail_tucked': 1, 'yawn': 1}), cfg).state, BodyState.stressed);
      expect(assessBody(summary({'tail_tucked': 1}), cfg).state, BodyState.calm);
      final frozen = assessBody(summary({'freeze': 1}), cfg);
      expect(frozen.state, BodyState.stressed);
      expect(frozen.referral, isTrue);
      expect(assessBody(summary({'tail_wag': 1, 'high_motion': 1}), cfg).state, BodyState.excited);
      expect(assessBody(summary({}, motion: 1.2), cfg).state, BodyState.excited);
      expect(assessBody(summary({'tail_wag': 1}), cfg).state, BodyState.calm);
      // 照片只有一帧也能判断
      expect(assessBody(summary({}, usable: 1, kind: 'image'), cfg).state, BodyState.calm);
    });

    test('该停了：窗口内压力信号次数达到门槛', () {
      expect(shouldStop({'yawn': 2, 'body_low': 1}, cfg), isTrue);
      expect(shouldStop({'yawn': 2, 'tail_wag': 5}, cfg), isFalse);
      final w = worstStopWindow(summary({'yawn': 3}), cfg); // 0、5、10 秒
      expect(w.count, 3);
      expect(w.start, 0);
    });

    test('节奏建议：最近几次里至少两次同一状态', () {
      expect(pacingState([BodyState.stressed, BodyState.calm, BodyState.stressed], cfg), BodyState.stressed);
      expect(pacingState([BodyState.excited, BodyState.unclear, BodyState.excited], cfg), BodyState.excited);
      expect(pacingState([BodyState.calm, BodyState.stressed, BodyState.excited], cfg), isNull);
    });
  });

  test('存储：状态记录不会出现在视频纠错记录里', () async {
    final db = memoryDb();
    final body = BodyRepository(db);
    final video = VideoRepository(db);
    final now = DateTime.utc(2026, 11, 23, 10);
    final s = summary({'yawn': 1, 'body_low': 1});
    await body.save(
        dogId: 'd', assessment: assessBody(s, cfg), summary: s, context: BodyContext.preTraining,
        contentVersion: 'v', now: now, skillId: 'sit');
    final recs = await body.recent('d');
    expect(recs.single.state, BodyState.stressed);
    expect(recs.single.summary.count('yawn'), 1);
    expect(recs.single.skillId, 'sit');
    expect(await video.watchRecent('d', 'sit').first, isEmpty);
    expect(await video.attempts('d', 'sit'), isEmpty);
    expect((await body.between('d', now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1)))).length, 1);
    await db.close();
  });

  test('实时快照：解析最近的信号次数', () {
    final s = LiveSnapshot.fromJson({
      't': 3.0, 'mic_level_db': -40, 'trials': [], 'late_sec': 1.0,
      'body': {'counts': {'yawn': 2, 'tail_tucked': 1}, 'window': 30, 'usable': 50},
    });
    expect(s.bodyCounts, {'yawn': 2, 'tail_tucked': 1});
    expect(shouldStop(s.bodyCounts, cfg), isTrue);
  });

  test('AI 助理工具 get_dog_state：返回状态、信号含义原文和节奏建议', () async {
    final db = memoryDb();
    final content = await loadRepoContent(db: db);
    final repo = BodyRepository(db);
    for (var i = 0; i < 2; i++) {
      final s = summary({'tail_tucked': 1, 'yawn': 1});
      await repo.save(
          dogId: 'd', assessment: assessBody(s, cfg), summary: s, context: BodyContext.preTraining,
          contentVersion: 'v', now: DateTime.utc(2026, 11, 20 + i));
    }
    final box = AgentToolbox(db: db, library: content, dogId: 'd');
    final r = jsonDecode(await box.run('get_dog_state', {})) as Map;
    expect((r['checks'] as List).length, 2);
    expect((r['checks'] as List).first['state'], '有压力信号');
    expect(r['pacing_advice'], cfg.pacingAdvice[BodyState.stressed]);
    expect(agentTools.map((t) => t['name']), contains('get_dog_state'));
    await db.close();
  }, skip: false);

  group('页面', () {
    List<String> texts(WidgetTester t) => [
          for (final w in t.widgetList<Text>(find.byType(Text)))
            if ((w.data ?? '').trim().isNotEmpty) w.data!,
        ];

    Future<FakeBodyApi> pumpCheck(WidgetTester t, BodySummary result, {String skillId = 'sit'}) async {
      final api = FakeBodyApi(result);
      final db = memoryDb();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contentLibraryProvider.overrideWith((ref) async => lib),
          bodyCheckApiProvider.overrideWithValue(api),
          bodyMediaPickerProvider.overrideWithValue(FakePicker()),
          currentDogProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(home: BodyCheckPage(skillId: skillId)),
      ));
      await t.pumpAndSettle();
      return api;
    }

    testWidgets('兴奋：显示内容库建议原文与"先做安静趴垫"', (t) async {
      final api = await pumpCheck(t, summary({'tail_wag': 1, 'high_motion': 2}));
      await t.tap(find.byKey(const Key('body_record')));
      await t.pumpAndSettle();
      expect(api.calls, 1);
      expect(find.text(BodyStrings.stateName(BodyState.excited)), findsOneWidget);
      expect(find.text(cfg.advice[BodyState.excited]!), findsOneWidget);
      expect(find.byKey(const Key('body_do_calm')), findsOneWidget);
      expect(find.text(BodyStrings.doFirst(lib.skillById[cfg.calmDownSkill]!.name)), findsOneWidget);
      // 原文性：每段文字要么是内容库原文，要么是模板
      final allowed = {
        ...cfg.advice.values, ...cfg.sources, cfg.referralAdvice,
        for (final s in cfg.signals.values) ...[s.name, s.meaning],
        for (final s in cfg.signals.values)
          for (var n = 1; n < 5; n++) BodyStrings.signalCount(s.name, n),
        BodyStrings.pageTitle, BodyStrings.observed, BodyStrings.disclaimer, BodyStrings.retry, BodyStrings.sources,
        BodyStrings.doFirst(lib.skillById[cfg.calmDownSkill]!.name),
        for (final s in BodyState.values) BodyStrings.stateName(s),
      };
      for (final s in texts(t)) {
        expect(allowed.contains(s), isTrue, reason: '「$s」');
      }
    });

    testWidgets('有压力信号 + 僵住：显示转介卡片与降级技能入口', (t) async {
      await pumpCheck(t, summary({'freeze': 1, 'tail_tucked': 1}), skillId: 'down');
      await t.tap(find.byKey(const Key('body_record')));
      await t.pumpAndSettle();
      expect(find.text(BodyStrings.stateName(BodyState.stressed)), findsOneWidget);
      expect(find.byKey(const Key('body_referral')), findsOneWidget);
      expect(find.text(cfg.referralAdvice), findsOneWidget);
      expect(find.byKey(const Key('body_do_downgrade')), findsOneWidget);
    });

    testWidgets('视频结果：显示"狗的状态"与"该停一停"', (t) async {
      final skill = lib.skillById['sit']!;
      const j = VideoJudgement(
          status: VideoStatus.ok, metrics: VideoMetrics(totalTrials: 3, reliableTrials: 3), findings: []);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VideoResultView(
            skill: skill,
            judgement: j,
            config: lib.videoChecks!,
            body: summary({'yawn': 2, 'body_low': 2}),
            bodyConfig: cfg,
          ),
        ),
      ));
      expect(find.byKey(const Key('video_body')), findsOneWidget);
      expect(find.byKey(const Key('body_stop')), findsOneWidget);
      expect(find.text(cfg.stopAdvice), findsOneWidget);
    });
  });
}
