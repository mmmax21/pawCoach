/// 视频纠错判定器（PRD AI-4，M5 简报 4.2）。纯函数，无 IO、无 Flutter。
///
/// 输入：视频服务返回的 result JSON、该技能的 `video_checks` 映射、
/// `video_checks.yaml` 的规则与阈值、本次目标保持时长。
/// 输出：[VideoJudgement]（status / metrics / findings）。
///
/// 规则：
/// - 只用可靠轮次（result.trials[].reliable == true）。
/// - 可靠轮次 < min_reliable_trials 或 quality.unclear_ratio > retake_unclear_ratio（或服务端预检拦下）
///   → retake，不做任何纠错判定；重拍原因见 [RetakeReason]。
/// - 8 个检测器严格按 video_checks.yaml 的 rule 实现，阈值全部来自 [VideoChecksConfig]，本文件不写任何阈值。
/// - 本文件不产生任何文字；展示文字只有内容库原文与 `features/video/video_strings.dart` 的模板。
library;

// ---------------------------------------------------------------------------
// 内容库模型（video_checks.yaml 与技能的 video_checks 字段）
// ---------------------------------------------------------------------------

/// 技能 YAML 里的一条 `video_checks` 映射：检测器 → `tutorial.common_mistakes` 下标。
class VideoCheckMapping {
  const VideoCheckMapping({required this.detector, required this.mistake});
  final String detector;
  final int mistake;
}

/// `video_checks.yaml` 里的一个检测器：id、名称、阈值（数字字段原样保留）。
class VideoDetectorRule {
  const VideoDetectorRule(
      {required this.id, required this.name, required this.params});
  final String id;
  final String name;
  final Map<String, num> params;

  /// 取阈值；缺失时抛 [StateError]（解析阶段已校验齐全，这里只是兜底）。
  num p(String key) {
    final v = params[key];
    if (v == null) throw StateError('检测器 $id 缺阈值 $key');
    return v;
  }
}

/// `video_checks.yaml` 整份。
class VideoChecksConfig {
  const VideoChecksConfig({
    required this.minReliableTrials,
    required this.retakeUnclearRatio,
    required this.markerWords,
    required this.releaseWords,
    required this.correctionWords,
    required this.detectors,
  });
  final int minReliableTrials;
  final double retakeUnclearRatio;
  final List<String> markerWords;
  final List<String> releaseWords;
  final List<String> correctionWords;

  /// 按 id 索引，保持 YAML 顺序。
  final Map<String, VideoDetectorRule> detectors;
}

/// 客户端实现的检测器，以及每个检测器必需的阈值字段（与 content/validate.py 一致）。
const videoDetectorParams = <String, List<String>>{
  'late_reward': ['threshold_sec', 'min_ratio'],
  'repeated_cue': ['threshold_count', 'min_ratio'],
  'session_too_long': ['max_trials'],
  'target_too_long': ['max_success_ratio'],
  'reward_after_standup': ['min_ratio'],
  'self_release': ['min_ratio'],
  'no_hold_marker': ['min_hold_sec', 'min_ratio'],
  'verbal_correction': [],
  'slow_response': ['threshold_sec', 'min_ratio'],
};

// ---------------------------------------------------------------------------
// 视频服务结果（只取判定需要的字段）
// ---------------------------------------------------------------------------

class VideoTrial {
  const VideoTrial({
    this.cueT,
    this.sitStart,
    this.sitEnd,
    this.endedBy,
    this.rewardT,
    this.latency,
    this.hold,
    this.cueTimes = const [],
    this.markersDuringHold = 0,
    this.corrections = const [],
    this.reliable = false,
  });

  final double? cueT;
  final double? sitStart;
  final double? sitEnd;
  final String? endedBy;
  final double? rewardT;
  final double? latency;
  final double? hold;
  final List<double> cueTimes;
  final int markersDuringHold;
  final List<({String word, double t})> corrections;
  final bool reliable;

  /// 本轮开始时刻（最早的口令或坐下）。
  double? get start {
    final c = [cueT, sitStart, ...cueTimes].whereType<double>();
    return c.isEmpty ? null : c.reduce((a, b) => a < b ? a : b);
  }

  static double? _d(Object? v) => v is num ? v.toDouble() : null;

  factory VideoTrial.fromJson(Map json) => VideoTrial(
        cueT: _d(json['cue_t']),
        sitStart: _d(json['sit_start']),
        sitEnd: _d(json['sit_end']),
        endedBy: json['ended_by'] as String?,
        rewardT: _d(json['reward_t']),
        latency: _d(json['latency']),
        hold: _d(json['hold']),
        cueTimes: [
          for (final v in (json['cue_times'] as List? ?? const []))
            (v as num).toDouble(),
        ],
        markersDuringHold: (json['markers_during_hold'] as num?)?.toInt() ?? 0,
        corrections: [
          for (final c in (json['corrections'] as List? ?? const []))
            (
              word: (c as Map)['word'].toString(),
              t: (c['t'] as num).toDouble()
            ),
        ],
        // 旧版服务没有 reliable 字段：一律按不可靠处理（宁可提示重拍，不误判）
        reliable: json['reliable'] == true,
      );
}

// ---------------------------------------------------------------------------
// 判定结果
// ---------------------------------------------------------------------------

enum VideoStatus { retake, ok }

/// 为什么要重拍（减少重拍：按原因给出能照着做的提示）。只取最主要的一个原因，按下面的顺序判断：
/// 1. 服务端预检拦下：[noDog] 没拍到狗 / [wrongAngle] 看不出姿势（俯拍、正面）；
/// 2. [tooUnclear]：整段分析后看不清的时间超过门槛；
/// 3. 可靠轮次不够：[noVoice] 没录到说话声 / [cueNotHeard] 看到狗坐下但没听清口令（可以补标口令）/
///    [tooFewReliable] 其余情况（练的轮次太少）。
enum RetakeReason {
  noDog,
  wrongAngle,
  tooUnclear,
  noVoice,
  cueNotHeard,
  tooFewReliable
}

/// 一次没配上口令的坐下（服务端 unpaired 里的 sit_without_cue），用户可以确认"这次是听口令坐下的"。
class VideoSitCandidate {
  const VideoSitCandidate(this.start, this.end);
  final double start;
  final double end;
}

/// 可以补标口令的坐下。结果里没有 events（旧版服务）时无法重新对齐，返回空。
List<VideoSitCandidate> cueCandidates(Map result) {
  final pose = ((result['events'] as Map?)?['pose'] as List?) ?? const [];
  if (pose.isEmpty) return const [];
  return [
    for (final u in (result['unpaired'] as List? ?? const []))
      if ((u as Map)['type'] == 'sit_without_cue')
        VideoSitCandidate(
            (u['t_start'] as num).toDouble(), (u['t_end'] as num).toDouble()),
  ];
}

RetakeReason? _retakeReason(
    Map result, int reliable, VideoChecksConfig config) {
  final quality = (result['quality'] as Map?) ?? const {};
  final precheck = result['precheck'] as Map?;
  final issues = [
    for (final i in (precheck?['issues'] as List? ?? const [])) '$i'
  ];
  if (issues.contains('no_dog')) return RetakeReason.noDog;
  if (issues.contains('angle')) return RetakeReason.wrongAngle;
  final unclearRatio = (quality['unclear_ratio'] as num?)?.toDouble() ?? 0.0;
  if (unclearRatio > config.retakeUnclearRatio) return RetakeReason.tooUnclear;
  if (reliable >= config.minReliableTrials) return null;
  final asr = '${quality['asr'] ?? ''}';
  final noVoice = quality['audio_ok'] == false ||
      asr == 'no_audio' ||
      precheck?['voice'] == false;
  if (noVoice) return RetakeReason.noVoice;
  final candidates = cueCandidates(result).length;
  if (candidates > 0 && reliable + candidates >= config.minReliableTrials) {
    return RetakeReason.cueNotHeard;
  }
  return RetakeReason.tooFewReliable;
}

class VideoMetrics {
  const VideoMetrics({
    required this.totalTrials,
    required this.reliableTrials,
    this.latencyMedian,
    this.holdMedian,
    this.successRate,
    this.targetHold,
  });

  final int totalTrials;
  final int reliableTrials;

  /// 反应快慢中位数（秒），可靠轮次里有口令→坐下时间的才计。
  final double? latencyMedian;

  /// 保持时长中位数（秒）。
  final double? holdMedian;

  /// 成功率：可靠轮次里保持时长达到本次目标的比例（0–1）。目标未知时为 null。
  final double? successRate;
  final double? targetHold;

  Map<String, Object?> toJson() => {
        'total_trials': totalTrials,
        'reliable_trials': reliableTrials,
        'latency_median': latencyMedian,
        'hold_median': holdMedian,
        'success_rate': successRate,
        'target_hold': targetHold,
      };

  factory VideoMetrics.fromJson(Map j) => VideoMetrics(
        totalTrials: (j['total_trials'] as num).toInt(),
        reliableTrials: (j['reliable_trials'] as num).toInt(),
        latencyMedian: (j['latency_median'] as num?)?.toDouble(),
        holdMedian: (j['hold_median'] as num?)?.toDouble(),
        successRate: (j['success_rate'] as num?)?.toDouble(),
        targetHold: (j['target_hold'] as num?)?.toDouble(),
      );
}

/// 一个命中的检测器。[evidence] 只含数字与时间（以及内容库词表里的纠正词），
/// 由模板句式渲染成一行证据。
class VideoFinding {
  const VideoFinding(
      {required this.detector, required this.mistake, required this.evidence});
  final String detector;
  final int mistake;
  final Map<String, Object?> evidence;

  Map<String, Object?> toJson() =>
      {'detector': detector, 'mistake': mistake, 'evidence': evidence};

  factory VideoFinding.fromJson(Map j) => VideoFinding(
        detector: j['detector'] as String,
        mistake: (j['mistake'] as num).toInt(),
        evidence: Map<String, Object?>.from(j['evidence'] as Map),
      );
}

class VideoJudgement {
  const VideoJudgement({
    required this.status,
    required this.metrics,
    required this.findings,
    this.retakeReasons = const [],
  });
  final VideoStatus status;
  final VideoMetrics metrics;
  final List<VideoFinding> findings;
  final List<RetakeReason> retakeReasons;
}

// ---------------------------------------------------------------------------
// 判定
// ---------------------------------------------------------------------------

double? _median(Iterable<double> values) {
  final v = values.toList()..sort();
  if (v.isEmpty) return null;
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// 主入口。[skillChecks] 为该技能的 `video_checks`（为空时不做任何检测）。
VideoJudgement judgeVideo({
  required Map result,
  required List<VideoCheckMapping> skillChecks,
  required VideoChecksConfig config,
  double? targetHold,
}) {
  final all = [
    for (final t in (result['trials'] as List? ?? const []))
      VideoTrial.fromJson(t as Map),
  ];
  final rewardOf = _ownRewards(all);
  final reliable = [
    for (var i = 0; i < all.length; i++)
      if (all[i].reliable) i
  ];

  final holds =
      [for (final i in reliable) all[i].hold].whereType<double>().toList();
  final metrics = VideoMetrics(
    totalTrials: all.length,
    reliableTrials: reliable.length,
    latencyMedian:
        _median([for (final i in reliable) all[i].latency].whereType<double>()),
    holdMedian: _median(holds),
    successRate: (targetHold == null || reliable.isEmpty)
        ? null
        : _r2(reliable.where((i) => (all[i].hold ?? -1) >= targetHold).length /
            reliable.length),
    targetHold: targetHold,
  );

  final reason = _retakeReason(result, reliable.length, config);
  if (reason != null) {
    return VideoJudgement(
        status: VideoStatus.retake,
        metrics: metrics,
        findings: const [],
        retakeReasons: [reason]);
  }

  final ctx = _Ctx(
    trials: [for (final i in reliable) all[i]],
    rewards: [for (final i in reliable) rewardOf[i]],
    targetHold: targetHold,
    correctionWords: config.correctionWords,
  );
  final findings = <VideoFinding>[];
  for (final m in skillChecks) {
    final rule = config.detectors[m.detector];
    if (rule == null) continue; // 解析阶段已拒绝，兜底
    final ev = _detectors[m.detector]?.call(ctx, rule);
    if (ev != null) {
      findings.add(
          VideoFinding(detector: m.detector, mistake: m.mistake, evidence: ev));
    }
  }
  return VideoJudgement(
      status: VideoStatus.ok, metrics: metrics, findings: findings);
}

/// 每轮自己的奖励时刻：服务端按"坐下后最近的奖励"配对，没给奖励的一轮可能借到下一轮的奖励；
/// 这里把落在下一轮开始之后的奖励视为不属于本轮（按全部轮次的时间顺序，不只可靠轮次）。
List<double?> _ownRewards(List<VideoTrial> all) {
  final order = [for (var i = 0; i < all.length; i++) i]
    ..sort((a, b) => (all[a].start ?? 0).compareTo(all[b].start ?? 0));
  final out = List<double?>.filled(all.length, null);
  for (var k = 0; k < order.length; k++) {
    final t = all[order[k]];
    final next = k + 1 < order.length ? all[order[k + 1]].start : null;
    final r = t.rewardT;
    out[order[k]] = (r != null && (next == null || r < next)) ? r : null;
  }
  return out;
}

class _Ctx {
  _Ctx({
    required this.trials,
    required this.rewards,
    required this.targetHold,
    required this.correctionWords,
  });
  final List<VideoTrial> trials; // 只有可靠轮次
  final List<double?> rewards; // 与 trials 对齐
  final double? targetHold;
  final List<String> correctionWords;
}

typedef _Detector = Map<String, Object?>? Function(_Ctx c, VideoDetectorRule r);

final Map<String, _Detector> _detectors = {
  // 有奖励的轮次中，奖励时刻比坐下时刻晚超过 threshold_sec 秒的占比 ≥ min_ratio
  'late_reward': (c, r) {
    final th = r.p('threshold_sec').toDouble();
    final rewarded = <(VideoTrial, double, double)>[]; // trial, reward, delay
    for (var i = 0; i < c.trials.length; i++) {
      final t = c.trials[i];
      final rw = c.rewards[i];
      if (rw != null && t.sitStart != null)
        rewarded.add((t, rw, rw - t.sitStart!));
    }
    if (rewarded.isEmpty) return null;
    final late = rewarded.where((e) => e.$3 > th).toList();
    if (late.length / rewarded.length < r.p('min_ratio')) return null;
    final worst = late.reduce((a, b) => b.$3 > a.$3 ? b : a);
    return {
      'sit_start': worst.$1.sitStart,
      'reward_t': worst.$2,
      'delay': _r2(worst.$3),
      'late': late.length,
      'rewarded': rewarded.length,
      'threshold_sec': th,
    };
  },

  // 狗坐下之前识别到的口令次数 ≥ threshold_count 的轮次占比 ≥ min_ratio
  // （分母：坐下前识别到口令的可靠轮次；等待类"狗先坐好再说口令"的轮次不计）
  'repeated_cue': (c, r) {
    final th = r.p('threshold_count');
    final withCue = c.trials.where((t) => t.cueTimes.isNotEmpty).toList();
    if (withCue.isEmpty) return null;
    final rep = withCue.where((t) => t.cueTimes.length >= th).toList();
    if (rep.length / withCue.length < r.p('min_ratio')) return null;
    final worst =
        rep.reduce((a, b) => b.cueTimes.length > a.cueTimes.length ? b : a);
    return {
      'cue_times': worst.cueTimes,
      'count': worst.cueTimes.length,
      'repeated': rep.length,
      'trials': withCue.length,
    };
  },

  // 本段视频的总轮次 > max_trials（只数可靠轮次，宁可漏报）
  'session_too_long': (c, r) {
    final n = c.trials.length;
    if (n <= r.p('max_trials')) return null;
    return {'trials': n, 'max_trials': r.p('max_trials')};
  },

  // 达到本次目标保持时长的可靠轮次占比 < max_success_ratio
  'target_too_long': (c, r) {
    final target = c.targetHold;
    if (target == null || c.trials.isEmpty) return null;
    final reached = c.trials.where((t) => (t.hold ?? -1) >= target).length;
    if (reached / c.trials.length >= r.p('max_success_ratio')) return null;
    return {'reached': reached, 'trials': c.trials.length, 'target': target};
  },

  // 有奖励的轮次中，奖励时刻晚于狗起身时刻的占比 ≥ min_ratio
  'reward_after_standup': (c, r) {
    final rewarded = <(VideoTrial, double)>[];
    for (var i = 0; i < c.trials.length; i++) {
      final t = c.trials[i];
      final rw = c.rewards[i];
      if (rw != null && t.sitEnd != null) rewarded.add((t, rw));
    }
    if (rewarded.isEmpty) return null;
    final after = rewarded.where((e) => e.$2 > e.$1.sitEnd!).toList();
    if (after.length / rewarded.length < r.p('min_ratio')) return null;
    final ex = after.first;
    return {
      'sit_end': ex.$1.sitEnd,
      'reward_t': ex.$2,
      'after': after.length,
      'rewarded': rewarded.length,
    };
  },

  // 结束方式为"狗自行起身"的可靠轮次占比 ≥ min_ratio
  'self_release': (c, r) {
    if (c.trials.isEmpty) return null;
    final n = c.trials.where((t) => t.endedBy == 'stand_up').length;
    if (n / c.trials.length < r.p('min_ratio')) return null;
    return {'self': n, 'trials': c.trials.length};
  },

  // 保持时长 ≥ min_hold_sec 的轮次中，保持期间没有任何标记词的占比 ≥ min_ratio
  'no_hold_marker': (c, r) {
    final long =
        c.trials.where((t) => (t.hold ?? -1) >= r.p('min_hold_sec')).toList();
    if (long.isEmpty) return null;
    final silent = long.where((t) => t.markersDuringHold == 0).toList();
    if (silent.length / long.length < r.p('min_ratio')) return null;
    final ex = silent.reduce((a, b) => (b.hold ?? 0) > (a.hold ?? 0) ? b : a);
    return {
      'hold': ex.hold,
      'markers': ex.markersDuringHold,
      'silent': silent.length,
      'long': long.length,
    };
  },

  // 有口令时刻的轮次中，口令到进入目标姿势的时间超过 threshold_sec 秒的占比 ≥ min_ratio
  // （latency 为空的轮次不计：狗本来就在目标姿势里，或口令是用户补标的）
  'slow_response': (c, r) {
    final th = r.p('threshold_sec').toDouble();
    final timed = c.trials.where((t) => t.latency != null && t.cueT != null).toList();
    if (timed.isEmpty) return null;
    final slow = timed.where((t) => t.latency! > th).toList();
    if (slow.length / timed.length < r.p('min_ratio')) return null;
    final worst = slow.reduce((a, b) => b.latency! > a.latency! ? b : a);
    return {
      'cue_t': worst.cueT,
      'sit_start': worst.sitStart,
      'latency': _r2(worst.latency!),
      'slow': slow.length,
      'trials': timed.length,
      'threshold_sec': th,
    };
  },

  // 任一轮中识别到 correction_words 中的词
  'verbal_correction': (c, r) {
    final hits = [
      for (final t in c.trials)
        for (final x in t.corrections)
          // 只认内容库词表里的词（证据里会展示这个词）
          if (c.correctionWords.contains(x.word)) {'word': x.word, 't': x.t},
    ];
    if (hits.isEmpty) return null;
    return {'hits': hits};
  },
};

/// 已实现的检测器 ID（供内容解析校验）。
Set<String> get implementedVideoDetectors => _detectors.keys.toSet();

// ---------------------------------------------------------------------------
// 本次目标保持时长
// ---------------------------------------------------------------------------

/// 每个技能成功标准里写明的保持秒数（M5 简报 4.3：写在一张 Dart 常量表里并注明出处）。
/// 出处（content/skills/*.yaml 的 tutorial.success_criteria 原文）：
/// - sit：「…狗在 3 秒内坐下并保持 2 秒以上…」→ 2
/// - stay_short：「…狗坐着等满 3 秒不起身…」→ 3
/// - stay_long：「…时长：你站在狗身边，狗等满 30 秒直到"好了"才起身…」→ 30
/// - down：「…狗在 3 秒内趴下（肘部碰地）并保持 2 秒以上…」→ 2
/// - calm_settle：「…能安静趴 30 秒以上…」→ 30
/// 单测会核对这些数字确实出现在对应技能的成功标准原文里。
const videoTargetHoldSec = <String, int>{
  'sit': 2,
  'stay_short': 3,
  'stay_long': 30,
  'down': 2,
  'calm_settle': 30,
};

/// 视频纠错的目标姿势（技能 YAML 的 video_target，v1.5 起；缺省 sit）。
enum VideoTarget { sit, down }
