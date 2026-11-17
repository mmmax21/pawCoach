/// 家庭共享同步（M4 简报第 5 节）。
///
/// - [SyncApi]：服务端接口（[DioSyncApi] 走 HTTP；测试用内存替身）。
/// - [HttpSyncService]：匿名账号、建家上传、加入家庭、上行发件箱、按 server_seq 增量下行。
///
/// token 与邀请码不写日志：异常信息只带 HTTP 状态与错误码。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../db/sync_tables.dart';
import '../repositories/repositories.dart';
import 'sync_codec.dart';

/// 同步地址：构建参数 SYNC_BASE_URL，默认与 AI 代理同一服务（Android 模拟器访问宿主机）。
const syncBaseUrl = String.fromEnvironment('SYNC_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

class SyncException implements Exception {
  const SyncException(this.code, {this.status});
  final String code;
  final int? status;

  bool get isNetwork => status == null;

  @override
  String toString() => 'SyncException($code${status == null ? '' : ', $status'})';
}

class HouseholdInfo {
  const HouseholdInfo({
    required this.householdId,
    required this.name,
    required this.creatorUserId,
    required this.inviteCode,
    required this.members,
  });
  final String householdId;
  final String name;
  final String creatorUserId;
  final String? inviteCode;
  final List<({String userId, String role, String nickname})> members;
}

class PushResult {
  const PushResult({required this.accepted, required this.maxSeq});
  final List<bool> accepted;
  final int maxSeq;
}

class PullResult {
  const PullResult({required this.records, required this.maxSeq, required this.hasMore});
  final List<SyncRecord> records;
  final int maxSeq;
  final bool hasMore;
}

abstract class SyncApi {
  Future<({String userId, String token})> register(String nickname);
  Future<void> setNickname(String token, String nickname);
  Future<({String inviteCode, int maxSeq})> createHousehold(
      String token, String householdId, String name, List<SyncRecord> records);
  Future<String> join(String token, String inviteCode, String nickname);
  Future<HouseholdInfo> household(String token, String householdId);
  Future<String> regenerateInvite(String token, String householdId);
  Future<PushResult> push(String token, String householdId, List<SyncRecord> records);
  Future<PullResult> pull(String token, String householdId, int sinceSeq);

  /// FM-4：创建者移除成员。
  Future<void> removeMember(String token, String householdId, String userId);
}

class DioSyncApi implements SyncApi {
  DioSyncApi({String baseUrl = syncBaseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
            ));
  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  Future<Map<String, Object?>> _call(Future<Response<dynamic>> Function() f) async {
    try {
      final r = await f();
      return (r.data as Map).cast<String, Object?>();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      throw SyncException(detail is String ? detail : (status == null ? 'network' : 'http'), status: status);
    }
  }

  @override
  Future<({String userId, String token})> register(String nickname) async {
    final j = await _call(() => _dio.post('/v1/users', data: {'nickname': nickname}));
    return (userId: j['user_id'] as String, token: j['token'] as String);
  }

  @override
  Future<void> setNickname(String token, String nickname) async {
    await _call(() => _dio.patch('/v1/users/me', data: {'nickname': nickname}, options: _auth(token)));
  }

  @override
  Future<({String inviteCode, int maxSeq})> createHousehold(
      String token, String householdId, String name, List<SyncRecord> records) async {
    final j = await _call(() => _dio.post('/v1/households',
        data: {
          'household_id': householdId,
          'name': name,
          'records': [for (final r in records) r.toJson()],
        },
        options: _auth(token)));
    return (inviteCode: j['invite_code'] as String, maxSeq: (j['max_seq'] as num).toInt());
  }

  @override
  Future<String> join(String token, String inviteCode, String nickname) async {
    final j = await _call(() => _dio.post('/v1/households/join',
        data: {'invite_code': inviteCode, 'nickname': nickname}, options: _auth(token)));
    return j['household_id'] as String;
  }

  @override
  Future<HouseholdInfo> household(String token, String householdId) async {
    final j = await _call(() => _dio.get('/v1/households/$householdId', options: _auth(token)));
    return HouseholdInfo(
      householdId: j['household_id'] as String,
      name: j['name'] as String,
      creatorUserId: j['creator_user_id'] as String,
      inviteCode: j['invite_code'] as String?,
      members: [
        for (final m in (j['members'] as List).cast<Map>())
          (
            userId: m['user_id'] as String,
            role: m['role'] as String,
            nickname: (m['nickname'] as String?) ?? '',
          ),
      ],
    );
  }

  @override
  Future<String> regenerateInvite(String token, String householdId) async {
    final j = await _call(() => _dio.post('/v1/households/$householdId/invite_code', options: _auth(token)));
    return j['invite_code'] as String;
  }

  @override
  Future<PushResult> push(String token, String householdId, List<SyncRecord> records) async {
    final j = await _call(() => _dio.post('/v1/sync/push',
        data: {'household_id': householdId, 'records': [for (final r in records) r.toJson()]},
        options: _auth(token)));
    return PushResult(
      accepted: [for (final r in (j['results'] as List).cast<Map>()) r['accepted'] == true],
      maxSeq: (j['max_seq'] as num).toInt(),
    );
  }

  @override
  Future<void> removeMember(String token, String householdId, String userId) async {
    await _call(() => _dio.delete('/v1/households/$householdId/members/$userId', options: _auth(token)));
  }

  @override
  Future<PullResult> pull(String token, String householdId, int sinceSeq) async {
    final j = await _call(() => _dio.get('/v1/sync/pull',
        queryParameters: {'household_id': householdId, 'since_seq': sinceSeq}, options: _auth(token)));
    return PullResult(
      records: [for (final r in (j['records'] as List).cast<Map>()) SyncRecord.fromJson(r.cast())],
      maxSeq: (j['max_seq'] as num).toInt(),
      hasMore: j['has_more'] == true,
    );
  }
}

/// 同步接口（M1 简报第 8 节定义，M4 实现）。
abstract class SyncService {
  /// 上行：推送发件箱里的本地变更。返回推送条数。
  Future<int> pushPending();

  /// 下行：按 server_seq 增量拉取并应用。返回有变化的表名。
  Future<Set<String>> pull();
}

/// 未加入任何家庭 / 测试用：什么都不做。
class LocalOnlySyncService implements SyncService {
  const LocalOnlySyncService();

  @override
  Future<int> pushPending() async => 0;

  @override
  Future<Set<String>> pull() async => const {};
}

/// 下行改动了哪些表之后要做的本地重算（Streak、DogSkillStatus、徽章、首页刷新）。
typedef RemoteChangeHandler = Future<void> Function(Set<String> tables);

class HttpSyncService implements SyncService {
  HttpSyncService({required this.db, required this.api, this.onRemoteChange})
      : codec = SyncCodec(db);

  final AppDatabase db;
  final SyncApi api;
  final SyncCodec codec;
  RemoteChangeHandler? onRemoteChange;

  /// FM-4：被创建者移出家庭后置为家庭名称（界面提示一次后清空）。
  final ValueNotifier<String?> removedNotice = ValueNotifier(null);

  /// 被移出后的本地清理之后调用（取消本机通知等）。
  Future<void> Function()? onRemoved;

  static bool _isRemoval(Object e) => e is SyncException && e.status == 403 && e.code == 'not_member';

  Future<void> _lock = Future.value();

  /// 串行执行，避免推拉交错。
  Future<T> _serial<T>(Future<T> Function() body) {
    final c = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        c.complete(await body());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  // ---- 账号 ----------------------------------------------------------------

  Future<LocalAccount?> account() => (db.select(db.localAccounts)..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<SyncState?> state() => (db.select(db.syncStates)..limit(1)).getSingleOrNull();

  /// 已注册则直接返回；否则注册匿名账号，并把建档时的本地用户 'local_user' 换成服务端 user_id。
  Future<LocalAccount> ensureAccount({String? nickname}) async {
    final existing = await account();
    if (existing != null) return existing;
    final local = await (db.select(db.users)
          ..where((t) => t.id.equals(HouseholdRepository.localUserId)))
        .getSingleOrNull();
    final nick = (nickname ?? local?.nickname ?? '').trim();
    final reg = await api.register(nick);
    await db.transaction(() async {
      await db.into(db.localAccounts).insert(LocalAccountsCompanion.insert(
            id: const Value(1),
            userId: reg.userId,
            token: reg.token,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ));
      await rekeyLocalUser(db, reg.userId, nickname: nick.isEmpty ? null : nick);
    });
    return (await account())!;
  }

  // ---- 建家 / 加入 ---------------------------------------------------------

  /// 本地已有家庭但尚未上传（建档后首次联网、M3 老用户升级后首次联网）：
  /// 注册 → POST /v1/households 上传家庭、狗及全部现有数据 → 记下邀请码。
  /// 已上传或本地没有家庭时返回 false。
  Future<bool> ensureHouseholdUploaded() => _serial(() async {
        if (await state() != null) return false;
        final hh = await (db.select(db.households)..limit(1)).getSingleOrNull();
        if (hh == null) return false;
        final acc = await ensureAccount();
        final hhNow = (await (db.select(db.households)..limit(1)).getSingle());
        final queued = await db.select(db.syncOutbox).get();
        final records = await codec.readAll();
        final res = await api.createHousehold(acc.token, hhNow.id, hhNow.name, records);
        await db.untracked(() async {
          await (db.update(db.households)..where((t) => t.id.equals(hhNow.id)))
              .write(HouseholdsCompanion(inviteCode: Value(res.inviteCode)));
          await db.into(db.syncStates).insertOnConflictUpdate(SyncStatesCompanion.insert(
                householdId: hhNow.id,
                lastPullSeq: Value(res.maxSeq),
                lastPushAt: Value(DateTime.now().toUtc().toIso8601String()),
              ));
          for (final q in queued) {
            await (db.delete(db.syncOutbox)
                  ..where((t) => t.tbl.equals(q.tbl) & t.pk.equals(q.pk) & t.version.equals(q.version)))
                .go();
          }
        });
        return true;
      });

  /// 加入家庭（简报 5.2）：只在本机尚未建档时可用。注册 → 加入 → 全量拉取。
  Future<String> joinHousehold({required String inviteCode, required String nickname}) async {
    if (await (db.select(db.dogs)..limit(1)).getSingleOrNull() != null) {
      throw const SyncException('already_has_dog');
    }
    final acc = await ensureAccount(nickname: nickname);
    final hid = await api.join(acc.token, inviteCode.trim().toUpperCase(), nickname.trim());
    await db.into(db.syncStates).insertOnConflictUpdate(
        SyncStatesCompanion.insert(householdId: hid, lastPullSeq: const Value(0)));
    await pull();
    return hid;
  }

  // ---- 上行 ----------------------------------------------------------------

  @override
  Future<int> pushPending() => _guardRemoval(_pushPending);

  /// 推 / 拉收到"不是该家庭成员"（403 not_member）时：本机已被移出家庭，
  /// 清空本地家庭数据、回到"未加入家庭"状态，并提示一次（简报 FM-4，Fable 决策见交接单）。
  Future<T> _guardRemoval<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      if (!_isRemoval(e)) rethrow;
      final name = (await (db.select(db.households)..limit(1)).getSingleOrNull())?.name ?? '';
      await clearHouseholdData(db);
      removedNotice.value = name;
      await onRemoved?.call();
      throw SyncException('removed_from_household', status: 403);
    }
  }

  Future<int> _pushPending() => _serial(() async {
        final st = await state();
        final acc = await account();
        if (st == null || acc == null) return 0;
        var total = 0;
        while (true) {
          final queued = await (db.select(db.syncOutbox)..limit(200)).get();
          if (queued.isEmpty) break;
          final records = <SyncRecord>[];
          for (final q in queued) {
            final row = q.deleted ? null : await codec.read(q.tbl, q.pk);
            records.add(row ??
                SyncRecord(
                  table: q.tbl,
                  pk: q.pk,
                  payload: const {},
                  clientUpdatedAt: q.changedAt.isEmpty ? DateTime.now().toUtc().toIso8601String() : q.changedAt,
                  deleted: true,
                ));
          }
          await api.push(acc.token, st.householdId, records);
          // 推送期间又改过的条目（version 变了）留到下一轮。
          await db.transaction(() async {
            for (final q in queued) {
              await (db.delete(db.syncOutbox)
                    ..where((t) => t.tbl.equals(q.tbl) & t.pk.equals(q.pk) & t.version.equals(q.version)))
                  .go();
            }
          });
          total += queued.length;
          if (queued.length < 200) break;
        }
        await (db.update(db.syncStates)..where((t) => t.householdId.equals(st.householdId)))
            .write(SyncStatesCompanion(lastPushAt: Value(DateTime.now().toUtc().toIso8601String())));
        return total;
      });

  // ---- 下行 ----------------------------------------------------------------

  @override
  Future<Set<String>> pull() => _guardRemoval(_pull);

  Future<Set<String>> _pull() async {
    final changed = await _serial(() async {
      final st = await state();
      final acc = await account();
      if (st == null || acc == null) return <String>{};
      final changed = <String>{};
      var since = st.lastPullSeq;
      while (true) {
        final page = await api.pull(acc.token, st.householdId, since);
        if (page.records.isNotEmpty) {
          await db.untracked(() async {
            for (final r in page.records) {
              final o = await codec.apply(r);
              if (o == ApplyOutcome.inserted || o == ApplyOutcome.updated || o == ApplyOutcome.deleted) {
                changed.add(r.table);
              } else if (o == ApplyOutcome.failed) {
                debugPrint('同步：跳过一条无法应用的记录 ${r.table}');
              }
            }
          });
        }
        since = page.maxSeq > since ? page.maxSeq : since;
        await (db.update(db.syncStates)..where((t) => t.householdId.equals(st.householdId)))
            .write(SyncStatesCompanion(lastPullSeq: Value(since)));
        if (!page.hasMore) break;
      }
      if (changed.isNotEmpty) {
        // customStatement 写入不经过 drift 的表跟踪，手动通知首页等 stream 刷新。
        db.notifyUpdates({
          for (final t in db.allTables)
            if (changed.contains(t.actualTableName)) TableUpdate.onTable(t),
        });
      }
      return changed;
    });
    if (changed.isNotEmpty) await onRemoteChange?.call(changed);
    return changed;
  }

  // ---- 家庭信息 ------------------------------------------------------------

  Future<HouseholdInfo?> householdInfo() async {
    final st = await state();
    final acc = await account();
    if (st == null || acc == null) return null;
    final info = await api.household(acc.token, st.householdId);
    if (info.inviteCode != null) {
      await db.untracked(() => (db.update(db.households)..where((t) => t.id.equals(st.householdId)))
          .write(HouseholdsCompanion(inviteCode: Value(info.inviteCode))));
    }
    return info;
  }

  Future<String> regenerateInvite() async {
    final st = await state();
    final acc = await account();
    if (st == null || acc == null) throw const SyncException('not_synced');
    final code = await api.regenerateInvite(acc.token, st.householdId);
    await db.untracked(() => (db.update(db.households)..where((t) => t.id.equals(st.householdId)))
        .write(HouseholdsCompanion(inviteCode: Value(code))));
    return code;
  }

  /// FM-4：创建者移除成员，随后拉一次让本机成员列表更新。
  Future<void> removeMember(String userId) async {
    final st = await state();
    final acc = await account();
    if (st == null || acc == null) throw const SyncException('not_synced');
    await api.removeMember(acc.token, st.householdId, userId);
    await pull();
  }

  Future<void> setNickname(String nickname) async {
    final acc = await account();
    if (acc == null) return;
    await api.setNickname(acc.token, nickname);
  }
}

/// 建档时的本地用户 'local_user' 换成服务端 user_id：users、household_members、
/// households.creator_user_id、training_sessions.user_id、dog_badges.earned_by_user_id。
Future<void> rekeyLocalUser(AppDatabase db, String userId, {String? nickname}) async {
  const old = HouseholdRepository.localUserId;
  final local = await (db.select(db.users)..where((t) => t.id.equals(old))).getSingleOrNull();
  final now = DateTime.now().toUtc().toIso8601String();
  await db.into(db.users).insertOnConflictUpdate(UsersCompanion.insert(
        id: userId,
        nickname: nickname ?? local?.nickname ?? '我',
        createdAt: local?.createdAt ?? now,
      ));
  if (local == null) return;
  await db.customStatement('UPDATE household_members SET user_id = ? WHERE user_id = ?', [userId, old]);
  await db.customStatement('UPDATE households SET creator_user_id = ? WHERE creator_user_id = ?', [userId, old]);
  await db.customStatement('UPDATE training_sessions SET user_id = ? WHERE user_id = ?', [userId, old]);
  await db.customStatement('UPDATE dog_badges SET earned_by_user_id = ? WHERE earned_by_user_id = ?', [userId, old]);
  await (db.delete(db.users)..where((t) => t.id.equals(old))).go();
  db.notifyUpdates({
    for (final t in <TableInfo>[db.users, db.householdMembers, db.households, db.trainingSessions, db.dogBadges])
      TableUpdate.onTable(t),
  });
}

/// 被移出家庭后清空本机的家庭数据（同步表、派生表、同步状态、提醒设置、建档草稿、已弹徽章），
/// 保留内容库缓存与本机匿名账号（同一账号之后可重新加入或自己建档）。不进发件箱。
Future<void> clearHouseholdData(AppDatabase db) async {
  const keep = {'local_accounts', 'sync_flags'};
  await db.untracked(() async {
    for (final t in db.allTables) {
      final name = t.actualTableName;
      if (name.startsWith('content_') || keep.contains(name)) continue;
      await db.customStatement('DELETE FROM $name');
    }
  });
  db.notifyUpdates({for (final t in db.allTables) TableUpdate.onTable(t)});
}

/// 本机当前用户 id：注册后为服务端 user_id，之前为 'local_user'。
Future<String> currentUserId(AppDatabase db) async {
  final acc = await (db.select(db.localAccounts)..where((t) => t.id.equals(1))).getSingleOrNull();
  return acc?.userId ?? HouseholdRepository.localUserId;
}

/// 是否为同步表（供调度器判断哪些本地写入需要触发推送）。
bool isSyncedTable(String name) => syncTableByName.containsKey(name);
