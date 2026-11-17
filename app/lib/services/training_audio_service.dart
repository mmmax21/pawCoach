/// 跟练的后台音频（TR-3 / TR-4，M2 简报第 6 节）。
///
/// 一个 audio_service 的 [BaseAudioHandler]，同时承担四件事：
/// - 通知栏 / 锁屏控制中心：技能名 + 当前步骤 + 剩余秒数，"暂停 / 下一步"按钮；
/// - 前台服务保活：循环播放一条静音轨道（just_audio），让系统认为 App 在播放音频；
/// - TTS：flutter_tts 朗读步骤指令与"下一步"；
/// - 响片音效：just_audio 播放 assets/audio/clicker.wav。
///
/// 计时本身不在这里：这里只在每次收到 tick（来自 UI 的 Timer 或回前台）时
/// 把状态机算好的剩余秒数写进通知。后台期间 Timer 可能被冻结，
/// 回到前台第一次 tick 由 [TrainingMachine.tick] 按绝对时间差值追赶。
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

/// 跟练页依赖的音频能力。真实实现是 [TrainingAudioHandler]，单测用假实现。
abstract class TrainingAudioPort {
  Future<void> beginSession({
    required String skillName,
    required TrainingRemoteControls controls,
  });
  Future<void> endSession();
  void showProgress({
    required String skillName,
    required int stepNumber,
    required int stepCount,
    required int remainingSec,
    required bool paused,
  });

  /// 依次朗读；开始前先打断正在朗读的内容。
  Future<void> speakSequence(List<String> lines);
  Future<void> stopSpeaking();
  Future<void> playClicker();
}

/// 通知栏按钮回调，由跟练页绑定到状态机。
class TrainingRemoteControls {
  TrainingRemoteControls({
    required this.onPauseResume,
    required this.onNext,
  });
  final void Function() onPauseResume;
  final void Function() onNext;
}

class TrainingAudioHandler extends BaseAudioHandler
    implements TrainingAudioPort {
  TrainingAudioHandler() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _silence = AudioPlayer();
  final AudioPlayer _clicker = AudioPlayer();

  TrainingRemoteControls? _controls;
  bool _ready = false;
  bool _session = false;
  bool _paused = false;

  /// 诊断用：最近一次朗读的文本与计数（日志里带时间戳，交接单的锁屏实测靠它核对）。
  final ValueNotifier<String> lastSpoken = ValueNotifier('');
  int speakCount = 0;
  int speakCompleted = 0;
  int _speakGeneration = 0;

  Future<void> _init() async {
    try {
      await _tts.setLanguage('zh-CN');
    } catch (e) {
      debugPrint('TTS setLanguage 失败：$e');
    }
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => debugPrint('TTS start @${DateTime.now().toIso8601String()}'));
    _tts.setCompletionHandler(() {
      speakCompleted++;
      debugPrint('TTS completed #$speakCompleted @${DateTime.now().toIso8601String()}');
    });
    _tts.setErrorHandler((m) => debugPrint('TTS error: $m'));
    // iOS：playback 类别，锁屏与静音开关下仍可发声；与静音保活轨道、响片混音。
    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
      );
    } catch (_) {
      // 非 iOS 平台忽略。
    }
    try {
      await _silence.setAsset('assets/audio/silence.wav');
      await _silence.setLoopMode(LoopMode.one);
      await _silence.setVolume(0);
      await _clicker.setAsset('assets/audio/clicker.wav');
    } catch (e) {
      debugPrint('音频资源加载失败：$e');
    }
    _ready = true;
  }

  // ---- 会话生命周期 ------------------------------------------------------

  /// 开始一次跟练会话：启动前台服务与静音保活轨道。
  @override
  Future<void> beginSession({
    required String skillName,
    required TrainingRemoteControls controls,
  }) async {
    _controls = controls;
    _paused = false;
    _session = true;
    while (!_ready) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    mediaItem.add(MediaItem(id: 'training', title: skillName));
    _publish(playing: true);
    // 保活轨道只为让系统认为 App 在播放音频，音量为 0。
    unawaited(_silence.play());
  }

  /// 结束会话：关闭保活轨道与前台服务。
  @override
  Future<void> endSession() async {
    _session = false;
    _controls = null;
    await _tts.stop();
    await _silence.pause();
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  // ---- 状态展示 ----------------------------------------------------------

  /// 更新通知栏 / 锁屏文案：技能名 + 步骤 + 剩余秒数。
  @override
  void showProgress({
    required String skillName,
    required int stepNumber,
    required int stepCount,
    required int remainingSec,
    required bool paused,
  }) {
    if (!_session) return;
    _paused = paused;
    mediaItem.add(MediaItem(
      id: 'training',
      title: skillName,
      album: '第 $stepNumber / $stepCount 步',
      artist: paused ? '已暂停' : '剩余 $remainingSec 秒',
    ));
    _publish(playing: !paused);
  }

  void _publish({required bool playing}) {
    playbackState.add(PlaybackState(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.pause, MediaAction.play, MediaAction.skipToNext},
      androidCompactActionIndices: const [0, 1],
      processingState: AudioProcessingState.ready,
      playing: playing, // Android 媒体按钮按此状态渲染；前台服务由 androidStopForegroundOnPause=false 保持
    ));
  }

  // ---- 语音与音效 --------------------------------------------------------

  /// 依次朗读 [lines]。新的调用会打断上一次尚未读完的序列（跳步、重来、暂停）。
  @override
  Future<void> speakSequence(List<String> lines) async {
    final gen = ++_speakGeneration;
    try {
      await _tts.stop();
    } catch (_) {}
    for (final line in lines) {
      if (line.isEmpty) continue;
      if (gen != _speakGeneration || !_session) return;
      speakCount++;
      lastSpoken.value = line;
      debugPrint('TTS speak #$speakCount @${DateTime.now().toIso8601String()}: $line');
      try {
        await _tts.speak(line);
      } catch (e) {
        debugPrint('TTS 朗读失败：$e');
      }
    }
  }

  @override
  Future<void> stopSpeaking() async {
    _speakGeneration++;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> playClicker() async {
    try {
      await _clicker.seek(Duration.zero);
      unawaited(_clicker.play());
    } catch (e) {
      debugPrint('响片音效播放失败：$e');
    }
  }

  // ---- 通知栏按钮 --------------------------------------------------------

  @override
  Future<void> pause() async => _controls?.onPauseResume();

  @override
  Future<void> play() async => _controls?.onPauseResume();

  @override
  Future<void> skipToNext() async => _controls?.onNext();

  @override
  Future<void> stop() async {
    // 通知栏被划掉：不丢弃训练，只暂停。
    if (_session && !_paused) _controls?.onPauseResume();
  }
}

TrainingAudioHandler? _handler;

/// 全局唯一的 handler，main() 里初始化。
TrainingAudioHandler get trainingAudio {
  final h = _handler;
  if (h == null) {
    throw StateError('TrainingAudioHandler 尚未初始化，先调用 initTrainingAudio()');
  }
  return h;
}

bool get trainingAudioReady => _handler != null;

Future<void> initTrainingAudio() async {
  if (_handler != null) return;
  _handler = await AudioService.init(
    builder: TrainingAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.puppytrainer.puppy_trainer.training',
      androidNotificationChannelName: '训练引导',
      androidNotificationChannelDescription: '跟练时显示当前步骤与剩余时间',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );
}
