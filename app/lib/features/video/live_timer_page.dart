/// 实时计时页：边练边看口令、坐下、奖励各发生在第几秒，以及奖励比坐下晚了多久。
///
/// 画面（竖屏，相机预览铺满上半部分）：
/// - 预览上叠狗的检测框，颜色随状态变：坐着 / 站着 / 还没看清
/// - 一个大读数：狗坐下后从 0 开始走，奖励一出现就定格；超过阈值变红
/// - 超过阈值时，读数下方出现内容库里"奖励给得太晚"那一条 common_mistakes 的原文
///   （原文，一字不改；怎么改由内容库说，页面只负责把它放到对的时刻）
/// - 底部：最近几轮的口令 / 坐下 / 奖励时刻，和一个大的"奖励"按钮（没有麦克风时的主要输入方式）
///
/// 页面只依赖 [LiveController]，相机、麦克风、网络都在接口后面，所以能用替身做 widget 测试。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/video/capture_camera.dart';
import '../../data/video/frame_check.dart' show NRect;
import '../../data/video/live_client.dart';
import '../../data/video/live_controller.dart';
import '../../domain/models.dart';
import 'live_strings.dart';

/// 内容库里"奖励晚"这条常见错误的原文，由技能的 video_checks 映射决定下标。没有映射时返回 null。
String? lateRewardMistakeText(Skill skill) {
  for (final m in skill.videoChecks) {
    if (m.detector == 'late_reward' && m.mistake < skill.tutorial.commonMistakes.length) {
      return skill.tutorial.commonMistakes[m.mistake];
    }
  }
  return null;
}

/// 重复口令那一条的原文。
String? repeatedCueMistakeText(Skill skill) {
  for (final m in skill.videoChecks) {
    if (m.detector == 'repeated_cue' && m.mistake < skill.tutorial.commonMistakes.length) {
      return skill.tutorial.commonMistakes[m.mistake];
    }
  }
  return null;
}

/// 内容库里 late_reward 的 threshold_sec。没有配置（或没有该检测器）返回 null，页面据此不显示入口，
/// 不会退回一个写死的数。
double? lateThresholdOf(VideoChecksConfig? config) {
  final rule = config?.detectors['late_reward'];
  final v = rule?.params['threshold_sec'];
  return v?.toDouble();
}

typedef LiveControllerFactory = LiveController Function(WidgetRef ref, double lateSec);

class LiveTimerPage extends ConsumerStatefulWidget {
  const LiveTimerPage({super.key, required this.skill, required this.lateSec, this.onFinished});
  final Skill skill;

  /// "奖励晚"的阈值（秒），由调用方从内容库 video_checks.yaml 的 late_reward.threshold_sec 读出。
  final double lateSec;

  /// 点"结束并查看"拿到最终结果后回调（带服务端结果）。为 null 时页面自己 pop 并返回结果。
  final void Function(Map<String, dynamic> result)? onFinished;

  @override
  ConsumerState<LiveTimerPage> createState() => _LiveTimerPageState();
}

class _LiveTimerPageState extends ConsumerState<LiveTimerPage> with WidgetsBindingObserver {
  LiveController? _ctl;
  CaptureCamera? _camera;
  String? _cameraError;
  bool _cameraPermission = true;
  bool _opening = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _cameraError = null;
    });
    final cam = ref.read(captureCameraFactoryProvider)();
    _camera = cam;
    try {
      await cam.open();
    } on CaptureCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _cameraPermission = !e.isPermission;
        _cameraError = e.isPermission ? LiveStrings.errNoPermission : LiveStrings.errCamera;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _cameraError = LiveStrings.errCamera;
      });
      return;
    }
    if (!mounted) {
      await cam.dispose();
      return;
    }
    final ctl = ref.read(liveControllerFactoryProvider)(ref, widget.lateSec)..addListener(_onChange);
    _ctl = ctl;
    setState(() => _opening = false);
    unawaited(ctl.connect());
    // 读数每 100 毫秒刷新一次：服务端快照是事件驱动的，狗坐着不动时不会有新快照，
    // 但"已等多久"要一直走，所以页面按本地时钟补算。
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _ctl?.phase == LivePhase.running) setState(() {});
    });
  }

  void _onChange() {
    if (!mounted) return;
    final c = _ctl!;
    if (c.phase == LivePhase.done && c.result != null) {
      final cb = widget.onFinished;
      if (cb != null) {
        cb(c.result!);
      } else {
        Navigator.of(context).pop<Map<String, dynamic>>(c.result);
      }
      return;
    }
    setState(() {});
  }

  Future<void> _start() async {
    final c = _ctl, cam = _camera;
    if (c == null || cam == null) return;
    await c.start();
    try {
      await cam.startStream((frame) => c.onCameraFrame(frame, sensorOrientation: cam.sensorOrientation));
    } on CaptureCameraException {
      if (mounted) setState(() => _cameraError = LiveStrings.errCamera);
    }
  }

  Future<void> _finish() async {
    await _camera?.stopStream();
    await _ctl?.finish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 练习中切后台：相机和连接都会被系统收走，回来不可能无缝继续，直接诚实地结束这一次
    if ((state == AppLifecycleState.paused) && _ctl?.phase == LivePhase.running) {
      unawaited(_finish());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _ctl?.removeListener(_onChange);
    _ctl?.dispose();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  // ---------------------------------------------------------------- 界面 ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(LiveStrings.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_opening) return const Center(child: CircularProgressIndicator(key: Key('live_opening')));
    if (_cameraError != null) return _errorView(_cameraError!, canRetry: _cameraPermission);
    final c = _ctl;
    if (c == null) return const Center(child: CircularProgressIndicator());
    switch (c.phase) {
      case LivePhase.failed:
        return _errorView(_failureText(c), canRetry: true, onRetry: () {
          unawaited(c.connect());
        });
      case LivePhase.idle:
      case LivePhase.connecting:
        return _withPreview(_centerNote(LiveStrings.connecting, key: const Key('live_connecting')), c);
      case LivePhase.ready:
        return _withPreview(_readyPanel(), c);
      case LivePhase.running:
      case LivePhase.finishing:
      case LivePhase.done:
        return _runningView(context, c);
    }
  }

  String _failureText(LiveController c) => switch (c.failure) {
        LiveFailure.unreachable => LiveStrings.errUnreachable,
        LiveFailure.poseUnavailable => LiveStrings.errPose,
        LiveFailure.disconnected => LiveStrings.errDisconnected,
        _ => LiveStrings.errServer,
      };

  Widget _errorView(String text, {required bool canRetry, VoidCallback? onRetry}) => Center(
        key: const Key('live_error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            if (canRetry)
              FilledButton(
                key: const Key('live_retry'),
                onPressed: onRetry ?? () => unawaited(_open()),
                child: const Text(LiveStrings.retry),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('live_back'),
              onPressed: () => Navigator.of(context).pop<Map<String, dynamic>>(null),
              child: const Text(LiveStrings.back),
            ),
          ]),
        ),
      );

  Widget _centerNote(String text, {Key? key}) => Center(
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      );

  Widget _readyPanel() => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(LiveStrings.intro, textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('live_start'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _start,
              child: const Text(LiveStrings.start),
            ),
          ]),
        ),
      );

  Widget _withPreview(Widget overlay, LiveController c) {
    final cam = _camera!;
    return Center(
      child: AspectRatio(
        aspectRatio: cam.previewAspectRatio,
        child: Stack(fit: StackFit.expand, children: [cam.buildPreview(context), overlay]),
      ),
    );
  }

  Widget _runningView(BuildContext context, LiveController c) {
    final cam = _camera!;
    final snap = c.snapshot;
    final live = snap?.liveTrial;
    final stage = stageOf(snap);
    final delay = _shownDelay(c, live);
    // "晚"以服务端判定为准，本地补算只让数字走动：服务端 late 是它按同一阈值算的，
    // 本地时钟比服务端最后一次快照走得更快，用本地值判晚会在服务端还没确认时提前亮红。
    // 唯一的例外是读数已经明显越过阈值、而服务端快照还没追上（狗坐着不动、没有新快照）。
    final late = _liveLate(c, live);
    final hintCode = snap?.hint;
    final hintText = LiveStrings.hintFor(hintCode, cueCount: live?.cueCount ?? 0);
    final mistake = (hintCode == 'reward_late' || late == true)
        ? lateRewardMistakeText(widget.skill)
        : (hintCode == 'cue_repeated' ? repeatedCueMistakeText(widget.skill) : null);
    final finishing = c.phase == LivePhase.finishing;

    return Column(children: [
      Expanded(
        flex: 5,
        child: Center(
          child: AspectRatio(
            aspectRatio: cam.previewAspectRatio,
            child: Stack(fit: StackFit.expand, children: [
              cam.buildPreview(context),
              CustomPaint(painter: _DogBoxPainter(snap?.dogBox, _dogColor(snap?.dogState))),
              Positioned(top: 8, left: 8, child: _dogChip(snap?.dogState)),
              Positioned(top: 8, right: 8, child: _micChip(c)),
              if (hintText != null)
                Positioned(
                  top: 44,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      key: const Key('live_hint'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: hintCode == 'reward_late' ? Colors.red : Colors.orange,
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(hintText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
      Container(
        width: double.infinity,
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _delayReadout(stage, delay, late, live),
          if (mistake != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                key: const Key('live_mistake'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3A1F1F), borderRadius: BorderRadius.circular(10)),
                child: Text(mistake, style: const TextStyle(color: Colors.white, height: 1.35)),
              ),
            ),
          const SizedBox(height: 8),
          _trialStrip(snap),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                key: const Key('live_reward'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: finishing ? null : c.tapReward,
                icon: const Icon(Icons.pets),
                label: const Text(LiveStrings.reward, style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton(
                key: const Key('live_finish'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), foregroundColor: Colors.white),
                onPressed: finishing ? null : _finish,
                child: Text(finishing ? LiveStrings.finishing : LiveStrings.finish),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  /// 屏幕上的延迟读数。已奖励：服务端给的最终值。还没奖励：服务端的 runningDelay 是它最后一次
  /// 算出来的，狗坐着不动时不会有新快照，所以用"本地现在 - 快照时刻"补上这段时间，读数才会一直走。
  double? _shownDelay(LiveController c, LiveTrialView? live) {
    if (live == null) return null;
    if (live.rewardDelay != null) return live.rewardDelay;
    final base = live.runningDelay;
    final snapT = c.snapshot?.t;
    if (base == null || snapT == null) return base;
    return base + (c.now - snapT).clamp(0.0, 30.0);
  }

  bool? _liveLate(LiveController c, LiveTrialView? live) {
    if (live == null) return null;
    if (live.rewardDelay != null) return live.late; // 已奖励：最终值，服务端说了算
    final d = _shownDelay(c, live);
    if (d == null) return null;
    return live.late || d > c.lateSec; // 等奖励中：服务端已判晚，或本地读数已越过阈值
  }

  Widget _delayReadout(LiveStage stage, double? delay, bool? late, LiveTrialView? live) {
    final color = late == true ? Colors.redAccent : (stage == LiveStage.rewarded ? Colors.greenAccent : Colors.white);
    final label = switch (stage) {
      LiveStage.waitingCue => LiveStrings.waitingCue,
      LiveStage.waitingDog => LiveStrings.waitingDog,
      LiveStage.waitingReward => delay == null ? LiveStrings.waitingReward : LiveStrings.delayRunning(delay),
      LiveStage.rewarded => delay == null
          ? LiveStrings.noRewardYet
          : (late == true ? LiveStrings.delay(delay) : LiveStrings.onTime(delay)),
    };
    return Column(children: [
      Text(
        LiveStrings.bigDelay(delay),
        key: const Key('live_delay'),
        style: TextStyle(color: color, fontSize: 56, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      Text(label, key: const Key('live_stage'), style: TextStyle(color: color, fontSize: 15)),
    ]);
  }

  Widget _trialStrip(LiveSnapshot? snap) {
    final trials = snap?.trials ?? const [];
    if (trials.isEmpty) return const SizedBox(height: 4);
    final recent = trials.length > 3 ? trials.sublist(trials.length - 3) : trials;
    final offset = trials.length - recent.length;
    return Column(
      key: const Key('live_trials'),
      children: [
        for (var i = 0; i < recent.length; i++) _trialRow(offset + i + 1, recent[i]),
      ],
    );
  }

  Widget _trialRow(int n, LiveTrialView t) {
    final row = LiveStrings.trialRow(n, cues: t.cueTimes, sit: t.sitStart, reward: t.rewardT);
    final bad = t.late || t.cueCount >= 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(bad ? Icons.error_outline : Icons.check_circle_outline, size: 16, color: bad ? Colors.redAccent : Colors.greenAccent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(row,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ]),
    );
  }

  Color _dogColor(String? state) => switch (state) {
        'sit' => const Color(0xFF3DDC84),
        'stand' => const Color(0xFFFFC107),
        _ => Colors.white54,
      };

  Widget _dogChip(String? state) {
    final text = switch (state) {
      'sit' => LiveStrings.dogSit,
      'stand' => LiveStrings.dogStand,
      _ => LiveStrings.dogUnknown,
    };
    return _chip(text, key: const Key('live_dog_chip'));
  }

  Widget _micChip(LiveController c) {
    if (c.micDenied) return _chip(LiveStrings.micDenied, key: const Key('live_mic_chip'), warn: true);
    if (!c.micOk && c.micTried) return _chip(LiveStrings.micOff, key: const Key('live_mic_chip'), warn: true);
    final alive = c.snapshot?.micAlive ?? true;
    if (!alive) return _chip(LiveStrings.micQuiet, key: const Key('live_mic_chip'), warn: true);
    return const SizedBox.shrink();
  }

  Widget _chip(String text, {Key? key, bool warn = false}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: warn ? Colors.orange.shade800 : Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class _DogBoxPainter extends CustomPainter {
  _DogBoxPainter(this.box, this.color);
  final NRect? box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final b = box;
    if (b == null) return;
    final r = Rect.fromLTRB(b.left * size.width, b.top * size.height, b.right * size.width, b.bottom * size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DogBoxPainter old) => old.box != box || old.color != color;
}

// ---------------------------------------------------------------------------
// 技能页入口与结果衔接
// ---------------------------------------------------------------------------

/// 技能详情页里的"实时计时"入口。只在该技能有"奖励太晚"检测（late_reward）时出现，
/// 阈值取内容库 video_checks.yaml 里 late_reward 的 threshold_sec，不在这里写数。
/// 与"上传视频纠错"共用同一个功能开关：开关关闭时不显示。
class LiveTimerEntry extends ConsumerWidget {
  const LiveTimerEntry({super.key, required this.skill});
  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!skill.videoChecks.any((m) => m.detector == 'late_reward')) return const SizedBox.shrink();
    if (!ref.watch(videoAnalysisEnabledProvider)) return const SizedBox.shrink();
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final late = lateThresholdOf(lib?.videoChecks);
    if (late == null) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      key: const Key('live_entry'),
      icon: const Icon(Icons.timer_outlined),
      label: const Text(LiveStrings.entry),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LiveTimerPage(skill: skill, lateSec: late)),
      ),
    );
  }
}
