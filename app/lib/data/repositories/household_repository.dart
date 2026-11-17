/// 家庭成员与昵称（FM-1 / FM-2 / FM-5，M4 简报第 5 节）。
library;

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../sync/sync_service.dart' show currentUserId;

class MemberView {
  const MemberView({required this.userId, required this.nickname, required this.role, required this.isMe});
  final String userId;
  final String nickname;
  final String role;
  final bool isMe;
}

class FamilyRepository {
  FamilyRepository(this.db);
  final AppDatabase db;

  Future<Household?> household() => (db.select(db.households)..limit(1)).getSingleOrNull();
  Stream<Household?> watchHousehold() => (db.select(db.households)..limit(1)).watchSingleOrNull();

  /// user_id → 昵称（记录流显示操作者用）。找不到时显示"家庭成员"。
  Stream<Map<String, String>> watchNicknames() =>
      db.select(db.users).watch().map((rows) => {for (final u in rows) u.id: u.nickname});

  Future<Map<String, String>> nicknames() async =>
      {for (final u in await db.select(db.users).get()) u.id: u.nickname};

  Stream<List<MemberView>> watchMembers() {
    final q = db.select(db.householdMembers).join([
      leftOuterJoin(db.users, db.users.id.equalsExp(db.householdMembers.userId)),
    ])
      ..orderBy([OrderingTerm.asc(db.householdMembers.joinedAt)]);
    return q.watch().asyncMap((rows) async {
      final me = await currentUserId(db);
      return [
        for (final r in rows)
          MemberView(
            userId: r.readTable(db.householdMembers).userId,
            nickname: r.readTableOrNull(db.users)?.nickname ?? '家庭成员',
            role: r.readTable(db.householdMembers).role,
            isMe: r.readTable(db.householdMembers).userId == me,
          ),
      ];
    });
  }

  Future<void> setMyNickname(String nickname) async {
    final me = await currentUserId(db);
    await (db.update(db.users)..where((t) => t.id.equals(me))).write(UsersCompanion(nickname: Value(nickname)));
  }

  Future<String> myNickname() async {
    final me = await currentUserId(db);
    final u = await (db.select(db.users)..where((t) => t.id.equals(me))).getSingleOrNull();
    return u?.nickname ?? '';
  }

  /// 家庭改名（M1 决策第 6 条：默认"<狗名>的家"）。
  Future<void> rename(String name) async {
    final h = await household();
    if (h == null) return;
    await (db.update(db.households)..where((t) => t.id.equals(h.id))).write(HouseholdsCompanion(name: Value(name)));
  }
}

/// 记录流里显示的操作者昵称。
String displayNickname(Map<String, String> nicknames, String userId, {String? meId}) {
  final n = nicknames[userId];
  if (n == null || n.isEmpty) return '家庭成员';
  return userId == meId ? '$n（我）' : n;
}
