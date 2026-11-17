/// 全屏跟练页（TR-2 / TR-3 / TR-4 / TR-6）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_service.dart' show currentUserId;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/training_audio_service.dart';
import 'training_controller.dart';
import 'training_runner.dart';
import 'training_strings.dart';

/// 音频后端，默认是真实的 audio_service；测试 override 成假实现。
final trainingAudioPortProvider = Provider<TrainingAudioPort>((ref) {
  return trainingAudio;
});

class TrainingPage extends ConsumerStatefulWidget {
  const TrainingPage({super.key, required this.skillId, required this.part});
  final String skillId;
  final int part;

  @override
  ConsumerState<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends ConsumerState<TrainingPage>
    with WidgetsBindingObserver {
  TrainingRunner? _runner;
  String? _cue;
  String? _error;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    try {
      final lib = await ref.read(contentLibraryProvider.future);
      final skill = lib.skillById[widget.skillId];
      if (skill == null) throw StateError('技能 ${widget.skillId} 不存在');
      final dog = await ref.read(dogRepositoryProvider).currentDog();
      if (dog != null) {
        final cues = await ref.read(profileRepositoryProvider).cues(dog.id);
        _cue = cues
            .where((c) => c.skillId == skill.id)
            .map((c) => c.cueWord)
            .firstOrNull;
      }
      final runner = TrainingRunner(
        skill: skill,
        part: widget.part,
        audio: ref.read(trainingAudioPortProvider),
        clock: ref.read(clockProvider),
      );
      runner.finishedFlag.addListener(_onFinished);
      await runner.start();
      if (!mounted) {
        await runner.shutdown();
        runner.dispose();
        return;
      }
      setState(() => _runner = runner);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _runner?.onLifecycle(foreground: state == AppLifecycleState.resumed);
  }

  Future<void> _onFinished() async {
    final r = _runner;
    if (r == null || !r.finishedFlag.value || _leaving) return;
    _leaving = true;
    final m = r.machine;
    final dog = await ref.read(dogRepositoryProvider).currentDog();
    if (dog == null) return;
    final draft = SessionDraft(
      dogId: dog.id,
      userId: await currentUserId(ref.read(databaseProvider)),
      skillId: r.skill.id,
      scriptPart: r.part,
      startedAt: m.startedAt!,
      endedAt: m.endedAt!,
      durationSec: m.durationSec,
      clickerCount: m.clickerCount,
      skippedSteps: m.skippedSteps,
    );
    await r.shutdown();
    if (!mounted) return;
    context.go('/record', extra: draft);
  }

  Future<bool> _confirmQuit() async {
    final r = _runner;
    final wasRunning = r?.machine.phase == TrainingPhase.running;
    if (wasRunning) r!.togglePause();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(TrainingStrings.quitTitle),
        content: const Text(TrainingStrings.quitBody),
        actions: [
          TextButton(
            key: const Key('quit_cancel'),
            onPressed: () => Navigator.pop(c, false),
            child: const Text(TrainingStrings.quitCancel),
          ),
          TextButton(
            key: const Key('quit_confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(TrainingStrings.quitConfirm),
          ),
        ],
      ),
    );
    if (ok == true) return true;
    if (wasRunning) r!.togglePause();
    return false;
  }

  /// 中途退出：确认后丢弃本次，不写 TrainingSession，不算打卡（简报第 5 节）。
  Future<void> _quit() async {
    final r = _runner;
    if (r == null) return;
    final ok = await _confirmQuit();
    if (!ok) return;
    _leaving = true;
    await r.shutdown();
    if (!mounted) return;
    GoRouter.of(context).go('/home');
  }

  /// M3：跟练中"问教练"。进入前暂停（复用状态机的暂停），返回后恢复。
  Future<void> _askCoach() async {
    final r = _runner;
    if (r == null) return;
    final wasRunning = r.machine.phase == TrainingPhase.running;
    if (wasRunning) r.togglePause();
    final step = r.machine.stepIndex + 1;
    await context.push('/coach/chat?skill=${r.skill.id}&step=$step&part=${r.part}');
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (wasRunning && r.machine.phase == TrainingPhase.paused) r.togglePause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final r = _runner;
    if (r != null) {
      r.finishedFlag.removeListener(_onFinished);
      r.shutdown();
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('无法开始跟练：$_error')),
      );
    }
    final r = _runner;
    if (r == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: ListenableBuilder(
        listenable: r,
        builder: (_, __) => _TrainingView(
          runner: r,
          cue: _cue,
          onQuit: _quit,
          onAskCoach: _askCoach,
        ),
      ),
    );
  }
}

class _TrainingView extends StatelessWidget {
  const _TrainingView({
    required this.runner,
    required this.cue,
    required this.onQuit,
    required this.onAskCoach,
  });
  final TrainingRunner runner;
  final String? cue;
  final VoidCallback onQuit;
  final VoidCallback onAskCoach;

  @override
  Widget build(BuildContext context) {
    final m = runner.machine;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final step = m.currentStep;
    final paused = m.phase == TrainingPhase.paused;
    final remaining = m.remainingSec();
    final total = step.durationSec;
    final progress = total == 0 ? 0.0 : 1 - (m.remainingMs() / (total * 1000));

    return Scaffold(
      // 跟练页没有输入框；从"问教练"返回时键盘还在收起，若按键盘让位会把整列挤溢出（M3 设备实测 47px）。
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(runner.skill.name),
        leading: IconButton(
          key: const Key('training_quit'),
          icon: const Icon(Icons.close),
          onPressed: onQuit,
        ),
        actions: [
          TextButton.icon(
            key: const Key('training_ask_coach'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('问教练'),
            onPressed: onAskCoach,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cue != null)
                Text('${TrainingStrings.yourCue}$cue',
                    key: const Key('training_cue'),
                    style: t.titleSmall,
                    textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('${m.stepIndex + 1} / ${m.stepCount}',
                  key: const Key('training_step_no'),
                  style: t.labelLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // 配图占位：内容库的图片文件本期不存在，不依赖文件（M2 简报第 6 节）。
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                    '${TrainingStrings.imagePlaceholder} · ${m.stepIndex + 1}',
                    style: t.bodyMedium),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(step.instruction,
                      key: const Key('training_instruction'),
                      style: t.titleLarge),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '$remaining',
                  key: const Key('training_remaining'),
                  style: t.displayLarge?.copyWith(
                      color: paused ? cs.outline : cs.primary),
                ),
              ),
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              const SizedBox(height: 12),
              if (step.clickerHint)
                Text(TrainingStrings.clickerPrompt,
                    key: const Key('training_clicker_prompt'),
                    style: t.titleMedium?.copyWith(color: cs.primary),
                    textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // 大面积响片按钮：始终可按，clicker_hint 的步骤高亮。
              SizedBox(
                height: 96,
                child: FilledButton(
                  key: const Key('training_clicker'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        step.clickerHint ? cs.primary : cs.secondaryContainer,
                    foregroundColor:
                        step.clickerHint ? cs.onPrimary : cs.onSecondaryContainer,
                  ),
                  onPressed: runner.clicker,
                  child: Text(
                      '${TrainingStrings.clickerButton} · ${m.clickerCount}',
                      style: t.headlineSmall?.copyWith(
                          color: step.clickerHint
                              ? cs.onPrimary
                              : cs.onSecondaryContainer)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('training_restart'),
                      onPressed: runner.restart,
                      child: const Text(TrainingStrings.restart),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('training_skip'),
                      onPressed: runner.skip,
                      child: const Text(TrainingStrings.skip),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('training_pause'),
                      onPressed: runner.togglePause,
                      child: Text(paused
                          ? TrainingStrings.resume
                          : TrainingStrings.pause),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      key: const Key('training_next'),
                      onPressed: runner.next,
                      child: Text(m.isLastStep
                          ? TrainingStrings.finish
                          : TrainingStrings.next),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
