/// 实时计时的控制器：把相机帧、麦克风、WebSocket 和快照串起来。
///
/// 页面只依赖这个控制器，不直接碰相机、麦克风或网络，所以整条链路能用假相机、假麦克风、假服务端单测。
///
/// 职责：
/// - 相机帧：限流（最多 [frameRate] 帧每秒）、转正缩小，丢掉还没发完的旧帧，不排队
/// - 麦克风：把 PCM 切成块带会话时刻发出去；没权限或开不了时降级成"只用点按"，不阻止练习
/// - 奖励点按：用会话时钟打时刻，服务端不用自己的时钟
/// - 连接状态：连不上 / 中途断开都明确告诉页面，绝不静默停在旧画面上
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'frame_convert.dart';
import 'framing_controller.dart' show FrameConverter, rotationForFrame;
import 'live_client.dart';

/// 麦克风：给 16kHz 单声道 16 位小端 PCM 的字节流。真实现用 `record` 插件，测试用假的。
abstract class LiveMic {
  /// 开始采集。没有权限或开不了时抛 [LiveMicException]。
  Future<Stream<Uint8List>> start();
  Future<void> stop();
}

class LiveMicException implements Exception {
  LiveMicException(this.code, [this.message]);
  final String code; // permission / unavailable / ...
  final String? message;
  bool get isPermission => code == 'permission';
  @override
  String toString() => 'LiveMicException($code${message == null ? '' : ': $message'})';
}

enum LivePhase {
  idle, // 还没连
  connecting, // 连服务、等模型加载
  ready, // 已连上，等点开始
  running, // 计时中
  finishing, // 点了结束，等最终结果
  done, // 拿到最终结果
  failed, // 连不上 / 服务报错 / 中途断开
}

enum LiveFailure { unreachable, poseUnavailable, disconnected, serverError }

class LiveController extends ChangeNotifier {
  LiveController({
    required this.client,
    required this.mic,
    required this.lateSec,
    LiveClock? clock,
    this.frameRate = 5.0,
    this.targetLongSide = 320,
    FrameConverter? converter,
    this.finishTimeout = const Duration(seconds: 8),
  })  : _clock = clock ?? LiveClock(),
        _convert = converter ?? convertFrame;

  final LiveClient client;
  final LiveMic mic;

  /// "奖励晚"的阈值（秒），由页面从内容库 video_checks.yaml 读出后传入，不在这里写死。
  final double lateSec;
  final double frameRate;
  final int targetLongSide;
  final Duration finishTimeout;
  final LiveClock _clock;
  final FrameConverter _convert;

  LivePhase _phase = LivePhase.idle;
  LiveFailure? _failure;
  String? _failureDetail;
  LiveSnapshot? _snapshot;
  Map<String, dynamic>? _result;
  bool _micOk = false;
  bool _micTried = false;
  bool _micDenied = false;
  StreamSubscription<LiveEvent>? _evSub;
  StreamSubscription<Uint8List>? _micSub;
  Timer? _finishTimer;
  bool _disposed = false;

  // 帧限流
  double _lastFrameT = -1e9;
  int _framesSent = 0;
  int _framesDropped = 0;
  bool _converting = false;

  // 麦克风：每 100 毫秒一块（3200 字节）；系统给的块大小不一，攒够再发
  static const _audioChunkBytes = 3200;
  final BytesBuilder _audioBuf = BytesBuilder(copy: false);
  double _audioT0 = 0;

  LivePhase get phase => _phase;
  LiveFailure? get failure => _failure;
  String? get failureDetail => _failureDetail;
  LiveSnapshot? get snapshot => _snapshot;
  Map<String, dynamic>? get result => _result;

  /// 麦克风是否在工作。false 时页面应提示"没有声音输入，请用奖励按钮"。
  bool get micOk => _micOk;
  bool get micDenied => _micDenied;
  int get framesSent => _framesSent;
  int get framesDropped => _framesDropped;
  double get now => _clock.now;

  void _set(LivePhase p, {LiveFailure? failure, String? detail}) {
    if (_disposed) return;
    _phase = p;
    _failure = failure;
    _failureDetail = detail;
    notifyListeners();
  }

  /// 连接服务，等模型加载完（服务端回 ready）。
  Future<void> connect() async {
    if (_phase != LivePhase.idle && _phase != LivePhase.failed) return;
    _set(LivePhase.connecting);
    _evSub?.cancel();
    _evSub = client.events.listen(_onEvent);
    try {
      await client.connect();
    } catch (e) {
      _set(LivePhase.failed, failure: LiveFailure.unreachable, detail: '$e');
    }
  }

  void _onEvent(LiveEvent e) {
    if (_disposed) return;
    switch (e) {
      case LiveReady():
        if (_phase == LivePhase.connecting) _set(LivePhase.ready);
      case LiveSnapshotEvent(:final snapshot):
        _snapshot = snapshot;
        notifyListeners();
      case LiveResultEvent(:final result):
        _finishTimer?.cancel();
        _result = result;
        _set(LivePhase.done);
      case LiveErrorEvent(:final message):
        _set(LivePhase.failed,
            failure: message.startsWith('pose_unavailable') ? LiveFailure.poseUnavailable : LiveFailure.serverError,
            detail: message);
      case LiveClosedEvent():
        // 正常结束（已经拿到结果）之后的关闭不算故障
        if (_phase == LivePhase.done || _phase == LivePhase.failed) return;
        _stopMic();
        _set(LivePhase.failed, failure: LiveFailure.disconnected);
    }
  }

  /// 点"开始"：开会话时钟、告诉服务端、开麦克风。
  Future<void> start() async {
    if (_phase != LivePhase.ready) return;
    _clock.start();
    _lastFrameT = -1e9;
    client.start(lateSec: lateSec, mic: true);
    _set(LivePhase.running);
    await _startMic();
  }

  Future<void> _startMic() async {
    _micTried = true;
    try {
      final s = await mic.start();
      _micOk = true;
      _micSub = s.listen(_onAudio, onError: (_) => _micFailed(), onDone: () {});
    } on LiveMicException catch (e) {
      _micFailed(denied: e.isPermission);
    } catch (_) {
      _micFailed();
    }
    notifyListeners();
  }

  void _micFailed({bool denied = false}) {
    _micOk = false;
    _micDenied = denied;
    notifyListeners();
  }

  Future<void> _stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      await mic.stop();
    } catch (_) {}
  }

  void _onAudio(Uint8List data) {
    if (_phase != LivePhase.running || data.isEmpty) return;
    if (_audioBuf.isEmpty) {
      // 这一块第一个采样的会话时刻：当前时刻减去这块自己的时长
      _audioT0 = (_clock.now - data.length / 32000.0).clamp(0.0, double.infinity);
    }
    _audioBuf.add(data);
    while (_audioBuf.length >= _audioChunkBytes) {
      final all = _audioBuf.takeBytes();
      client.sendAudio(_audioT0, Uint8List.sublistView(all, 0, _audioChunkBytes));
      _audioT0 += _audioChunkBytes / 32000.0;
      if (all.length > _audioChunkBytes) {
        _audioBuf.add(Uint8List.sublistView(all, _audioChunkBytes));
      }
    }
  }

  /// 相机每来一帧就调一次，不会抛异常。
  void onCameraFrame(RawFrame frame, {required int sensorOrientation}) {
    if (_phase != LivePhase.running || _disposed) return;
    final t = _clock.now;
    if (t - _lastFrameT < 1.0 / frameRate) return;
    if (_converting) {
      _framesDropped++;
      return;
    }
    _lastFrameT = t;
    _converting = true;
    try {
      final rot = rotationForFrame(
          frameWidth: frame.width, frameHeight: frame.height, sensorOrientation: sensorOrientation);
      final rgb = _convert(frame, rotationDegrees: rot, targetLongSide: targetLongSide);
      client.sendFrame(t, rgb);
      _framesSent++;
    } catch (_) {
      _framesDropped++; // 转换出错：丢这一帧，不让相机回调链崩
    } finally {
      _converting = false;
    }
  }

  /// 点"奖励"按钮。用点按的这一刻打时刻。
  void tapReward() {
    if (_phase != LivePhase.running) return;
    client.tap(_clock.now);
  }

  /// 点"结束"：让服务端出最终结果。最多等 [finishTimeout]，超时当作失败（页面可以重试或放弃）。
  Future<void> finish() async {
    if (_phase != LivePhase.running) return;
    await _stopMic();
    _set(LivePhase.finishing);
    client.stop();
    _finishTimer = Timer(finishTimeout, () {
      if (_phase == LivePhase.finishing) {
        _set(LivePhase.failed, failure: LiveFailure.disconnected, detail: 'finish_timeout');
      }
    });
  }

  /// 麦克风是否尝试过（页面用来区分"还没开"和"开失败了"）。
  bool get micTried => _micTried;

  @override
  void dispose() {
    _disposed = true;
    _finishTimer?.cancel();
    _evSub?.cancel();
    _micSub?.cancel();
    unawaited(mic.stop().catchError((_) {}));
    unawaited(client.close());
    super.dispose();
  }
}
