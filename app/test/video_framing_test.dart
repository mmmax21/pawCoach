// 取景自检的纯逻辑：帧转换（转向、缩放、色彩）、平滑规则、模型解析、接口客户端的降级。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/video/frame_check.dart';
import 'package:puppy_trainer/data/video/frame_convert.dart';

RawFrame bgra(int w, int h, List<List<int>> rgbPerPixel) {
  final b = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final p = rgbPerPixel[i];
    b[i * 4] = p[2];
    b[i * 4 + 1] = p[1];
    b[i * 4 + 2] = p[0];
    b[i * 4 + 3] = 255;
  }
  return RawFrame(
      format: RawFormat.bgra8888, width: w, height: h, planes: [RawPlane(b, bytesPerRow: w * 4)]);
}

List<int> px(RgbFrame f, int x, int y) {
  final i = (y * f.width + x) * 3;
  return [f.bytes[i], f.bytes[i + 1], f.bytes[i + 2]];
}

void main() {
  group('convertFrame 转向', () {
    // 2 宽 × 3 高：
    //   R G
    //   B W
    //   K Y        K=黑 Y=黄
    const r = [255, 0, 0], g = [0, 255, 0], b = [0, 0, 255], w = [255, 255, 255];
    const k = [0, 0, 0], y = [255, 255, 0];
    final src = bgra(2, 3, [r, g, b, w, k, y]);

    test('0 度原样', () {
      final o = convertFrame(src, rotationDegrees: 0);
      expect((o.width, o.height), (2, 3));
      expect(px(o, 0, 0), r);
      expect(px(o, 1, 2), y);
    });

    test('顺时针 90 度：左上角的红色应出现在右上角，宽高互换', () {
      final o = convertFrame(src, rotationDegrees: 90);
      expect((o.width, o.height), (3, 2));
      expect(px(o, 2, 0), r); // 原左上 → 右上
      expect(px(o, 2, 1), g); // 原右上 → 右下
      expect(px(o, 0, 0), k); // 原左下 → 左上
      expect(px(o, 0, 1), y); // 原右下 → 左下
    });

    test('180 度', () {
      final o = convertFrame(src, rotationDegrees: 180);
      expect((o.width, o.height), (2, 3));
      expect(px(o, 1, 2), r);
      expect(px(o, 0, 0), y);
    });

    test('270 度：左上角的红色应出现在左下角', () {
      final o = convertFrame(src, rotationDegrees: 270);
      expect((o.width, o.height), (3, 2));
      expect(px(o, 0, 1), r);
      expect(px(o, 0, 0), g);
      expect(px(o, 2, 0), y);
    });

    test('转 90 度四次回到原图', () {
      var cur = convertFrame(src, rotationDegrees: 0);
      for (var i = 0; i < 4; i++) {
        cur = convertFrame(
            RawFrame(
                format: RawFormat.bgra8888,
                width: cur.width,
                height: cur.height,
                planes: [
                  RawPlane(
                      Uint8List.fromList([
                        for (var j = 0; j < cur.width * cur.height; j++) ...[
                          cur.bytes[j * 3 + 2],
                          cur.bytes[j * 3 + 1],
                          cur.bytes[j * 3],
                          255
                        ]
                      ]),
                      bytesPerRow: cur.width * 4)
                ]),
            rotationDegrees: 90);
      }
      expect((cur.width, cur.height), (2, 3));
      expect([for (var i = 0; i < 6; i++) px(cur, i % 2, i ~/ 2)], [r, g, b, w, k, y]);
    });

    test('负角度与大于 360 的角度按取模处理', () {
      expect(convertFrame(src, rotationDegrees: -90).bytes, convertFrame(src, rotationDegrees: 270).bytes);
      expect(convertFrame(src, rotationDegrees: 450).bytes, convertFrame(src, rotationDegrees: 90).bytes);
    });
  });

  group('convertFrame 缩放', () {
    test('长边超过目标时缩小，保持宽高比', () {
      final big = RawFrame(
          format: RawFormat.bgra8888,
          width: 1280,
          height: 720,
          planes: [RawPlane(Uint8List(1280 * 720 * 4), bytesPerRow: 1280 * 4)]);
      final o = convertFrame(big, rotationDegrees: 0, targetLongSide: 320);
      expect((o.width, o.height), (320, 180));
      expect(o.bytes.length, 320 * 180 * 3);
    });

    test('缩小后再转 90 度：竖屏手机的 1280x720 传感器帧变成 180x320', () {
      final big = RawFrame(
          format: RawFormat.bgra8888,
          width: 1280,
          height: 720,
          planes: [RawPlane(Uint8List(1280 * 720 * 4), bytesPerRow: 1280 * 4)]);
      final o = convertFrame(big, rotationDegrees: 90);
      expect((o.width, o.height), (180, 320));
    });

    test('已经够小就不放大', () {
      final s = bgra(4, 4, List.filled(16, [1, 2, 3]));
      final o = convertFrame(s, rotationDegrees: 0, targetLongSide: 320);
      expect((o.width, o.height), (4, 4));
    });

    test('行有对齐填充（bytesPerRow > width*4）时不错位', () {
      // 2x2，每行 12 字节（比 8 多 4 字节填充），填充里放干扰值
      final bytes = Uint8List(24);
      void set(int x, int y, List<int> rgb) {
        final i = y * 12 + x * 4;
        bytes[i] = rgb[2];
        bytes[i + 1] = rgb[1];
        bytes[i + 2] = rgb[0];
        bytes[i + 3] = 255;
      }

      set(0, 0, [10, 20, 30]);
      set(1, 0, [40, 50, 60]);
      set(0, 1, [70, 80, 90]);
      set(1, 1, [100, 110, 120]);
      for (final i in [8, 9, 10, 11, 20, 21, 22, 23]) {
        bytes[i] = 99;
      }
      final f = RawFrame(
          format: RawFormat.bgra8888, width: 2, height: 2, planes: [RawPlane(bytes, bytesPerRow: 12)]);
      final o = convertFrame(f, rotationDegrees: 0);
      expect(px(o, 1, 0), [40, 50, 60]);
      expect(px(o, 0, 1), [70, 80, 90]);
    });
  });

  group('convertFrame YUV', () {
    // BT.601：纯红 Y=81 U=90 V=240；纯绿 Y=145 U=54 V=34；纯蓝 Y=41 U=240 V=110
    RawFrame yuv420(int w, int h, int y, int u, int v, {bool nv21 = false}) {
      final yBytes = Uint8List(w * h)..fillRange(0, w * h, y);
      if (nv21) {
        final c = Uint8List(w * h ~/ 2);
        for (var i = 0; i < c.length; i += 2) {
          c[i] = v; // NV21 是 V 在前
          c[i + 1] = u;
        }
        return RawFrame(
            format: RawFormat.nv21,
            width: w,
            height: h,
            planes: [RawPlane(Uint8List.fromList([...yBytes, ...c]), bytesPerRow: w)]);
      }
      final cw = w ~/ 2, ch = h ~/ 2;
      return RawFrame(format: RawFormat.yuv420, width: w, height: h, planes: [
        RawPlane(yBytes, bytesPerRow: w),
        RawPlane(Uint8List(cw * ch)..fillRange(0, cw * ch, u), bytesPerRow: cw),
        RawPlane(Uint8List(cw * ch)..fillRange(0, cw * ch, v), bytesPerRow: cw),
      ]);
    }

    void near(List<int> got, List<int> want, {int tol = 4}) {
      for (var i = 0; i < 3; i++) {
        expect((got[i] - want[i]).abs() <= tol, isTrue, reason: '通道 $i：得到 $got，期望约 $want');
      }
    }

    test('三平面 YUV420：红 / 绿 / 蓝', () {
      near(px(convertFrame(yuv420(4, 4, 81, 90, 240), rotationDegrees: 0), 1, 1), [255, 0, 0]);
      near(px(convertFrame(yuv420(4, 4, 145, 54, 34), rotationDegrees: 0), 1, 1), [0, 255, 0]);
      near(px(convertFrame(yuv420(4, 4, 41, 240, 110), rotationDegrees: 0), 1, 1), [0, 0, 255]);
    });

    test('NV21 的 V U 顺序没有搞反：红还是红', () {
      near(px(convertFrame(yuv420(4, 4, 81, 90, 240, nv21: true), rotationDegrees: 0), 2, 2), [255, 0, 0]);
      near(px(convertFrame(yuv420(4, 4, 41, 240, 110, nv21: true), rotationDegrees: 0), 2, 2), [0, 0, 255]);
    });

    test('交错的 UV 半平面（bytesPerPixel=2）', () {
      // Android 的 YUV_420_888 常见布局：U、V 平面各自步长 2，指向同一块交错内存
      const w = 4, h = 4;
      final y = Uint8List(w * h)..fillRange(0, w * h, 81);
      final u = Uint8List(w * h ~/ 2), v = Uint8List(w * h ~/ 2);
      for (var i = 0; i < u.length; i += 2) {
        u[i] = 90;
        v[i] = 240;
      }
      final f = RawFrame(format: RawFormat.yuv420, width: w, height: h, planes: [
        RawPlane(y, bytesPerRow: w),
        RawPlane(u, bytesPerRow: w, bytesPerPixel: 2),
        RawPlane(v, bytesPerRow: w, bytesPerPixel: 2),
      ]);
      near(px(convertFrame(f, rotationDegrees: 0), 3, 3), [255, 0, 0]);
    });

    test('U / V 平面比"行数×行距"短几个字节时不越界（真机常见）', () {
      const w = 4, h = 4;
      final y = Uint8List(w * h)..fillRange(0, w * h, 81);
      // 理论长度 (h/2) * w = 8，实际少 1 个字节
      final u = Uint8List(7)..fillRange(0, 7, 90);
      final v = Uint8List(7)..fillRange(0, 7, 240);
      final f = RawFrame(format: RawFormat.yuv420, width: w, height: h, planes: [
        RawPlane(y, bytesPerRow: w),
        RawPlane(u, bytesPerRow: w, bytesPerPixel: 2),
        RawPlane(v, bytesPerRow: w, bytesPerPixel: 2),
      ]);
      expect(() => convertFrame(f, rotationDegrees: 0), returnsNormally);
    });

    test('黑和白不越界', () {
      near(px(convertFrame(yuv420(4, 4, 16, 128, 128), rotationDegrees: 0), 0, 0), [0, 0, 0]);
      near(px(convertFrame(yuv420(4, 4, 235, 128, 128), rotationDegrees: 0), 0, 0), [255, 255, 255]);
      near(px(convertFrame(yuv420(4, 4, 255, 128, 128), rotationDegrees: 0), 0, 0), [255, 255, 255], tol: 20);
    });
  });

  group('smoothLevels', () {
    const g = FramingLevel.green, y = FramingLevel.yellow, r = FramingLevel.red;
    test('没有历史按红', () => expect(smoothLevels([]), r));
    test('连续三次绿才算绿', () {
      expect(smoothLevels([g, g, g]), g);
      expect(smoothLevels([g, g]), y);
    });
    test('偶尔一帧红不翻成红', () => expect(smoothLevels([g, r, g]), y));
    test('连续两次红才算红', () {
      expect(smoothLevels([g, r, r]), r);
      expect(smoothLevels([r, r, g, g, g]), g);
    });
    test('黄不会被当成绿', () => expect(smoothLevels([g, g, y]), y));
  });

  group('FramingVerdict.fromJson', () {
    test('完整字段', () {
      final v = FramingVerdict.fromJson(jsonDecode(
          '{"level":"yellow","message":"没看到主人","reasons":["no_person"],"dog_box":[0.1,0.2,0.5,0.6],'
          '"person_box":null,"guide":[0.08,0.4,0.92,0.8],"inside":0.9}') as Map<String, dynamic>);
      expect(v.level, FramingLevel.yellow);
      expect(v.reasons, ['no_person']);
      expect(v.dogBox, const NRect(0.1, 0.2, 0.5, 0.6));
      expect(v.personBox, isNull);
      expect(v.guide, const NRect(0.08, 0.4, 0.92, 0.8));
      expect(v.inside, 0.9);
    });

    test('缺字段按红 + 整屏引导框，不崩', () {
      final v = FramingVerdict.fromJson({});
      expect(v.level, FramingLevel.red);
      expect(v.guide, const NRect(0, 0, 1, 1));
      expect(v.reasons, isEmpty);
    });
  });

  group('DioFrameChecker 降级', () {
    DioFrameChecker checker(Future<Response<dynamic>> Function(RequestOptions) h) {
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = _Adapter(h);
      return DioFrameChecker(baseUrl: 'http://x', dio: dio);
    }

    Future<FrameCheckOutcome> run(DioFrameChecker c) =>
        c.check(rgb: Uint8List(12), width: 2, height: 2, view: FramingView.side);

    test('200 → FrameChecked，并带上 format / width / height / view', () async {
      late RequestOptions seen;
      final c = checker((o) async {
        seen = o;
        return Response(
            requestOptions: o,
            statusCode: 200,
            data: {'level': 'green', 'message': 'ok', 'reasons': [], 'guide': [0, 0, 1, 1]});
      });
      final out = await run(c);
      expect(out, isA<FrameChecked>());
      expect((out as FrameChecked).verdict.level, FramingLevel.green);
      expect(seen.path, '/frame-check');
      final fields = {for (final f in (seen.data as FormData).fields) f.key: f.value};
      expect(fields, {'view': 'side', 'format': 'rgb', 'width': '2', 'height': '2'});
    });

    test('429 → FrameBusy（丢帧，不是故障）', () async {
      final c = checker((o) async => throw DioException(
          requestOptions: o, type: DioExceptionType.badResponse, response: Response(requestOptions: o, statusCode: 429)));
      expect(await run(c), isA<FrameBusy>());
    });

    test('503 → 不可用（服务缺检测器）', () async {
      final c = checker((o) async => throw DioException(
          requestOptions: o, type: DioExceptionType.badResponse, response: Response(requestOptions: o, statusCode: 503)));
      final out = await run(c);
      expect(out, isA<FrameUnavailable>());
      expect((out as FrameUnavailable).reason, 'detector_unavailable');
    });

    test('连不上 / 超时 → 不可用，不抛异常', () async {
      for (final t in [DioExceptionType.connectionError, DioExceptionType.receiveTimeout, DioExceptionType.connectionTimeout]) {
        final c = checker((o) async => throw DioException(requestOptions: o, type: t));
        expect(await run(c), isA<FrameUnavailable>(), reason: t.name);
      }
    });

    test('返回体不是对象 → 不可用，不抛异常', () async {
      final c = checker((o) async => Response(requestOptions: o, statusCode: 200, data: 'oops'));
      expect(await run(c), isA<FrameUnavailable>());
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<Response<dynamic>> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final r = await handler(options);
    // 直接把响应塞给 Dio：用一个空 body 加状态码，真正的数据由 transformer 之前的 data 提供不了，
    // 所以这里改为抛出带响应的异常或返回 JSON 文本。
    final text = r.data is String ? r.data as String : jsonEncode(r.data);
    return ResponseBody.fromString(text, r.statusCode ?? 200, headers: {
      Headers.contentTypeHeader: [r.data is String ? 'text/plain' : 'application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}
