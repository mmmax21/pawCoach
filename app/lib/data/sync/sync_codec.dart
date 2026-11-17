/// 本地行 ↔ 同步记录 JSON（M4 简报第 5.3 节）。
///
/// 按 drift 表元数据通用处理 [syncTables] 里的 16 张表：payload 为该行除
/// client_updated_at / deleted / 本地专用列以外的全部列（snake_case 列名 → SQLite 原值）。
/// 布尔列在 SQLite 里是 0/1 整数，JSON 里也保持整数，往返一致。
library;

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/sync_tables.dart';

class SyncRecord {
  const SyncRecord({
    required this.table,
    required this.pk,
    required this.payload,
    required this.clientUpdatedAt,
    this.deleted = false,
    this.serverSeq,
  });

  final String table;
  final String pk;
  final Map<String, Object?> payload;
  final String clientUpdatedAt;
  final bool deleted;
  final int? serverSeq;

  Map<String, Object?> toJson() => {
        'table': table,
        'pk': pk,
        'payload': payload,
        'client_updated_at': clientUpdatedAt,
        'deleted': deleted,
      };

  factory SyncRecord.fromJson(Map<String, Object?> j) => SyncRecord(
        table: j['table'] as String,
        pk: j['pk'] as String,
        payload: ((j['payload'] as Map?) ?? const {}).cast<String, Object?>(),
        clientUpdatedAt: j['client_updated_at'] as String,
        deleted: j['deleted'] == true,
        serverSeq: (j['server_seq'] as num?)?.toInt(),
      );

  @override
  String toString() => 'SyncRecord($table/$pk @$clientUpdatedAt${deleted ? ' deleted' : ''})';
}

enum ApplyOutcome { inserted, updated, deleted, skippedLocalNewer, skippedNoop, failed }

/// 把时间戳统一成 UTC 毫秒 'Z' 结尾，字符串比较即时间比较（与 server/store.py 一致）。
String normalizeSyncTs(String ts) {
  if (ts.isEmpty) return ts;
  final d = DateTime.parse(ts).toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}T'
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}.${three(d.millisecond)}Z';
}

class SyncCodec {
  SyncCodec(this.db) {
    for (final t in db.allTables) {
      final spec = syncTableByName[t.actualTableName];
      if (spec == null) continue;
      _columns[spec.name] = [for (final c in t.$columns) c.name];
    }
  }

  final AppDatabase db;
  final _columns = <String, List<String>>{};

  static const _meta = {'client_updated_at', 'deleted'};

  List<String> payloadColumns(String table) {
    final spec = syncTableByName[table]!;
    return [
      for (final c in _columns[table]!)
        if (!_meta.contains(c) && !spec.localOnlyColumns.contains(c)) c,
    ];
  }

  List<String> splitPk(String table, String pk) {
    final spec = syncTableByName[table]!;
    final parts = pk.split(pkSeparator);
    if (parts.length != spec.pkColumns.length) {
      throw FormatException('主键段数不符：$table/$pk');
    }
    return parts;
  }

  String pkOf(String table, Map<String, Object?> row) =>
      syncTableByName[table]!.pkColumns.map((c) => '${row[c]}').join(pkSeparator);

  String _where(String table) =>
      syncTableByName[table]!.pkColumns.map((c) => '$c = ?').join(' AND ');

  SyncRecord fromRow(String table, Map<String, Object?> row) {
    return SyncRecord(
      table: table,
      pk: pkOf(table, row),
      payload: {for (final c in payloadColumns(table)) c: row[c]},
      clientUpdatedAt: normalizeSyncTs((row['client_updated_at'] as String?) ?? ''),
      deleted: row['deleted'] == 1 || row['deleted'] == true,
    );
  }

  Future<Map<String, Object?>?> _row(String table, String pk) async {
    final rows = await db
        .customSelect('SELECT * FROM $table WHERE ${_where(table)}',
            variables: [for (final v in splitPk(table, pk)) Variable<String>(v)])
        .get();
    return rows.isEmpty ? null : rows.first.data;
  }

  /// 读一行为同步记录；不存在返回 null。
  Future<SyncRecord?> read(String table, String pk) async {
    final row = await _row(table, pk);
    return row == null ? null : fromRow(table, row);
  }

  /// 全部同步表的全部行（建家时整体上传用）。
  Future<List<SyncRecord>> readAll() async {
    final out = <SyncRecord>[];
    for (final spec in syncTables) {
      final rows = await db.customSelect('SELECT * FROM ${spec.name}').get();
      out.addAll(rows.map((r) => fromRow(spec.name, r.data)));
    }
    return out;
  }

  /// 应用一条下行记录。调用方负责包在 [AppDatabase.untracked] 里。
  ///
  /// 按 client_updated_at 比较：本地较新（或相同）不覆盖；发件箱里有该行待推送的
  /// 本地删除且删除时刻较新，也不覆盖。deleted = true 时删除本地行。
  Future<ApplyOutcome> apply(SyncRecord r) async {
    final spec = syncTableByName[r.table];
    if (spec == null) return ApplyOutcome.failed;
    final remoteTs = normalizeSyncTs(r.clientUpdatedAt);
    final local = await _row(r.table, r.pk);
    if (local != null && immutableSyncTables.contains(r.table)) {
      if (_samePayload(r.table, local, r.payload)) {
        await (db.delete(db.syncOutbox)..where((t) => t.tbl.equals(r.table) & t.pk.equals(r.pk))).go();
        return ApplyOutcome.skippedNoop;
      }
    } else if (local != null) {
      final localTs = normalizeSyncTs((local['client_updated_at'] as String?) ?? '');
      final c = localTs.compareTo(remoteTs);
      if (c > 0) return ApplyOutcome.skippedLocalNewer;
      // 时间戳相同：服务端以先到者为准，下行的就是服务端采纳的版本；内容相同才算无变化。
      if (c == 0 && !r.deleted && _samePayload(r.table, local, r.payload)) return ApplyOutcome.skippedNoop;
    } else {
      final tomb = await (db.select(db.syncOutbox)
            ..where((t) => t.tbl.equals(r.table) & t.pk.equals(r.pk) & t.deleted.equals(true)))
          .getSingleOrNull();
      if (tomb != null && normalizeSyncTs(tomb.changedAt).compareTo(remoteTs) >= 0) {
        return ApplyOutcome.skippedLocalNewer;
      }
    }

    ApplyOutcome outcome;
    try {
      if (r.deleted) {
        if (local == null) {
          outcome = ApplyOutcome.skippedNoop;
        } else {
          await db.customStatement('DELETE FROM ${r.table} WHERE ${_where(r.table)}', splitPk(r.table, r.pk));
          outcome = ApplyOutcome.deleted;
        }
      } else {
        final allowed = payloadColumns(r.table).toSet();
        final cols = [for (final c in r.payload.keys) if (allowed.contains(c)) c];
        for (final (i, c) in spec.pkColumns.indexed) {
          if (!cols.contains(c)) {
            cols.add(c);
            r.payload[c] = splitPk(r.table, r.pk)[i];
          }
        }
        final all = [...cols, 'client_updated_at', 'deleted'];
        final values = [for (final c in cols) _sqlValue(r.payload[c]), remoteTs, 0];
        final updates = [for (final c in all) if (!spec.pkColumns.contains(c)) '$c = excluded.$c'];
        await db.customStatement(
          'INSERT INTO ${r.table} (${all.join(', ')}) VALUES (${List.filled(all.length, '?').join(', ')}) '
          'ON CONFLICT(${spec.pkColumns.join(', ')}) DO UPDATE SET ${updates.join(', ')}',
          values,
        );
        outcome = local == null ? ApplyOutcome.inserted : ApplyOutcome.updated;
      }
    } catch (_) {
      // 例如 weekly_plans (dog_id, week_start) 唯一约束与旧随机主键冲突：跳过这一条，不卡住同步。
      return ApplyOutcome.failed;
    }
    // 远端胜出：本地对这一行的待推送变更作废。
    await (db.delete(db.syncOutbox)..where((t) => t.tbl.equals(r.table) & t.pk.equals(r.pk))).go();
    return outcome;
  }

  bool _samePayload(String table, Map<String, Object?> local, Map<String, Object?> remote) {
    for (final c in payloadColumns(table)) {
      if (remote.containsKey(c) && '${local[c]}' != '${_sqlValue(remote[c])}') return false;
    }
    return true;
  }

  static Object? _sqlValue(Object? v) => switch (v) {
        bool b => b ? 1 : 0,
        double d when d == d.roundToDouble() && d.abs() < 1e15 => d,
        _ => v,
      };
}
