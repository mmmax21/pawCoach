/// 视频纠错（PRD AI-4，M5 简报 4.3 / 4.4）。
///
/// 流程：安全勾选 → 选视频 → 上传 → 每 3 秒轮询（5 分钟超时）→ 判定 → 结果页 → 存本机历史。
/// 页面上的文字只有两类：内容库原文（common_mistakes / success_criteria / 技能名）与
/// [VideoStrings] 的模板。不展示视频服务返回的 coach 字段。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/video/video_api.dart';
import '../../domain/models.dart';
import '../../core/theme.dart';
import '../../domain/video_checks.dart';
import '../../domain/video_progress.dart';
import '../../data/body/body_api.dart';
import '../../data/repositories/body_repository.dart';
import '../../domain/body_signals.dart';
import '../body/body_strings.dart';
import '../body/body_widgets.dart';
import 'guided_capture_page.dart';
import 'video_strings.dart';

/// 组装上传 meta（简报 4.3）。口令取该狗口令表，词表取 video_checks.yaml，目标秒数取常量表。
Map<String, Object?> buildVideoMeta({
  required Skill skill,
  required VideoChecksConfig config,
  String? dogCue,
}) =>
    {
      'cues': [dogCue ?? skill.defaultCue],
      'marker_words': config.markerWords,
      'release_words': config.releaseWords,
      'correction_words': config.correctionWords,
      'target_hold': videoTargetHoldSec[skill.id]?.toDouble(),
      'target_pose': skill.videoTarget.name,
      'language': 'zh',
      'max_duration': videoMaxDurationSec,
    };

enum _Phase { intro, uploading, waiting, realigning, result, error }

class VideoCheckPage extends ConsumerStatefulWidget {
  const VideoCheckPage({super.key, required this.skillId});
  final String skillId;

  @override
  ConsumerState<VideoCheckPage> createState() => _VideoCheckPageState();
}

class _VideoCheckPageState extends ConsumerState<VideoCheckPage> {
  _Phase _phase = _Phase.intro;
  bool _unsafe = false;
  String? _videoPath;
  VideoErrorKind? _error;
  VideoJudgement? _judgement;
  // 减少重拍：补标口令要用到上次的原始结果与 meta；重新判定后覆盖同一条记录
  Map<String, dynamic>? _result;
  Map<String, Object?>? _meta;
  String? _savedId;
  AttemptProgress? _progress; // 多次上传：和上一次检查比
  String? _stage;
  List<double>? _realignFailedCues; // 重新判定失败时记下用户的选择，重试用
  int _run = 0; // 每次上传自增；页面关闭或重新开始时让旧的轮询自行退出

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  Future<void> _pick(bool camera) async {
    if (_unsafe) return; // 简报 4.4：勾选安全项后不上传
    final path = await ref.read(videoPickerProvider).pick(camera: camera);
    if (path == null || !mounted) return;
    _videoPath = path;
    await _upload();
  }

  /// 引导拍摄：进入取景页，拍完拿到视频路径后走和相册选择完全相同的上传分析。
  Future<void> _guided() async {
    if (_unsafe) return;
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const GuidedCapturePage()),
    );
    if (path == null || !mounted) return;
    _videoPath = path;
    await _upload();
  }

  Future<void> _upload() async {
    final path = _videoPath;
    if (path == null || _unsafe) return;
    final lib = await ref.read(contentLibraryProvider.future);
    final skill = lib.skillById[widget.skillId]!;
    final config = lib.videoChecks!;
    final dog = ref.read(currentDogProvider).valueOrNull;
    String? cue;
    if (dog != null) {
      final cues = await ref.read(profileRepositoryProvider).cues(dog.id);
      cue = cues
          .where((c) => c.skillId == skill.id)
          .map((c) => c.cueWord)
          .firstOrNull;
    }
    final run = ++_run;
    setState(() {
      _phase = _Phase.uploading;
      _error = null;
      _stage = null;
      _realignFailedCues = null;
    });
    final api = ref.read(videoAnalysisApiProvider);
    final polling = ref.read(videoPollingProvider);
    final meta = buildVideoMeta(skill: skill, config: config, dogCue: cue);
    try {
      final job = await api.submit(filePath: path, meta: meta);
      if (!mounted || run != _run) return;
      setState(() => _phase = _Phase.waiting);
      final deadline = DateTime.now().add(polling.timeout);
      Map<String, dynamic>? result;
      var waited = Duration.zero;
      while (result == null) {
        await Future<void>.delayed(polling.interval);
        waited += polling.interval;
        if (!mounted || run != _run) return;
        final s = await api.poll(job);
        if (!mounted || run != _run) return;
        switch (s) {
          case VideoJobDone(result: final r):
            result = r;
          case VideoJobFailed(:final error):
            throw VideoApiException(
                isTooLongError(error)
                    ? VideoErrorKind.tooLong
                    : VideoErrorKind.failed,
                error);
          case VideoJobPending(:final stage):
            if (stage != _stage) setState(() => _stage = stage);
            if (waited >= polling.timeout || DateTime.now().isAfter(deadline)) {
              throw VideoApiException(VideoErrorKind.timeout);
            }
        }
      }
      final j = judgeVideo(
        result: result,
        skillChecks: skill.videoChecks,
        config: config,
        targetHold: videoTargetHoldSec[skill.id]?.toDouble(),
      );
      String? savedId;
      if (dog != null) {
        savedId = await ref.read(videoRepositoryProvider).save(
              dogId: dog.id,
              skillId: skill.id,
              judgement: j,
              contentVersion: lib.version,
              now: ref.read(clockProvider)(),
            );
      }
      final progress = await _progressFor(dog?.id, skill.id, savedId, j);
      // v1.6：服务端附带的身体信号 → 存一条"视频"来源的状态记录（周报、节奏建议用）
      final bodyCfg = lib.bodySignals;
      if (bodyCfg != null && dog != null && result['body'] is Map && j.status == VideoStatus.ok) {
        final s = BodySummary.fromJson(result['body'] as Map);
        final a = assessBody(s, bodyCfg);
        if (a.state != BodyState.unclear) {
          await ref.read(bodyRepositoryProvider).save(
                dogId: dog.id,
                assessment: a,
                summary: s,
                context: BodyContext.video,
                contentVersion: lib.version,
                now: ref.read(clockProvider)(),
                skillId: skill.id,
              );
        }
      }
      if (!mounted || run != _run) return;
      setState(() {
        _judgement = j;
        _result = result;
        _meta = meta;
        _savedId = savedId;
        _progress = progress;
        _phase = _Phase.result;
      });
    } on VideoApiException catch (e) {
      if (!mounted || run != _run) return;
      setState(() {
        _error = e.kind;
        _phase = _Phase.error;
      });
    } catch (_) {
      if (!mounted || run != _run) return;
      setState(() {
        _error = VideoErrorKind.failed;
        _phase = _Phase.error;
      });
    }
  }

  /// 用户确认了哪几次坐下是听口令坐下的 → 服务端重新对齐（不用重传视频）→ 重新判定，覆盖同一条记录。
  Future<void> _confirmCues(List<double> sitStarts) async {
    final result = _result, meta = _meta;
    if (result == null || meta == null) return;
    final lib = await ref.read(contentLibraryProvider.future);
    final skill = lib.skillById[widget.skillId]!;
    final config = lib.videoChecks!;
    final run = ++_run;
    setState(() {
      _phase = _Phase.realigning;
      _realignFailedCues = null;
    });
    try {
      final r = await ref
          .read(videoAnalysisApiProvider)
          .realign(result: result, meta: meta, userCueSits: sitStarts);
      final j = judgeVideo(
        result: r,
        skillChecks: skill.videoChecks,
        config: config,
        targetHold: videoTargetHoldSec[skill.id]?.toDouble(),
      );
      final id = _savedId;
      if (id != null) await ref.read(videoRepositoryProvider).replace(id, j);
      final dog = ref.read(currentDogProvider).valueOrNull;
      final progress = await _progressFor(dog?.id, skill.id, id, j);
      if (!mounted || run != _run) return;
      setState(() {
        _judgement = j;
        _result = r;
        _progress = progress;
        _phase = _Phase.result;
      });
    } catch (_) {
      if (!mounted || run != _run) return;
      setState(() {
        _realignFailedCues = sitStarts;
        _phase = _Phase.result;
      });
    }
  }

  /// 读出该技能的全部检查，算这次（[savedId]）相对上一次的进度；没有狗档案时只看这一次。
  Future<AttemptProgress?> _progressFor(
      String? dogId, String skillId, String? savedId, VideoJudgement j) async {
    if (j.status != VideoStatus.ok) return null;
    if (dogId == null || savedId == null) {
      return progressAt(
          [VideoAttempt(at: DateTime.now(), judgement: j)], 0);
    }
    final all = await ref.read(videoRepositoryProvider).attempts(dogId, skillId);
    final i = all.indexWhere((a) => a.id == savedId);
    return i < 0 ? null : progressAt(all, i);
  }

  void _restart() {
    _run++;
    setState(() {
      _phase = _Phase.intro;
      _judgement = null;
      _error = null;
      _videoPath = null;
      _result = null;
      _meta = null;
      _savedId = null;
      _progress = null;
      _stage = null;
      _realignFailedCues = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(VideoStrings.pageTitle)),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (lib) {
          final skill = lib.skillById[widget.skillId];
          if (skill == null || lib.videoChecks == null)
            return const SizedBox.shrink();
          return switch (_phase) {
            _Phase.intro => _intro(context, skill),
            _Phase.uploading => _busy(VideoStrings.uploading),
            _Phase.waiting => _busy(_stage == 'precheck'
                ? VideoStrings.prechecking
                : VideoStrings.analyzing),
            _Phase.realigning => _busy(VideoStrings.realigning),
            _Phase.error => _errorView(),
            _Phase.result => VideoResultView(
                skill: skill,
                judgement: _judgement!,
                config: lib.videoChecks!,
                progress: _progress,
                body: _result?['body'] is Map ? BodySummary.fromJson(_result!['body'] as Map) : null,
                bodyConfig: lib.bodySignals,
                onReupload: _restart,
                candidates:
                    _result == null ? const [] : cueCandidates(_result!),
                onConfirmCues: _confirmCues,
                realignFailedCues: _realignFailedCues,
              ),
          };
        },
      ),
    );
  }

  Widget _intro(BuildContext context, Skill skill) {
    final t = Theme.of(context).textTheme;
    return ListView(
      key: const Key('video_intro'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(skill.name, style: t.titleLarge),
        const SizedBox(height: 8),
        Text(VideoStrings.shootingHintFor(skill.videoTarget)),
        const SizedBox(height: 16),
        CheckboxListTile(
          key: const Key('video_safety_check'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _unsafe,
          onChanged: (v) => setState(() => _unsafe = v ?? false),
          title: const Text(VideoStrings.safetyCheck),
        ),
        const SizedBox(height: 16),
        if (_unsafe)
          Card(
            key: const Key('video_safety_stop'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(VideoStrings.safetyStop),
            ),
          )
        else ...[
          FilledButton.icon(
            key: const Key('video_guided'),
            icon: const Icon(Icons.center_focus_strong_outlined),
            label: const Text(VideoStrings.guidedEntry),
            onPressed: _guided,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('video_pick_gallery'),
            icon: const Icon(Icons.video_library_outlined),
            label: const Text(VideoStrings.pickGallery),
            onPressed: () => _pick(false),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('video_pick_camera'),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text(VideoStrings.pickCamera),
            onPressed: () => _pick(true),
          ),
        ],
      ],
    );
  }

  Widget _busy(String text) => Center(
        key: const Key('video_waiting'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(text),
          ],
        ),
      );

  Widget _errorView() {
    final msg = switch (_error) {
      VideoErrorKind.unreachable => VideoStrings.errUnreachable,
      VideoErrorKind.tooLong => VideoStrings.errTooLong,
      VideoErrorKind.timeout => VideoStrings.errTimeout,
      _ => VideoStrings.errFailed,
    };
    return Padding(
      key: const Key('video_error'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(msg),
          const SizedBox(height: 16),
          if (_error != VideoErrorKind.tooLong)
            FilledButton(
              key: const Key('video_retry'),
              onPressed: _upload,
              child: const Text(VideoStrings.retry),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('video_repick'),
            onPressed: _restart,
            child: const Text(VideoStrings.repick),
          ),
        ],
      ),
    );
  }
}

/// 结果页（简报 4.3，顺序固定）：重拍提示 / 本次数据 / 检测到的问题或无问题提示 + 成功标准 / 跟练与教程按钮。
class VideoResultView extends StatelessWidget {
  const VideoResultView({
    super.key,
    required this.skill,
    required this.judgement,
    required this.config,
    this.onReupload,
    this.candidates = const [],
    this.onConfirmCues,
    this.realignFailedCues,
    this.progress,
    this.body,
    this.bodyConfig,
  });

  /// v1.6：这段视频里狗的身体信号（服务端 result.body）与内容库规则；任一为 null 时不显示。
  final BodySummary? body;
  final BodySignalsConfig? bodyConfig;
  final Skill skill;
  final VideoJudgement judgement;
  final VideoChecksConfig config;
  final VoidCallback? onReupload;

  /// 多次上传：这次检查和上一次的比较；null 时不显示（旧调用方）。
  final AttemptProgress? progress;

  /// 减少重拍：可以补标口令的坐下；[onConfirmCues] 为 null（历史页）时不显示补标。
  final List<VideoSitCandidate> candidates;
  final void Function(List<double> sitStarts)? onConfirmCues;

  /// 上次重新判定失败时用户的选择（显示失败提示，保留勾选）。
  final List<double>? realignFailedCues;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (judgement.status == VideoStatus.retake) {
      // 简报 4.3 第 1 条：retake 时只显示重拍提示与重新上传按钮，不显示任何纠错
      final reason = judgement.retakeReasons.firstOrNull;
      final canConfirm = onConfirmCues != null &&
          candidates.isNotEmpty &&
          (reason == RetakeReason.cueNotHeard ||
              reason == RetakeReason.noVoice);
      return ListView(
        key: const Key('video_retake'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
              VideoStrings.retakeFor(reason,
                  minTrials: config.minReliableTrials,
                  target: skill.videoTarget),
              key: const Key('video_retake_text')),
          const SizedBox(height: 8),
          Text(VideoStrings.retakeNotCounted,
              style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
          if (canConfirm) ...[
            const SizedBox(height: 16),
            _CueConfirmCard(
              key: const Key('video_cue_confirm'),
              candidates: candidates,
              target: skill.videoTarget,
              initial: realignFailedCues,
              failed: realignFailedCues != null,
              onConfirm: onConfirmCues!,
            ),
          ],
          const SizedBox(height: 16),
          if (onReupload != null)
            FilledButton(
              key: const Key('video_reupload'),
              onPressed: onReupload,
              child: const Text(VideoStrings.reupload),
            ),
        ],
      );
    }
    final m = judgement.metrics;
    String secOr(double? v) =>
        v == null ? VideoStrings.noData : VideoStrings.seconds(v);
    return ListView(
      key: const Key('video_result'),
      padding: const EdgeInsets.all(16),
      children: [
        if (progress != null) ...[
          _ProgressCard(skill: skill, progress: progress!),
          const SizedBox(height: 12),
        ],
        Card(
          key: const Key('video_metrics'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(VideoStrings.metricsTitle, style: t.titleMedium),
                const SizedBox(height: 8),
                _row(VideoStrings.latency, secOr(m.latencyMedian)),
                _row(VideoStrings.hold, secOr(m.holdMedian)),
                if (m.targetHold != null)
                  _row(
                    VideoStrings.successRate(m.targetHold!),
                    m.successRate == null
                        ? VideoStrings.noData
                        : VideoStrings.percent(m.successRate!),
                  ),
                _row(VideoStrings.reliable,
                    VideoStrings.ratio(m.reliableTrials, m.totalTrials)),
              ],
            ),
          ),
        ),
        if (body != null && bodyConfig != null) ..._bodySection(context, body!, bodyConfig!),
        const SizedBox(height: 16),
        if (judgement.findings.isNotEmpty) ...[
          Text(VideoStrings.findingsTitle, style: t.titleMedium),
          const SizedBox(height: 8),
          for (final f in judgement.findings)
            Card(
              key: Key('video_finding_${f.detector}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (progress != null && !progress!.isFirst)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _Tag(
                          key: Key('video_finding_tag_${f.detector}'),
                          text: progress!.still
                                  .any((s) => s.detector == f.detector)
                              ? VideoStrings.tagStill
                              : VideoStrings.tagFresh,
                          color: progress!.still
                                  .any((s) => s.detector == f.detector)
                              ? AppColors.primary
                              : AppColors.streak,
                        ),
                      ),
                    // 常见错误原文（逐字取自内容库）
                    Text(skill.tutorial.commonMistakes[f.mistake],
                        style: t.bodyLarge),
                    const SizedBox(height: 8),
                    Text(VideoStrings.evidence(f, target: skill.videoTarget),
                        style: t.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
            ),
        ] else ...[
          const Text(VideoStrings.noFindings, key: Key('video_no_findings')),
          const SizedBox(height: 12),
          Text(VideoStrings.successCriteria, style: t.titleSmall),
          const SizedBox(height: 4),
          Text(skill.tutorial.successCriteria),
        ],
        const SizedBox(height: 24),
        for (var p = 1; p <= skill.scriptParts; p++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              key: Key('video_practice_$p'),
              onPressed: () => context.push('/training/${skill.id}/$p'),
              child: Text(skill.scriptParts <= 1
                  ? VideoStrings.practice
                  : VideoStrings.practicePart(p)),
            ),
          ),
        OutlinedButton(
          key: const Key('video_tutorial'),
          onPressed: () => context.push('/skill/${skill.id}'),
          child: const Text(VideoStrings.tutorial),
        ),
        if (onReupload != null) ...[
          const SizedBox(height: 8),
          if (judgement.findings.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('video_reupload'),
              icon: const Icon(Icons.replay),
              onPressed: onReupload,
              label: const Text(VideoStrings.checkAgain),
            )
          else
            TextButton(
              key: const Key('video_reupload'),
              onPressed: onReupload,
              child: const Text(VideoStrings.reupload),
            ),
        ],
      ],
    );
  }

  List<Widget> _bodySection(BuildContext context, BodySummary s, BodySignalsConfig c) {
    final a = assessBody(s, c);
    if (a.state == BodyState.unclear) return const [];
    final w = worstStopWindow(s, c);
    return [
      const SizedBox(height: 16),
      Text(BodyStrings.videoTitle, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      BodyAssessmentCard(key: const Key('video_body'), assessment: a, config: c, showAdvice: false),
      if (w.count >= c.stopMinCount && w.start != null) ...[
        const SizedBox(height: 8),
        BodyStopNotice(
          text: c.stopAdvice,
          detail: BodyStrings.stopWindow(w.start!, c.sessionWindowS, w.count),
        ),
      ],
    ];
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value),
          ],
        ),
      );
}

/// 结果页顶部：第几次检查、和上次比（已改正 / 还要改 / 新发现）、整体进度或"通过"。
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.skill, required this.progress});
  final Skill skill;
  final AttemptProgress progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = progress;
    final passed = p.passed;
    final mistakes = skill.tutorial.commonMistakes;
    Widget line(IconData icon, Color color, String label, VideoFinding f,
            String key) =>
        Padding(
          key: Key(key),
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: t.labelLarge?.copyWith(color: color)),
              const SizedBox(width: 8),
              Expanded(child: Text(mistakes[f.mistake], style: t.bodyMedium)),
            ],
          ),
        );
    return Card(
      key: const Key('video_progress'),
      color: passed ? AppColors.successSoft : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(VideoStrings.attemptTitle(p.attemptNo),
                    key: const Key('video_attempt_no'), style: t.titleMedium),
                const Spacer(),
                if (passed)
                  _Tag(
                      key: const Key('video_passed'),
                      text: VideoStrings.passed,
                      color: AppColors.success,
                      icon: Icons.verified)
                else if (p.everFound.isNotEmpty && !p.isFirst)
                  Text(VideoStrings.fixedProgress(p.fixedTotal, p.everFound.length),
                      key: const Key('video_fixed_progress'),
                      style: t.labelLarge?.copyWith(color: AppColors.success)),
              ],
            ),
            if (passed) ...[
              const SizedBox(height: 4),
              Text(VideoStrings.passedNote, style: t.bodyMedium),
            ],
            if (!p.isFirst) ...[
              const SizedBox(height: 10),
              Text(VideoStrings.vsLast,
                  style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
              for (final f in p.fixed)
                line(Icons.check_circle, AppColors.success,
                    VideoStrings.fixedLabel, f, 'video_fixed_${f.detector}'),
              for (final f in p.still)
                line(Icons.error_outline, AppColors.primary,
                    VideoStrings.stillLabel, f, 'video_still_${f.detector}'),
              for (final f in p.fresh)
                line(Icons.fiber_new_outlined, AppColors.streak,
                    VideoStrings.freshLabel, f, 'video_fresh_${f.detector}'),
            ],
            if (!passed) ...[
              const SizedBox(height: 10),
              Text(p.isFirst ? VideoStrings.firstAttemptNote : VideoStrings.againNote,
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({super.key, required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// 补标口令：列出没配上口令的坐下，用户勾选"这次是听口令坐下的"。
class _CueConfirmCard extends StatefulWidget {
  const _CueConfirmCard({
    super.key,
    required this.candidates,
    required this.onConfirm,
    this.initial,
    this.failed = false,
    this.target = VideoTarget.sit,
  });
  final VideoTarget target;
  final List<VideoSitCandidate> candidates;
  final void Function(List<double> sitStarts) onConfirm;
  final List<double>? initial;
  final bool failed;

  @override
  State<_CueConfirmCard> createState() => _CueConfirmCardState();
}

class _CueConfirmCardState extends State<_CueConfirmCard> {
  late final Set<double> _picked = {...?widget.initial};

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(VideoStrings.confirmTitleFor(widget.target), style: t.titleMedium),
            const SizedBox(height: 4),
            Text(VideoStrings.confirmNote, style: t.bodySmall),
            for (final (i, c) in widget.candidates.indexed)
              CheckboxListTile(
                key: Key('video_cue_candidate_$i'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _picked.contains(c.start),
                onChanged: (v) => setState(() =>
                    v == true ? _picked.add(c.start) : _picked.remove(c.start)),
                title: Text(VideoStrings.sitCandidate(c.start, c.end,
                    target: widget.target)),
              ),
            if (widget.failed) ...[
              Text(VideoStrings.errRealign,
                  key: const Key('video_realign_error'),
                  style: t.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: const Key('video_cue_confirm_button'),
              onPressed: _picked.isEmpty
                  ? null
                  : () => widget.onConfirm(_picked.toList()..sort()),
              child: const Text(VideoStrings.confirmButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// 历史里的一次结果（只读，从本机表还原）。
final _storedAnalysisProvider = FutureProvider.autoDispose
    .family<StoredVideoAnalysis?, String>(
        (ref, id) => ref.watch(videoRepositoryProvider).byId(id));

/// 历史里某一次检查相对它上一次的进度。
final _historyProgressProvider = FutureProvider.autoDispose
    .family<AttemptProgress?, ({String dogId, String skillId, String id})>(
        (ref, k) async {
  final all =
      await ref.watch(videoRepositoryProvider).attempts(k.dogId, k.skillId);
  final i = all.indexWhere((a) => a.id == k.id);
  return i < 0 ? null : progressAt(all, i);
});

class VideoHistoryResultPage extends ConsumerWidget {
  const VideoHistoryResultPage(
      {super.key, required this.skillId, required this.analysisId});
  final String skillId;
  final String analysisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final a = ref.watch(_storedAnalysisProvider(analysisId)).valueOrNull;
    final skill = lib?.skillById[skillId];
    return Scaffold(
      appBar: AppBar(title: const Text(VideoStrings.pageTitle)),
      body: (a == null || skill == null || lib?.videoChecks == null)
          ? const Center(child: CircularProgressIndicator())
          : VideoResultView(
              skill: skill,
              judgement: a.judgement,
              config: lib!.videoChecks!,
              progress: ref
                  .watch(_historyProgressProvider(
                      (dogId: a.dogId, skillId: skillId, id: a.id)))
                  .valueOrNull,
            ),
    );
  }
}

/// 技能详情页里的入口与最近 5 次记录（只在技能有 video_checks 且开关打开时显示）。
class VideoCheckSection extends ConsumerWidget {
  const VideoCheckSection({super.key, required this.skill});
  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (skill.videoChecks.isEmpty) return const SizedBox.shrink();
    if (!ref.watch(videoAnalysisEnabledProvider)) {
      // 暂不开放（2026-11-18 用户决定）：入口显示为"敬请期待"，不可点；
      // 构建时加 --dart-define=VIDEO_ANALYSIS=true 仍可打开完整功能（开发 / 内测用）。
      return OutlinedButton.icon(
        key: const Key('video_coming_soon'),
        icon: const Icon(Icons.video_camera_back_outlined),
        label: const Text(VideoStrings.comingSoonEntry),
        onPressed: null,
      );
    }
    final dog = ref.watch(currentDogProvider).valueOrNull;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('video_entry'),
          icon: const Icon(Icons.video_camera_back_outlined),
          label: const Text(VideoStrings.entry),
          onPressed: () => context.push('/skill/${skill.id}/video'),
        ),
        if (dog != null)
          StreamBuilder(
            stream: ref
                .watch(videoRepositoryProvider)
                .watchRecent(dog.id, skill.id),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                key: const Key('video_history'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(VideoStrings.history, style: t.titleMedium),
                  _SectionProgress(dogId: dog.id, skillId: skill.id),
                  for (final a in items)
                    ListTile(
                      key: Key('video_history_${a.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(VideoStrings.historyDate(a.createdAt)),
                      subtitle: Text(a.status == VideoStatus.retake
                          ? VideoStrings.historyRetake
                          : a.findings.isEmpty
                              ? VideoStrings.passed
                              : VideoStrings.historyFindings(
                                  a.findings.length)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/skill/${skill.id}/video/${a.id}'),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// 技能页"视频纠错记录"下的一行进度：最新一次检查是第几次、已改正几个 / 通过。
class _SectionProgress extends ConsumerWidget {
  const _SectionProgress({required this.dogId, required this.skillId});
  final String dogId;
  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: ref.watch(videoRepositoryProvider).watchAttempts(dogId, skillId),
      builder: (context, snap) {
        final p = latestProgress(snap.data ?? const []);
        if (p == null) return const SizedBox.shrink();
        final t = Theme.of(context).textTheme;
        final parts = [
          VideoStrings.attemptTitle(p.attemptNo),
          if (p.passed)
            VideoStrings.passed
          else if (p.everFound.isNotEmpty)
            VideoStrings.fixedProgress(p.fixedTotal, p.everFound.length),
        ];
        return Padding(
          key: const Key('video_section_progress'),
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(p.passed ? Icons.verified : Icons.trending_up,
                size: 18,
                color: p.passed ? AppColors.success : AppColors.primary),
            const SizedBox(width: 6),
            Text(parts.join(' · '), style: t.bodyMedium),
          ]),
        );
      },
    );
  }
}
