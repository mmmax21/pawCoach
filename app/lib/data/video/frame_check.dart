/// 取景自检（实时引导）的数据模型、平滑规则与客户端。
///
/// 服务端 `POST /frame-check` 对每一帧给出红 / 黄 / 绿；App 把最近几次结果平滑后再显示，
/// 避免框一闪一闪。平滑规则与 video_service/pawcoach/framing.py 的 `smooth_levels` 一致。
///
/// 降级：连不上、超时、服务缺检测器（503）都不是错误，只是"取景自检不可用"——框变成静态引导框，
/// 仍然允许录制。App 绝不因为取景自检挂了而不让录像。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

enum FramingLevel { green, yellow, red }

/// 引导机位：侧拍判姿态与时机，俯拍判手法（识别能力赛后做，这里只有取景）。
enum FramingView { side, top }

/// 归一化矩形（0~1，相对画面宽高）。
class NRect {
  const NRect(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;

  double get width => right - left;
  double get height => bottom - top;

  factory NRect.fromList(List<dynamic> v) => NRect(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is NRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'NRect($left, $top, $right, $bottom)';
}

/// 与服务端 `FrameVerdict.to_dict()` 一一对应。
class FramingVerdict {
  const FramingVerdict({
    required this.level,
    required this.message,
    required this.reasons,
    required this.guide,
    this.dogBox,
    this.personBox,
    this.inside = 0,
  });

  final FramingLevel level;
  final String message;
  final List<String> reasons;
  final NRect guide;
  final NRect? dogBox;
  final NRect? personBox;
  final double inside;

  factory FramingVerdict.fromJson(Map<String, dynamic> j) {
    NRect? rect(Object? v) => v is List ? NRect.fromList(v) : null;
    return FramingVerdict(
      level: switch (j['level']) {
        'green' => FramingLevel.green,
        'yellow' => FramingLevel.yellow,
        _ => FramingLevel.red,
      },
      message: (j['message'] ?? '').toString(),
      reasons: [for (final r in (j['reasons'] as List? ?? const [])) r.toString()],
      guide: rect(j['guide']) ?? const NRect(0, 0, 1, 1),
      dogBox: rect(j['dog_box']),
      personBox: rect(j['person_box']),
      inside: (j['inside'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 把最近几次判定平滑成一个结果。规则（与服务端 smooth_levels 相同）：
/// 最近 [need] 次全是绿才算绿；最近两次都是红才算红；其余黄。没有历史按红。
FramingLevel smoothLevels(List<FramingLevel> history, {int need = 3}) {
  if (history.isEmpty) return FramingLevel.red;
  final recent = history.length > need ? history.sublist(history.length - need) : history;
  if (recent.length >= need && recent.every((l) => l == FramingLevel.green)) {
    return FramingLevel.green;
  }
  if (recent.length >= 2 &&
      recent.sublist(recent.length - 2).every((l) => l == FramingLevel.red)) {
    return FramingLevel.red;
  }
  return FramingLevel.yellow;
}

/// 一次取景自检的结果：有判定，或"不可用"（降级）。
sealed class FrameCheckOutcome {
  const FrameCheckOutcome();
}

class FrameChecked extends FrameCheckOutcome {
  const FrameChecked(this.verdict);
  final FramingVerdict verdict;
}

/// 服务忙（429）：这一帧丢掉即可，不算故障。
class FrameBusy extends FrameCheckOutcome {
  const FrameBusy();
}

/// 取景自检不可用：连不上 / 超时 / 服务缺检测器 / 返回了看不懂的东西。
class FrameUnavailable extends FrameCheckOutcome {
  const FrameUnavailable(this.reason);
  final String reason;
}

abstract class FrameChecker {
  /// 发一帧原始 RGB（[width] × [height] × 3 字节）做取景检查。永远不抛异常。
  Future<FrameCheckOutcome> check({
    required Uint8List rgb,
    required int width,
    required int height,
    required FramingView view,
  });
}

class DioFrameChecker implements FrameChecker {
  DioFrameChecker({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              // 取景检查要快：一帧超过 1.5 秒就当这一帧没了，不让预览框越来越滞后
              connectTimeout: const Duration(seconds: 2),
              sendTimeout: const Duration(milliseconds: 1500),
              receiveTimeout: const Duration(milliseconds: 1500),
            ));

  final Dio _dio;

  @override
  Future<FrameCheckOutcome> check({
    required Uint8List rgb,
    required int width,
    required int height,
    required FramingView view,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(rgb, filename: 'frame.rgb'),
        'view': view.name,
        'format': 'rgb',
        'width': width,
        'height': height,
      });
      final resp = await _dio.post<Map<String, dynamic>>('/frame-check', data: form);
      final body = resp.data;
      if (body == null) return const FrameUnavailable('empty');
      return FrameChecked(FramingVerdict.fromJson(body));
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 429) return const FrameBusy();
      if (code == 503) return const FrameUnavailable('detector_unavailable');
      return FrameUnavailable(e.type.name);
    } catch (e) {
      // 返回体字段不对等：当作不可用，不让预览页崩
      return FrameUnavailable('bad_response');
    }
  }
}
