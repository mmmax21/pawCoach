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
