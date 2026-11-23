/// 视频纠错 v3：多次上传直到改正。
///
/// - 纯函数：和上次比（已改正 / 还要改 / 新发现）、已改正 X / Y、通过；重拍不算一次检查。
/// - 存储：attempts 只取已判定记录、按时间升序。
/// - 页面：第 N 次检查卡片、问题卡片上的"上次也有 / 新出现"、通过状态；原文性不变。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/data/repositories/video_repository.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/video_checks.dart';
import 'package:puppy_trainer/domain/video_progress.dart';
import 'package:puppy_trainer/features/video/video_check_page.dart';
import 'package:puppy_trainer/features/video/video_strings.dart';

import 'helpers.dart';

/// 每个检测器一份能被证据句式渲染的样例证据。
const _evidence = <String, Map<String, Object?>>{
  'late_reward': {'sit_start': 1.0, 'reward_t': 4.0, 'delay': 3.0, 'late': 2, 'rewarded': 3, 'threshold_sec': 1.0},
  'repeated_cue': {'cue_times': [0.0, 2.0], 'count': 2, 'repeated': 2, 'trials': 3},
  'session_too_long': {'trials': 12, 'max_trials': 10},
  'target_too_long': {'reached': 0, 'trials': 3, 'target': 3.0},
  'reward_after_standup': {'sit_end': 5.0, 'reward_t': 6.0, 'after': 2, 'rewarded': 3},
  'self_release': {'self': 2, 'trials': 3},
  'no_hold_marker': {'hold': 12.0, 'markers': 0, 'silent': 2, 'long': 2},
  'verbal_correction': {'hits': []},
  'reward_after_release': {'sit_end': 5.0, 'reward_t': 6.0, 'after': 2, 'rewarded': 3},
};

VideoFinding f(String d, int m) => VideoFinding(detector: d, mistake: m, evidence: _evidence[d] ?? const {});

VideoJudgement ok(List<VideoFinding> fs) => VideoJudgement(
    status: VideoStatus.ok,
    metrics: const VideoMetrics(totalTrials: 3, reliableTrials: 3),
    findings: fs);

const retake = VideoJudgement(
    status: VideoStatus.retake,
    metrics: VideoMetrics(totalTrials: 1, reliableTrials: 0),
    findings: [],
    retakeReasons: [RetakeReason.tooFewReliable]);

VideoAttempt at(int minute, VideoJudgement j, [String? id]) =>
    VideoAttempt(id: id, at: DateTime.utc(2026, 11, 23, 10, minute), judgement: j);

void main() {
  group('和上次比', () {
    final attempts = [
      at(0, ok([f('late_reward', 0), f('repeated_cue', 1)])),
      at(5, ok([f('repeated_cue', 1), f('self_release', 2)])),
      at(9, ok(const [])),
    ];

    test('第一次：全部是新发现，没有上次', () {
      final p = progressAt(attempts, 0);
      expect(p.attemptNo, 1);
      expect(p.isFirst, isTrue);
      expect(p.fresh.map((x) => x.detector), ['late_reward', 'repeated_cue']);
      expect(p.fixed, isEmpty);
      expect(p.still, isEmpty);
      expect(p.passed, isFalse);
      expect(p.fixedTotal, 0);
    });

    test('第二次：改正 1 个、还有 1 个、新出现 1 个', () {
      final p = progressAt(attempts, 1);
      expect(p.attemptNo, 2);
      expect(p.fixed.map((x) => x.detector), ['late_reward']);
      expect(p.still.map((x) => x.detector), ['repeated_cue']);
      expect(p.fresh.map((x) => x.detector), ['self_release']);
      expect(p.everFound, {'late_reward', 'repeated_cue', 'self_release'});
      expect(p.fixedTotal, 1);
    });

    test('第三次：全部改正，通过', () {
      final p = latestProgress(attempts)!;
      expect(p.attemptNo, 3);
      expect(p.passed, isTrue);
      expect(p.fixed.map((x) => x.detector), ['repeated_cue', 'self_release']);
      expect(p.fixedTotal, 3);
      expect(p.everFound.length, 3);
    });

    test('重拍不算一次检查，顺序乱也按时间排', () {
      final all = judgedAttempts([attempts[2], at(3, retake), attempts[0], attempts[1]]);
      expect(all.length, 3);
      expect(progressAt(all, 1).attemptNo, 2);
      expect(latestProgress(const []), isNull);
    });
  });

  test('存储：attempts 只取已判定、按时间升序', () async {
    final db = memoryDb();
    final repo = VideoRepository(db);
    final now = DateTime.utc(2026, 11, 23, 10);
    final a = await repo.save(
        dogId: 'd', skillId: 'sit', judgement: ok([f('late_reward', 0)]), contentVersion: 'v', now: now);
    await repo.save(
        dogId: 'd',
        skillId: 'sit',
        judgement: retake,
        contentVersion: 'v',
        now: now.add(const Duration(minutes: 1)));
    final c = await repo.save(
        dogId: 'd', skillId: 'sit', judgement: ok(const []), contentVersion: 'v', now: now.add(const Duration(minutes: 2)));
    await repo.save(
        dogId: 'd', skillId: 'down', judgement: ok(const []), contentVersion: 'v', now: now.add(const Duration(minutes: 3)));
    final list = await repo.attempts('d', 'sit');
    expect(list.map((x) => x.id), [a, c]);
    expect(latestProgress(list)!.passed, isTrue);
    expect(latestProgress(list)!.fixed.single.detector, 'late_reward');
    await db.close();
  });

  test('slow_response：口令后超过 3 秒才做到的轮次过半才命中，证据是最慢一轮', () async {
    final lib = await loadRepoContent();
    final cfg = lib.videoChecks!;
    Map<String, Object?> t(double cue, double sit) => {
          'cue_t': cue, 'sit_start': sit, 'sit_end': sit + 4, 'ended_by': 'release', 'reward_t': sit + 0.3,
          'latency': sit - cue, 'hold': 4.0, 'conf': 0.9, 'cue_times': [cue], 'reliable': true,
        };
    VideoJudgement judge(List<Map<String, Object?>> ts) => judgeVideo(
        result: {'trials': ts, 'quality': {'unclear_ratio': 0.0, 'audio_ok': true}},
        skillChecks: const [VideoCheckMapping(detector: 'slow_response', mistake: 4)],
        config: cfg);
    final hit = judge([t(0, 5), t(20, 26.5), t(40, 41)]);
    expect(hit.findings.single.evidence['latency'], 6.5);
    expect(VideoStrings.evidence(hit.findings.single, target: VideoTarget.down),
        '第 20 秒说口令，第 26.5 秒才趴下，用了 6.5 秒（3 轮里 2 轮超过 3 秒）');
    expect(judge([t(0, 5), t(20, 21), t(40, 41)]).findings, isEmpty);
  });

  test('召回（arrive）：证据与提示按"跑到你面前"代入，并属于模板集合', () {
    const f = VideoFinding(detector: 'repeated_cue', mistake: 0, evidence: {
      'cue_times': [0.5, 2.0, 3.5], 'count': 3, 'repeated': 2, 'trials': 3,
    });
    final text = VideoStrings.evidence(f, target: VideoTarget.arrive);
    expect(text, '第 0.5 秒、第 2 秒、第 3.5 秒各识别到一次口令，共 3 次后狗才跑到你面前（3 轮里 2 轮口令重复）');
    expect(VideoStrings.isTemplate(text), isTrue);
    expect(VideoStrings.isTemplate(VideoStrings.sitCandidate(3, 4.5, target: VideoTarget.arrive)), isTrue);
    expect(VideoStrings.retakeFor(RetakeReason.cueNotHeard, target: VideoTarget.arrive),
        VideoStrings.retakeCueNotHeardArrive);
  });

  group('结果页', () {
    late ContentLibrary lib;
    late Skill skill;
    setUpAll(() async {
      lib = await loadRepoContent();
      skill = lib.skillById['stay_short']!;
    });

    List<String> texts(WidgetTester t) => [
          for (final w in t.widgetList<Text>(find.byType(Text)))
            if ((w.data ?? '').trim().isNotEmpty) w.data!,
        ];

    Future<void> show(WidgetTester t, VideoJudgement j, AttemptProgress p) => t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VideoResultView(
                skill: skill, judgement: j, config: lib.videoChecks!, progress: p, onReupload: () {}))));

    testWidgets('第二次检查：已改正 / 还要改 / 新发现 + 问题标签；全是模板或内容库原文', (t) async {
      final checks = skill.videoChecks;
      expect(checks.length, greaterThanOrEqualTo(3));
      final c0 = checks[0], c1 = checks[1], c2 = checks[2];
      final list = [
        at(0, ok([f(c0.detector, c0.mistake), f(c1.detector, c1.mistake)])),
        at(5, ok([f(c1.detector, c1.mistake), f(c2.detector, c2.mistake)])),
      ];
      await show(t, list[1].judgement, progressAt(list, 1));
      expect(find.text(VideoStrings.attemptTitle(2)), findsOneWidget);
      expect(find.text(VideoStrings.fixedProgress(1, 3)), findsOneWidget);
      expect(find.byKey(Key('video_fixed_${c0.detector}')), findsOneWidget);
      expect(find.byKey(Key('video_still_${c1.detector}')), findsOneWidget);
      expect(find.byKey(Key('video_fresh_${c2.detector}')), findsOneWidget);
      expect(
          t.widget<Text>(find.descendant(
              of: find.byKey(Key('video_finding_tag_${c1.detector}')), matching: find.byType(Text))).data,
          VideoStrings.tagStill);
      await t.scrollUntilVisible(find.text(VideoStrings.checkAgain), 300);
      expect(find.text(VideoStrings.checkAgain), findsOneWidget);
      final allowed = {skill.name, skill.tutorial.successCriteria, ...skill.tutorial.commonMistakes};
      for (final s in texts(t)) {
        expect(allowed.contains(s) || VideoStrings.isTemplate(s, correctionWords: lib.videoChecks!.correctionWords),
            isTrue,
            reason: '「$s」');
      }
    });

    testWidgets('通过', (t) async {
      final c0 = skill.videoChecks[0];
      final list = [at(0, ok([f(c0.detector, c0.mistake)])), at(5, ok(const []))];
      await show(t, list[1].judgement, progressAt(list, 1));
      expect(find.byKey(const Key('video_passed')), findsOneWidget);
      expect(find.text(VideoStrings.passedNote), findsOneWidget);
      expect(find.byKey(Key('video_fixed_${c0.detector}')), findsOneWidget);
    });

    testWidgets('第一次检查：提示改完再拍一段对比', (t) async {
      final c0 = skill.videoChecks[0];
      final list = [at(0, ok([f(c0.detector, c0.mistake)]))];
      await show(t, list[0].judgement, progressAt(list, 0));
      expect(find.text(VideoStrings.attemptTitle(1)), findsOneWidget);
      expect(find.text(VideoStrings.firstAttemptNote), findsOneWidget);
      expect(find.byKey(const Key('video_finding_tag_late_reward')), findsNothing);
    });
  });
}
