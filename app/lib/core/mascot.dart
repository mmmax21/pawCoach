/// 小狗形象与空状态（2026-11-18 情感化）。全部用代码绘制，不依赖图片素材。
library;

import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// 一只圆脸小狗：耷拉耳、圆眼睛、小舌头。
class PuppyMascot extends StatelessWidget {
  const PuppyMascot({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _PuppyPainter()));
}

class _PuppyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    Offset at(double x, double y) => Offset(x * w, y * w);
    final fur = Paint()..color = const Color(0xFFF2B27A);
    final ear = Paint()..color = const Color(0xFFB8682E);
    final light = Paint()..color = const Color(0xFFFFE3C7);
    final dark = Paint()..color = AppColors.textPrimary;

    // 底部光晕
    canvas.drawCircle(at(0.5, 0.55), 0.46 * w, Paint()..color = AppColors.primarySoft);
    // 耳朵
    canvas.save();
    canvas.translate(0.24 * w, 0.36 * w);
    canvas.rotate(0.35);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.2 * w, height: 0.34 * w), ear);
    canvas.restore();
    canvas.save();
    canvas.translate(0.76 * w, 0.36 * w);
    canvas.rotate(-0.35);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.2 * w, height: 0.34 * w), ear);
    canvas.restore();
    // 头
    canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.5), width: 0.6 * w, height: 0.56 * w), fur);
    // 嘴部浅色
    canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.63), width: 0.34 * w, height: 0.24 * w), light);
    // 眼睛
    canvas.drawCircle(at(0.39, 0.47), 0.045 * w, dark);
    canvas.drawCircle(at(0.61, 0.47), 0.045 * w, dark);
    canvas.drawCircle(at(0.40, 0.455), 0.014 * w, Paint()..color = Colors.white);
    canvas.drawCircle(at(0.62, 0.455), 0.014 * w, Paint()..color = Colors.white);
    // 鼻子
    canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.575), width: 0.1 * w, height: 0.07 * w), dark);
    // 嘴 + 舌头
    final mouth = Path()
      ..moveTo(0.43 * w, 0.64 * w)
      ..quadraticBezierTo(0.5 * w, 0.69 * w, 0.57 * w, 0.64 * w);
    canvas.drawPath(
        mouth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.018 * w
          ..strokeCap = StrokeCap.round
          ..color = AppColors.textPrimary);
    canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.695), width: 0.08 * w, height: 0.07 * w),
        Paint()..color = const Color(0xFFE5737A));
    // 腮红
    canvas.drawCircle(at(0.33, 0.57), 0.035 * w, Paint()..color = const Color(0x33E5737A));
    canvas.drawCircle(at(0.67, 0.57), 0.035 * w, Paint()..color = const Color(0x33E5737A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 空状态：小狗 + 一句话（+ 可选的说明）。
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.hint, this.compact = false});
  final String title;
  final String? hint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? AppSpace.lg : AppSpace.xl, horizontal: AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PuppyMascot(size: compact ? 72 : 112),
          const SizedBox(height: AppSpace.md),
          Text(title, textAlign: TextAlign.center, style: t.titleMedium),
          if (hint != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(hint!,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
