/// 徽章判定（ST-2，M4 简报第 7 节）。纯函数，无 IO，不依赖 Flutter。
///
/// 定义全部来自 content/badges.yaml，按 condition_type 判定；
/// 未知的 condition_type 永不颁发。
library;

import 'models.dart';

/// 判定输入里的一次训练记录（只关心谁、什么时候）。
class BadgeSession {
  const BadgeSession({required this.userId, required this.startedAt});
  final String userId;
  final DateTime startedAt;
}

class BadgeInput {
  const BadgeInput({
    required this.sessions,
    required this.longestStreakDays,
    required this.masteredCount,
    required this.diagnosisCount,
    required this.memberIds,
  });

  final List<BadgeSession> sessions;

  /// 历史最长连续打卡天数（按家庭计，RC-3）。连续天数达成过即颁发，之后断了不收回。
  final int longestStreakDays;
  final int masteredCount;
  final int diagnosisCount;

  /// 家庭成员的 user_id。
  final List<String> memberIds;
}

class BadgeAward {
  const BadgeAward({required this.badgeId, this.earnedByUserId});
  final String badgeId;

  /// 由数据决定的获得者（例如让累计次数跨过门槛的那次记录的练习者），
  /// 两台设备各自判定得到同一个人；null 表示无法从数据归属，调用方用当前用户。
  final String? earnedByUserId;

  @override
  String toString() => 'BadgeAward($badgeId, $earnedByUserId)';
}

/// 当前数据已达成、且不在 [alreadyEarned] 中的徽章，按 [defs] 顺序。
/// 已获得的不会重复返回（重复判定不重复颁发）。
List<BadgeAward> newBadgeAwards({
  required List<Badge> defs,
  required BadgeInput input,
  required Set<String> alreadyEarned,
}) {
  final sorted = [...input.sessions]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final out = <BadgeAward>[];
  for (final b in defs) {
    if (alreadyEarned.contains(b.id)) continue;
    final award = _judge(b, input, sorted);
    if (award != null) out.add(award);
  }
  return out;
}

BadgeAward? _judge(Badge b, BadgeInput input, List<BadgeSession> sorted) {
  final v = b.conditionValue;
  switch (b.conditionType) {
    case 'first_checkin':
      final n = v < 1 ? 1 : v;
      return sorted.length >= n ? BadgeAward(badgeId: b.id, earnedByUserId: sorted[n - 1].userId) : null;
    case 'sessions_total':
      return sorted.length >= v && v > 0
          ? BadgeAward(badgeId: b.id, earnedByUserId: sorted[v - 1].userId)
          : null;
    case 'streak_days':
      if (input.longestStreakDays < v) return null;
      return BadgeAward(badgeId: b.id, earnedByUserId: _streakAchiever(sorted, v));
    case 'skills_mastered':
      return input.masteredCount >= v ? BadgeAward(badgeId: b.id) : null;
    case 'first_diagnosis':
      return input.diagnosisCount >= (v < 1 ? 1 : v) ? BadgeAward(badgeId: b.id) : null;
    case 'household_members':
      // 全家总动员：至少 v 位成员各自有过打卡记录（与 description 一致）。
      final members = input.memberIds.toSet();
      final seen = <String>[];
      for (final s in sorted) {
        if (!members.contains(s.userId) || seen.contains(s.userId)) continue;
        seen.add(s.userId);
        if (seen.length >= v) return BadgeAward(badgeId: b.id, earnedByUserId: s.userId);
      }
      return null;
    default:
      return null;
  }
}

DateTime _day(DateTime t) {
  final l = t.toLocal();
  return DateTime.utc(l.year, l.month, l.day);
}

/// 第一次达到 [n] 天连续时，那一天最早一次记录的练习者。
String? _streakAchiever(List<BadgeSession> sorted, int n) {
  DateTime? prev;
  var run = 0;
  for (final s in sorted) {
    final d = _day(s.startedAt);
    if (prev != null && d == prev) continue;
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    prev = d;
    if (run >= n) return s.userId;
  }
  return null;
}

/// 徽章图标按 condition_type 映射（yaml 的 icon 字段本期不用）。返回 Material 图标名，
/// 由 UI 层转成 IconData，保持本文件不依赖 Flutter。
String badgeIconName(String conditionType) => switch (conditionType) {
      'first_checkin' => 'flag',
      'streak_days' => 'local_fire_department',
      'skills_mastered' => 'school',
      'first_diagnosis' => 'medical_information',
      'sessions_total' => 'fitness_center',
      'household_members' => 'family_restroom',
      _ => 'emoji_events',
    };
