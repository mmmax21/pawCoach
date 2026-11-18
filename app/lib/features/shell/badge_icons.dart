import 'package:material_ui/material_ui.dart';

import '../../domain/badges.dart';

/// condition_type → Material 图标（yaml 的 icon 字段本期不用）。
IconData badgeIcon(String conditionType) => switch (badgeIconName(conditionType)) {
      'flag' => Icons.flag,
      'local_fire_department' => Icons.local_fire_department,
      'school' => Icons.school,
      'medical_information' => Icons.medical_information,
      'fitness_center' => Icons.fitness_center,
      'family_restroom' => Icons.family_restroom,
      _ => Icons.emoji_events,
    };

/// 每类徽章一种配色（成对：浅、深），让徽章墙一眼能分出类别。
(Color, Color) badgeColors(String conditionType) => switch (badgeIconName(conditionType)) {
      'flag' => (const Color(0xFFFFB27A), const Color(0xFFD9641F)),
      'local_fire_department' => (const Color(0xFFFFD36B), const Color(0xFFF08A24)),
      'school' => (const Color(0xFF8FD3A6), const Color(0xFF2F8A56)),
      'medical_information' => (const Color(0xFF9CC8F0), const Color(0xFF3A7BC8)),
      'fitness_center' => (const Color(0xFFF5A3A3), const Color(0xFFC84B4B)),
      'family_restroom' => (const Color(0xFFC9B3F0), const Color(0xFF7A55C2)),
      _ => (const Color(0xFFFFD36B), const Color(0xFFD99A1E)),
    };

/// 奖牌样式的徽章：渐变圆 + 白色图标 + 外圈；未获得为灰色并带小锁。
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.conditionType, required this.earned, this.size = 72});
  final String conditionType;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (light, dark) = earned ? badgeColors(conditionType) : (const Color(0xFFE6DDD5), const Color(0xFFBDAEA2));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, dark]),
              border: Border.all(color: Colors.white, width: size * 0.06),
              boxShadow: earned
                  ? [BoxShadow(color: dark.withValues(alpha: 0.35), blurRadius: size * 0.18, offset: Offset(0, size * 0.06))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(badgeIcon(conditionType), size: size * 0.46, color: Colors.white),
          ),
          if (!earned)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.lock, size: size * 0.18, color: const Color(0xFFBDAEA2)),
              ),
            ),
        ],
      ),
    );
  }
}
