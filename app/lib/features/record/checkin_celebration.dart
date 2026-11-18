/// 打卡成功庆祝（2026-11-18 情感化）：彩纸 + 连续天数，约 2.6 秒后自动关闭，也可点"完成"。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';

class CelebrationStrings {
  const CelebrationStrings._();
  static const done = '完成';
  static String streak(int days) => '已连续打卡 $days 天';
  static String headline(Score s) => switch (s) {
        Score.full => '太棒了！',
        Score.partial => '有进步！',
        Score.none => '坚持就有收获',
      };
  static const checkedIn = '今天已打卡';
}

/// 显示庆祝层，关闭（自动或点按）后返回。
Future<void> showCheckinCelebration(
  BuildContext context, {
  required Score score,
  required int streakDays,
  required String skillName,
  Duration autoClose = const Duration(milliseconds: 2600),
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: CelebrationStrings.done,
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (c, _, __) => _Celebration(
      score: score,
      streakDays: streakDays,
      skillName: skillName,
      autoClose: autoClose,
    ),
    transitionBuilder: (c, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.score,
    required this.streakDays,
    required this.skillName,
    required this.autoClose,
  });
  final Score score;
  final int streakDays;
  final String skillName;
  final Duration autoClose;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();
  late final List<_Piece> _pieces = _Piece.burst(46, math.Random(7));
  bool _closed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoClose, _close);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) =>
                    CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
              ),
            ),
          ),
          Center(
            child: Container(
              key: const Key('checkin_celebration'),
              width: 300,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xFFFFC56B), AppColors.streak]),
                    ),
                    child: const Icon(Icons.local_fire_department,
                        color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text(CelebrationStrings.headline(widget.score),
                      style: t.headlineSmall),
                  const SizedBox(height: 6),
                  Text('${widget.skillName} · ${CelebrationStrings.checkedIn}',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.streakSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(CelebrationStrings.streak(widget.streakDays),
                        key: const Key('checkin_celebration_streak'),
                        style: t.titleSmall
                            ?.copyWith(color: const Color(0xFF8A5A00))),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('checkin_celebration_done'),
                      onPressed: _close,
                      child: const Text(CelebrationStrings.done),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Piece {
  _Piece(this.angle, this.speed, this.spin, this.color, this.size, this.delay);
  final double angle, speed, spin, size, delay;
  final Color color;

  static const _colors = [
    AppColors.primary,
    AppColors.streak,
    AppColors.success,
    Color(0xFFF6B27A),
    Color(0xFF6FA8DC),
    Color(0xFFE57373),
  ];

  static List<_Piece> burst(int n, math.Random r) => [
        for (var i = 0; i < n; i++)
          _Piece(
            -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.9, // 主要向上喷
            0.55 + r.nextDouble() * 0.6,
            (r.nextDouble() - 0.5) * 12,
            _colors[i % _colors.length],
            6 + r.nextDouble() * 6,
            r.nextDouble() * 0.15,
          ),
      ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final scale = size.height * 0.75;
    for (final p in pieces) {
      final k = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final v = p.speed * scale;
      final dx = math.cos(p.angle) * v * k;
      final dy = math.sin(p.angle) * v * k + 0.9 * scale * k * k; // 抛物线下落
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - k * k).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.spin * k);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
