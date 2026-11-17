/// 徽章（ST-2，M4 简报第 7 节）：判定、颁发、祝贺弹窗去重。
library;

import 'package:drift/drift.dart';

import '../../domain/badges.dart';
import '../../domain/models.dart';
import '../../domain/streak.dart';
import '../db/database.dart';
import '../sync/sync_service.dart' show currentUserId;

class BadgeRepository {
  BadgeRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _clock;

  Future<BadgeInput> input(String dogId) async {
    final sessions = await (db.select(db.trainingSessions)..where((t) => t.dogId.equals(dogId))).get();
    final starts = [for (final s in sessions) DateTime.parse(s.startedAt)];
    final streak = computeStreak(startedAt: starts, today: _clock());
    final statuses = await (db.select(db.dogSkillStatuses)
          ..where((t) => t.dogId.equals(dogId) & t.status.equals('mastered')))
        .get();
    final diag = await (db.select(db.diagnosisResults)..where((t) => t.dogId.equals(dogId))).get();
    final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingleOrNull();
    final members = dog == null
        ? <HouseholdMember>[]
        : await (db.select(db.householdMembers)..where((t) => t.householdId.equals(dog.householdId))).get();
    return BadgeInput(
      sessions: [for (final s in sessions) BadgeSession(userId: s.userId, startedAt: DateTime.parse(s.startedAt))],
      longestStreakDays: streak.longestDays,
      masteredCount: statuses.length,
      diagnosisCount: diag.length,
      memberIds: [for (final m in members) m.userId],
    );
  }

  Future<List<DogBadge>> earned(String dogId) =>
      (db.select(db.dogBadges)..where((t) => t.dogId.equals(dogId))).get();

  Stream<List<DogBadge>> watchEarned(String dogId) =>
      (db.select(db.dogBadges)..where((t) => t.dogId.equals(dogId))).watch();

  /// 判定并颁发新徽章（已存在的不动，主键 dog_id + badge_id）。返回新颁发的徽章 id。
  Future<List<String>> evaluate(String dogId, List<Badge> defs) async {
    final already = {for (final b in await earned(dogId)) b.badgeId};
    final awards = newBadgeAwards(defs: defs, input: await input(dogId), alreadyEarned: already);
    if (awards.isEmpty) return const [];
    final me = await currentUserId(db);
    final now = _clock().toUtc().toIso8601String();
    final out = <String>[];
    for (final a in awards) {
      final n = await db.into(db.dogBadges).insert(
            DogBadgesCompanion.insert(
              dogId: dogId,
              badgeId: a.badgeId,
              earnedAt: now,
              earnedByUserId: a.earnedByUserId ?? me,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (n > 0) out.add(a.badgeId);
    }
    return out;
  }

  /// 本机还没弹过祝贺的已获得徽章（按获得时间）。
  Stream<List<DogBadge>> watchUnseen(String dogId) {
    final q = db.select(db.dogBadges).join([
      leftOuterJoin(
          db.badgePopupsSeen,
          db.badgePopupsSeen.dogId.equalsExp(db.dogBadges.dogId) &
              db.badgePopupsSeen.badgeId.equalsExp(db.dogBadges.badgeId)),
    ])
      ..where(db.dogBadges.dogId.equals(dogId) & db.badgePopupsSeen.badgeId.isNull())
      ..orderBy([OrderingTerm.asc(db.dogBadges.earnedAt)]);
    return q.watch().map((rows) => [for (final r in rows) r.readTable(db.dogBadges)]);
  }

  Future<void> markSeen(String dogId, String badgeId) => db.into(db.badgePopupsSeen).insert(
        BadgePopupsSeenCompanion.insert(
            dogId: dogId, badgeId: badgeId, seenAt: _clock().toUtc().toIso8601String()),
        mode: InsertMode.insertOrIgnore,
      );
}
