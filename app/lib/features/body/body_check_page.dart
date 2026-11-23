/// 练前状态检查：拍一小段视频或选一张照片 → 视频分析服务测身体信号 → 按内容库判断平静 / 兴奋 / 有压力信号。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/body/body_api.dart';
import '../../data/repositories/body_repository.dart';
import '../../domain/body_signals.dart';
import '../../domain/models.dart';
import 'body_strings.dart';
import 'body_widgets.dart';

enum _Phase { intro, busy, result, error }

class BodyCheckPage extends ConsumerStatefulWidget {
  const BodyCheckPage({super.key, this.skillId});

  /// 从哪个技能进来（可空）。有压力信号时可推荐它的降级技能。
  final String? skillId;

  @override
  ConsumerState<BodyCheckPage> createState() => _BodyCheckPageState();
}

class _BodyCheckPageState extends ConsumerState<BodyCheckPage> {
  _Phase _phase = _Phase.intro;
  BodyCheckError? _error;
  BodySummary? _summary;
  BodyAssessment? _assessment;
  String? _lastPath;

  Future<void> _pick(BodyMediaSource src) async {
    final path = await ref.read(bodyMediaPickerProvider).pick(src);
    if (path == null || !mounted) return;
    _lastPath = path;
    await _run();
  }

  Future<void> _run() async {
    final path = _lastPath;
    if (path == null) return;
    setState(() {
      _phase = _Phase.busy;
      _error = null;
    });
    try {
      final lib = await ref.read(contentLibraryProvider.future);
      final cfg = lib.bodySignals!;
      final s = await ref.read(bodyCheckApiProvider).check(path);
      final a = assessBody(s, cfg);
      final dog = ref.read(currentDogProvider).valueOrNull;
      if (dog != null && a.state != BodyState.unclear) {
        await ref.read(bodyRepositoryProvider).save(
              dogId: dog.id,
              assessment: a,
              summary: s,
              context: BodyContext.preTraining,
              contentVersion: lib.version,
              now: ref.read(clockProvider)(),
              skillId: widget.skillId,
            );
      }
      if (!mounted) return;
      setState(() {
        _summary = s;
        _assessment = a;
        _phase = _Phase.result;
      });
    } on BodyCheckException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.kind;
        _phase = _Phase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = BodyCheckError.failed;
        _phase = _Phase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final cfg = lib?.bodySignals;
    return Scaffold(
      appBar: AppBar(title: const Text(BodyStrings.pageTitle)),
      body: cfg == null
          ? const Center(child: CircularProgressIndicator())
          : switch (_phase) {
              _Phase.intro => _intro(context),
              _Phase.busy => const Center(
                  key: Key('body_busy'),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(BodyStrings.analyzing),
                  ]),
                ),
              _Phase.error => _errorView(),
              _Phase.result => _result(context, lib!, cfg),
            },
    );
  }

  Widget _intro(BuildContext context) => ListView(
        key: const Key('body_intro'),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(BodyStrings.intro),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('body_record'),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text(BodyStrings.recordVideo),
            onPressed: () => _pick(BodyMediaSource.recordVideo),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('body_gallery'),
            icon: const Icon(Icons.video_library_outlined),
            label: const Text(BodyStrings.galleryVideo),
            onPressed: () => _pick(BodyMediaSource.galleryVideo),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('body_photo'),
            icon: const Icon(Icons.photo_outlined),
            label: const Text(BodyStrings.photo),
            onPressed: () => _pick(BodyMediaSource.photo),
          ),
          const SizedBox(height: 16),
          const Text(BodyStrings.disclaimer),
        ],
      );

  Widget _errorView() => Padding(
        key: const Key('body_error'),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(switch (_error) {
            BodyCheckError.unreachable => BodyStrings.errUnreachable,
            BodyCheckError.busy => BodyStrings.errBusy,
            _ => BodyStrings.errFailed,
          }),
          const SizedBox(height: 16),
          FilledButton(key: const Key('body_retry'), onPressed: _run, child: const Text(BodyStrings.retry)),
        ]),
      );

  Widget _result(BuildContext context, ContentLibrary lib, BodySignalsConfig cfg) {
    final a = _assessment!;
    final skill = widget.skillId == null ? null : lib.skillById[widget.skillId];
    final calm = lib.skillById[cfg.calmDownSkill];
    final downgrade = skill?.downgradeTo == null ? null : lib.skillById[skill!.downgradeTo];
    return ListView(
      key: const Key('body_result'),
      padding: const EdgeInsets.all(16),
      children: [
        BodyAssessmentCard(assessment: a, config: cfg, isPhoto: _summary!.kind == 'image'),
        const SizedBox(height: 16),
        if (a.state == BodyState.excited && calm != null && calm.id != skill?.id)
          FilledButton(
            key: const Key('body_do_calm'),
            onPressed: () => context.push('/skill/${calm.id}'),
            child: Text(BodyStrings.doFirst(calm.name)),
          ),
        if (a.state == BodyState.stressed && downgrade != null)
          FilledButton(
            key: const Key('body_do_downgrade'),
            onPressed: () => context.push('/skill/${downgrade.id}'),
            child: Text(BodyStrings.doFirst(downgrade.name)),
          ),
        if (a.state == BodyState.calm && skill != null)
          FilledButton(
            key: const Key('body_start'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(BodyStrings.startTraining),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('body_again'),
          onPressed: () => setState(() => _phase = _Phase.intro),
          child: const Text(BodyStrings.retry),
        ),
        const SizedBox(height: 16),
        Text(BodyStrings.sources, style: Theme.of(context).textTheme.labelMedium),
        for (final s in cfg.sources) Text(s, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 技能详情页里的入口（和视频纠错同一个开关：都需要电脑上的视频分析服务）。
class BodyCheckEntry extends ConsumerWidget {
  const BodyCheckEntry({super.key, required this.skill});
  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    if (lib?.bodySignals == null) return const SizedBox.shrink();
    if (!ref.watch(videoAnalysisEnabledProvider)) {
      return OutlinedButton.icon(
        key: const Key('body_coming_soon'),
        icon: const Icon(Icons.pets_outlined),
        label: const Text(BodyStrings.comingSoonEntry),
        onPressed: null,
      );
    }
    final dog = ref.watch(currentDogProvider).valueOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(
        key: const Key('body_entry'),
        icon: const Icon(Icons.pets_outlined),
        label: const Text(BodyStrings.entry),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BodyCheckPage(skillId: skill.id)),
        ),
      ),
      if (dog != null) ...[
        const SizedBox(height: 8),
        BodyPacingTip(dogId: dog.id),
      ],
    ]);
  }
}
