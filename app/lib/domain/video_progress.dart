/// 视频纠错的"多次上传直到改正"（v3，2026-11-23）。纯函数，无 IO、无 Flutter。
///
/// 像做测试一样：每次上传是一次"检查"，和同一技能的上一次检查比：
/// - 已改正：上次检测到、这次没有的问题；
/// - 还要改：上次有、这次还有；
/// - 新发现：上次没有、这次出现。
/// 需要重拍的上传（看不清 / 没录到声音等）不算一次检查，也不参与比较。
/// 一次检查没有检测到任何问题就是"通过"。
library;

import 'video_checks.dart';

/// 一次已判定的检查（历史记录里 status == ok 的那些），按时间从早到晚。
class VideoAttempt {
  const VideoAttempt({required this.at, required this.judgement, this.id});
  final String? id;
  final DateTime at;
  final VideoJudgement judgement;

  Set<String> get detectors => {for (final f in judgement.findings) f.detector};
  bool get passed =>
      judgement.status == VideoStatus.ok && judgement.findings.isEmpty;
}

/// 这次检查和上一次检查的比较，以及到这次为止的整体纠错进度。
class AttemptProgress {
  const AttemptProgress({
    required this.attemptNo,
    required this.fixed,
    required this.still,
    required this.fresh,
    required this.everFound,
    required this.passed,
    this.previousAt,
  });

  /// 第几次检查（从 1 开始，只数已判定的上传）。
  final int attemptNo;

  /// 上一次检查的时间；第一次检查为 null。
  final DateTime? previousAt;

  /// 上次有、这次没有的问题（取上一次的 finding，用来显示常见错误原文）。
  final List<VideoFinding> fixed;

  /// 上次有、这次还有。
  final List<VideoFinding> still;

  /// 上次没有、这次出现（第一次检查时等于全部问题）。
  final List<VideoFinding> fresh;

  /// 从第一次检查到这次，出现过的全部检测器（"已改正 X / Y" 的 Y）。
  final Set<String> everFound;

  /// 这次没有检测到任何问题。
  final bool passed;

  bool get isFirst => previousAt == null;

  /// 出现过、这次已经没有的问题个数（"已改正 X / Y" 的 X）。
  int get fixedTotal => everFound.length - (still.length + fresh.length);
}

/// 计算第 [index] 次检查（[attempts] 按时间升序）的进度。
AttemptProgress progressAt(List<VideoAttempt> attempts, int index) {
  final cur = attempts[index];
  final prev = index > 0 ? attempts[index - 1] : null;
  final prevDet = prev?.detectors ?? const <String>{};
  final curDet = cur.detectors;
  return AttemptProgress(
    attemptNo: index + 1,
    previousAt: prev?.at,
    fixed: [
      for (final f in prev?.judgement.findings ?? const <VideoFinding>[])
        if (!curDet.contains(f.detector)) f,
    ],
    still: [
      for (final f in cur.judgement.findings)
        if (prevDet.contains(f.detector)) f,
    ],
    fresh: [
      for (final f in cur.judgement.findings)
        if (!prevDet.contains(f.detector)) f,
    ],
    everFound: {for (var i = 0; i <= index; i++) ...attempts[i].detectors},
    passed: cur.passed,
  );
}

/// 最新一次检查的进度；没有任何已判定的检查时为 null。
AttemptProgress? latestProgress(List<VideoAttempt> attempts) =>
    attempts.isEmpty ? null : progressAt(attempts, attempts.length - 1);

/// 只保留已判定的检查并按时间升序（输入可以混有重拍记录、顺序任意）。
List<VideoAttempt> judgedAttempts(Iterable<VideoAttempt> all) =>
    [for (final a in all) if (a.judgement.status == VideoStatus.ok) a]
      ..sort((a, b) => a.at.compareTo(b.at));
