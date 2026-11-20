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
import '../../domain/video_checks.dart';
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
      if (!mounted || run != _run) return;
      setState(() {
        _judgement = j;
        _result = result;
        _meta = meta;
        _savedId = savedId;
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
      if (!mounted || run != _run) return;
      setState(() {
        _judgement = j;
        _result = r;
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
        const Text(VideoStrings.shootingHint),
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
  });
  final Skill skill;
  final VideoJudgement judgement;
  final VideoChecksConfig config;
  final VoidCallback? onReupload;

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
                  minTrials: config.minReliableTrials),
              key: const Key('video_retake_text')),
          if (canConfirm) ...[
            const SizedBox(height: 16),
            _CueConfirmCard(
              key: const Key('video_cue_confirm'),
              candidates: candidates,
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
                    // 常见错误原文（逐字取自内容库）
                    Text(skill.tutorial.commonMistakes[f.mistake],
                        style: t.bodyLarge),
                    const SizedBox(height: 8),
                    Text(VideoStrings.evidence(f),
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
          TextButton(
            key: const Key('video_reupload'),
            onPressed: onReupload,
            child: const Text(VideoStrings.reupload),
          ),
        ],
      ],
    );
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

/// 补标口令：列出没配上口令的坐下，用户勾选"这次是听口令坐下的"。
class _CueConfirmCard extends StatefulWidget {
  const _CueConfirmCard({
    super.key,
    required this.candidates,
    required this.onConfirm,
    this.initial,
    this.failed = false,
  });
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
            Text(VideoStrings.confirmTitle, style: t.titleMedium),
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
                title: Text(VideoStrings.sitCandidate(c.start, c.end)),
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
              skill: skill, judgement: a.judgement, config: lib!.videoChecks!),
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
                  for (final a in items)
                    ListTile(
                      key: Key('video_history_${a.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(VideoStrings.historyDate(a.createdAt)),
                      subtitle: Text(a.status == VideoStatus.retake
                          ? VideoStrings.historyRetake
                          : a.findings.isEmpty
                              ? VideoStrings.noFindings
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
