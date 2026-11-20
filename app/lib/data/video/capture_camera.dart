/// 引导拍摄用的相机：把 `camera` 插件藏在一个小接口后面。
///
/// 页面只依赖 [CaptureCamera]，测试用假相机，不碰平台通道。
/// 真实现 [PluginCaptureCamera]：后置镜头、锁竖屏、720p、带声音（口令识别要用）。
///
/// 预览阶段开图像流给取景自检用；开始录制前先关掉图像流再开录，
/// 因为"边录边流"在部分机型上受限，演示要稳，录制中不做实时检查。
library;

import 'dart:io' show File, Platform;

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'frame_convert.dart';

/// 相机出错。[code]：permission（没给权限）/ no_camera（没有相机）/ 其它原样透出插件的错误码。
class CaptureCameraException implements Exception {
  CaptureCameraException(this.code, [this.message]);
  final String code;
  final String? message;
  bool get isPermission => code == 'permission';
  @override
  String toString() => 'CaptureCameraException($code${message == null ? '' : ': $message'})';
}

abstract class CaptureCamera {
  /// 打开后置相机并锁竖屏。失败抛 [CaptureCameraException]。
  Future<void> open();

  /// 预览画面本身（不含取景框）。比例由 [previewAspectRatio] 给出。
  Widget buildPreview(BuildContext context);

  /// 竖屏下预览的 宽 / 高（小于 1）。
  double get previewAspectRatio;

  /// 传感器方向（度），转正取景帧用。
  int get sensorOrientation;

  Future<void> startStream(void Function(RawFrame frame) onFrame);
  Future<void> stopStream();

  Future<void> startRecording();

  /// 停止录制，返回视频文件路径。
  Future<String> stopRecording();

  Future<void> dispose();
}

typedef CaptureCameraFactory = CaptureCamera Function();

const _permissionCodes = {
  'CameraAccessDenied',
  'CameraAccessDeniedWithoutPrompt',
  'CameraAccessRestricted',
  'AudioAccessDenied',
  'AudioAccessDeniedWithoutPrompt',
  'AudioAccessRestricted',
};

class PluginCaptureCamera implements CaptureCamera {
  CameraController? _c;
  CameraDescription? _desc;
  bool _streaming = false;
  bool _recording = false;

  CameraController get _ctl {
    final c = _c;
    if (c == null) throw CaptureCameraException('not_open');
    return c;
  }

  @override
  Future<void> open() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CaptureCameraException('no_camera');
      _desc = cams.firstWhere((d) => d.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(
        _desc!,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await c.initialize();
      _c = c;
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (e) {
      throw CaptureCameraException(_permissionCodes.contains(e.code) ? 'permission' : e.code, e.description);
    }
  }

  @override
  Widget buildPreview(BuildContext context) => CameraPreview(_ctl);

  @override
  double get previewAspectRatio {
    final ar = _ctl.value.aspectRatio; // 传感器方向的 宽/高，一般大于 1
    return ar >= 1 ? 1 / ar : ar;
  }

  @override
  int get sensorOrientation => _desc?.sensorOrientation ?? 90;

  @override
  Future<void> startStream(void Function(RawFrame frame) onFrame) async {
    if (_streaming) return;
    try {
      await _ctl.startImageStream((img) {
        final raw = _toRaw(img);
        if (raw != null) onFrame(raw);
      });
      _streaming = true;
    } on CameraException catch (e) {
      throw CaptureCameraException(e.code, e.description);
    }
  }

  @override
  Future<void> stopStream() async {
    if (!_streaming) return;
    _streaming = false;
    try {
      await _ctl.stopImageStream();
    } on CameraException {
      // 已经停了就算了
    }
  }

  @override
  Future<void> startRecording() async {
    try {
      await _ctl.startVideoRecording();
      _recording = true;
    } on CameraException catch (e) {
      throw CaptureCameraException(e.code, e.description);
    }
  }

  @override
  Future<String> stopRecording() async {
    try {
      final f = await _ctl.stopVideoRecording();
      _recording = false;
      return f.path;
    } on CameraException catch (e) {
      throw CaptureCameraException(e.code, e.description);
    }
  }

  @override
  Future<void> dispose() async {
    final c = _c;
    _c = null;
    if (c == null) return;
    try {
      if (_streaming) await c.stopImageStream();
    } catch (_) {}
    try {
      if (_recording) {
        // 页面被关掉时还在录：停掉并删掉半截视频
        final f = await c.stopVideoRecording();
        try {
          await File(f.path).delete();
        } catch (_) {}
      }
    } catch (_) {}
    _streaming = false;
    _recording = false;
    await c.dispose();
  }

  RawFrame? _toRaw(CameraImage img) {
    RawPlane plane(Plane p) => RawPlane(p.bytes, bytesPerRow: p.bytesPerRow, bytesPerPixel: p.bytesPerPixel ?? 1);
    switch (img.format.group) {
      case ImageFormatGroup.bgra8888:
        return RawFrame(format: RawFormat.bgra8888, width: img.width, height: img.height, planes: [plane(img.planes[0])]);
      case ImageFormatGroup.nv21:
        return RawFrame(format: RawFormat.nv21, width: img.width, height: img.height, planes: [plane(img.planes[0])]);
      case ImageFormatGroup.yuv420:
        if (img.planes.length < 3) return null; // iOS 的双平面 YUV 没有请求，不处理
        return RawFrame(
            format: RawFormat.yuv420, width: img.width, height: img.height, planes: [for (final p in img.planes) plane(p)]);
      default:
        return null;
    }
  }
}
