/// 真实麦克风：用 `record` 插件取 16kHz 单声道 16 位小端 PCM 流，交给 [LiveController]。
///
/// 和相机录像同时占用麦克风：相机的 startImageStream 不录音（只取画面），所以实时计时阶段
/// 麦克风只有这一路在用。真机上"相机预览 + record 采集"是否冲突没有验证过，见交接单"待真机验证"。
///
/// 回声消除、降噪、自动增益全部关掉：它们会把短促的口令当成噪声压掉，起音检测反而更不准。
library;

import 'dart:typed_data';

import 'package:record/record.dart';

import 'live_controller.dart';

class RecordLiveMic implements LiveMic {
  RecordLiveMic([AudioRecorder? recorder]) : _rec = recorder ?? AudioRecorder();
  final AudioRecorder _rec;

  @override
  Future<Stream<Uint8List>> start() async {
    try {
      if (!await _rec.hasPermission()) {
        throw LiveMicException('permission');
      }
      return await _rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ));
    } on LiveMicException {
      rethrow;
    } catch (e) {
      throw LiveMicException('unavailable', '$e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (await _rec.isRecording()) await _rec.stop();
    } catch (_) {}
  }
}
