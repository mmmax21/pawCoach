/// 狗的状态（身体信号）：调用视频分析服务的 POST /body-check，以及选视频 / 照片。
///
/// 和视频纠错用同一个服务地址（"我的 → 视频分析服务地址"）。上传的文件服务端分析完立即删除。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/providers.dart';
import '../../domain/body_signals.dart';
import '../repositories/body_repository.dart';

enum BodyCheckError { unreachable, busy, failed }

class BodyCheckException implements Exception {
  BodyCheckException(this.kind, [this.detail = '']);
  final BodyCheckError kind;
  final String detail;
  @override
  String toString() => 'BodyCheckException($kind, $detail)';
}

abstract class BodyCheckApi {
  /// 上传一段 ≤20 秒的视频或一张照片，返回身体信号测量结果。
  Future<BodySummary> check(String filePath);
}

class DioBodyCheckApi implements BodyCheckApi {
  DioBodyCheckApi({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(minutes: 2),
              receiveTimeout: const Duration(minutes: 2),
            ));
  final Dio _dio;

  @override
  Future<BodySummary> check(String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: p.basename(filePath)),
      });
      final resp = await _dio.post<Map<String, dynamic>>('/body-check', data: form);
      return BodySummary.fromJson(resp.data ?? const {});
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        throw BodyCheckException(
            e.response?.statusCode == 429 ? BodyCheckError.busy : BodyCheckError.failed, '${e.response?.statusCode}');
      }
      throw BodyCheckException(BodyCheckError.unreachable, e.type.name);
    }
  }
}

enum BodyMediaSource { recordVideo, galleryVideo, photo }

abstract class BodyMediaPicker {
  Future<String?> pick(BodyMediaSource source);
}

class ImagePickerBodyMedia implements BodyMediaPicker {
  @override
  Future<String?> pick(BodyMediaSource source) async {
    final picker = ImagePicker();
    final XFile? x = switch (source) {
      BodyMediaSource.recordVideo =>
        await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 15)),
      BodyMediaSource.galleryVideo => await picker.pickVideo(source: ImageSource.gallery),
      BodyMediaSource.photo => await picker.pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 85),
    };
    return x?.path;
  }
}

final bodyCheckApiProvider =
    Provider<BodyCheckApi>((ref) => DioBodyCheckApi(baseUrl: ref.watch(videoUrlProvider)));
final bodyMediaPickerProvider = Provider<BodyMediaPicker>((ref) => ImagePickerBodyMedia());
final bodyRepositoryProvider = Provider((ref) => BodyRepository(ref.watch(databaseProvider)));
