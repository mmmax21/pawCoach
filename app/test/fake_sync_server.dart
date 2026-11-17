/// 测试用：与 server/store.py 语义一致的内存同步服务端替身。
library;

import 'package:puppy_trainer/data/sync/sync_codec.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';

class _Row {
  _Row(this.r, this.seq);
  SyncRecord r;
  int seq;
}

class FakeSyncServer implements SyncApi {
  final users = <String, String>{}; // token -> userId
  final nick = <String, String>{};
  final memberOf = <String, String>{}; // userId -> hid
  final creator = <String, String>{};
  final invite = <String, String>{}; // code -> hid
  final names = <String, String>{};
  final rows = <String, Map<String, _Row>>{}; // hid -> key -> row
  int _seq = 0;
  int _u = 0;
  int _c = 0;
  bool offline = false;
  int pushCalls = 0;

  static const immutable = {'dog_badges'};

  void _net() {
    if (offline) throw const SyncException('network');
  }

  String _user(String token) {
    final u = users[token];
    if (u == null) throw const SyncException('unauthorized', status: 401);
    return u;
  }

  void _member(String hid, String uid) {
    if (memberOf[uid] != hid) throw const SyncException('not_member', status: 403);
  }

  String _newCode(String hid) {
    invite.removeWhere((_, v) => v == hid);
    final code = 'C${(++_c).toString().padLeft(5, 'A')}';
    invite[code] = hid;
    return code;
  }

  bool apply(String hid, SyncRecord r) {
    final m = rows.putIfAbsent(hid, () => {});
    final key = '${r.table}/${r.pk}';
    final ts = normalizeSyncTs(r.clientUpdatedAt);
    final cur = m[key];
    if (cur != null) {
      if (immutable.contains(r.table)) return false;
      if (ts.compareTo(cur.r.clientUpdatedAt) <= 0) return false;
    }
    final rec = SyncRecord(
        table: r.table, pk: r.pk, payload: Map.of(r.payload), clientUpdatedAt: ts, deleted: r.deleted);
    m[key] = _Row(rec, ++_seq);
    return true;
  }

  int maxSeq(String hid) =>
      (rows[hid]?.values ?? const <_Row>[]).fold(0, (a, r) => r.seq > a ? r.seq : a);

  @override
  Future<({String userId, String token})> register(String nickname) async {
    _net();
    final uid = 'u_${++_u}';
    final token = 'tok_$_u';
    users[token] = uid;
    nick[uid] = nickname;
    return (userId: uid, token: token);
  }

  @override
  Future<void> setNickname(String token, String nickname) async {
    _net();
    nick[_user(token)] = nickname;
  }

  @override
  Future<({String inviteCode, int maxSeq})> createHousehold(
      String token, String householdId, String name, List<SyncRecord> records) async {
    _net();
    final uid = _user(token);
    if (memberOf[uid] != null && memberOf[uid] != householdId) {
      throw const SyncException('already_in_household', status: 409);
    }
    memberOf[uid] = householdId;
    creator.putIfAbsent(householdId, () => uid);
    names[householdId] = name;
    final code = invite.entries.where((e) => e.value == householdId).map((e) => e.key).firstOrNull ??
        _newCode(householdId);
    for (final r in records) {
      apply(householdId, r);
    }
    return (inviteCode: code, maxSeq: maxSeq(householdId));
  }

  @override
  Future<String> join(String token, String inviteCode, String nickname) async {
    _net();
    final uid = _user(token);
    final hid = invite[inviteCode.toUpperCase()];
    if (hid == null) throw const SyncException('invalid_invite', status: 404);
    memberOf[uid] = hid;
    if (nickname.isNotEmpty) nick[uid] = nickname;
    final ts = DateTime.now().toUtc().toIso8601String();
    apply(hid, SyncRecord(table: 'household_members', pk: '$hid|$uid', payload: {
      'household_id': hid, 'user_id': uid, 'role': 'member', 'joined_at': ts,
    }, clientUpdatedAt: ts));
    apply(hid, SyncRecord(table: 'users', pk: uid, payload: {
      'id': uid, 'nickname': nick[uid], 'created_at': ts,
    }, clientUpdatedAt: ts));
    return hid;
  }

  @override
  Future<HouseholdInfo> household(String token, String householdId) async {
    _net();
    _member(householdId, _user(token));
    return HouseholdInfo(
      householdId: householdId,
      name: names[householdId] ?? '',
      creatorUserId: creator[householdId]!,
      inviteCode: invite.entries.where((e) => e.value == householdId).map((e) => e.key).firstOrNull,
      members: [
        for (final e in memberOf.entries)
          if (e.value == householdId)
            (userId: e.key, role: creator[householdId] == e.key ? 'creator' : 'member', nickname: nick[e.key] ?? ''),
      ],
    );
  }

  @override
  Future<String> regenerateInvite(String token, String householdId) async {
    _net();
    final uid = _user(token);
    _member(householdId, uid);
    if (creator[householdId] != uid) throw const SyncException('not_creator', status: 403);
    return _newCode(householdId);
  }

  @override
  Future<PushResult> push(String token, String householdId, List<SyncRecord> records) async {
    _net();
    pushCalls++;
    _member(householdId, _user(token));
    final acc = [for (final r in records) apply(householdId, r)];
    return PushResult(accepted: acc, maxSeq: maxSeq(householdId));
  }

  @override
  Future<PullResult> pull(String token, String householdId, int sinceSeq) async {
    _net();
    _member(householdId, _user(token));
    final list = [
      for (final r in (rows[householdId]?.values ?? const <_Row>[]))
        if (r.seq > sinceSeq) r,
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    return PullResult(
      records: [
        for (final r in list)
          SyncRecord(
            table: r.r.table,
            pk: r.r.pk,
            payload: Map.of(r.r.payload),
            clientUpdatedAt: r.r.clientUpdatedAt,
            deleted: r.r.deleted,
            serverSeq: r.seq,
          ),
      ],
      maxSeq: maxSeq(householdId) > sinceSeq ? maxSeq(householdId) : sinceSeq,
      hasMore: false,
    );
  }

  @override
  Future<void> removeMember(String token, String householdId, String userId) async {
    _net();
    final by = _user(token);
    _member(householdId, by);
    if (creator[householdId] != by) throw const SyncException('not_creator', status: 403);
    if (userId == by) throw const SyncException('cannot_remove_self', status: 400);
    if (memberOf[userId] != householdId) throw const SyncException('member_not_found', status: 404);
    memberOf.remove(userId);
    final ts = DateTime.now().toUtc().toIso8601String();
    apply(householdId, SyncRecord(table: 'household_members', pk: '$householdId|$userId', payload: {
      'household_id': householdId, 'user_id': userId, 'role': 'member', 'joined_at': ts,
    }, clientUpdatedAt: ts, deleted: true));
  }

  List<SyncRecord> recordsOf(String hid, String table) => [
        for (final r in (rows[hid]?.values ?? const <_Row>[]))
          if (r.r.table == table) r.r,
      ];
}
