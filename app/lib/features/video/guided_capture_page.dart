/// 引导拍摄页（PRD AI-4 的拍摄环节）：相机预览 + 引导框 + 实时取景自检 + 倒计时 + 录制。
///
/// 流程：预览（边预览边把帧送去取景自检）→ 红 / 黄 / 绿 → 开始录制（倒计时 3 秒）→ 录制中 → 点"这一轮结束"
/// → 返回视频路径给上一页走原来的上传分析。
///
/// 取景自检只是引导：
/// - 绿灯：直接开始。
/// - 黄灯：能录，提示可能判不准。
/// - 红灯：按钮文案变成"仍然录制"提醒主人多半拍不到完整的狗，但不禁止：现场光线、机位总有检测器看不准的时候。
/// - 取景检查不可用（连不上服务 / 缺检测器）：显示静态引导框，允许直接录制，演示不会因此卡死。
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/video/capture_camera.dart';
import '../../data/video/frame_check.dart';
import '../../data/video/framing_controller.dart';
import 'video_strings.dart';

/// 录制时长上下限（秒）。上限与服务端 max_duration 一致；下限防止误触录出一段空视频。
const guidedMinSeconds = 3;
const guidedMaxSeconds = 120;
const guidedCountdownSeconds = 3;

enum _Stage { opening, preview, countdown, recording, stopping, error }

class GuidedCapturePage extends ConsumerStatefulWidget {
  const GuidedCapturePage({super.key, this.view = FramingView.side});
  final FramingView view;

  @override
  ConsumerState<GuidedCapturePage> createState() => _GuidedCapturePageState();
}

class _GuidedCapturePageState extends ConsumerState<GuidedCapturePage> with WidgetsBindingObserver {
  CaptureCamera? _camera;
  FramingController? _framing;
  _Stage _stage = _Stage.opening;
  String? _errorText;
  bool _errorIsPermission = false;
  int _count = guidedCountdownSeconds;
  int _seconds = 0;
  Timer? _timer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final cam = ref.read(captureCameraFactoryProvider)();
    _camera = cam;
    try {
      await cam.open();
      if (_disposed) {
        await cam.dispose();
        return;
      }
      final framing = FramingController(checker: ref.read(frameCheckerProvider), view: widget.view)
        ..addListener(_onFraming);
      _framing = framing;
      await _startStream();
      if (!mounted) return;
      setState(() => _stage = _Stage.preview);
    } on CaptureCameraException catch (e) {
      _fail(e);
    } catch (e) {
      _fail(CaptureCameraException('open_failed', '$e'));
    }
  }

  Future<void> _startStream() async {
    final cam = _camera, framing = _framing;
    if (cam == null || framing == null) return;
    try {
      await cam.startStream((frame) {
        // 帧大多是横的传感器图，转正后再发
        final rot = rotationForFrame(
            frameWidth: frame.width, frameHeight: frame.height, sensorOrientation: cam.sensorOrientation);
        framing.onFrame(frame, rotationDegrees: rot);
      });
    } on CaptureCameraException {
      // 图像流开不了：取景检查没法用，但相机预览和录制照常
      framing.dispose();
      _framing = null;
    }
  }

  void _fail(CaptureCameraException e) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.error;
      _errorIsPermission = e.isPermission;
      _errorText = e.isPermission
          ? VideoStrings.guideNoPermission
          : e.code == 'no_camera'
              ? VideoStrings.guideNoCamera
              : VideoStrings.guideCameraFailed;
    });
  }

  void _onFraming() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切后台：录制中的视频不能丢，但预览阶段要释放相机；回来后重开
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_stage == _Stage.preview || _stage == _Stage.countdown) {
        _timer?.cancel();
        unawaited(_releaseCamera());
        if (mounted) setState(() => _stage = _Stage.opening);
      }
    } else if (state == AppLifecycleState.resumed && _stage == _Stage.opening && _camera == null) {
      unawaited(_open());
    }
  }

  Future<void> _releaseCamera() async {
    final cam = _camera;
    final framing = _framing;
    _camera = null;
    _framing = null;
    framing?.dispose();
    await cam?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_releaseCamera());
    super.dispose();
  }

  // ---- 录制
  bool get _canStartDirectly {
    final f = _framing;
    if (f == null || f.unavailable) return true; // 没有自检就不拦
    return f.level != FramingLevel.red;
  }

  Future<void> _beginCountdown() async {
    if (_stage != _Stage.preview) return;
    setState(() {
      _stage = _Stage.countdown;
      _count = guidedCountdownSeconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_count <= 1) {
        t.cancel();
        unawaited(_startRecording());
      } else {
        setState(() => _count--);
      }
    });
  }

  Future<void> _startRecording() async {
    final cam = _camera;
    if (cam == null || !mounted) return;
    try {
      // 录制中不做取景检查：先停图像流再开录，避免"边录边流"在部分机型上受限
      await cam.stopStream();
      await cam.startRecording();
    } on CaptureCameraException {
      _fail(CaptureCameraException('record_failed'));
      return;
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.recording;
      _seconds = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _seconds++);
      if (_seconds >= guidedMaxSeconds) {
        t.cancel();
        unawaited(_stopRecording());
      }
    });
  }

  Future<void> _stopRecording() async {
    if (_stage != _Stage.recording) return;
    _timer?.cancel();
    final cam = _camera;
    if (cam == null) return;
    setState(() => _stage = _Stage.stopping);
    try {
      final path = await cam.stopRecording();
      if (!mounted) return;
      Navigator.of(context).pop<String>(path);
    } on CaptureCameraException {
      _fail(CaptureCameraException('record_failed'));
    }
  }

  // ---- 界面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(VideoStrings.guidedTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.opening => const Center(child: CircularProgressIndicator(key: Key('guided_opening'))),
          _Stage.error => _errorView(),
          _ => _cameraView(context),
        },
      ),
    );
  }

  Widget _errorView() => Center(
        key: const Key('guided_error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_errorText ?? VideoStrings.guideCameraFailed,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            if (!_errorIsPermission)
              FilledButton(
                key: const Key('guided_retry'),
                onPressed: () {
                  setState(() => _stage = _Stage.opening);
                  unawaited(_releaseCamera().then((_) => _open()));
                },
                child: const Text(VideoStrings.retry),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('guided_back'),
              onPressed: () => Navigator.of(context).pop<String>(null),
              child: const Text(VideoStrings.pickGallery),
            ),
          ]),
        ),
      );

  Color _levelColor(FramingLevel l) => switch (l) {
        FramingLevel.green => const Color(0xFF3DDC84),
        FramingLevel.yellow => const Color(0xFFFFC107),
        FramingLevel.red => const Color(0xFFFF5252),
      };

  Widget _cameraView(BuildContext context) {
    final cam = _camera!;
    final framing = _framing;
    final recording = _stage == _Stage.recording || _stage == _Stage.stopping;
    final live = !recording && framing != null && !framing.unavailable && framing.verdict != null;
    final level = live ? framing.level : null;
    final color = level == null ? Colors.white70 : _levelColor(level);
    final guide = live ? framing.verdict!.guide : _staticGuide(widget.view);

    final message = recording
        ? VideoStrings.guideRecording
        : _stage == _Stage.countdown
            ? VideoStrings.guideCountdown
            : framing == null || framing.unavailable
                ? VideoStrings.guideOffline
                : framing.verdict == null
                    ? VideoStrings.guideChecking
                    : framing.verdict!.message;

    return Column(children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: cam.previewAspectRatio,
            child: Stack(fit: StackFit.expand, children: [
              cam.buildPreview(context),
              CustomPaint(
                key: const Key('guided_overlay'),
                painter: _OverlayPainter(
                  guide: guide,
                  dogBox: live ? framing.verdict!.dogBox : null,
                  personBox: live ? framing.verdict!.personBox : null,
                  color: color,
                  dashed: !live,
                ),
              ),
              if (_stage == _Stage.countdown)
                Center(
                  child: Text('$_count',
                      key: const Key('guided_count'),
                      style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold)),
                ),
              if (recording)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Text(VideoStrings.guideSeconds(_seconds),
                          key: const Key('guided_seconds'), style: const TextStyle(color: Colors.white)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
      Container(
        width: double.infinity,
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(message,
                  key: const Key('guided_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ]),
          if (!recording && framing != null && framing.unavailable)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(VideoStrings.guideOfflineBanner,
                  key: Key('guided_offline'), style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          if (_stage == _Stage.preview && (framing == null))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(VideoStrings.guideSideHint, style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          _actionButton(),
        ]),
      ),
    ]);
  }

  Widget _actionButton() {
    switch (_stage) {
      case _Stage.preview:
        final direct = _canStartDirectly;
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('guided_start'),
            icon: const Icon(Icons.fiber_manual_record),
            label: Text(direct ? VideoStrings.guideStart : VideoStrings.guideStartAnyway),
            style: direct ? null : FilledButton.styleFrom(backgroundColor: Colors.white24),
            onPressed: () => unawaited(_beginCountdown()),
          ),
        );
      case _Stage.countdown:
        return const SizedBox(height: 48);
      case _Stage.recording:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('guided_stop'),
            icon: const Icon(Icons.stop),
            label: const Text(VideoStrings.guideStop),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _seconds < guidedMinSeconds ? null : _stopRecording,
          ),
        );
      default:
        return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
    }
  }

  /// 取景检查不可用时的静态引导框（与服务端 SPECS 的 guide 一致）。
  NRect _staticGuide(FramingView v) =>
      v == FramingView.side ? const NRect(0.08, 0.40, 0.92, 0.80) : const NRect(0.10, 0.12, 0.90, 0.62);

}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.guide,
    required this.dogBox,
    required this.personBox,
    required this.color,
    required this.dashed,
  });

  final NRect guide;
  final NRect? dogBox;
  final NRect? personBox;
  final Color color;
  final bool dashed;

  Rect _r(NRect n, Size s) => Rect.fromLTRB(n.left * s.width, n.top * s.height, n.right * s.width, n.bottom * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final g = RRect.fromRectAndRadius(_r(guide, size), const Radius.circular(12));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    if (dashed) {
      _dashed(canvas, g, stroke);
    } else {
      canvas.drawRRect(g, stroke);
    }
    if (dogBox != null) {
      canvas.drawRect(
          _r(dogBox!, size),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: 0.8));
    }
    if (personBox != null) {
      canvas.drawRect(
          _r(personBox!, size),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white54);
    }
  }

  void _dashed(Canvas canvas, RRect rr, Paint paint) {
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 10), paint);
        d += 18;
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter o) =>
      o.guide != guide || o.dogBox != dogBox || o.personBox != personBox || o.color != color || o.dashed != dashed;
}
