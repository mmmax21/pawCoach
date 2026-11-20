/// 实时计时的数据层：服务端快照模型、WebSocket 客户端、二进制消息编码。
///
/// 协议见 video_service/app/live.py。这里全是纯 Dart，不碰相机、麦克风和平台通道，能直接单测。
///
/// 时间基准：全部是"会话时间"（点开始那一刻为 0 秒），由 [LiveClock] 提供。
/// 帧、音频、点按都带自己的会话时刻发给服务端，服务端不用自己的时钟，
/// 所以网络延迟只会让屏幕上的数字晚一点出现，不会让"奖励延迟"变大。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'frame_check.dart' show NRect;
import 'frame_convert.dart' show RgbFrame;

/// 会话时钟：从 [start] 起算的秒数。测试里可以注入假时钟。
class LiveClock {
  LiveClock({Stopwatch? stopwatch}) : _sw = stopwatch ?? Stopwatch();
  final Stopwatch _sw;
  void start() => _sw
    ..reset()
    ..start();
  double get now => _sw.elapsedMicroseconds / 1e6;
}

// ---------------------------------------------------------------------------
// 快照
// ---------------------------------------------------------------------------

class LiveTrialView {
  const LiveTrialView({
    required this.cueTimes,
    required this.sitStart,
    this.sitEnd,
    this.rewardT,
    this.rewardSrc,
    this.rewardDelay,
    this.latency,
    this.waitingReward = false,
    this.runningDelay,
    this.late = false,
    this.markersDuringHold = 0,
  });

  final List<double> cueTimes;
  final double sitStart;
  final double? sitEnd;
  final double? rewardT;
  final String? rewardSrc;

  /// 已经奖励了的这一轮：奖励时刻 - 坐下时刻。
  final double? rewardDelay;
  final double? latency;

  /// 还坐着、还没奖励：延迟正在增长，[runningDelay] 是到现在为止已经等了多久。
  final bool waitingReward;
  final double? runningDelay;
  final bool late;
  final int markersDuringHold;

  int get cueCount => cueTimes.length;

  /// 屏幕上该显示的延迟：奖励了就是最终值，没奖励就是正在增长的值。
  double? get shownDelay => rewardDelay ?? runningDelay;

  static double? _d(Object? v) => v is num ? v.toDouble() : null;

  factory LiveTrialView.fromJson(Map j) => LiveTrialView(
        cueTimes: [for (final v in (j['cue_times'] as List? ?? const [])) (v as num).toDouble()],
        sitStart: (j['sit_start'] as num).toDouble(),
        sitEnd: _d(j['sit_end']),
        rewardT: _d(j['reward_t']),
        rewardSrc: j['reward_src'] as String?,
        rewardDelay: _d(j['reward_delay']),
        latency: _d(j['latency']),
        waitingReward: j['waiting_reward'] == true,
        runningDelay: _d(j['running_delay']),
        late: j['late'] == true,
        markersDuringHold: (j['markers_during_hold'] as num?)?.toInt() ?? 0,
      );
}

class LiveSnapshot {
  const LiveSnapshot({
    required this.t,
    required this.dogState,
    required this.dogBox,
    required this.micLevelDb,
    required this.micAlive,
    required this.trials,
    required this.pendingCueT,
    required this.liveTrial,
    required this.lateSec,
    required this.hint,
  });

  final double t;
  final String? dogState; // sit | stand | null（还没确认）
  final NRect? dogBox;
  final double micLevelDb;
  final bool micAlive;
  final List<LiveTrialView> trials;
  final double? pendingCueT; // 口令已经出声，狗还没坐下
  final LiveTrialView? liveTrial;
  final double lateSec;
  final String? hint; // 服务端给的当场提示："该奖励了" / "奖励晚了" / "口令说了 N 次，只说一次"

  factory LiveSnapshot.fromJson(Map j) {
    final box = j['dog_box'];
    return LiveSnapshot(
      t: (j['t'] as num).toDouble(),
      dogState: j['dog_state'] as String?,
      dogBox: box is List && box.length == 4 ? NRect.fromList(box) : null,
      micLevelDb: (j['mic_level_db'] as num?)?.toDouble() ?? -90,
      micAlive: j['mic_alive'] == true,
      trials: [for (final t in (j['trials'] as List? ?? const [])) LiveTrialView.fromJson(t as Map)],
      pendingCueT: (j['pending_cue_t'] as num?)?.toDouble(),
      liveTrial: j['live_trial'] is Map ? LiveTrialView.fromJson(j['live_trial'] as Map) : null,
      lateSec: (j['late_sec'] as num?)?.toDouble() ?? 1.0,
      hint: j['hint'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// 消息编码（与 video_service/app/live.py 一致，小端）
// ---------------------------------------------------------------------------

Uint8List encodeFrame(double t, RgbFrame f) {
  final out = Uint8List(9 + f.bytes.length);
  final b = ByteData.sublistView(out);
  out[0] = 0x46; // 'F'
  b.setFloat32(1, t, Endian.little);
  b.setUint16(5, f.width, Endian.little);
  b.setUint16(7, f.height, Endian.little);
  out.setRange(9, out.length, f.bytes);
  return out;
}

/// [pcm16le]：16kHz 单声道 16 位小端 PCM 的原始字节。
Uint8List encodeAudio(double t0, Uint8List pcm16le) {
  final out = Uint8List(5 + pcm16le.length);
  final b = ByteData.sublistView(out);
  out[0] = 0x41; // 'A'
  b.setFloat32(1, t0, Endian.little);
  out.setRange(5, out.length, pcm16le);
  return out;
}

// ---------------------------------------------------------------------------
// 客户端
// ---------------------------------------------------------------------------

/// 服务端回过来的事件。
sealed class LiveEvent {
  const LiveEvent();
}

class LiveReady extends LiveEvent {
  const LiveReady();
}

class LiveSnapshotEvent extends LiveEvent {
  const LiveSnapshotEvent(this.snapshot);
  final LiveSnapshot snapshot;
}

class LiveResultEvent extends LiveEvent {
  const LiveResultEvent(this.result);
  final Map<String, dynamic> result;
}

class LiveErrorEvent extends LiveEvent {
  const LiveErrorEvent(this.message);
  final String message;
}

/// 连接断了（服务没了 / 网络掉了）。
class LiveClosedEvent extends LiveEvent {
  const LiveClosedEvent();
}

abstract class LiveClient {
  Stream<LiveEvent> get events;
  Future<void> connect();
  void start({required double lateSec, required bool mic});
  void sendFrame(double t, RgbFrame frame);
  void sendAudio(double t0, Uint8List pcm16le);
  void tap(double t);
  void stop();
  Future<void> close();
}

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

class WsLiveClient implements LiveClient {
  WsLiveClient({required this.baseUrl, ChannelFactory? channelFactory})
      : _factory = channelFactory ?? ((u) => WebSocketChannel.connect(u));

  /// 视频分析服务地址（http://host:port），连接时换成 ws://host:port/live。
  final String baseUrl;
  final ChannelFactory _factory;
  final _events = StreamController<LiveEvent>.broadcast();
  WebSocketChannel? _ch;
  bool _closed = false;

  @override
  Stream<LiveEvent> get events => _events.stream;

  static Uri liveUri(String baseUrl) {
    final u = Uri.parse(baseUrl);
    // 用构造函数重新拼：Uri.replace(query: null) 是"不改"而不是"清空"，会把原地址的查询串带进连接地址
    return Uri(
      scheme: u.scheme == 'https' ? 'wss' : 'ws',
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: '/live',
    );
  }

  @override
  Future<void> connect() async {
    final ch = _factory(liveUri(baseUrl));
    _ch = ch;
    await ch.ready; // 连不上在这里抛
    ch.stream.listen(
      _onMessage,
      onError: (_) => _emit(const LiveClosedEvent()),
      onDone: () => _emit(const LiveClosedEvent()),
      cancelOnError: false,
    );
  }

  void _emit(LiveEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _onMessage(dynamic raw) {
    try {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (m['type']) {
        case 'ready':
          _emit(const LiveReady());
        case 'snapshot':
          _emit(LiveSnapshotEvent(LiveSnapshot.fromJson(m)));
        case 'result':
          _emit(LiveResultEvent(Map<String, dynamic>.from(m['result'] as Map)));
        case 'error':
          _emit(LiveErrorEvent('${m['message']}'));
      }
    } catch (_) {
      // 看不懂的消息丢掉，不让一条坏消息断掉整个页面
    }
  }

  void _sendText(Map<String, Object?> m) {
    if (_closed) return;
    try {
      _ch?.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  void _sendBytes(Uint8List b) {
    if (_closed) return;
    try {
      _ch?.sink.add(b);
    } catch (_) {}
  }

  @override
  void start({required double lateSec, required bool mic}) =>
      _sendText({'type': 'start', 'late_sec': lateSec, 'mic': mic});

  @override
  void sendFrame(double t, RgbFrame frame) => _sendBytes(encodeFrame(t, frame));

  @override
  void sendAudio(double t0, Uint8List pcm16le) => _sendBytes(encodeAudio(t0, pcm16le));

  @override
  void tap(double t) => _sendText({'type': 'tap', 't': t});

  @override
  void stop() => _sendText({'type': 'stop'});

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _ch?.sink.close();
    } catch (_) {}
    await _events.close();
  }
}
