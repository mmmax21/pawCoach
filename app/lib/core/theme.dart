import 'package:material_ui/material_ui.dart';

/// 主题与通用文案工具。
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      colorSchemeSeed: const Color(0xFFE8893A),
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }
}

/// 周龄 → 文案："10 周（约 2 个半月）"
String ageWeeksLabel(int weeks) {
  final months = weeks / 4.345;
  final rounded = (months * 2).round() / 2;
  final monthText = rounded == rounded.truncate()
      ? '${rounded.truncate()} 个月'
      : '${rounded.truncate()} 个半月';
  return '$weeks 周（约 $monthText）';
}

/// typical_age_weeks [8, 24] → "常见于 2-6 月"
String typicalAgeLabel(List<int> weeks) {
  int toMonth(int w) => (w / 4.345).round().clamp(1, 24);
  return '常见于 ${toMonth(weeks[0])}-${toMonth(weeks[1])} 月';
}

String difficultyStars(int difficulty) => '★' * difficulty + '☆' * (5 - difficulty);
