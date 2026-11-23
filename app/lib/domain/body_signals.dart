/// 狗的身体信号（v1.6，2026-11-23）。纯函数，无 IO、无 Flutter。
///
/// 视频分析服务（POST /body-check、上传分析、实时计时）只给出"哪些信号在什么时候出现"；
/// 本文件按内容库 body_signals.yaml 的规则判断：
/// 1. 练前状态检查：平静 / 兴奋 / 有压力信号 / 看不清；
/// 2. 练习中：最近一段时间的压力信号够不够"该停了"；
/// 3. 最近几次检查 → 训练节奏建议；
/// 4. 需要转介的信号。
/// 本文件不产生任何文字；展示文字只有内容库原文与 `features/body/body_strings.dart` 的模板。
library;

/// 一种信号的内容库条目。
class BodySignalInfo {
  const BodySignalInfo({
    required this.id,
    required this.name,
    required this.looksLike,
    required this.meaning,
    required this.isStress,
  });
  final String id;
  final String name;
  final String looksLike;
  final String meaning;
  final bool isStress; // stress / arousal
}

class BodySignalsConfig {
  const BodySignalsConfig({
    required this.signals,
    required this.minUsableFrames,
    required this.stressedAnyOf,
    required this.stressedCountOf,
    required this.stressedMinCount,
    required this.excitedCountOf,
    required this.excitedMinCount,
    required this.excitedMotionOver,
    required this.advice,
    required this.calmDownSkill,
    required this.sessionWindowS,
    required this.stopCountOf,
    required this.stopMinCount,
    required this.stopAdvice,
    required this.pacingLookback,
    required this.pacingMinSame,
    required this.pacingAdvice,
    required this.referralSignals,
    required this.referralAdvice,
    required this.sources,
  });

  /// 按 YAML 顺序。
  final Map<String, BodySignalInfo> signals;
  final int minUsableFrames;
  final List<String> stressedAnyOf;
  final List<String> stressedCountOf;
  final int stressedMinCount;
  final List<String> excitedCountOf;
  final int excitedMinCount;
  final double excitedMotionOver;

  /// calm / excited / stressed / unclear → 原文。
  final Map<BodyState, String> advice;
  final String calmDownSkill;
  final double sessionWindowS;
  final List<String> stopCountOf;
  final int stopMinCount;
  final String stopAdvice;
  final int pacingLookback;
  final int pacingMinSame;

  /// stressed / excited → 原文。
  final Map<BodyState, String> pacingAdvice;
  final List<String> referralSignals;
  final String referralAdvice;
  final List<String> sources;
}

enum BodyState { calm, excited, stressed, unclear }

/// 服务端返回的一次身体信号测量（/body-check、result.body、实时快照）。
class BodySummary {
  const BodySummary({
    required this.usable,
    required this.signals,
    this.motionMean,
    this.kind = 'video',
  });
  final int usable;
  final List<({String id, double start, double end})> signals;
  final double? motionMean;
  final String kind;

  int count(String id) => signals.where((s) => s.id == id).length;

  static double _d(Object? v) => (v as num).toDouble();

  factory BodySummary.fromJson(Map j) => BodySummary(
        usable: (j['usable'] as num?)?.toInt() ?? 0,
        kind: '${j['kind'] ?? 'video'}',
        motionMean: ((j['metrics'] as Map?)?['motion_mean'] as num?)?.toDouble(),
        signals: [
          for (final s in (j['signals'] as List? ?? const []))
            (id: '${(s as Map)['id']}', start: _d(s['t_start']), end: _d(s['t_end'])),
        ],
      );

  Map<String, Object?> toJson() => {
        'usable': usable,
        'kind': kind,
        'metrics': {'motion_mean': motionMean},
        'signals': [
          for (final s in signals) {'id': s.id, 't_start': s.start, 't_end': s.end},
        ],
      };
}

/// 一次判断：状态 + 依据（出现的信号，按内容库顺序）+ 是否需要转介。
class BodyAssessment {
  const BodyAssessment({
    required this.state,
    required this.evidence,
    required this.referral,
  });
  final BodyState state;

  /// 出现过的信号 id → 次数（只含内容库里有的信号）。
  final Map<String, int> evidence;
  final bool referral;
}

/// 练前状态检查（以及视频结果里"狗的状态"）。
BodyAssessment assessBody(BodySummary s, BodySignalsConfig c) {
  final evidence = <String, int>{
    for (final id in c.signals.keys)
      if (s.count(id) > 0) id: s.count(id),
  };
  final referral = c.referralSignals.any((id) => s.count(id) > 0);
  // 照片只有一帧：不看可用帧门槛（看得到狗就行）
  final enough = s.kind == 'image' ? s.usable >= 1 : s.usable >= c.minUsableFrames;
  if (!enough) {
    return BodyAssessment(state: BodyState.unclear, evidence: evidence, referral: referral);
  }
  int sum(List<String> ids) => ids.fold(0, (a, id) => a + s.count(id));
  final stressed = c.stressedAnyOf.any((id) => s.count(id) > 0) || sum(c.stressedCountOf) >= c.stressedMinCount;
  if (stressed) {
    return BodyAssessment(state: BodyState.stressed, evidence: evidence, referral: referral);
  }
  final excited = sum(c.excitedCountOf) >= c.excitedMinCount || (s.motionMean ?? 0) > c.excitedMotionOver;
  return BodyAssessment(
      state: excited ? BodyState.excited : BodyState.calm, evidence: evidence, referral: referral);
}

/// 练习中：最近窗口内的压力信号次数（实时快照的 counts，或视频里某一段）是否够"该停了"。
bool shouldStop(Map<String, int> recentCounts, BodySignalsConfig c) =>
    c.stopCountOf.fold<int>(0, (a, id) => a + (recentCounts[id] ?? 0)) >= c.stopMinCount;

/// 视频里任意 [BodySignalsConfig.sessionWindowS] 秒窗口内的压力信号最多出现几次，以及那个窗口的起点。
({int count, double? start}) worstStopWindow(BodySummary s, BodySignalsConfig c) {
  final times = [
    for (final x in s.signals)
      if (c.stopCountOf.contains(x.id)) x.start,
  ]..sort();
  var best = 0;
  double? at;
  for (var i = 0; i < times.length; i++) {
    var n = 0;
    for (var j = i; j < times.length && times[j] - times[i] <= c.sessionWindowS; j++) {
      n++;
    }
    if (n > best) {
      best = n;
      at = times[i];
    }
  }
  return (count: best, start: at);
}

/// 最近几次检查（新的在前）→ 节奏建议的状态；不够一致时为 null。
BodyState? pacingState(List<BodyState> recentNewestFirst, BodySignalsConfig c) {
  final recent = recentNewestFirst.where((s) => s != BodyState.unclear).take(c.pacingLookback).toList();
  for (final s in [BodyState.stressed, BodyState.excited]) {
    if (recent.where((x) => x == s).length >= c.pacingMinSame) return s;
  }
  return null;
}

/// 一周内各状态的次数（周报用）。
Map<BodyState, int> weeklyCounts(Iterable<BodyState> states) {
  final out = <BodyState, int>{};
  for (final s in states) {
    out[s] = (out[s] ?? 0) + 1;
  }
  return out;
}

// ---------------------------------------------------------------------------
// 解析（content/body_signals.yaml）
// ---------------------------------------------------------------------------

/// 解析失败抛 [FormatException]（上层包装成 ContentParseException）。
BodySignalsConfig bodySignalsFromMap(Map m) {
  T req<T>(Map map, String k) {
    final v = map[k];
    if (v is! T) throw FormatException('body_signals.yaml 缺字段或类型不对：$k');
    return v;
  }

  List<String> strs(Map map, String k) => [for (final v in (map[k] as List? ?? const [])) '$v'];
  final signals = <String, BodySignalInfo>{};
  for (final s in req<List>(m, 'signals')) {
    final x = s as Map;
    final id = req<String>(x, 'id');
    signals[id] = BodySignalInfo(
      id: id,
      name: req<String>(x, 'name'),
      looksLike: req<String>(x, 'looks_like'),
      meaning: req<String>(x, 'meaning'),
      isStress: req<String>(x, 'category') == 'stress',
    );
  }
  final r = req<Map>(m, 'readiness');
  final st = req<Map>(r, 'stressed');
  final ex = req<Map>(r, 'excited');
  final adv = req<Map>(r, 'advice');
  final ses = req<Map>(m, 'in_session');
  final pac = req<Map>(m, 'pacing');
  final ref = req<Map>(m, 'referral');
  final cfg = BodySignalsConfig(
    signals: signals,
    minUsableFrames: req<int>(r, 'min_usable_frames'),
    stressedAnyOf: strs(st, 'any_of'),
    stressedCountOf: strs(st, 'count_of'),
    stressedMinCount: req<int>(st, 'min_count'),
    excitedCountOf: strs(ex, 'count_of'),
    excitedMinCount: req<int>(ex, 'min_count'),
    excitedMotionOver: req<num>(ex, 'motion_mean_over').toDouble(),
    advice: {
      for (final s in BodyState.values) s: req<String>(adv, s.name),
    },
    calmDownSkill: req<String>(r, 'calm_down_skill'),
    sessionWindowS: req<num>(ses, 'window_s').toDouble(),
    stopCountOf: strs(ses, 'stop_count_of'),
    stopMinCount: req<int>(ses, 'stop_min_count'),
    stopAdvice: req<String>(ses, 'stop_advice'),
    pacingLookback: req<int>(pac, 'lookback'),
    pacingMinSame: req<int>(pac, 'min_same'),
    pacingAdvice: {
      BodyState.stressed: req<String>(pac, 'stressed'),
      BodyState.excited: req<String>(pac, 'excited'),
    },
    referralSignals: strs(ref, 'signals'),
    referralAdvice: req<String>(ref, 'advice'),
    sources: strs(m, 'sources'),
  );
  for (final id in [...cfg.stressedAnyOf, ...cfg.stressedCountOf, ...cfg.excitedCountOf, ...cfg.stopCountOf, ...cfg.referralSignals]) {
    if (!signals.containsKey(id)) throw FormatException('body_signals.yaml 引用不存在的信号 $id');
  }
  return cfg;
}
