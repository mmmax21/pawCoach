/// M5 视频纠错（PRD AI-4，M5 简报第 5 节第 2 条）。
///
/// - 判定器：8 个检测器各有命中 / 未命中；阈值改动后结果随之变化（证明读自内容库）；
///   retake 两种触发；只用可靠轮次。
/// - 内容库 v1.3 解析：video_checks.yaml、技能 video_checks、非法内容报错、版本门槛、目标秒数出处。
/// - 存储：schema 5、4 → 5 迁移保留数据、最近 5 次。
/// - 页面：上传 / 等待 / 结果 / 重拍 / 失败五种状态；安全勾选后不发任何请求；
///   原文性：结果页每个文本块要么逐字等于内容库字段，要么属于模板集合。
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_parser.dart';
import 'package:puppy_trainer/data/content/content_repository.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/db/sync_tables.dart' show syncTableByName;
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/video_repository.dart';
import 'package:puppy_trainer/data/video/video_api.dart';
import 'package:puppy_trainer/data/video/video_picker.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/video_checks.dart';
import 'package:puppy_trainer/features/video/video_check_page.dart';
import 'package:puppy_trainer/features/video/video_strings.dart';

import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

// ---------------------------------------------------------------------------
// 构造视频服务结果
// ---------------------------------------------------------------------------

Map<String, Object?> tr({
  double? cue,
  required double sit,
  required double end,
  double? reward,
  String endedBy = 'release',
  List<double>? cueTimes,
  int markers = 0,
  List<Map<String, Object?>> corrections = const [],
  bool reliable = true,
}) =>
    {
      'cue_t': cue,
      'sit_start': sit,
      'sit_end': end,
      'ended_by': endedBy,
      'reward_t': reward,
      'latency': cue == null ? null : double.parse((sit - cue).toStringAsFixed(2)),
      'hold': double.parse((end - sit).toStringAsFixed(2)),
      'reward_delay': null,
      'conf': reliable ? 0.9 : 0.2,
      'cue_times': cueTimes ?? (cue == null ? <double>[] : [cue]),
      'markers_during_hold': markers,
      'corrections': corrections,
      'reliable': reliable,
    };

Map<String, Object?> res(List<Map<String, Object?>> trials, {double unclear = 0.0}) => {
      'video_id': 'x',
      'quality': {'unclear_ratio': unclear, 'audio_ok': true},
      'trials': trials,
      'summary': {'trials': trials.length},
      'unpaired': [],
      'coach': '这段文字来自视频服务，App 不应展示',
    };

/// 减少重拍：1 轮识别到口令，另外两次坐下没听清口令（带 events，可以补标）。
Map<String, Object?> cueMissed({bool withEvents = true, bool audioOk = true}) => {
      ...res([tr(cue: 0, sit: 1, end: 5, reward: 1.4)]),
      'quality': {'unclear_ratio': 0.1, 'audio_ok': audioOk, 'asr': 'transcribed'},
      'unpaired': [
        {'type': 'sit_without_cue', 't_start': 20.0, 't_end': 25.0},
        {'type': 'cue_without_sit', 'word': '坐', 't': 30.0},
        {'type': 'sit_without_cue', 't_start': 40.0, 't_end': 44.5},
      ],
      if (withEvents)
        'events': {
          'pose': [
            {'t_start': 1.0, 't_end': 5.0, 'label': 'sit', 'conf': 0.9},
          ],
          'audio': [],
        },
    };

/// 一组"干净"的轮次：每轮一次口令、坐下即奖励、听释放词结束、保持 4 秒。
List<Map<String, Object?>> clean(int n, {double hold = 4, int markers = 0}) => [
      for (var i = 0; i < n; i++)
        tr(cue: i * 20.0, sit: i * 20.0 + 1, end: i * 20.0 + 1 + hold, reward: i * 20.0 + 1.4,
            markers: markers),
    ];

const allDetectors = [
  'late_reward', 'repeated_cue', 'session_too_long', 'target_too_long',
  'reward_after_standup', 'self_release', 'no_hold_marker', 'verbal_correction',
];

final allChecks = [
  for (var i = 0; i < allDetectors.length; i++) VideoCheckMapping(detector: allDetectors[i], mistake: i),
];

VideoChecksConfig withParam(VideoChecksConfig c, String id, String key, num v) {
  final d = c.detectors[id]!;
  return VideoChecksConfig(
    minReliableTrials: c.minReliableTrials,
    retakeUnclearRatio: c.retakeUnclearRatio,
    markerWords: c.markerWords,
    releaseWords: c.releaseWords,
    correctionWords: c.correctionWords,
    detectors: {
      ...c.detectors,
      id: VideoDetectorRule(id: id, name: d.name, params: {...d.params, key: v}),
    },
  );
}

VideoChecksConfig withGate(VideoChecksConfig c, {int? minReliable, double? unclear}) =>
    VideoChecksConfig(
      minReliableTrials: minReliable ?? c.minReliableTrials,
      retakeUnclearRatio: unclear ?? c.retakeUnclearRatio,
      markerWords: c.markerWords,
      releaseWords: c.releaseWords,
      correctionWords: c.correctionWords,
      detectors: c.detectors,
    );

void main() {
  late ContentLibrary lib;
  late VideoChecksConfig cfg;
  setUpAll(() async {
    lib = await loadRepoContent();
    cfg = lib.videoChecks!;
  });

  Set<String> hits(Map<String, Object?> result, {VideoChecksConfig? config, double? target = 3}) =>
      judgeVideo(result: result, skillChecks: allChecks, config: config ?? cfg, targetHold: target)
          .findings
          .map((f) => f.detector)
          .toSet();

  // =========================================================================
  group('判定器：8 个检测器', () {
    test('干净的视频：一个都不命中', () {
      expect(hits(res(clean(4))), isEmpty);
    });

    test('late_reward 命中 / 未命中，证据是最晚的一轮', () {
      final late = [
        tr(cue: 0, sit: 1, end: 6, reward: 3.5),
        tr(cue: 10, sit: 12.5, end: 17, reward: 14.3),
        tr(cue: 20, sit: 21, end: 26, reward: 21.3),
      ];
      final j = judgeVideo(result: res(late), skillChecks: allChecks, config: cfg, targetHold: 3);
      final f = j.findings.firstWhere((f) => f.detector == 'late_reward');
      expect(f.mistake, 0);
      expect(f.evidence['sit_start'], 1);
      expect(f.evidence['reward_t'], 3.5);
      expect(f.evidence['delay'], 2.5);
      expect(f.evidence['late'], 2);
      expect(f.evidence['rewarded'], 3);
      // 1 秒以内不算晚（threshold_sec = 1.0）
      expect(hits(res([tr(cue: 0, sit: 1, end: 6, reward: 1.9), tr(cue: 10, sit: 11, end: 16, reward: 12)])),
          isNot(contains('late_reward')));
    });

    test('repeated_cue 命中 / 未命中', () {
      final rep = [
        tr(cue: 0, sit: 5, end: 10, reward: 5.2, cueTimes: [0, 2, 4]),
        tr(cue: 20, sit: 21, end: 26, reward: 21.2),
        tr(cue: 30, sit: 31, end: 36, reward: 31.2),
      ];
      final j = judgeVideo(result: res(rep), skillChecks: allChecks, config: cfg, targetHold: 3);
      final f = j.findings.firstWhere((f) => f.detector == 'repeated_cue');
      expect(f.evidence['cue_times'], [0, 2, 4]);
      expect(f.evidence['count'], 3);
      // 1/4 = 0.25 < 0.3 不命中
      expect(hits(res([...rep, tr(cue: 40, sit: 41, end: 46, reward: 41.2)])), isNot(contains('repeated_cue')));
    });

    test('session_too_long：可靠轮次 > 8 命中，= 8 不命中', () {
      expect(hits(res(clean(9))), contains('session_too_long'));
      expect(hits(res(clean(8))), isNot(contains('session_too_long')));
      // 不可靠轮次不计
      expect(hits(res([...clean(8), tr(cue: 500, sit: 501, end: 505, reliable: false)])),
          isNot(contains('session_too_long')));
    });

    test('target_too_long：达标占比 < 0.5 命中；目标未知不判定', () {
      final short = clean(4, hold: 2); // 目标 3 秒，全部没达标
      expect(hits(res(short), target: 3), contains('target_too_long'));
      expect(hits(res(short), target: 2), isNot(contains('target_too_long')));
      expect(hits(res(short), target: null), isNot(contains('target_too_long')));
      final j = judgeVideo(result: res(short), skillChecks: allChecks, config: cfg, targetHold: 3);
      final f = j.findings.firstWhere((f) => f.detector == 'target_too_long');
      expect(f.evidence, {'reached': 0, 'trials': 4, 'target': 3.0});
    });

    test('reward_after_standup 命中 / 未命中；借到下一轮的奖励不算本轮的', () {
      final after = [
        tr(cue: 0, sit: 1, end: 4, reward: 5, endedBy: 'stand_up'),
        tr(cue: 10, sit: 11, end: 15, reward: 11.3),
      ];
      expect(hits(res(after)), contains('reward_after_standup'));
      // 第一轮没给奖励，服务端把第二轮的奖励（11.3）配给了它：不应判成"起身后奖励"
      final borrowed = [
        tr(cue: 0, sit: 1, end: 4, reward: 11.3),
        tr(cue: 10, sit: 11, end: 15, reward: 11.3),
        tr(cue: 20, sit: 21, end: 25, reward: 21.3),
      ];
      expect(hits(res(borrowed)), isNot(contains('reward_after_standup')));
    });

    test('self_release：自行起身占比 ≥ 0.5 命中', () {
      final self = [
        tr(cue: 0, sit: 1, end: 5, reward: 1.3, endedBy: 'stand_up'),
        tr(cue: 10, sit: 11, end: 15, reward: 11.3),
      ];
      expect(hits(res(self)), contains('self_release'));
      expect(hits(res([...self, ...clean(2).map((t) => {...t, 'cue_t': 100.0, 'sit_start': 101.0})])),
          isNot(contains('self_release')));
    });

    test('no_hold_marker：保持 ≥ 10 秒且期间无标记词占比 ≥ 0.5 命中', () {
      final long = [
        tr(cue: 0, sit: 1, end: 31, reward: 1.3, markers: 0),
        tr(cue: 40, sit: 41, end: 71, reward: 41.3, markers: 2),
      ];
      final j = judgeVideo(result: res(long), skillChecks: allChecks, config: cfg, targetHold: 30);
      final f = j.findings.firstWhere((f) => f.detector == 'no_hold_marker');
      expect(f.evidence['hold'], 30);
      expect(f.evidence['markers'], 0);
      expect(hits(res([...long, tr(cue: 80, sit: 81, end: 111, reward: 81.3, markers: 1)]), target: 30),
          isNot(contains('no_hold_marker')));
      // 保持不足 10 秒的轮次不参与
      expect(hits(res(clean(3, hold: 5))), isNot(contains('no_hold_marker')));
    });

    test('verbal_correction：识别到纠正词即命中；词表外的词不算', () {
      final c = [
        tr(cue: 0, sit: 1, end: 5, reward: 1.3, corrections: [{'word': '不对', 't': 6.0}]),
        ...clean(2).map((t) => {...t, 'cue_t': 100.0, 'sit_start': 101.0, 'cue_times': [100.0]}),
      ];
      final j = judgeVideo(result: res(c), skillChecks: allChecks, config: cfg, targetHold: 3);
      expect(j.findings.firstWhere((f) => f.detector == 'verbal_correction').evidence['hits'],
          [{'word': '不对', 't': 6.0}]);
      final other = [
        tr(cue: 0, sit: 1, end: 5, reward: 1.3, corrections: [{'word': '别动', 't': 6.0}]),
        ...clean(1).map((t) => {...t, 'cue_t': 100.0, 'sit_start': 101.0, 'cue_times': [100.0]}),
      ];
      expect(hits(res(other)), isNot(contains('verbal_correction')));
    });

    test('只用可靠轮次：不可靠轮次里的错误不计', () {
      final r = [
        ...clean(2),
        tr(cue: 50, sit: 55, end: 60, reward: 59, cueTimes: [50, 52, 54], endedBy: 'stand_up',
            corrections: [{'word': '不对', 't': 61.0}], reliable: false),
      ];
      expect(hits(res(r)), isEmpty);
      final j = judgeVideo(result: res(r), skillChecks: allChecks, config: cfg, targetHold: 3);
      expect(j.metrics.reliableTrials, 2);
      expect(j.metrics.totalTrials, 3);
    });

    test('只判定本技能映射的检测器，mistake 下标原样带出', () {
      final sit = lib.skillById['sit']!;
      final j = judgeVideo(result: res(clean(9)), skillChecks: sit.videoChecks, config: cfg, targetHold: 2);
      expect(j.findings.map((f) => (f.detector, f.mistake)), [('session_too_long', 4)]);
    });
  });

  // =========================================================================
  group('阈值读自内容库', () {
    test('改 threshold_sec / min_ratio / max_trials / min_hold_sec 后结果随之变化', () {
      final r = res([
        tr(cue: 0, sit: 1, end: 6, reward: 2.5),
        tr(cue: 10, sit: 11, end: 16, reward: 11.2),
        tr(cue: 20, sit: 21, end: 26, reward: 21.2),
        tr(cue: 30, sit: 31, end: 36, reward: 31.2),
      ]);
      expect(hits(r), isNot(contains('late_reward'))); // 1/4 < 0.3
      expect(hits(r, config: withParam(cfg, 'late_reward', 'min_ratio', 0.25)), contains('late_reward'));
      expect(hits(r, config: withParam(cfg, 'late_reward', 'threshold_sec', 2.0)
          .let((c) => withParam(c, 'late_reward', 'min_ratio', 0.25))), isNot(contains('late_reward')));

      expect(hits(res(clean(4)), config: withParam(cfg, 'session_too_long', 'max_trials', 3)),
          contains('session_too_long'));
      expect(hits(res(clean(4, hold: 4)), config: withParam(cfg, 'no_hold_marker', 'min_hold_sec', 3)),
          contains('no_hold_marker'));
      expect(hits(res(clean(4, hold: 4)), config: withParam(cfg, 'target_too_long', 'max_success_ratio', 1.01)),
          contains('target_too_long'));
      final self1 = res([tr(cue: 0, sit: 1, end: 5, reward: 1.2, endedBy: 'stand_up'), ...clean(3)
          .map((t) => {...t, 'cue_t': (t['cue_t'] as double) + 100, 'sit_start': (t['sit_start'] as double) + 100})]);
      expect(hits(self1), isNot(contains('self_release')));
      expect(hits(self1, config: withParam(cfg, 'self_release', 'min_ratio', 0.25)), contains('self_release'));
    });

    test('retake 门槛同样读自内容库', () {
      final r = res(clean(2), unclear: 0.4);
      expect(judgeVideo(result: r, skillChecks: allChecks, config: cfg).status, VideoStatus.ok);
      expect(judgeVideo(result: r, skillChecks: allChecks, config: withGate(cfg, minReliable: 3)).status,
          VideoStatus.retake);
      expect(judgeVideo(result: r, skillChecks: allChecks, config: withGate(cfg, unclear: 0.3)).status,
          VideoStatus.retake);
    });

    test('lib/ 里不出现内容库阈值数字的硬编码（检测器实现不含数字字面量阈值）', () {
      final src = File('lib/domain/video_checks.dart').readAsStringSync();
      final body = src.substring(src.indexOf('final Map<String, _Detector> _detectors'),
          src.indexOf('Set<String> get implementedVideoDetectors'));
      // 除了下标 0/1、-1（缺省保持时长）外不应有数字字面量
      final nums = RegExp(r'(?<![\w.$])\d+(\.\d+)?(?![\w])').allMatches(body).map((m) => m.group(0)).toSet();
      expect(nums.difference({'0', '1'}), isEmpty, reason: '检测器里出现了数字：$nums');
    });
  });

  // =========================================================================
  group('retake', () {
    test('可靠轮次 < min_reliable_trials → retake，不出任何纠错', () {
      final r = res([
        tr(cue: 0, sit: 5, end: 6, reward: 9, cueTimes: [0, 2, 4], endedBy: 'stand_up'),
        tr(cue: 10, sit: 11, end: 12, reliable: false),
      ]);
      final j = judgeVideo(result: r, skillChecks: allChecks, config: cfg, targetHold: 3);
      expect(j.status, VideoStatus.retake);
      expect(j.findings, isEmpty);
      expect(j.retakeReasons, [RetakeReason.tooFewReliable]);
    });

    test('unclear_ratio > retake_unclear_ratio → retake', () {
      final r = res([...clean(3, hold: 1), tr(cue: 70, sit: 71, end: 72, reward: 75)], unclear: 0.6);
      final j = judgeVideo(result: r, skillChecks: allChecks, config: cfg, targetHold: 3);
      expect(j.status, VideoStatus.retake);
      expect(j.findings, isEmpty);
      expect(j.retakeReasons, [RetakeReason.tooUnclear]);
    });

    test('旧版服务结果没有 reliable 字段 → 全部按不可靠，提示重拍', () {
      final r = res([for (final t in clean(4)) {...t}..remove('reliable')]);
      expect(judgeVideo(result: r, skillChecks: allChecks, config: cfg).status, VideoStatus.retake);
    });
  });

  // =========================================================================
  group('减少重拍：按原因提示、可补标口令', () {
    RetakeReason? reasonOf(Map<String, Object?> r) =>
        judgeVideo(result: r, skillChecks: allChecks, config: cfg).retakeReasons.firstOrNull;

    test('服务端预检拦下：没拍到狗 / 角度不对，优先于其他原因', () {
      Map<String, Object?> pre(String issue) =>
          {...res(const [], unclear: 1.0), 'precheck': {'issues': [issue], 'voice': true}};
      expect(reasonOf(pre('no_dog')), RetakeReason.noDog);
      expect(reasonOf(pre('angle')), RetakeReason.wrongAngle);
    });

    test('看到坐下但没听清口令 → cueNotHeard，列出可补标的坐下', () {
      final r = cueMissed();
      expect(reasonOf(r), RetakeReason.cueNotHeard);
      final c = cueCandidates(r);
      expect([for (final x in c) (x.start, x.end)], [(20.0, 25.0), (40.0, 44.5)]);
    });

    test('旧版服务结果没有 events → 不能补标，按轮次不足提示', () {
      final r = cueMissed(withEvents: false);
      expect(cueCandidates(r), isEmpty);
      expect(reasonOf(r), RetakeReason.tooFewReliable);
    });

    test('没录到声音 → noVoice', () {
      expect(reasonOf(cueMissed(audioOk: false)), RetakeReason.noVoice);
      final r = {...cueMissed(), 'precheck': {'issues': [], 'voice': false}};
      expect(reasonOf(r), RetakeReason.noVoice);
    });

    test('补标了也凑不够 min_reliable_trials → 轮次不足', () {
      final r = {...cueMissed(), 'unpaired': []};
      expect(reasonOf(r), RetakeReason.tooFewReliable);
    });

    test('看不清的时间过多仍是原来的重拍句', () {
      expect(reasonOf(res(clean(3), unclear: 0.8)), RetakeReason.tooUnclear);
      expect(VideoStrings.retakeFor(RetakeReason.tooUnclear), VideoStrings.retake);
    });

    test('每个重拍原因都有对应的句子，且都属于模板集合', () {
      final texts = {for (final r in RetakeReason.values) VideoStrings.retakeFor(r, minTrials: cfg.minReliableTrials)};
      expect(texts.length, RetakeReason.values.length);
      for (final t in [...texts, VideoStrings.sitCandidate(20, 25.5), VideoStrings.confirmTitle,
          VideoStrings.confirmNote, VideoStrings.confirmButton, VideoStrings.prechecking]) {
        expect(VideoStrings.isTemplate(t), isTrue, reason: t);
      }
      expect(VideoStrings.retakeFor(RetakeReason.tooFewReliable, minTrials: 2), contains('不到 2 轮'));
    });

    test('重拍原因随记录保存；旧记录没有原因字段也能读', () async {
      final db = memoryDb();
      final repo = VideoRepository(db);
      final j = judgeVideo(result: cueMissed(), skillChecks: allChecks, config: cfg);
      final id = await repo.save(dogId: 'd', skillId: 'sit', judgement: j, contentVersion: 'v1.3', now: DateTime(2026, 11, 18));
      expect((await repo.byId(id))!.judgement.retakeReasons, [RetakeReason.cueNotHeard]);
      // 补标后覆盖同一条
      final ok = judgeVideo(result: res(clean(3)), skillChecks: const [], config: cfg);
      await repo.replace(id, ok);
      final after = await repo.byId(id);
      expect(after!.status, VideoStatus.ok);
      expect(after.judgement.retakeReasons, isEmpty);
      expect(await repo.watchRecent('d', 'sit').first, hasLength(1));
      await db.close();
    });
  });

  test('metrics：中位数与成功率只用可靠轮次', () {
    final r = res([
      tr(cue: 0, sit: 1, end: 3, reward: 1.2), // latency 1, hold 2
      tr(cue: 10, sit: 12, end: 16, reward: 12.2), // latency 2, hold 4
      tr(cue: 20, sit: 23, end: 29, reward: 23.2), // latency 3, hold 6
      tr(cue: 30, sit: 40, end: 41, reliable: false),
    ]);
    final m = judgeVideo(result: r, skillChecks: const [], config: cfg, targetHold: 3).metrics;
    expect(m.latencyMedian, 2);
    expect(m.holdMedian, 4);
    expect(m.successRate, closeTo(0.67, 0.001));
    expect((m.reliableTrials, m.totalTrials), (3, 4));
    expect(VideoMetrics.fromJson(m.toJson()).toJson(), m.toJson());
  });

  // =========================================================================
  group('内容库 v1.3', () {
    test('video_checks.yaml 与三个技能的映射', () {
      expect(lib.version, 'v1.3');
      expect(cfg.detectors.keys.toSet(), allDetectors.toSet());
      expect(cfg.minReliableTrials, 2);
      expect(cfg.markerWords, contains('好'));
      expect(lib.skillById['sit']!.videoChecks.map((c) => c.detector),
          ['late_reward', 'repeated_cue', 'session_too_long']);
      expect(lib.skillById['stay_short']!.videoChecks.length, 4);
      expect(lib.skillById['stay_long']!.videoChecks.length, 2);
      expect(lib.skills.where((s) => s.videoChecks.isNotEmpty).map((s) => s.id).toSet(),
          {'sit', 'stay_short', 'stay_long'});
    });

    test('从数据库缓存读回与解析一致', () async {
      final db = memoryDb();
      await loadRepoContent(db: db);
      final again = await loadRepoContent(db: db);
      expect(again.videoChecks!.detectors['late_reward']!.params, cfg.detectors['late_reward']!.params);
      expect(again.skillById['stay_short']!.videoChecks.map((c) => c.mistake), [0, 1, 2, 3]);
    });

    test('非法 video_checks.yaml 报错', () {
      final text = File('${repoContentDir().path}/video_checks.yaml').readAsStringSync();
      expect(() => parseVideoChecks('v.yaml', text.replaceFirst('id: late_reward', 'id: mystery')),
          throwsA(isA<ContentParseException>().having((e) => e.message, 'm', contains('mystery'))));
      expect(() => parseVideoChecks('v.yaml', text.replaceFirst('threshold_sec: 1.0', 'foo: 1.0')),
          throwsA(isA<ContentParseException>()));
      expect(() => parseVideoChecks('v.yaml', text.replaceFirst('min_reliable_trials: 2', '')),
          throwsA(isA<ContentParseException>()));
    });

    test('技能 video_checks 下标越界报错', () {
      final text = File('${repoContentDir().path}/skills/sit.yaml').readAsStringSync();
      expect(() => parseSkill('skills/sit.yaml', text.replaceFirst('mistake: 4 }', 'mistake: 9 }')),
          throwsA(isA<ContentParseException>().having((e) => e.message, 'm', contains('越界'))));
    });

    test('v1.2 及以下不再支持（video_checks.yaml 必填）', () {
      expect(() => requireSupportedContentVersion('VERSION.md', 'v1.2'),
          throwsA(isA<ContentParseException>()));
      requireSupportedContentVersion('VERSION.md', 'v1.3');
    });

    test('缺 video_checks.yaml 报错，不静默降级', () async {
      final tmp = Directory.systemTemp.createTempSync('content_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      await Process.run('cp', ['-R', '${repoContentDir().path}/.', tmp.path]);
      File('${tmp.path}/video_checks.yaml').deleteSync();
      final repo = ContentRepositoryForTest(tmp);
      expect(repo.load(), throwsA(isA<ContentParseException>()));
    });

    test('目标保持秒数常量表的出处：数字出现在成功标准原文里', () {
      for (final e in videoTargetHoldSec.entries) {
        final crit = lib.skillById[e.key]!.tutorial.successCriteria;
        expect(crit, contains('${e.value} 秒'), reason: e.key);
      }
      expect(videoTargetHoldSec.keys.toSet(),
          lib.skills.where((s) => s.videoChecks.isNotEmpty).map((s) => s.id).toSet());
    });

    test('上传 meta：口令取狗的口令表，词表取内容库，language=zh', () {
      final sit = lib.skillById['stay_short']!;
      final m = buildVideoMeta(skill: sit, config: cfg, dogCue: '停');
      expect(m['cues'], ['停']);
      expect(m['marker_words'], cfg.markerWords);
      expect(m['release_words'], cfg.releaseWords);
      expect(m['correction_words'], cfg.correctionWords);
      expect(m['target_hold'], 3.0);
      expect(m['language'], 'zh');
      expect(m['max_duration'], 120);
      expect(m.containsKey('red_flags'), isFalse); // 简报 4.4：本期不传 red_flags
    });
  });

  // =========================================================================
  group('存储', () {
    test('schema 5；4 → 5 迁移保留数据并新建 video_analyses', () async {
      final dir = Directory.systemTemp.createTempSync('m5mig');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      // 先用当前代码建库并写入一只狗，再退回 v4 形态（删表 + user_version=4）
      var db = AppDatabase(NativeDatabase(file));
      await HouseholdRepository(db).ensureLocalUser();
      final r = await OnboardingRepository(db).complete(
        form: _form(),
        content: lib,
        now: DateTime(2026, 11, 18),
      );
      await db.customStatement('DROP TABLE video_analyses');
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      expect(db.schemaVersion, 5);
      final dog = await DogRepository(db).currentDog();
      expect(dog?.id, r.dogId);
      final repo = VideoRepository(db);
      for (var i = 0; i < 7; i++) {
        await repo.save(
          dogId: r.dogId,
          skillId: 'sit',
          judgement: judgeVideo(result: res(clean(3)), skillChecks: const [], config: cfg, targetHold: 2),
          contentVersion: lib.version,
          now: DateTime.utc(2026, 11, 18, 10, i),
        );
      }
      final recent = await repo.watchRecent(r.dogId, 'sit').first;
      expect(recent.length, 5);
      expect(recent.first.createdAt, DateTime.utc(2026, 11, 18, 10, 6));
      expect(recent.first.metrics.reliableTrials, 3);
      await db.close();
    });

    test('video_analyses 不在同步表里', () {
      expect(syncTableByName.keys, isNot(contains('video_analyses')));
    });
  });

  // =========================================================================
  group('原文性：结果页每个文本块是内容库原文或模板', () {
    for (final skillId in ['sit', 'stay_short', 'stay_long']) {
      testWidgets('$skillId：全部检测器命中 / 无命中 / 重拍', (t) async {
        final skill = lib.skillById[skillId]!;
        final allowed = <String>{
          ...skill.tutorial.commonMistakes,
          skill.tutorial.successCriteria,
          skill.name,
        };
        // 构造一个让本技能所有检测器都命中的结果
        final bad = res([
          tr(cue: 0, sit: 5, end: 40, reward: 41, cueTimes: [0, 2, 4], endedBy: 'stand_up',
              corrections: [{'word': '不对', 't': 42.0}]),
          tr(cue: 50, sit: 55, end: 56, reward: 57.5, cueTimes: [50, 53], endedBy: 'stand_up'),
          for (var i = 0; i < 8; i++) tr(cue: 100.0 + i * 10, sit: 101.0 + i * 10, end: 102.0 + i * 10,
              reward: 103.5 + i * 10, endedBy: 'stand_up',
              cueTimes: i.isEven ? [100.0 + i * 10, 100.5 + i * 10] : null),
        ]);
        final judgements = {
          'bad': judgeVideo(result: bad, skillChecks: skill.videoChecks, config: cfg,
              targetHold: videoTargetHoldSec[skillId]!.toDouble()),
          'good': judgeVideo(result: res(clean(3, hold: 40, markers: 3)), skillChecks: skill.videoChecks, config: cfg,
              targetHold: videoTargetHoldSec[skillId]!.toDouble()),
          'retake': judgeVideo(result: res(clean(1)), skillChecks: skill.videoChecks, config: cfg),
        };
        expect(judgements['bad']!.findings.map((f) => f.detector).toSet(),
            skill.videoChecks.map((c) => c.detector).toSet(),
            reason: '构造的结果应让 $skillId 的所有检测器命中');
        expect(judgements['good']!.findings, isEmpty);
        expect(judgements['retake']!.status, VideoStatus.retake);

        for (final e in judgements.entries) {
          await t.pumpWidget(MaterialApp(
            home: Scaffold(
              body: VideoResultView(skill: skill, judgement: e.value, config: cfg, onReupload: () {}),
            ),
          ));
          final texts = _allTexts(t);
          expect(texts, isNotEmpty);
          for (final s in texts) {
            expect(allowed.contains(s) || VideoStrings.isTemplate(s, correctionWords: cfg.correctionWords),
                isTrue, reason: '$skillId/${e.key}：文本「$s」既不是内容库原文也不在模板集合内');
          }
          expect(texts, isNot(contains(contains('App 不应展示'))));
          if (e.key == 'retake') {
            // 重拍句按原因选（减少重拍）；这里构造的是"可靠轮次不足"
            expect(texts.toSet(), {
              VideoStrings.retakeFor(e.value.retakeReasons.first, minTrials: cfg.minReliableTrials),
              VideoStrings.reupload,
            });
          }
          if (e.key == 'bad') {
            for (final c in skill.videoChecks) {
              expect(texts, contains(skill.tutorial.commonMistakes[c.mistake]));
            }
          }
          if (e.key == 'good') {
            expect(texts, containsAll([VideoStrings.noFindings, skill.tutorial.successCriteria]));
          }
        }
      });
    }

    test('模板集合本身不含训练方法词', () {
      // 模板只能是标签、提示与证据句式；不得出现内容库里的方法描述
      final methodWords = ['零食', '响片', '手势', '后退', '保持费', '释放词', '退回'];
      for (final s in VideoStrings.fixed) {
        for (final w in methodWords) {
          expect(s.contains(w), isFalse, reason: '模板「$s」含方法词「$w」');
        }
      }
    });

    test('证据句式对每个检测器都能被模板识别', () {
      final samples = <VideoFinding>[
        const VideoFinding(detector: 'late_reward', mistake: 0, evidence: {
          'sit_start': 12.5, 'reward_t': 14.3, 'delay': 1.8, 'late': 2, 'rewarded': 3, 'threshold_sec': 1.0}),
        const VideoFinding(detector: 'repeated_cue', mistake: 0, evidence: {
          'cue_times': [1.0, 2.5], 'count': 2, 'repeated': 1, 'trials': 3}),
        const VideoFinding(detector: 'session_too_long', mistake: 0, evidence: {'trials': 9, 'max_trials': 8}),
        const VideoFinding(detector: 'target_too_long', mistake: 0, evidence: {'reached': 1, 'trials': 4, 'target': 3.0}),
        const VideoFinding(detector: 'reward_after_standup', mistake: 0, evidence: {
          'sit_end': 4.0, 'reward_t': 5.0, 'after': 1, 'rewarded': 2}),
        const VideoFinding(detector: 'self_release', mistake: 0, evidence: {'self': 2, 'trials': 3}),
        const VideoFinding(detector: 'no_hold_marker', mistake: 0, evidence: {
          'hold': 30.0, 'markers': 0, 'silent': 1, 'long': 2}),
        const VideoFinding(detector: 'verbal_correction', mistake: 0, evidence: {
          'hits': [{'word': '不对', 't': 6.0}, {'word': '不行', 't': 9.5}]}),
      ];
      for (final f in samples) {
        final s = VideoStrings.evidence(f);
        expect(VideoStrings.isTemplate(s, correctionWords: cfg.correctionWords), isTrue, reason: s);
      }
      expect(VideoStrings.evidence(samples.first), startsWith('第 12.5 秒坐下，第 14.3 秒才奖励，晚了 1.8 秒'));
      // 词表外的词不被模板接受
      expect(VideoStrings.isTemplate('第 6 秒识别到「坐好别动」', correctionWords: cfg.correctionWords), isFalse);
    });
  });

  // =========================================================================
  group('页面', () {
    late AppDatabase db;
    late String dogId;
    final fakeNow = DateTime(2026, 11, 18, 9);

    Future<void> seed(WidgetTester t) async {
      db = memoryDb();
      await t.runAsync(() async {
        await HouseholdRepository(db).ensureLocalUser();
        final r = await OnboardingRepository(db).complete(form: _form(), content: lib, now: fakeNow);
        dogId = r.dogId;
      });
    }

    Future<void> pumpApp(WidgetTester t, FakeVideoApi api, {bool enabled = true}) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(ProviderScope(overrides: [
        databaseProvider.overrideWithValue(db),
        contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
        clockProvider.overrideWithValue(() => fakeNow),
        reminderNotifierProvider.overrideWithValue(FakeNotifier()),
        appEffectsEnabledProvider.overrideWithValue(false),
        videoAnalysisEnabledProvider.overrideWithValue(enabled),
        videoAnalysisApiProvider.overrideWithValue(api),
        videoPickerProvider.overrideWithValue(FakePicker()),
        videoPollingProvider.overrideWithValue(
            (interval: const Duration(milliseconds: 30), timeout: const Duration(milliseconds: 300))),
      ], child: const PuppyTrainerApp()));
    }

    GoRouter router(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp))).read(routerProvider);

    Future<void> settle(WidgetTester t, Finder f) async {
      for (var i = 0; i < 400; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 20));
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

    Future<void> openSkill(WidgetTester t, String skillId) async {
      await settle(t, find.byType(Scaffold));
      router(t).push('/skill/$skillId');
      await settle(t, find.text('成功标准'));
    }

    testWidgets('入口：仅有 video_checks 的技能且开关打开时显示', (t) async {
      await seed(t);
      final api = FakeVideoApi();
      await pumpApp(t, api);
      await openSkill(t, 'sit');
      expect(find.byKey(const Key('video_entry')), findsOneWidget);
      router(t).push('/skill/down');
      await settle(t, find.text('趴下'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('video_entry')), findsNothing);
      await teardown(t);
    });

    testWidgets('开关关闭（默认）时不显示入口', (t) async {
      await seed(t);
      await pumpApp(t, FakeVideoApi(), enabled: false);
      await openSkill(t, 'sit');
      expect(find.byKey(const Key('video_entry')), findsNothing);
      await teardown(t);
    });

    testWidgets('安全勾选后不上传、显示固定句，且不发任何请求', (t) async {
      await seed(t);
      final api = FakeVideoApi();
      await pumpApp(t, api);
      await openSkill(t, 'stay_short');
      await t.ensureVisible(find.byKey(const Key('video_entry')));
      await t.tap(find.byKey(const Key('video_entry')));
      await settle(t, find.byKey(const Key('video_safety_check')));
      await t.tap(find.byKey(const Key('video_safety_check')));
      await t.pump();
      expect(find.text(VideoStrings.safetyStop), findsOneWidget);
      expect(find.byKey(const Key('video_pick_gallery')), findsNothing);
      expect(find.byKey(const Key('video_pick_camera')), findsNothing);
      await t.pump(const Duration(milliseconds: 200));
      expect(api.submits, isEmpty);
      expect(api.polls, 0);
      await teardown(t);
    });

    testWidgets('上传 → 等待 → 结果（有问题）→ 存历史 → 按正确方法跟练', (t) async {
      await seed(t);
      final api = FakeVideoApi(script: [
        const VideoJobPending(),
        VideoJobDone(Map<String, dynamic>.from(res([
          tr(cue: 0, sit: 1, end: 6, reward: 3.5),
          tr(cue: 10, sit: 12.5, end: 17, reward: 14.3),
          tr(cue: 20, sit: 21, end: 26, reward: 21.3),
        ]))),
      ]);
      api.gate = Completer<void>();
      await pumpApp(t, api);
      await openSkill(t, 'sit');
      await t.ensureVisible(find.byKey(const Key('video_entry')));
      await t.tap(find.byKey(const Key('video_entry')));
      await settle(t, find.byKey(const Key('video_pick_gallery')));
      await t.tap(find.byKey(const Key('video_pick_gallery')));
      await settle(t, find.text(VideoStrings.uploading));
      api.gate!.complete();
      await settle(t, find.text(VideoStrings.analyzing));
      await settle(t, find.byKey(const Key('video_result')));

      // meta
      final meta = api.submits.single.meta;
      expect(meta['cues'], [lib.skillById['sit']!.defaultCue]); // 建档写入的口令表 = 默认口令
      expect(meta['language'], 'zh');
      expect(meta['target_hold'], 2.0);

      final sit = lib.skillById['sit']!;
      expect(find.text(sit.tutorial.commonMistakes[2]), findsOneWidget);
      expect(find.text(VideoStrings.findingsTitle), findsOneWidget);
      expect(find.textContaining('第 1 秒坐下，第 3.5 秒才奖励，晚了 2.5 秒'), findsOneWidget);
      expect(find.textContaining('不应展示'), findsNothing);

      final saved = await t.runAsync(() => VideoRepository(db).watchRecent(dogId, 'sit').first);
      expect(saved!.single.findings.single.detector, 'late_reward');
      expect(saved.single.contentVersion, 'v1.3');

      await t.ensureVisible(find.byKey(const Key('video_practice_1')));
      await t.tap(find.byKey(const Key('video_practice_1')));
      await t.pump();
      final conf = router(t).routerDelegate.currentConfiguration;
      final last = conf.matches.last;
      expect(last is ImperativeRouteMatch ? last.matches.uri.path : conf.uri.path, '/training/sit/1');
      await teardown(t);
    });

    testWidgets('结果（无问题）显示成功标准原文；历史可回看', (t) async {
      await seed(t);
      final api = FakeVideoApi(script: [VideoJobDone(Map<String, dynamic>.from(res(clean(3))))]);
      await pumpApp(t, api);
      await openSkill(t, 'stay_short');
      router(t).push('/skill/stay_short/video');
      await settle(t, find.byKey(const Key('video_pick_camera')));
      await t.tap(find.byKey(const Key('video_pick_camera')));
      await settle(t, find.byKey(const Key('video_no_findings')));
      expect(find.text(lib.skillById['stay_short']!.tutorial.successCriteria), findsOneWidget);
      router(t).go('/skill/stay_short');
      await settle(t, find.byKey(const Key('skill_ask_coach')));
      await t.drag(find.byType(ListView).first, const Offset(0, -4000));
      await settle(t, find.byKey(const Key('video_history')));
      final tile = find.descendant(of: find.byKey(const Key('video_history')), matching: find.byType(ListTile));
      expect(tile, findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text(VideoStrings.noFindings)), findsOneWidget);
      // 列表最底部的条目被底部"开始跟练"栏遮住，直接触发 onTap
      t.widget<ListTile>(tile).onTap!();
      await settle(t, find.byKey(const Key('video_no_findings')));
      await teardown(t);
    });

    testWidgets('重拍：只显示重拍提示与重新上传', (t) async {
      await seed(t);
      final api = FakeVideoApi(script: [VideoJobDone(Map<String, dynamic>.from(res(clean(3), unclear: 0.8)))]);
      await pumpApp(t, api);
      await openSkill(t, 'sit');
      router(t).push('/skill/sit/video');
      await settle(t, find.byKey(const Key('video_pick_gallery')));
      await t.tap(find.byKey(const Key('video_pick_gallery')));
      await settle(t, find.byKey(const Key('video_retake')));
      expect(find.text(VideoStrings.retake), findsOneWidget);
      expect(find.byKey(const Key('video_metrics')), findsNothing);
      expect(find.text(VideoStrings.findingsTitle), findsNothing);
      await t.tap(find.byKey(const Key('video_reupload')));
      await t.pump();
      expect(find.byKey(const Key('video_pick_gallery')), findsOneWidget);
      await teardown(t);
    });

    testWidgets('失败三种：连不上 / 服务失败 / 超时，均可重试', (t) async {
      await seed(t);
      final api = FakeVideoApi(unreachable: true);
      await pumpApp(t, api);
      await openSkill(t, 'sit');
      router(t).push('/skill/sit/video');
      await settle(t, find.byKey(const Key('video_pick_gallery')));
      await t.tap(find.byKey(const Key('video_pick_gallery')));
      await settle(t, find.text(VideoStrings.errUnreachable));

      // 重试 → 服务失败
      api
        ..unreachable = false
        ..script = [const VideoJobFailed('RuntimeError: boom')];
      await t.tap(find.byKey(const Key('video_retry')));
      await settle(t, find.text(VideoStrings.errFailed));
      expect(api.submits.length, 2);

      // 重试 → 一直 pending → 超时
      api.script = [const VideoJobPending()];
      await t.tap(find.byKey(const Key('video_retry')));
      await settle(t, find.text(VideoStrings.errTimeout));

      // 超长
      api.script = [const VideoJobFailed('video_too_long: 130.0s > 120s')];
      await t.tap(find.byKey(const Key('video_retry')));
      await settle(t, find.text(VideoStrings.errTooLong));
      expect(find.byKey(const Key('video_retry')), findsNothing);
      await teardown(t);
    });

    testWidgets('预检中显示"正在检查画面"；预检拦下 → 角度提示，不能补标', (t) async {
      await seed(t);
      final api = FakeVideoApi(script: [
        const VideoJobPending('precheck'),
        const VideoJobPending('precheck'),
        const VideoJobPending('precheck'),
        VideoJobDone(Map<String, dynamic>.from(
            {...res(const [], unclear: 1.0), 'precheck': {'issues': ['angle'], 'voice': true}})),
      ]);
      await pumpApp(t, api);
      await openSkill(t, 'sit');
      router(t).push('/skill/sit/video');
      await settle(t, find.byKey(const Key('video_pick_gallery')));
      await t.tap(find.byKey(const Key('video_pick_gallery')));
      await settle(t, find.text(VideoStrings.prechecking));
      await settle(t, find.byKey(const Key('video_retake')));
      expect(find.text(VideoStrings.retakeAngle), findsOneWidget);
      expect(find.byKey(const Key('video_cue_confirm')), findsNothing);
      await teardown(t);
    });

    testWidgets('没听清口令 → 补标两次坐下 → 重新判定出结果，覆盖同一条记录', (t) async {
      await seed(t);
      final api = FakeVideoApi(script: [VideoJobDone(Map<String, dynamic>.from(cueMissed()))]);
      await pumpApp(t, api);
      await openSkill(t, 'sit');
      router(t).push('/skill/sit/video');
      await settle(t, find.byKey(const Key('video_pick_gallery')));
      await t.tap(find.byKey(const Key('video_pick_gallery')));
      await settle(t, find.byKey(const Key('video_cue_confirm')));
      expect(find.text(VideoStrings.retakeCueNotHeard), findsOneWidget);
      expect(find.text(VideoStrings.sitCandidate(20, 25)), findsOneWidget);
      expect(find.text(VideoStrings.sitCandidate(40, 44.5)), findsOneWidget);
      // 原文性：重拍页每个文本块都属于模板集合
      for (final s in _allTexts(t).where((s) => s != VideoStrings.pageTitle)) {
        expect(VideoStrings.isTemplate(s), isTrue, reason: s);
      }
      // 没勾选时按钮不可用
      expect(t.widget<FilledButton>(find.byKey(const Key('video_cue_confirm_button'))).onPressed, isNull);

      // 第一次：服务失败 → 提示，勾选保留
      await t.tap(find.byKey(const Key('video_cue_candidate_1')));
      await t.tap(find.byKey(const Key('video_cue_candidate_0')));
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('video_cue_confirm_button')));
      await t.tap(find.byKey(const Key('video_cue_confirm_button')));
      await settle(t, find.byKey(const Key('video_realign_error')));
      expect(api.realigns.single.sits, [20.0, 40.0]);
      expect(api.realigns.single.meta['cues'], api.submits.single.meta['cues']);
      expect(api.realigns.single.result['events'], isNotNull);

      // 第二次：成功 → 结果页
      api.realignResult = Map<String, dynamic>.from(res([
        tr(cue: 0, sit: 1, end: 5, reward: 1.4),
        tr(cue: 20.15, sit: 20, end: 25, reward: 23.0)..['latency'] = null..['cue_times'] = <double>[],
        tr(cue: 40.15, sit: 40, end: 44.5, reward: 40.3)..['latency'] = null..['cue_times'] = <double>[],
      ]));
      await t.ensureVisible(find.byKey(const Key('video_cue_confirm_button')));
      await t.tap(find.byKey(const Key('video_cue_confirm_button')));
      await settle(t, find.byKey(const Key('video_result')));
      expect(find.text(lib.skillById['sit']!.tutorial.commonMistakes[2]), findsOneWidget); // 奖励太晚
      final saved = await t.runAsync(() => VideoRepository(db).watchRecent(dogId, 'sit').first);
      expect(saved!, hasLength(1));
      expect(saved.single.status, VideoStatus.ok);
      await teardown(t);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

OnboardingResult _form() => OnboardingResult(
      dogName: '豆豆',
      birthDate: DateTime(2026, 7, 1),
      breedId: 'mixed_or_unknown',
      breedText: '混种 / 不确定',
      sex: Sex.male,
      homeDate: DateTime(2026, 9, 1),
      concerns: const [],
      dailyMinutes: 10,
      trainerCount: 1,
      livingEnv: LivingEnv.apartment,
      masteredSkills: const {},
    );

List<String> _allTexts(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if ((w.data ?? w.textSpan?.toPlainText() ?? '').trim().isNotEmpty)
          (w.data ?? w.textSpan!.toPlainText()),
    ];

class ContentRepositoryForTest {
  ContentRepositoryForTest(this.dir);
  final Directory dir;
  Future<ContentLibrary> load() =>
      ContentRepository(db: memoryDb(), source: FileContentSource(dir)).ensureLoaded();
}

class FakePicker implements VideoPicker {
  @override
  Future<String?> pick({required bool camera}) async => '/tmp/fake_${camera ? 'cam' : 'gal'}.mp4';
}

class FakeVideoApi implements VideoAnalysisApi {
  FakeVideoApi({this.script = const [], this.unreachable = false});
  List<VideoJob> script;
  bool unreachable;
  Completer<void>? gate;
  final submits = <({String path, Map<String, Object?> meta})>[];
  int polls = 0;
  int _i = 0;

  @override
  Future<String> submit({required String filePath, required Map<String, Object?> meta}) async {
    submits.add((path: filePath, meta: meta));
    _i = 0;
    if (gate != null) await gate!.future;
    if (unreachable) throw VideoApiException(VideoErrorKind.unreachable);
    return 'job${submits.length}';
  }

  /// realign 的返回；为 null 时抛错（模拟服务失败）。
  Map<String, dynamic>? realignResult;
  final realigns = <({Map<String, dynamic> result, Map<String, Object?> meta, List<double> sits})>[];

  @override
  Future<Map<String, dynamic>> realign({
    required Map<String, dynamic> result,
    required Map<String, Object?> meta,
    required List<double> userCueSits,
  }) async {
    realigns.add((result: result, meta: meta, sits: userCueSits));
    final r = realignResult;
    if (r == null) throw VideoApiException(VideoErrorKind.failed, 'boom');
    return r;
  }

  @override
  Future<VideoJob> poll(String jobId) async {
    polls++;
    final s = script[_i < script.length ? _i : script.length - 1];
    _i++;
    return s;
  }
}
