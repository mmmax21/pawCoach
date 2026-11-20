// 引导拍摄页：用假相机和假检查器驱动，不碰平台通道。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/video/capture_camera.dart';
import 'package:puppy_trainer/data/video/frame_check.dart';
import 'package:puppy_trainer/data/video/frame_convert.dart';
import 'package:puppy_trainer/features/video/guided_capture_page.dart';
import 'package:puppy_trainer/features/video/video_strings.dart';

class FakeCamera implements CaptureCamera {
  FakeCamera({this.openError, this.recordError});
  final CaptureCameraException? openError;
  final CaptureCameraException? recordError;
  final calls = <String>[];
  void Function(RawFrame)? onFrame;
  bool disposed = false;

  @override
  Future<void> open() async {
    calls.add('open');
    if (openError != null) throw openError!;
  }

  @override
  Widget buildPreview(BuildContext context) => const ColoredBox(key: Key('fake_preview'), color: Color(0xFF223344));

  @override
  double get previewAspectRatio => 9 / 16;

  @override
  int get sensorOrientation => 90;

  @override
  Future<void> startStream(void Function(RawFrame frame) cb) async {
    calls.add('startStream');
    onFrame = cb;
  }

  @override
  Future<void> stopStream() async {
    calls.add('stopStream');
    onFrame = null;
  }

  @override
  Future<void> startRecording() async {
    calls.add('startRecording');
    if (recordError != null) throw recordError!;
  }

  @override
  Future<String> stopRecording() async {
    calls.add('stopRecording');
    return '/tmp/guided_take.mp4';
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
  }

  void push() => onFrame?.call(RawFrame(
      format: RawFormat.bgra8888, width: 16, height: 8, planes: [RawPlane(Uint8List(16 * 8 * 4), bytesPerRow: 64)]));
}

class ScriptedChecker implements FrameChecker {
  final queue = <FrameCheckOutcome>[];
  FrameCheckOutcome fallback = FrameChecked(verdict(FramingLevel.green, '取景合适，可以开始'));
  int calls = 0;

  @override
  Future<FrameCheckOutcome> check({
    required Uint8List rgb,
    required int width,
    required int height,
    required FramingView view,
  }) async {
    calls++;
    return queue.isEmpty ? fallback : queue.removeAt(0);
  }
}

FramingVerdict verdict(FramingLevel l, String msg, {List<String> reasons = const []}) => FramingVerdict(
    level: l,
    message: msg,
    reasons: reasons,
    guide: const NRect(0.08, 0.4, 0.92, 0.8),
    dogBox: const NRect(0.2, 0.45, 0.7, 0.75));

void main() {
  late FakeCamera cam;
  late ScriptedChecker checker;
  String? popped;
  var returned = false;

  Future<void> pumpHost(WidgetTester t, {FakeCamera? camera}) async {
    cam = camera ?? FakeCamera();
    checker = ScriptedChecker();
    popped = null;
    returned = false;
    await t.pumpWidget(ProviderScope(
      overrides: [
        captureCameraFactoryProvider.overrideWithValue(() => cam),
        frameCheckerProvider.overrideWithValue(checker),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_guided'),
                onPressed: () async {
                  popped = await Navigator.of(ctx).push<String>(MaterialPageRoute(builder: (_) => const GuidedCapturePage()));
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.byKey(const Key('open_guided')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  /// 每隔 350ms 真实时间推一帧（取景控制器按真实时钟限流）。
  Future<void> feed(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() async {
        cam.push();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await t.pump();
    }
  }

  testWidgets('打开相机、开图像流，显示预览与取景提示', (t) async {
    await pumpHost(t);
    expect(find.byKey(const Key('fake_preview')), findsOneWidget);
    expect(cam.calls.take(2), ['open', 'startStream']);
    expect(find.text(VideoStrings.guideOffline), findsNothing);
    expect(find.text(VideoStrings.guideChecking), findsOneWidget);
    await feed(t, 1);
    expect(find.text('取景合适，可以开始'), findsOneWidget);
  });

  testWidgets('连续绿灯后显示"开始录制"；点击倒计时 3 秒再开录，开录前先停图像流', (t) async {
    await pumpHost(t);
    await feed(t, 3);
    expect(find.text(VideoStrings.guideStart), findsOneWidget);
    await t.tap(find.byKey(const Key('guided_start')));
    await t.pump();
    expect(find.byKey(const Key('guided_count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    expect(cam.calls, isNot(contains('startRecording')));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(find.byKey(const Key('guided_seconds')), findsOneWidget);
    final i = cam.calls.indexOf('startRecording');
    expect(i, greaterThan(0));
    expect(cam.calls[i - 1], 'stopStream', reason: '录制前必须先停掉图像流');
    expect(find.text(VideoStrings.guideRecording), findsOneWidget);
  });

  testWidgets('录制不足 3 秒时"这一轮结束"不可点；够了以后返回视频路径', (t) async {
    await pumpHost(t);
    await feed(t, 1);
    await t.tap(find.byKey(const Key('guided_start')));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    final stop = find.byKey(const Key('guided_stop'));
    expect(stop, findsOneWidget);
    expect(t.widget<FilledButton>(stop).onPressed, isNull);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(t.widget<FilledButton>(stop).onPressed, isNull);
    await t.pump(const Duration(seconds: 1));
    expect(t.widget<FilledButton>(stop).onPressed, isNotNull);
    await t.tap(stop);
    await t.pumpAndSettle();
    expect(returned, isTrue);
    expect(popped, '/tmp/guided_take.mp4');
    expect(cam.calls, contains('stopRecording'));
    expect(cam.disposed, isTrue, reason: '页面关闭后相机必须释放');
  });

  testWidgets('红灯：显示原因，按钮改为"仍然录制"，仍可录', (t) async {
    await pumpHost(t);
    checker.fallback = FrameChecked(verdict(FramingLevel.red, '狗太小，请靠近一点', reasons: ['dog_small']));
    await feed(t, 3);
    expect(find.text('狗太小，请靠近一点'), findsOneWidget);
    expect(find.text(VideoStrings.guideStartAnyway), findsOneWidget);
    expect(find.text(VideoStrings.guideStart), findsNothing);
    await t.tap(find.byKey(const Key('guided_start')));
    await t.pump();
    expect(find.byKey(const Key('guided_count')), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(find.byKey(const Key('guided_seconds')), findsOneWidget);
  });

  testWidgets('黄灯可直接录，按钮仍是"开始录制"', (t) async {
    await pumpHost(t);
    checker.fallback = FrameChecked(verdict(FramingLevel.yellow, '没看到主人，请让手和上身入画', reasons: ['no_person']));
    await feed(t, 3);
    expect(find.text('没看到主人，请让手和上身入画'), findsOneWidget);
    expect(find.text(VideoStrings.guideStart), findsOneWidget);
  });

  testWidgets('取景检查连不上：连续失败后显示静态框与"取景检查不可用"，仍可直接录制', (t) async {
    await pumpHost(t);
    checker.fallback = const FrameUnavailable('connectionError');
    await feed(t, 3);
    expect(find.text(VideoStrings.guideOffline), findsOneWidget);
    expect(find.byKey(const Key('guided_offline')), findsOneWidget);
    expect(find.text(VideoStrings.guideStart), findsOneWidget);
    await t.tap(find.byKey(const Key('guided_start')));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(find.byKey(const Key('guided_seconds')), findsOneWidget);
  });

  testWidgets('服务忙（429）只丢帧，不显示"不可用"', (t) async {
    await pumpHost(t);
    checker.fallback = const FrameBusy();
    await feed(t, 4);
    expect(find.text(VideoStrings.guideOffline), findsNothing);
    expect(find.text(VideoStrings.guideChecking), findsOneWidget);
  });

  testWidgets('没有相机权限：说明原因，没有"重试"，可以回去选相册', (t) async {
    await pumpHost(t, camera: FakeCamera(openError: CaptureCameraException('permission')));
    await t.pump();
    expect(find.byKey(const Key('guided_error')), findsOneWidget);
    expect(find.text(VideoStrings.guideNoPermission), findsOneWidget);
    expect(find.byKey(const Key('guided_retry')), findsNothing);
    await t.tap(find.byKey(const Key('guided_back')));
    await t.pumpAndSettle();
    expect(returned, isTrue);
    expect(popped, isNull);
  });

  testWidgets('没有相机设备：给出对应说明', (t) async {
    await pumpHost(t, camera: FakeCamera(openError: CaptureCameraException('no_camera')));
    await t.pump();
    expect(find.text(VideoStrings.guideNoCamera), findsOneWidget);
  });

  testWidgets('其他相机错误：可重试，重试后重新打开', (t) async {
    var n = 0;
    final cams = <FakeCamera>[];
    cam = FakeCamera();
    checker = ScriptedChecker();
    await t.pumpWidget(ProviderScope(
      overrides: [
        captureCameraFactoryProvider.overrideWithValue(() {
          final c = n++ == 0 ? FakeCamera(openError: CaptureCameraException('boom')) : FakeCamera();
          cams.add(c);
          cam = c;
          return c;
        }),
        frameCheckerProvider.overrideWithValue(checker),
      ],
      child: const MaterialApp(home: GuidedCapturePage()),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text(VideoStrings.guideCameraFailed), findsOneWidget);
    await t.tap(find.byKey(const Key('guided_retry')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(cams.length, 2);
    expect(find.byKey(const Key('guided_error')), findsNothing);
    expect(find.byKey(const Key('fake_preview')), findsOneWidget);
  });

  testWidgets('开录失败：显示错误而不是卡在"录制中"', (t) async {
    await pumpHost(t, camera: FakeCamera(recordError: CaptureCameraException('x')));
    await feed(t, 1);
    await t.tap(find.byKey(const Key('guided_start')));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(find.byKey(const Key('guided_error')), findsOneWidget);
    expect(find.byKey(const Key('guided_seconds')), findsNothing);
  });

  testWidgets('页面在录制中被关掉，相机被释放', (t) async {
    await pumpHost(t);
    await feed(t, 1);
    await t.tap(find.byKey(const Key('guided_start')));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(find.byKey(const Key('guided_seconds')), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(cam.disposed, isTrue);
  });

  testWidgets('提示句只来自服务端登记过的取景句（原文性）', (t) async {
    await pumpHost(t);
    for (final m in VideoStrings.framingMessages) {
      expect(VideoStrings.isTemplate(m), isTrue, reason: m);
    }
  });
}
