/// 相机帧 → 小尺寸、方向正确的 RGB，供取景自检上传。
///
/// 相机插件给的是传感器方向的 YUV（Android）或 BGRA（iOS）。取景框画在竖屏预览上，
/// 所以上传前要按传感器方向转正，并缩到长边 [targetLongSide] 以内：一帧 320×240 的 RGB 只有 230 KB，
/// 局域网里几十毫秒传完，手机端不需要编码 JPEG。
///
/// 全是纯 Dart，不依赖相机插件，能直接单测。
library;

import 'dart:typed_data';

enum RawFormat { yuv420, nv21, bgra8888 }

class RawPlane {
  const RawPlane(this.bytes, {required this.bytesPerRow, this.bytesPerPixel = 1});
  final Uint8List bytes;
  final int bytesPerRow;

  /// U / V 平面的像素步长：分平面时是 1，交错存放（半平面）时是 2。
  final int bytesPerPixel;
}

class RawFrame {
  const RawFrame({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
  });
  final RawFormat format;
  final int width;
  final int height;
  final List<RawPlane> planes;
}

class RgbFrame {
  const RgbFrame(this.bytes, this.width, this.height);
  final Uint8List bytes; // width × height × 3，R G B 顺序
  final int width;
  final int height;
}

int _clamp(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

/// 读一个字节，下标越过缓冲区末尾时取最后一个字节。
/// 真机的 U / V 平面常比"行数 × 行距"少几个字节（最后一行没有填充），按严格下标读会越界。
int _at(Uint8List b, int i) => b[i < b.length ? i : b.length - 1];

/// 把一帧相机原始数据转成 [targetLongSide] 以内、按 [rotationDegrees] 转正的 RGB。
///
/// [rotationDegrees]：传感器图像需要顺时针转多少度才是用户看到的方向（0 / 90 / 180 / 270）。
/// 最近邻缩放：取景检查只要判断狗在哪，不需要好看，省 CPU。
RgbFrame convertFrame(RawFrame f, {required int rotationDegrees, int targetLongSide = 320}) {
  assert(rotationDegrees % 90 == 0);
  final rot = ((rotationDegrees % 360) + 360) % 360;
  // 先在传感器方向上缩小，再转向：转向只搬很少的像素
  final scale = f.width >= f.height
      ? (f.width > targetLongSide ? targetLongSide / f.width : 1.0)
      : (f.height > targetLongSide ? targetLongSide / f.height : 1.0);
  final sw = (f.width * scale).round().clamp(1, f.width);
  final sh = (f.height * scale).round().clamp(1, f.height);

  final small = Uint8List(sw * sh * 3);
  for (var y = 0; y < sh; y++) {
    final sy = (y * f.height ~/ sh).clamp(0, f.height - 1);
    for (var x = 0; x < sw; x++) {
      final sx = (x * f.width ~/ sw).clamp(0, f.width - 1);
      final o = (y * sw + x) * 3;
      switch (f.format) {
        case RawFormat.bgra8888:
          final p = f.planes[0];
          final i = sy * p.bytesPerRow + sx * 4;
          small[o] = p.bytes[i + 2];
          small[o + 1] = p.bytes[i + 1];
          small[o + 2] = p.bytes[i];
        case RawFormat.yuv420:
        case RawFormat.nv21:
          final yp = f.planes[0];
          final yv = _at(yp.bytes, sy * yp.bytesPerRow + sx);
          int u, v;
          if (f.format == RawFormat.nv21) {
            // NV21：一个平面，Y 之后是交错的 V U
            final p = f.planes[0];
            final base = f.height * p.bytesPerRow;
            final ci = base + (sy >> 1) * p.bytesPerRow + (sx >> 1) * 2;
            v = _at(p.bytes, ci);
            u = _at(p.bytes, ci + 1);
          } else {
            final up = f.planes[1], vp = f.planes[2];
            final ui = (sy >> 1) * up.bytesPerRow + (sx >> 1) * up.bytesPerPixel;
            final vi = (sy >> 1) * vp.bytesPerRow + (sx >> 1) * vp.bytesPerPixel;
            u = _at(up.bytes, ui);
            v = _at(vp.bytes, vi);
          }
          final c = yv - 16, d = u - 128, e = v - 128;
          final y1 = 298 * c;
          small[o] = _clamp((y1 + 409 * e + 128) >> 8);
          small[o + 1] = _clamp((y1 - 100 * d - 208 * e + 128) >> 8);
          small[o + 2] = _clamp((y1 + 516 * d + 128) >> 8);
      }
    }
  }
  return _rotate(small, sw, sh, rot);
}

RgbFrame _rotate(Uint8List src, int w, int h, int rot) {
  if (rot == 0) return RgbFrame(src, w, h);
  final nw = (rot == 90 || rot == 270) ? h : w;
  final nh = (rot == 90 || rot == 270) ? w : h;
  final out = Uint8List(nw * nh * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final int nx, ny;
      switch (rot) {
        case 90: // 顺时针 90°：(x, y) → (h-1-y, x)
          nx = h - 1 - y;
          ny = x;
        case 180:
          nx = w - 1 - x;
          ny = h - 1 - y;
        default: // 270：(x, y) → (y, w-1-x)
          nx = y;
          ny = w - 1 - x;
      }
      final si = (y * w + x) * 3;
      final di = (ny * nw + nx) * 3;
      out[di] = src[si];
      out[di + 1] = src[si + 1];
      out[di + 2] = src[si + 2];
    }
  }
  return RgbFrame(out, nw, nh);
}
