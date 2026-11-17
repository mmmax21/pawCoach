import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/training/training_controller.dart';

/// M2 简报第 11 节：训练状态机单测。
/// 正常走完、跳过、重来、暂停恢复、中途退出；后台 30 秒后倒计时重算。
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 11, 16, 9);
  DateTime now;
  DateTime call() => now;
  void advance(int seconds, [int ms = 0]) =>
      now = now.add(Duration(seconds: seconds, milliseconds: ms));
}

ScriptStep step(int n, int sec, {bool voice = true, bool clicker = false}) =>
    ScriptStep(
      step: n,
      part: 1,
      instruction: 'step$n',
      durationSec: sec,
      voice: voice,
      clickerHint: clicker,
    );

TrainingMachine build(FakeClock c, {List<ScriptStep>? steps}) => TrainingMachine(
      steps: steps ?? [step(1, 10), step(2, 20, clicker: true), step(3, 30)],
      clock: c.call,
    );

void main() {
  group('正常走完', () {
    test('倒计时归零自动进入下一步，最后一步归零结束', () {
      final c = FakeClock();
      final m = build(c);
      final first = m.start();
      expect(first.single, isA<StepEntered>());
      expect((first.single as StepEntered).index, 0);
      expect((first.single as StepEntered).speakInstruction, isTrue);
      expect((first.single as StepEntered).announceNext, isFalse);
      expect(m.phase, TrainingPhase.running);
      expect(m.remainingSec(), 10);

      c.advance(4);
      expect(m.tick(), isEmpty);
      expect(m.remainingSec(), 6);

      c.advance(6);
      final e = m.tick();
      expect(m.stepIndex, 1);
      expect(e.single, isA<StepEntered>());
      // 自然归零：先说"下一步"再读指令。
      expect((e.single as StepEntered).announceNext, isTrue);
      expect(m.remainingSec(), 20);

      c.advance(20);
      m.tick();
      expect(m.stepIndex, 2);
      c.advance(30);
      final done = m.tick();
      expect(done.single, isA<TrainingFinished>());
      expect(m.phase, TrainingPhase.finished);
      expect(m.skippedSteps, isEmpty);
      expect(m.durationSec, 60);
      expect(m.endedAt, c.now);
    });

    test('手动"下一步"提前进入，不播"下一步"，最后一步手动结束', () {
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(3);
      final e = m.next();
      expect(m.stepIndex, 1);
      expect((e.single as StepEntered).announceNext, isFalse);
      expect(m.remainingSec(), 20);
      m.next();
      expect(m.stepIndex, 2);
      expect(m.isLastStep, isTrue);
      c.advance(5);
      expect(m.next().single, isA<TrainingFinished>());
      expect(m.phase, TrainingPhase.finished);
      expect(m.durationSec, 8);
    });

    test('voice: false 的步骤不朗读', () {
      final c = FakeClock();
      final m = TrainingMachine(
          steps: [step(1, 5, voice: false)], clock: c.call);
      expect((m.start().single as StepEntered).speakInstruction, isFalse);
    });

    test('空脚本报错', () {
      expect(() => TrainingMachine(steps: const []), throwsArgumentError);
    });
  });

  group('跳过（TR-6）', () {
    test('跳过记入 skipped_steps，进入下一步', () {
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(2);
      m.skip();
      expect(m.skippedSteps, [1]);
      expect(m.stepIndex, 1);
      expect(m.remainingSec(), 20);
      m.skip();
      expect(m.skippedSteps, [1, 2]);
    });

    test('跳过最后一步：记录并结束', () {
      final c = FakeClock();
      final m = build(c, steps: [step(1, 10), step(2, 10)])..start();
      m.next();
      final e = m.skip();
      expect(e.single, isA<TrainingFinished>());
      expect(m.skippedSteps, [2]);
      expect(m.phase, TrainingPhase.finished);
    });

    test('skipped_steps 用内容库的 step 编号，不是下标', () {
      final c = FakeClock();
      final m = TrainingMachine(
          steps: [step(3, 10), step(7, 10)], clock: c.call)
        ..start();
      m.skip();
      expect(m.skippedSteps, [3]);
    });
  });

  group('重来', () {
    test('倒计时重置为 duration_sec，重新朗读，不记跳过', () {
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(7);
      expect(m.remainingSec(), 3);
      final e = m.restart();
      expect(m.stepIndex, 0);
      expect(m.remainingSec(), 10);
      expect((e.single as StepEntered).speakInstruction, isTrue);
      expect(m.skippedSteps, isEmpty);
    });

    test('暂停中重来：恢复运行并重置', () {
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(4);
      m.pause();
      c.advance(100);
      m.restart();
      expect(m.phase, TrainingPhase.running);
      expect(m.remainingSec(), 10);
      c.advance(3);
      expect(m.remainingSec(), 7);
    });
  });

  group('暂停与恢复', () {
    test('暂停期间倒计时不走，恢复后接着走', () {
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(4);
      m.pause();
      expect(m.phase, TrainingPhase.paused);
      expect(m.remainingSec(), 6);
      c.advance(500);
      expect(m.tick(), isEmpty);
      expect(m.stepIndex, 0);
      expect(m.remainingSec(), 6);
      m.resume();
      expect(m.phase, TrainingPhase.running);
      expect(m.remainingSec(), 6);
      c.advance(6);
      m.tick();
      expect(m.stepIndex, 1);
    });

    test('跟练时长扣除暂停时间', () {
      final c = FakeClock();
      final m = build(c, steps: [step(1, 10)])..start();
      c.advance(4);
      m.pause();
      c.advance(60);
      m.resume();
      c.advance(6);
      m.tick();
      expect(m.phase, TrainingPhase.finished);
      expect(m.durationSec, 10);
    });

    test('暂停中点"下一步"：恢复并进入下一步', () {
      final c = FakeClock();
      final m = build(c)..start();
      m.pause();
      c.advance(30);
      m.next();
      expect(m.phase, TrainingPhase.running);
      expect(m.stepIndex, 1);
      expect(m.remainingSec(), 20);
    });

    test('重复 pause / resume 无副作用', () {
      final c = FakeClock();
      final m = build(c)..start();
      expect(m.resume(), isEmpty);
      m.pause();
      expect(m.pause(), isEmpty);
    });
  });

  group('后台与锁屏：计时按绝对时间重算（TR-4）', () {
    test('后台 30 秒没有任何 tick，回来一次 tick 剩余时间准确', () {
      final c = FakeClock();
      final m = build(c, steps: [step(1, 60)])..start();
      c.advance(5);
      m.tick();
      // 进后台：Timer 全部冻结，30 秒内一次 tick 都没有。
      c.advance(30);
      expect(m.tick(), isEmpty);
      expect(m.remainingSec(), 25);
      expect(m.remainingMs(), 25000);
    });

    test('后台期间步骤归零：回来一次 tick 追到正确步骤和剩余秒数', () {
      final c = FakeClock();
      final m = build(c)..start(); // 10 + 20 + 30
      c.advance(5);
      m.tick();
      c.advance(30); // 总共 35 秒：第 1 步 10、第 2 步 20 都过了，第 3 步已进行 5 秒
      final e = m.tick();
      expect(m.stepIndex, 2);
      expect(m.remainingSec(), 25);
      // 跨过多步：只处理最终所在的一步，且不播"下一步"（延迟太久，已过时）。
      expect(e.single, isA<StepEntered>());
      expect((e.single as StepEntered).index, 2);
      expect((e.single as StepEntered).announceNext, isFalse);
    });

    test('后台期间整个脚本跑完：回来 tick 直接 finished，结束时间取理论结束时刻', () {
      final c = FakeClock();
      final start = c.now;
      final m = build(c)..start(); // 共 60 秒
      c.advance(500);
      final e = m.tick();
      expect(e.single, isA<TrainingFinished>());
      expect(m.phase, TrainingPhase.finished);
      expect(m.endedAt, start.add(const Duration(seconds: 60)));
      expect(m.durationSec, 60);
    });

    test('后台里手动暂停（通知栏按钮）再回来：时间不漏算也不多算', () {
      final c = FakeClock();
      final m = build(c, steps: [step(1, 60)])..start();
      c.advance(10);
      m.pause(); // 通知栏"暂停"
      c.advance(120); // 锁屏两分钟
      m.resume();
      expect(m.remainingSec(), 50);
    });

    test('自然归零后及时处理（≤3 秒）才播"下一步"', () {
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(10, 2500); // 超时 2.5 秒才 tick
      expect((m.tick().single as StepEntered).announceNext, isTrue);
      c.advance(20, 4000); // 超时 4 秒
      expect((m.tick().single as StepEntered).announceNext, isFalse);
    });

    test('步骤剩余时间永远不为负', () {
      final c = FakeClock();
      final m = build(c, steps: [step(1, 5), step(2, 5)])..start();
      c.advance(4, 999);
      expect(m.remainingMs(), 1);
      c.advance(1);
      m.tick();
      expect(m.remainingMs(), greaterThan(0));
    });
  });

  group('响片（TR-3）', () {
    test('不限步骤、暂停中也可按，计数累加', () {
      final c = FakeClock();
      final m = build(c)..start();
      m.clicker();
      m.next();
      m.clicker();
      m.pause();
      m.clicker();
      expect(m.clickerCount, 3);
    });

    test('未开始或已结束不计数', () {
      final c = FakeClock();
      final m = build(c, steps: [step(1, 5)]);
      m.clicker();
      expect(m.clickerCount, 0);
      m.start();
      c.advance(5);
      m.tick();
      m.clicker();
      expect(m.clickerCount, 0);
    });
  });

  group('中途退出', () {
    test('状态机本身不产生任何记录：退出就是丢掉对象', () {
      // 简报第 5 节：确认后丢弃本次，不写 TrainingSession，不算打卡。
      // 状态机没有"保存"出口，只有 finished 才有 startedAt / endedAt 可供写库。
      final c = FakeClock();
      final m = build(c)..start();
      c.advance(15);
      m.tick();
      expect(m.phase, TrainingPhase.running);
      expect(m.endedAt, isNull);
    });
  });
}
