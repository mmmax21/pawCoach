// 实时取景控制器：限流、不排队、平滑、降级与恢复。用假的检查器和假的时钟，不碰相机。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/video/frame_check.dart';
import 'package:puppy_trainer/data/video/frame_convert.dart';
import 'package:puppy_trainer/data/video/framing_controller.dart';

FramingVerdict v(FramingLevel l, {String msg = '', NRect? dog}) => FramingVerdict(
    level: l, message: msg, reasons: const [], guide: const NRect(0.1, 0.2, 0.9, 0.8), dogBox: dog);

RawFrame frame({int w = 8, int h = 4}) => RawFrame(
    format: RawFormat.bgra8888,
    width: w,
    height: h,
    planes: [RawPlane(Uint8List(w * h * 4), bytesPerRow: w * 4)]);

class FakeChecker implements FrameChecker {
  final queue = <FrameCheckOutcome>[];
  Completer<void>? gate;
  final calls = <({int w, int h, FramingView view})>[];

  @override
  Future<FrameCheckOutcome> check({
    required Uint8List rgb,
    required int width,
    required int height,
    required FramingView view,
  }) async {
    calls.add((w: width, h: height, view: view));
    expect(rgb.length, width * height * 3);
    if (gate != null) await gate!.future;
    return queue.isEmpty ? FrameChecked(v(FramingLevel.green)) : queue.removeAt(0);
  }
}

void main() {
  late FakeChecker checker;
  late DateTime now;
  late FramingController c;

  setUp(() {
    checker = FakeChecker();
    now = DateTime(2026, 11, 20, 12);
    c = FramingController(checker: checker, view: FramingView.side, clock: () => now);
  });
  tearDown(() => c.dispose());

  Future<void> step({int ms = 400, int rot = 0}) async {
    now = now.add(Duration(milliseconds: ms));
    c.onFrame(frame(), rotationDegrees: rot);
    await pumpEventQueue();
  }

  group('限流与不排队', () {
    test('300ms 内的帧被丢掉', () async {
      await step();
      now = now.add(const Duration(milliseconds: 100));
      c.onFrame(frame(), rotationDegrees: 0);
      await pumpEventQueue();
      expect(checker.calls.length, 1);
      await step(ms: 250);
      expect(checker.calls.length, 2);
    });

    test('上一帧的请求没回来时新帧直接丢，不排队', () async {
      checker.gate = Completer<void>();
      await step();
      await step();
      await step();
      expect(checker.calls.length, 1, reason: '请求还在路上，后面的帧都应丢弃');
      expect(c.sentCount, 1);
      checker.gate!.complete();
      await pumpEventQueue();
      await step();
      expect(checker.calls.length, 2);
    });

    test('把转向后的宽高与机位传给检查器', () async {
      await step(rot: 90); // 8x4 的传感器帧转 90 度 → 4x8
      expect(checker.calls.single.w, 4);
      expect(checker.calls.single.h, 8);
      expect(checker.calls.single.view, FramingView.side);
    });

    test('dispose 之后来的帧与迟到的回复都不会崩', () async {
      checker.gate = Completer<void>();
      await step();
      c.dispose();
      checker.gate!.complete();
      await pumpEventQueue();
      c.onFrame(frame(), rotationDegrees: 0);
      await pumpEventQueue();
      // 没有异常即通过
      c = FramingController(checker: checker, view: FramingView.top, clock: () => now); // 给 tearDown 一个未释放的实例
    });
  });

  group('平滑', () {
    test('没有结果时是红', () => expect(c.level, FramingLevel.red));

    test('连续三次绿才变绿', () async {
      await step();
      await step();
      expect(c.level, FramingLevel.yellow);
      await step();
      expect(c.level, FramingLevel.green);
    });

    test('绿里夹一帧红不会立刻变红', () async {
      for (var i = 0; i < 3; i++) {
        await step();
      }
      checker.queue.add(FrameChecked(v(FramingLevel.red)));
      await step();
      expect(c.level, FramingLevel.yellow);
      checker.queue.add(FrameChecked(v(FramingLevel.red)));
      await step();
      expect(c.level, FramingLevel.red);
    });

    test('提示和框取自最近一次判定', () async {
      checker.queue.add(FrameChecked(v(FramingLevel.yellow, msg: '请靠近一点', dog: const NRect(0.1, 0.1, 0.2, 0.2))));
      await step();
      expect(c.verdict!.message, '请靠近一点');
      expect(c.verdict!.dogBox, const NRect(0.1, 0.1, 0.2, 0.2));
    });

    test('每次有新判定都通知监听者；服务忙不通知', () async {
      var n = 0;
      c.addListener(() => n++);
      await step();
      expect(n, 1);
      checker.queue.add(const FrameBusy());
      await step();
      expect(n, 1);
    });
  });

  group('降级与恢复', () {
    test('偶发一两次失败不算不可用', () async {
      checker.queue.addAll(const [FrameUnavailable('x'), FrameUnavailable('x')]);
      await step();
      await step();
      expect(c.unavailable, isFalse);
    });

    test('连续三次失败进入不可用，并清掉旧结果', () async {
      await step(); // 先有一次绿
      expect(c.verdict, isNotNull);
      checker.queue.addAll(const [FrameUnavailable('a'), FrameUnavailable('b'), FrameUnavailable('c')]);
      await step();
      await step();
      await step();
      expect(c.unavailable, isTrue);
      expect(c.verdict, isNull, reason: '连不上时不能还显示过期的绿灯');
    });

    test('成功一次就恢复', () async {
      checker.queue.addAll(const [FrameUnavailable('a'), FrameUnavailable('b'), FrameUnavailable('c')]);
      for (var i = 0; i < 3; i++) {
        await step();
      }
      expect(c.unavailable, isTrue);
      await step();
      expect(c.unavailable, isFalse);
      expect(c.verdict, isNotNull);
    });

    test('失败计数被成功清零：失败、失败、成功、失败、失败 不算不可用', () async {
      checker.queue.addAll(const [
        FrameUnavailable('a'),
        FrameUnavailable('b'),
      ]);
      await step();
      await step();
      await step(); // 成功
      checker.queue.addAll(const [FrameUnavailable('c'), FrameUnavailable('d')]);
      await step();
      await step();
      expect(c.unavailable, isFalse);
    });

    test('服务忙不计入失败', () async {
      checker.queue.addAll(const [FrameBusy(), FrameBusy(), FrameBusy(), FrameBusy()]);
      for (var i = 0; i < 4; i++) {
        await step();
      }
      expect(c.unavailable, isFalse);
    });

    test('帧转换抛异常也算一次失败，不让相机回调崩', () async {
      var calls = 0;
      final bad = FramingController(
        checker: checker,
        view: FramingView.side,
        clock: () => now,
        converter: (f, {required rotationDegrees, int targetLongSide = 320}) {
          calls++;
          throw StateError('boom');
        },
      );
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(milliseconds: 400));
        bad.onFrame(frame(), rotationDegrees: 0);
        await pumpEventQueue();
      }
      expect(calls, 3);
      expect(bad.unavailable, isTrue);
      expect(checker.calls, isEmpty);
      bad.dispose();
    });
  });

  group('rotationForFrame', () {
    test('传感器给横图（宽>高）+ 传感器方向 90 → 转 90', () {
      expect(rotationForFrame(frameWidth: 640, frameHeight: 480, sensorOrientation: 90), 90);
      expect(rotationForFrame(frameWidth: 640, frameHeight: 480, sensorOrientation: 270), 270);
    });
    test('插件已经给了竖图就不再转', () {
      expect(rotationForFrame(frameWidth: 480, frameHeight: 640, sensorOrientation: 90), 0);
    });
    test('传感器方向是 0 / 180 或非常规值时不转', () {
      expect(rotationForFrame(frameWidth: 640, frameHeight: 480, sensorOrientation: 0), 0);
      expect(rotationForFrame(frameWidth: 640, frameHeight: 480, sensorOrientation: 180), 0);
      expect(rotationForFrame(frameWidth: 640, frameHeight: 480, sensorOrientation: 45), 0);
    });
    test('负角度取模', () {
      expect(rotationForFrame(frameWidth: 640, frameHeight: 480, sensorOrientation: -90), 270);
    });
  });
}
