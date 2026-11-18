/// 视频分析服务（video_service）客户端（PRD AI-4，M5 简报 4.3 / 4.5）。
///
/// 接口：POST /analyze（multipart：file + meta JSON）→ {job_id}；GET /results/{job_id} 轮询。
/// 构建参数：VIDEO_ANALYSIS（默认关闭）、VIDEO_BASE_URL（默认 http://10.0.2.2:8001，模拟器访问宿主机）。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// 是否显示视频纠错入口：--dart-define=VIDEO_ANALYSIS=true。
const videoAnalysisEnabled = bool.fromEnvironment('VIDEO_ANALYSIS', defaultValue: false);

/// 视频分析服务地址：真机演示时填笔记本局域网 IP，如 http://192.168.1.23:8001。
const videoBaseUrl =
    String.fromEnvironment('VIDEO_BASE_URL', defaultValue: 'http://10.0.2.2:8001');

/// 视频时长上限（秒），M5 简报 4.3。上传时作为 meta.max_duration 传给服务端校验。
const videoMaxDurationSec = 120;

enum VideoErrorKind {
  /// 连不上服务（未启动、地址不对、不在同一网络）。
  unreachable,

  /// 服务返回失败。
  failed,

  /// 视频超过时长上限。
  tooLong,

  /// 轮询超过 5 分钟。
  timeout,
}

class VideoApiException implements Exception {
  VideoApiException(this.kind, [this.detail]);
  final VideoErrorKind kind;
  final String? detail;
  @override
  String toString() => 'VideoApiException($kind${detail == null ? '' : ': $detail'})';
}

sealed class VideoJob {
  const VideoJob();
}

class VideoJobPending extends VideoJob {
  const VideoJobPending();
}

class VideoJobDone extends VideoJob {
  const VideoJobDone(this.result);
  final Map<String, dynamic> result;
}

class VideoJobFailed extends VideoJob {
  const VideoJobFailed(this.error);
  final String error;
}

abstract class VideoAnalysisApi {
  /// 上传视频与 meta，返回 job_id。连不上抛 [VideoApiException]（unreachable）。
  Future<String> submit({required String filePath, required Map<String, Object?> meta});

  Future<VideoJob> poll(String jobId);
}

class DioVideoAnalysisApi implements VideoAnalysisApi {
  DioVideoAnalysisApi({String baseUrl = videoBaseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(minutes: 3),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;

  @override
  Future<String> submit({required String filePath, required Map<String, Object?> meta}) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: p.basename(filePath)),
        'meta': jsonEncode(meta),
      });
      final resp = await _dio.post<Map<String, dynamic>>('/analyze', data: form);
      final id = resp.data?['job_id'];
      if (id is! String) throw VideoApiException(VideoErrorKind.failed, 'no job_id');
      return id;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<VideoJob> poll(String jobId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/results/$jobId');
      final body = resp.data ?? const {};
      switch (body['status']) {
        case 'done':
          return VideoJobDone(Map<String, dynamic>.from(body['result'] as Map));
        case 'failed':
          return VideoJobFailed((body['error'] ?? '').toString());
        default:
          return const VideoJobPending();
      }
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static VideoApiException _map(DioException e) {
    if (e.type == DioExceptionType.badResponse) {
      return VideoApiException(VideoErrorKind.failed, '${e.response?.statusCode}');
    }
    return VideoApiException(VideoErrorKind.unreachable, e.type.name);
  }
}

/// 服务端失败信息里带这个标记表示视频超长（video_service 的 max_duration 校验）。
bool isTooLongError(String error) => error.contains('video_too_long');
