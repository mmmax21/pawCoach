/// 实时取景自检的控制器：把相机帧限流、转换、发给服务端，再把结果平滑成稳定的红 / 黄 / 绿。
///
/// 只依赖 [FrameChecker] 和 [convertFrame]，不依赖相机插件，能用假相机帧直接测。
///
/// 规则：
/// - 最多每 [minInterval] 处理一帧；上一帧的请求还没回来就丢掉新帧（不排队，否则框会越来越滞后）。
/// - 服务忙（429）只丢这一帧；连续 [unavailableAfter] 次连不上 / 超时 / 缺检测器，进入"不可用"，
///   此时 [level] 不再有意义，页面显示静态引导框并仍然允许录制；之后只要有一次成功就自动恢复。
/// - 级别用 [smoothLevels] 平滑，避免框一闪一闪。
library;

import 'package:flutter/foundation.dart';

import 'frame_check.dart';
import 'frame_convert.dart';

typedef FrameConverter = RgbFrame Function(RawFrame frame, {required int rotationDegrees, int targetLongSide});

/// 页面锁竖屏时，传感器帧要顺时针转多少度才是用户看到的方向。
///
/// 传感器帧是横的（宽 > 高）就按传感器方向转正；插件已经给了竖图就不再转。
/// 只处理手机常见的 90 / 270；其它传感器方向不转（平板等，不在范围内）。
int rotationForFrame({required int frameWidth, required int frameHeight, required int sensorOrientation}) {
  if (frameWidth <= frameHeight) return 0;
  final s = ((sensorOrientation % 360) + 360) % 360;
  return (s == 90 || s == 270) ? s : 0;
}

class FramingController extends ChangeNotifier {
  FramingController({
    required this.checker,
    required this.view,
    DateTime Function()? clock,
    this.minInterval = const Duration(milliseconds: 300),
    this.unavailableAfter = 3,
    this.historyLength = 5,
    FrameConverter? converter,
  })  : _clock = clock ?? DateTime.now,
        _convert = converter ?? convertFrame;

  final FrameChecker checker;
  final FramingView view;
  final Duration minInterval;
  final int unavailableAfter;
  final int historyLength;
  final DateTime Function() _clock;
  final FrameConverter _convert;

  final List<FramingLevel> _history = [];
  FramingVerdict? _verdict;
  bool _unavailable = false;
  int _failures = 0;
  bool _busy = false;
  bool _disposed = false;
  DateTime? _lastSent;
  int _sent = 0;
  int _answered = 0;

  /// 平滑后的级别。没有任何结果时是红。
  FramingLevel get level => smoothLevels(_history);

  /// 最近一次服务端判定（框、提示都取自它）。
  FramingVerdict? get verdict => _verdict;

  /// 取景自检不可用（连不上 / 缺检测器）：页面应显示静态引导框，仍允许录制。
  bool get unavailable => _unavailable;

  /// 已发出 / 已收到判定的帧数，供测试与日志。
  int get sentCount => _sent;
  int get answeredCount => _answered;

  /// 相机每来一帧就调一次。不会抛异常。
  void onFrame(RawFrame frame, {required int rotationDegrees}) {
    if (_disposed || _busy) return;
    final now = _clock();
    final last = _lastSent;
    if (last != null && now.difference(last) < minInterval) return;
    _lastSent = now;
    _busy = true;
    _sent++;
    _run(frame, rotationDegrees);
  }

  Future<void> _run(RawFrame frame, int rotation) async {
    try {
      final rgb = _convert(frame, rotationDegrees: rotation, targetLongSide: 320);
      final out = await checker.check(rgb: rgb.bytes, width: rgb.width, height: rgb.height, view: view);
      if (_disposed) return;
      switch (out) {
        case FrameChecked(:final verdict):
          _answered++;
          _failures = 0;
          _unavailable = false;
          _verdict = verdict;
          _history.add(verdict.level);
          if (_history.length > historyLength) _history.removeAt(0);
        case FrameBusy():
          return; // 丢这一帧，不算故障，也不改显示
        case FrameUnavailable():
          _failures++;
          if (_failures >= unavailableAfter && !_unavailable) {
            _unavailable = true;
            _history.clear();
            _verdict = null;
          } else {
            return;
          }
      }
      notifyListeners();
    } catch (_) {
      // 帧转换出错等：当作一次失败，不让相机回调链崩
      if (_disposed) return;
      _failures++;
      if (_failures >= unavailableAfter && !_unavailable) {
        _unavailable = true;
        _history.clear();
        _verdict = null;
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
