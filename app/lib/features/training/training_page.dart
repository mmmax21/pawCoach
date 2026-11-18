/// 全屏跟练页（TR-2 / TR-3 / TR-4 / TR-6）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_service.dart' show currentUserId;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
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

/// 户外强光：高对比模式（黑底白字、按钮更醒目）。本次运行内记住。
final trainingHighContrastProvider = StateProvider<bool>((ref) => false);

class _TrainingView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = ref.watch(trainingHighContrastProvider);
    final m = runner.machine;
    final t = Theme.of(context).textTheme;
    final step = m.currentStep;
    final paused = m.phase == TrainingPhase.paused;
    final remaining = m.remainingSec();
    final total = step.durationSec;
    final progress = total == 0 ? 0.0 : 1 - (m.remainingMs() / (total * 1000));

    // 两套配色：普通 / 高对比
    final bg = hc ? Colors.black : AppColors.background;
    final fg = hc ? Colors.white : AppColors.textPrimary;
    final sub = hc ? const Color(0xFFE0E0E0) : AppColors.textSecondary;
    final accent = hc ? const Color(0xFFFFC14D) : AppColors.primary;
    final track = hc ? const Color(0xFF333333) : AppColors.primarySoft;
    final outline = hc ? Colors.white : const Color(0xFFE2CFC0);

    ButtonStyle outlined() => OutlinedButton.styleFrom(
          foregroundColor: hc ? Colors.white : AppColors.primaryDeep,
          side: BorderSide(color: outline, width: hc ? 2 : 1),
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          iconSize: 18,
          textStyle: t.titleSmall,
        );

    return Scaffold(
      backgroundColor: bg,
      // 跟练页没有输入框；从"问教练"返回时键盘还在收起，若按键盘让位会把整列挤溢出（M3 设备实测 47px）。
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        titleTextStyle: t.titleLarge?.copyWith(color: fg),
        title: Text(runner.skill.name),
        leading: IconButton(
          key: const Key('training_quit'),
          icon: const Icon(Icons.close),
          onPressed: onQuit,
        ),
        actions: [
          IconButton(
            key: const Key('training_contrast'),
            tooltip: hc ? TrainingStrings.contrastOff : TrainingStrings.contrastOn,
            icon: Icon(hc ? Icons.wb_sunny : Icons.wb_sunny_outlined),
            onPressed: () => ref.read(trainingHighContrastProvider.notifier).state = !hc,
          ),
          TextButton.icon(
            key: const Key('training_ask_coach'),
            style: TextButton.styleFrom(foregroundColor: accent),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('问教练'),
            onPressed: onAskCoach,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 步骤进度：一格一步
              Row(
                children: [
                  for (var i = 0; i < m.stepCount; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= m.stepIndex ? accent : track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Text('${m.stepIndex + 1} / ${m.stepCount}',
                      key: const Key('training_step_no'),
                      style: t.titleMedium?.copyWith(color: sub)),
                  const Spacer(),
                  if (cue != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hc ? const Color(0xFF222222) : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${TrainingStrings.yourCue}$cue',
                          key: const Key('training_cue'),
                          style: t.titleMedium?.copyWith(color: hc ? Colors.white : AppColors.primaryDeep)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(step.instruction,
                      key: const Key('training_instruction'),
                      style: t.headlineSmall?.copyWith(
                          color: fg, height: 1.4, fontSize: hc ? 28 : 25)),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              // 倒计时大圆环
              Center(
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        color: paused ? sub : accent,
                        backgroundColor: track,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$remaining',
                              key: const Key('training_remaining'),
                              style: t.displaySmall?.copyWith(
                                  color: paused ? sub : fg, fontWeight: FontWeight.w700, height: 1.0),
                            ),
                            Text(paused ? TrainingStrings.paused : TrainingStrings.seconds,
                                style: t.labelMedium?.copyWith(color: sub)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              if (step.clickerHint)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Text(TrainingStrings.clickerPrompt,
                      key: const Key('training_clicker_prompt'),
                      style: t.titleMedium?.copyWith(color: accent),
                      textAlign: TextAlign.center),
                ),
              // 大面积响片按钮：始终可按，clicker_hint 的步骤高亮。
              SizedBox(
                height: 104,
                child: FilledButton(
                  key: const Key('training_clicker'),
                  style: FilledButton.styleFrom(
                    backgroundColor: step.clickerHint
                        ? accent
                        : (hc ? const Color(0xFF2A2A2A) : AppColors.primarySoft),
                    foregroundColor: step.clickerHint
                        ? (hc ? Colors.black : Colors.white)
                        : (hc ? Colors.white : AppColors.primaryDeep),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: runner.clicker,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 34),
                      const SizedBox(width: AppSpace.md),
                      Text('${TrainingStrings.clickerButton} · ${m.clickerCount}',
                          style: t.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: step.clickerHint
                                  ? (hc ? Colors.black : Colors.white)
                                  : (hc ? Colors.white : AppColors.primaryDeep))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('training_restart'),
                      style: outlined(),
                      onPressed: runner.restart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text(TrainingStrings.restart),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('training_pause'),
                      style: outlined(),
                      onPressed: runner.togglePause,
                      icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                      label: Text(paused ? TrainingStrings.resume : TrainingStrings.pause),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('training_skip'),
                      style: outlined(),
                      onPressed: runner.skip,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text(TrainingStrings.skip),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  key: const Key('training_next'),
                  style: FilledButton.styleFrom(
                    backgroundColor: hc ? Colors.white : AppColors.success,
                    foregroundColor: hc ? Colors.black : Colors.white,
                  ),
                  onPressed: runner.next,
                  icon: Icon(m.isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded),
                  label: Text(m.isLastStep ? TrainingStrings.finish : TrainingStrings.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
