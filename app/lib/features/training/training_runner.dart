/// 把纯 Dart 的 [TrainingMachine] 接到音频、唤醒锁、定时 tick 上。
///
/// 前台用 200ms 的 Timer 刷新界面；这个 Timer 只负责"定期叫醒状态机"，
/// 状态本身来自绝对时间，Timer 被系统冻结也不影响正确性。
/// 回到前台时（[onResumed]）立刻 tick 一次追赶。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/models.dart';
import '../../services/training_audio_service.dart';
import 'training_controller.dart';
import 'training_strings.dart';

class TrainingRunner extends ChangeNotifier {
  TrainingRunner({
    required this.skill,
    required this.part,
    required this.audio,
    DateTime Function()? clock,
    bool useWakelock = true,
  })  : machine = TrainingMachine(
          steps: skill.stepsForPart(part),
          clock: clock,
        ),
        _useWakelock = useWakelock;

  final Skill skill;
  final int part;
  final TrainingAudioPort audio;
  final TrainingMachine machine;
  final bool _useWakelock;

  Timer? _ticker;
  bool _disposed = false;
  bool _foreground = true;

  /// 状态机进入 finished 时置 true，页面据此跳记录页。
  bool get finished => machine.phase == TrainingPhase.finished;

  /// 已经自然结束或手动结束，等待页面处理。
  final ValueNotifier<bool> finishedFlag = ValueNotifier(false);

  /// 可测性入口（M4 简报第 11 节）：当前正在跟练的 runner。集成测试读
  /// `TrainingRunner.active.value?.machine.remainingSec()` 取剩余秒数，
  /// 或调 `remoteControls` 走与通知栏按钮相同的回调。
  static final ValueNotifier<TrainingRunner?> active = ValueNotifier(null);

  /// 交给通知栏的同一组回调（暂停 / 继续、下一步）。
  late final TrainingRemoteControls remoteControls =
      TrainingRemoteControls(onPauseResume: togglePause, onNext: next);

  Future<void> start() async {
    await audio.beginSession(
      skillName: skill.name,
      controls: remoteControls,
    );
    active.value = this;
    if (_useWakelock) {
      unawaited(WakelockPlus.enable().catchError((_) {}));
    }
    _log('START');
    _apply(machine.start());
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => tick());
  }

  /// 前台 Timer、通知栏回调、回到前台都走这里。
  void tick() {
    if (_disposed) return;
    final events = machine.tick();
    _apply(events);
    _publishProgress();
    notifyListeners();
  }

  /// 回到前台：立刻按绝对时间追赶一次。
  void onLifecycle({required bool foreground}) {
    _foreground = foreground;
    _log(foreground ? 'LIFECYCLE foreground(before tick)' : 'LIFECYCLE background');
    if (foreground) {
      tick();
      _log('LIFECYCLE foreground(after tick)');
    }
  }

  /// 诊断日志：带绝对时间戳，锁屏实测时与屏幕读数、adb 时间对照。
  void _log(String what) {
    final m = machine;
    if (m.phase == TrainingPhase.idle) return;
    debugPrint('TRAIN $what step=${m.stepIndex + 1}/${m.stepCount} '
        'phase=${m.phase.name} remaining=${m.remainingMs()}ms '
        'stepStartedAt=${m.stepStartedAt.toIso8601String()} '
        'now=${DateTime.now().toIso8601String()}');
  }

  bool get inForeground => _foreground;

  void togglePause() {
    if (machine.phase == TrainingPhase.running) {
      _apply(machine.pause());
    } else if (machine.phase == TrainingPhase.paused) {
      _apply(machine.resume());
    }
    _publishProgress();
    notifyListeners();
  }

  void next() {
    _apply(machine.next());
    _publishProgress();
    notifyListeners();
  }

  void skip() {
    _apply(machine.skip());
    _publishProgress();
    notifyListeners();
  }

  void restart() {
    _apply(machine.restart());
    _publishProgress();
    notifyListeners();
  }

  void clicker() {
    machine.clicker();
    unawaited(audio.playClicker());
    notifyListeners();
  }

  void _apply(List<TrainingEvent> events) {
    for (final e in events) {
      switch (e) {
        case StepEntered():
          _log('ENTER step=${e.index + 1} announceNext=${e.announceNext}');
          final lines = <String>[
            if (e.announceNext) TrainingStrings.speakNext,
            if (e.speakInstruction) machine.steps[e.index].instruction,
          ];
          if (lines.isEmpty) {
            unawaited(audio.stopSpeaking());
          } else {
            // 口令词不做替换：朗读原文（M2 简报第 8 节）。
            unawaited(audio.speakSequence(lines));
          }
        case TrainingPaused():
          unawaited(audio.stopSpeaking());
        case TrainingResumed():
          // 恢复后从当前步重新朗读指令，倒计时继续。
          if (machine.currentStep.voice) {
            unawaited(audio.speakSequence([machine.currentStep.instruction]));
          }
        case TrainingFinished():
          _log('FINISHED');
          _ticker?.cancel();
          unawaited(audio.stopSpeaking());
          finishedFlag.value = true;
      }
    }
  }

  void _publishProgress() {
    if (machine.phase == TrainingPhase.finished) return;
    audio.showProgress(
      skillName: skill.name,
      stepNumber: machine.stepIndex + 1,
      stepCount: machine.stepCount,
      remainingSec: machine.remainingSec(),
      paused: machine.phase == TrainingPhase.paused,
    );
  }

  /// 释放音频会话与唤醒锁。结束或放弃都要调用。
  Future<void> shutdown() async {
    _ticker?.cancel();
    if (_useWakelock) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
    }
    await audio.endSession();
  }

  @override
  void dispose() {
    if (active.value == this) active.value = null;
    _disposed = true;
    _ticker?.cancel();
    finishedFlag.dispose();
    super.dispose();
  }
}
