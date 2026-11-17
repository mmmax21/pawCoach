/// 技能树数据层（ST-3 UI 留 M4）。提供每个技能的状态查询。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models.dart';

class SkillTreeNode {
  const SkillTreeNode({required this.skill, required this.status});
  final Skill skill;
  final SkillStatus status;
}

SkillStatus _statusFromDb(String s) => switch (s) {
      'mastered' => SkillStatus.mastered,
      'in_progress' => SkillStatus.inProgress,
      'available' => SkillStatus.available,
      _ => SkillStatus.locked,
    };

/// 当前狗的技能树：按 min_age_weeks、id 排序。M4 起随技能状态表变化自动刷新（同步重算后）。
final skillTreeProvider = StreamProvider<List<SkillTreeNode>>((ref) async* {
  final content = await ref.watch(contentLibraryProvider.future);
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield const [];
    return;
  }
  final db = ref.watch(databaseProvider);
  await for (final rows in (db.select(db.dogSkillStatuses)
        ..where((t) => t.dogId.equals(dog.id)))
      .watch()) {
    final byId = {for (final r in rows) r.skillId: _statusFromDb(r.status)};
    final nodes = [
      for (final s in content.skills)
        SkillTreeNode(skill: s, status: byId[s.id] ?? SkillStatus.locked),
    ]..sort((a, b) {
        final c = a.skill.minAgeWeeks.compareTo(b.skill.minAgeWeeks);
        return c != 0 ? c : a.skill.id.compareTo(b.skill.id);
      });
    yield nodes;
  }
});
