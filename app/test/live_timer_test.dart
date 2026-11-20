import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:puppy_trainer/data/video/frame_convert.dart';
import 'package:puppy_trainer/data/video/live_client.dart';
import 'package:puppy_trainer/data/video/live_controller.dart';

// ---- 替身 -------------------------------------------------------------------

class FakeClock extends LiveClock {
  FakeClock() : super();
  double t = 0;
  @override
  void start() => t = 0;
  @override
  double get now => t;
}

class FakeLiveClient implements LiveClient {
  final ctrl = StreamController<LiveEvent>.broadcast();
  final sent = <String>[];
  final frames = <(double, RgbFrame)>[];
  final audio = <(double, Uint8List)>[];
  final taps = <double>[];
  Object? connectError;
  bool closed = false;

  @override
  Stream<LiveEvent> get events => ctrl.stream;
  @override
  Future<void> connect() async {
    if (connectError != null) throw connectError!;
  }

  @override
  void start({required double lateSec, required bool mic}) => sent.add('start late=$lateSec mic=$mic');
  @override
  void sendFrame(double t, RgbFrame frame) => frames.add((t, frame));
  @override
  void sendAudio(double t0, Uint8List pcm16le) => audio.add((t0, pcm16le));
  @override
  void tap(double t) => taps.add(t);
  @override
  void stop() => sent.add('stop');
  @override
  Future<void> close() async {
    closed = true;
    await ctrl.close();
  }

  void emit(LiveEvent e) => ctrl.add(e);
}

class FakeMic implements LiveMic {
  FakeMic({this.error});
  final LiveMicException? error;
  final ctrl = StreamController<Uint8List>();
  bool started = false, stopped = false;
  @override
  Future<Stream<Uint8List>> start() async {
    if (error != null) throw error!;
    started = true;
    return ctrl.stream;
  }

  @override
  Future<void> stop() async => stopped = true;
}

RawFrame rawFrame({int w = 16, int h = 8}) => RawFrame(
      format: RawFormat.bgra8888,
      width: w,
      height: h,
      planes: [RawPlane(Uint8List(w * h * 4), bytesPerRow: w * 4)],
    );

RgbFrame fakeConvert(RawFrame f, {required int rotationDegrees, int targetLongSide = 320}) =>
    RgbFrame(Uint8List(6), 2, 1);

Future<(LiveController, FakeLiveClient, FakeMic, FakeClock)> running({FakeMic? mic}) async {
  final client = FakeLiveClient();
  final clock = FakeClock();
  final m = mic ?? FakeMic();
  final c = LiveController(client: client, mic: m, lateSec: 1.0, clock: clock, converter: fakeConvert);
  await c.connect();
  client.emit(const LiveReady());
  await Future<void>.delayed(Duration.zero);
  await c.start();
  return (c, client, m, clock);
}

Map<String, Object?> snapJson({List<Map<String, Object?>> trials = const [], Map<String, Object?>? live, String? hint}) => {
      't': 3.0,
      'dog_state': 'sit',
      'dog_box': [0.1, 0.4, 0.9, 0.8],
      'mic_level_db': -30.0,
      'mic_alive': true,
      'trials': trials,
      'pending_cue_t': null,
      'live_trial': live,
      'late_sec': 1.0,
      'hint': hint,
    };

Map<String, Object?> trialJson({double? delay, double? running, bool late = false, int cues = 1}) => {
      'cue_times': [for (var i = 0; i < cues; i++) 0.8 + i],
      'cue_count': cues,
      'sit_start': 2.0,
      'sit_end': null,
      'reward_t': delay == null ? null : 2.0 + delay,
      'reward_src': delay == null ? null : 'voice',
      'reward_delay': delay,
      'latency': 1.2,
      'waiting_reward': delay == null,
      'running_delay': running,
      'late': late,
      'markers_during_hold': 0,
    };

void main() {
  group('消息编码（与服务端 app/live.py 一致）', () {
    test('帧：F + float32 时刻 + 宽高 + RGB', () {
      final b = encodeFrame(1.5, RgbFrame(Uint8List.fromList([1, 2, 3, 4, 5, 6]), 2, 1));
      expect(b[0], 0x46);
      final d = ByteData.sublistView(b);
      expect(d.getFloat32(1, Endian.little), 1.5);
      expect(d.getUint16(5, Endian.little), 2);
      expect(d.getUint16(7, Endian.little), 1);
      expect(b.sublist(9), [1, 2, 3, 4, 5, 6]);
    });

    test('音频：A + float32 起始时刻 + PCM 原样', () {
      final b = encodeAudio(0.25, Uint8List.fromList([9, 8, 7, 6]));
      expect(b[0], 0x41);
      expect(ByteData.sublistView(b).getFloat32(1, Endian.little), 0.25);
      expect(b.sublist(5), [9, 8, 7, 6]);
    });

    test('连接地址：http → ws，https → wss，路径固定 /live', () {
      expect(WsLiveClient.liveUri('http://192.168.1.19:8001').toString(), 'ws://192.168.1.19:8001/live');
      expect(WsLiveClient.liveUri('https://x.example.com').toString(), 'wss://x.example.com/live');
      expect(WsLiveClient.liveUri('http://10.0.2.2:8001/foo?a=1').toString(), 'ws://10.0.2.2:8001/live');
    });
  });

  group('快照解析', () {
    test('等奖励中：shownDelay 取正在增长的值；已奖励：取最终值', () {
      final waiting = LiveTrialView.fromJson(trialJson(running: 1.4, late: true));
      expect(waiting.waitingReward, true);
      expect(waiting.shownDelay, 1.4);
      expect(waiting.late, true);
      final done = LiveTrialView.fromJson(trialJson(delay: 0.2));
      expect(done.shownDelay, 0.2);
      expect(done.waitingReward, false);
    });

    test('缺字段、null 都不崩', () {
      final s = LiveSnapshot.fromJson({'t': 1});
      expect(s.trials, isEmpty);
      expect(s.dogState, isNull);
      expect(s.dogBox, isNull);
      expect(s.micAlive, false);
      expect(s.lateSec, 1.0);
    });

    test('服务端 hint 是代码，原样保留', () {
      final s = LiveSnapshot.fromJson(snapJson(hint: 'reward_late'));
      expect(s.hint, 'reward_late');
    });
  });

  group('控制器：连接与阶段', () {
    test('连不上 → failed(unreachable)，不抛异常', () async {
      final client = FakeLiveClient()..connectError = Exception('refused');
      final c = LiveController(client: client, mic: FakeMic(), lateSec: 1.0, clock: FakeClock());
      await c.connect();
      expect(c.phase, LivePhase.failed);
      expect(c.failure, LiveFailure.unreachable);
    });

    test('服务端 ready → ready；缺姿态模型 → poseUnavailable', () async {
      final client = FakeLiveClient();
      final c = LiveController(client: client, mic: FakeMic(), lateSec: 1.0, clock: FakeClock());
      await c.connect();
      expect(c.phase, LivePhase.connecting);
      client.emit(const LiveReady());
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, LivePhase.ready);

      final c2 = LiveController(client: FakeLiveClient(), mic: FakeMic(), lateSec: 1.0, clock: FakeClock());
      final cl2 = c2.client as FakeLiveClient;
      await c2.connect();
      cl2.emit(const LiveErrorEvent('pose_unavailable: no deeplabcut'));
      await Future<void>.delayed(Duration.zero);
      expect(c2.failure, LiveFailure.poseUnavailable);
    });

    test('没点开始前发帧、发奖励点按都被忽略', () async {
      final client = FakeLiveClient();
      final c = LiveController(client: client, mic: FakeMic(), lateSec: 1.0, clock: FakeClock(), converter: fakeConvert);
      await c.connect();
      client.emit(const LiveReady());
      await Future<void>.delayed(Duration.zero);
      c.onCameraFrame(rawFrame(), sensorOrientation: 90);
      c.tapReward();
      expect(client.frames, isEmpty);
      expect(client.taps, isEmpty);
    });

    test('开始：告诉服务端阈值（来自内容库，不是写死的）', () async {
      final (c, client, _, _) = await running();
      expect(client.sent.first, 'start late=1.0 mic=true');
      expect(c.phase, LivePhase.running);
    });

    test('中途连接断开 → failed(disconnected)，并且关掉麦克风', () async {
      final (c, client, mic, _) = await running();
      client.emit(const LiveClosedEvent());
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, LivePhase.failed);
      expect(c.failure, LiveFailure.disconnected);
      expect(mic.stopped, true);
    });
  });

  group('控制器：相机帧', () {
    test('限流：5 帧/秒，30fps 相机每秒只发 5 帧', () async {
      final (c, client, _, clock) = await running();
      for (var i = 0; i < 90; i++) {
        clock.t = i / 30.0; // 3 秒的 30fps
        c.onCameraFrame(rawFrame(), sensorOrientation: 90);
      }
      expect(client.frames.length, inInclusiveRange(14, 16));
      // 每帧带的是会话时刻，且单调递增
      final ts = [for (final f in client.frames) f.$1];
      expect([...ts]..sort(), ts);
    });

    test('转换出错只丢这一帧，后面的帧照常', () async {
      var n = 0;
      final client = FakeLiveClient();
      final clock = FakeClock();
      final c = LiveController(
          client: client,
          mic: FakeMic(),
          lateSec: 1.0,
          clock: clock,
          converter: (f, {required rotationDegrees, targetLongSide = 320}) {
            if (n++ == 0) throw StateError('bad plane');
            return RgbFrame(Uint8List(6), 2, 1);
          });
      await c.connect();
      client.emit(const LiveReady());
      await Future<void>.delayed(Duration.zero);
      await c.start();
      clock.t = 0.0;
      c.onCameraFrame(rawFrame(), sensorOrientation: 90);
      clock.t = 0.3;
      c.onCameraFrame(rawFrame(), sensorOrientation: 90);
      expect(c.framesDropped, 1);
      expect(client.frames.length, 1);
    });
  });

  group('控制器：麦克风', () {
    test('音频攒够 100 毫秒（3200 字节）再发，带正确的会话起点', () async {
      final (c, client, mic, clock) = await running();
      clock.t = 0.05;
      mic.ctrl.add(Uint8List(1600)); // 50 毫秒
      await Future<void>.delayed(Duration.zero);
      expect(client.audio, isEmpty); // 不够一块
      clock.t = 0.10;
      mic.ctrl.add(Uint8List(1600));
      await Future<void>.delayed(Duration.zero);
      expect(client.audio.length, 1);
      expect(client.audio.first.$2.length, 3200);
      expect(client.audio.first.$1, closeTo(0.0, 0.01)); // 这块从 0.0 开始
    });

    test('系统给的块不整齐也不丢字节', () async {
      final (c, client, mic, clock) = await running();
      for (final n in [1000, 2500, 4100, 900]) {
        clock.t += n / 32000.0;
        mic.ctrl.add(Uint8List(n));
        await Future<void>.delayed(Duration.zero);
      }
      final sent = client.audio.fold<int>(0, (a, b) => a + b.$2.length);
      expect(sent, 8000 ~/ 3200 * 3200); // 8500 字节里发出 2 块 6400，剩 2100 在缓冲里
      expect(client.audio.every((a) => a.$2.length == 3200), true);
    });

    test('没权限：不阻止练习，micOk=false、micDenied=true，奖励点按照常可用', () async {
      final (c, client, _, clock) = await running(mic: FakeMic(error: LiveMicException('permission')));
      expect(c.phase, LivePhase.running);
      expect(c.micOk, false);
      expect(c.micDenied, true);
      clock.t = 3.1;
      c.tapReward();
      expect(client.taps, [3.1]);
    });

    test('点结束后不再发音频', () async {
      final (c, client, mic, clock) = await running();
      await c.finish();
      mic.ctrl.add(Uint8List(6400));
      await Future<void>.delayed(Duration.zero);
      expect(client.audio, isEmpty);
      expect(mic.stopped, true);
    });
  });

  group('控制器：奖励点按与结束', () {
    test('点按用会话时钟打时刻', () async {
      final (c, client, _, clock) = await running();
      clock.t = 4.25;
      c.tapReward();
      expect(client.taps, [4.25]);
    });

    test('结束：发 stop，收到最终结果 → done', () async {
      final (c, client, _, _) = await running();
      await c.finish();
      expect(c.phase, LivePhase.finishing);
      expect(client.sent.last, 'stop');
      client.emit(const LiveResultEvent({'trials': []}));
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, LivePhase.done);
      expect(c.result, {'trials': []});
    });

    test('结果之后的连接关闭不算故障', () async {
      final (c, client, _, _) = await running();
      await c.finish();
      client.emit(const LiveResultEvent({'trials': []}));
      client.emit(const LiveClosedEvent());
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, LivePhase.done);
    });

    test('结束后一直等不到结果 → 超时失败，不会永远转圈', () async {
      final client = FakeLiveClient();
      final c = LiveController(
          client: client,
          mic: FakeMic(),
          lateSec: 1.0,
          clock: FakeClock(),
          converter: fakeConvert,
          finishTimeout: const Duration(milliseconds: 30));
      await c.connect();
      client.emit(const LiveReady());
      await Future<void>.delayed(Duration.zero);
      await c.start();
      await c.finish();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.phase, LivePhase.failed);
      expect(c.failureDetail, 'finish_timeout');
    });

    test('快照到达后控制器通知页面刷新', () async {
      final (c, client, _, _) = await running();
      var n = 0;
      c.addListener(() => n++);
      client.emit(LiveSnapshotEvent(LiveSnapshot.fromJson(snapJson(live: trialJson(running: 1.2, late: true)))));
      await Future<void>.delayed(Duration.zero);
      expect(n, greaterThan(0));
      expect(c.snapshot!.liveTrial!.late, true);
    });

    test('dispose 关闭连接和麦克风', () async {
      final (c, client, mic, _) = await running();
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(client.closed, true);
      expect(mic.stopped, true);
    });
  });

  group('WebSocket 客户端：解析服务端消息', () {
    test('各类消息变成事件，坏消息被丢弃不崩', () async {
      final events = <LiveEvent>[];
      final fake = _FakeChannel();
      final c = WsLiveClient(baseUrl: 'http://x:1', channelFactory: (_) => fake);
      c.events.listen(events.add);
      await c.connect();
      fake.push(jsonEncode({'type': 'ready'}));
      fake.push(jsonEncode({'type': 'snapshot', ...snapJson(hint: 'reward_due')}));
      fake.push('这不是 json');
      fake.push(jsonEncode({'type': 'error', 'message': 'pose_unavailable: x'}));
      fake.push(jsonEncode({'type': 'result', 'result': {'trials': []}}));
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<LiveReady>().length, 1);
      expect(events.whereType<LiveSnapshotEvent>().single.snapshot.hint, 'reward_due');
      expect(events.whereType<LiveErrorEvent>().single.message, startsWith('pose_unavailable'));
      expect(events.whereType<LiveResultEvent>().single.result, {'trials': []});
    });

    test('发出去的文本消息格式', () async {
      final fake = _FakeChannel();
      final c = WsLiveClient(baseUrl: 'http://x:1', channelFactory: (_) => fake);
      await c.connect();
      c.start(lateSec: 1.0, mic: true);
      c.tap(3.2);
      c.stop();
      expect(jsonDecode(fake.sent[0] as String), {'type': 'start', 'late_sec': 1.0, 'mic': true});
      expect(jsonDecode(fake.sent[1] as String), {'type': 'tap', 't': 3.2});
      expect(jsonDecode(fake.sent[2] as String), {'type': 'stop'});
    });
  });
}


/// 最小的 WebSocketChannel 替身：不开真实连接，只收发消息。
/// 只实现测试会用到的四个成员，其余成员一律不应被调用（调用即测试出错）。
class _FakeChannel implements WebSocketChannel {
  final _in = StreamController<dynamic>.broadcast();
  final sent = <dynamic>[];
  late final _sink = _FakeSink(sent);

  void push(dynamic m) => _in.add(m);

  @override
  Stream get stream => _in.stream;
  @override
  WebSocketSink get sink => _sink;
  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_FakeChannel 没有实现 ${invocation.memberName}');
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this.sent);
  final List<dynamic> sent;
  @override
  void add(dynamic data) => sent.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream stream) async {}
  @override
  Future close([int? closeCode, String? closeReason]) async {}
  @override
  Future get done => Future.value();
}
