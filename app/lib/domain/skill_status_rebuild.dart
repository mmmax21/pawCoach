/// 从同步来的历史本地重算 DogSkillStatus（M4 简报第 5.3 节：不再由服务端重算）。
/// 纯函数，无 IO，不依赖 Flutter。
library;

import 'models.dart';

class RebuiltSkillStatus {
  const RebuiltSkillStatus({
    required this.status,
    required this.masteredAt,
    required this.fullSuccessCount,
    required this.failCount,
  });
  final SkillStatus status;
  final String? masteredAt;
  final int fullSuccessCount;
  final int failCount;
}

/// 一次记录的最小视图。
class StatusSession {
  const StatusSession({required this.skillId, required this.scriptPart, required this.score});
  final String skillId;
  final int scriptPart;
  final Score? score;
}

/// [initialMastered]：建档勾选的已会技能（Dog.initial_mastered），掌握时间取 [dogCreatedAt]；
/// [reportMastered]：周报 WP-6 判定掌握的技能 → 该周报 created_at（取最早）；
/// [sessions]：全部训练记录。
///
/// 规则与 M1/M2 增量写法一致：mastered 优先；有过记录且前置已满足 → in_progress；
/// 前置已满足 → available；否则 locked。完全做到 / 没做到只统计正式脚本（script_part ≥ 1）。
Map<String, RebuiltSkillStatus> rebuildSkillStatuses({
  required List<Skill> skills,
  required Set<String> initialMastered,
  required String dogCreatedAt,
  required Map<String, String> reportMastered,
  required List<StatusSession> sessions,
}) {
  final masteredAt = <String, String>{
    for (final id in initialMastered) id: dogCreatedAt,
  };
  reportMastered.forEach((id, at) => masteredAt.putIfAbsent(id, () => at));
  final full = <String, int>{};
  final fail = <String, int>{};
  final practiced = <String>{};
  for (final s in sessions) {
    practiced.add(s.skillId);
    if (s.scriptPart == miniScriptPart) continue;
    if (s.score == Score.full) full[s.skillId] = (full[s.skillId] ?? 0) + 1;
    if (s.score == Score.none) fail[s.skillId] = (fail[s.skillId] ?? 0) + 1;
  }
  final mastered = masteredAt.keys.toSet();
  return {
    for (final sk in skills)
      sk.id: RebuiltSkillStatus(
        status: mastered.contains(sk.id)
            ? SkillStatus.mastered
            : !sk.prerequisites.every(mastered.contains)
                ? SkillStatus.locked
                : practiced.contains(sk.id)
                    ? SkillStatus.inProgress
                    : SkillStatus.available,
        masteredAt: masteredAt[sk.id],
        fullSuccessCount: full[sk.id] ?? 0,
        failCount: fail[sk.id] ?? 0,
      ),
  };
}
