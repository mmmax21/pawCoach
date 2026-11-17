/// 跟练状态机（TR-2 / TR-3 / TR-6，M2 简报第 5、6 节）。
///
/// 纯 Dart：不依赖 Flutter、drift，时钟由外部注入，便于单测。
///
/// 计时不依赖任何前台 Timer：每一步只记 `stepStartedAt` 绝对时间，
/// 剩余时间永远是 `duration - (now - stepStartedAt - 暂停累计)`。
/// 调用方（UI 的 Timer、audio_service 的 tick、回到前台）只负责定期调用 [tick]，
/// 即使很久没调用，下一次 [tick] 也会按差值追赶到正确的步骤和剩余秒数。
library;

import '../../domain/models.dart';

enum TrainingPhase { idle, running, paused, finished }

/// 状态机对外发出的事件，由调用方转成 TTS、通知等副作用。
sealed class TrainingEvent {
  const TrainingEvent();
}

/// 进入某一步。
class StepEntered extends TrainingEvent {
  const StepEntered({
    required this.index,
    required this.speakInstruction,
    required this.announceNext,
  });
  final int index;

  /// 该步 `voice: true`，进入时朗读 instruction。
  final bool speakInstruction;

  /// 倒计时自然归零进入本步，且没有明显延迟：先说一句"下一步"再读 instruction。
  final bool announceNext;
}

class TrainingPaused extends TrainingEvent {
  const TrainingPaused();
}

class TrainingResumed extends TrainingEvent {
  const TrainingResumed();
}

class TrainingFinished extends TrainingEvent {
  const TrainingFinished();
}

/// 自然归零后晚于此阈值才处理（例如锁屏被系统冻结），不再播报"下一步"。
const announceLateTolerance = Duration(seconds: 3);

class TrainingMachine {
  TrainingMachine({required this.steps, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    if (steps.isEmpty) {
      throw ArgumentError.value(steps, 'steps', '跟练脚本不能为空');
    }
  }

  final List<ScriptStep> steps;
  final DateTime Function() _clock;

  TrainingPhase _phase = TrainingPhase.idle;
  int _index = 0;
  DateTime _stepStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _pausedMsInStep = 0;
  int _pausedMsTotal = 0;
  DateTime? _pausedAt;
  DateTime? _startedAt;
  DateTime? _endedAt;
  final List<int> _skipped = [];
  int _clickerCount = 0;

  TrainingPhase get phase => _phase;
  int get stepIndex => _index;
  int get stepCount => steps.length;
  ScriptStep get currentStep => steps[_index];
  bool get isLastStep => _index == steps.length - 1;

  /// 当前步开始的绝对时间（暂停时间不计入，见 [remainingMs]）。
  DateTime get stepStartedAt => _stepStartedAt;
  DateTime? get startedAt => _startedAt;
  DateTime? get endedAt => _endedAt;

  /// 被跳过的步骤编号（ScriptStep.step）。
  List<int> get skippedSteps => List.unmodifiable(_skipped);
  int get clickerCount => _clickerCount;

  /// 当前步剩余毫秒，按绝对时间差值计算，不依赖 tick 的频率。
  int remainingMs([DateTime? at]) {
    if (_phase == TrainingPhase.idle) return steps.first.durationSec * 1000;
    if (_phase == TrainingPhase.finished) return 0;
    final ref = _phase == TrainingPhase.paused ? _pausedAt! : (at ?? _clock());
    final elapsed =
        ref.difference(_stepStartedAt).inMilliseconds - _pausedMsInStep;
    final left = currentStep.durationSec * 1000 - elapsed;
    return left < 0 ? 0 : left;
  }

  /// 剩余整秒，向上取整（显示用）。
  int remainingSec([DateTime? at]) => (remainingMs(at) + 999) ~/ 1000;

  /// 实际跟练时长（秒）：开始到结束，去掉暂停的时间。
  int get durationSec {
    final s = _startedAt;
    if (s == null) return 0;
    final e = _endedAt ?? _clock();
    final ms = e.difference(s).inMilliseconds - _pausedMsTotal;
    return ms <= 0 ? 0 : (ms / 1000).round();
  }

  // -- 操作 -----------------------------------------------------------------

  List<TrainingEvent> start() {
    if (_phase != TrainingPhase.idle) return const [];
    final now = _clock();
    _startedAt = now;
    _phase = TrainingPhase.running;
    _enter(0, now);
    return [_entered(announceNext: false)];
  }

  /// 按当前时间重算。到点自动进入下一步；最后一步到点则结束。
  /// 即使很久没调用（切后台、锁屏），也会一次追赶到正确位置。
  List<TrainingEvent> tick() {
    if (_phase != TrainingPhase.running) return const [];
    final now = _clock();
    var advanced = 0;
    while (_phase == TrainingPhase.running) {
      final deadline = _stepStartedAt.add(Duration(
          milliseconds: currentStep.durationSec * 1000 + _pausedMsInStep));
      if (now.isBefore(deadline)) break;
      if (isLastStep) {
        _finish(deadline);
        return const [TrainingFinished()];
      }
      _enter(_index + 1, deadline);
      advanced++;
    }
    if (advanced == 0) return const [];
    final late = now.difference(_stepStartedAt);
    return [
      _entered(announceNext: advanced == 1 && late <= announceLateTolerance),
    ];
  }

  List<TrainingEvent> pause() {
    if (_phase != TrainingPhase.running) return const [];
    _pausedAt = _clock();
    _phase = TrainingPhase.paused;
    return const [TrainingPaused()];
  }

  List<TrainingEvent> resume() {
    if (_phase != TrainingPhase.paused) return const [];
    _closePause(_clock());
    return const [TrainingResumed()];
  }

  /// 手动"下一步"。最后一步则结束。
  List<TrainingEvent> next() => _advanceManually(skip: false);

  /// 跳过当前步：记入 skipped_steps，进入下一步（最后一步则结束）。
  List<TrainingEvent> skip() => _advanceManually(skip: true);

  /// 重来一次：倒计时重置，重新朗读。暂停中也会恢复运行。
  List<TrainingEvent> restart() {
    if (_phase != TrainingPhase.running && _phase != TrainingPhase.paused) {
      return const [];
    }
    final now = _clock();
    if (_phase == TrainingPhase.paused) _closePause(now);
    _enter(_index, now);
    return [_entered(announceNext: false)];
  }

  /// 响片按钮：不限步骤，运行或暂停中都可按。
  void clicker() {
    if (_phase == TrainingPhase.running || _phase == TrainingPhase.paused) {
      _clickerCount++;
    }
  }

  // -- 内部 -----------------------------------------------------------------

  List<TrainingEvent> _advanceManually({required bool skip}) {
    if (_phase != TrainingPhase.running && _phase != TrainingPhase.paused) {
      return const [];
    }
    final now = _clock();
    if (_phase == TrainingPhase.paused) _closePause(now);
    if (skip) _skipped.add(currentStep.step);
    if (isLastStep) {
      _finish(now);
      return const [TrainingFinished()];
    }
    _enter(_index + 1, now);
    return [_entered(announceNext: false)];
  }

  void _closePause(DateTime now) {
    final p = _pausedAt!;
    final ms = now.difference(p).inMilliseconds;
    _pausedMsInStep += ms;
    _pausedMsTotal += ms;
    _pausedAt = null;
    _phase = TrainingPhase.running;
  }

  void _enter(int index, DateTime at) {
    _index = index;
    _stepStartedAt = at;
    _pausedMsInStep = 0;
  }

  void _finish(DateTime at) {
    _endedAt = at;
    _phase = TrainingPhase.finished;
  }

  StepEntered _entered({required bool announceNext}) => StepEntered(
        index: _index,
        speakInstruction: currentStep.voice,
        announceNext: announceNext,
      );
}
