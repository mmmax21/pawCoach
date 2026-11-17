/// 同步表清单（M4 简报第 5.3 节）：表名、主键列、本地专用不上行的列。
///
/// 复合主键在同步记录里用 [pkSeparator] 连接，顺序即 [SyncTableSpec.pkColumns]，
/// 与 server/store.py 的 PK_SEP 一致。
library;

const pkSeparator = '|';

class SyncTableSpec {
  const SyncTableSpec(this.name, this.pkColumns,
      {this.localOnlyColumns = const {}, this.timeColumn});

  final String name;
  final List<String> pkColumns;

  /// 不上行、下行时也不覆盖的列（除 client_updated_at / deleted 外）。
  final Set<String> localOnlyColumns;

  /// schema 4 迁移时给现有记录补 client_updated_at 用的时间列；null 用迁移时刻。
  final String? timeColumn;

  /// 触发器里拼主键的 SQL 表达式，[row] 为 NEW 或 OLD。
  String pkSql(String row) =>
      pkColumns.map((c) => '$row.$c').join(" || '$pkSeparator' || ");
}

const syncTables = <SyncTableSpec>[
  SyncTableSpec('households', ['id'], localOnlyColumns: {'invite_code'}, timeColumn: 'created_at'),
  SyncTableSpec('household_members', ['household_id', 'user_id'], timeColumn: 'joined_at'),
  // users 只同步 id 与昵称（created_at 一并带上，非空列）。
  SyncTableSpec('users', ['id'],
      localOnlyColumns: {'phone_or_email', 'avatar_url'}, timeColumn: 'created_at'),
  SyncTableSpec('dogs', ['id'], timeColumn: 'updated_at'),
  SyncTableSpec('dog_concerns', ['dog_id', 'issue_id'], timeColumn: 'created_at'),
  SyncTableSpec('dog_cues', ['dog_id', 'skill_id'], timeColumn: 'updated_at'),
  SyncTableSpec('weekly_plans', ['id'], timeColumn: 'created_at'),
  SyncTableSpec('plan_goals', ['plan_id', 'skill_id']),
  SyncTableSpec('daily_mini_tasks', ['plan_id']),
  SyncTableSpec('training_sessions', ['id'], localOnlyColumns: {'synced_at'}, timeColumn: 'ended_at'),
  SyncTableSpec('weekly_reports', ['id'], timeColumn: 'created_at'),
  SyncTableSpec('ai_conversations', ['id'], timeColumn: 'updated_at'),
  SyncTableSpec('ai_messages', ['id'], timeColumn: 'created_at'),
  SyncTableSpec('diagnosis_results', ['id'], timeColumn: 'created_at'),
  SyncTableSpec('care_reminders', ['id']),
  SyncTableSpec('dog_badges', ['dog_id', 'badge_id'], timeColumn: 'earned_at'),
];

/// 已存在即不覆盖的表（简报 5.3 徽章例外）：服务端拒绝更新；客户端下行时无条件采用服务端版本
/// （服务端版本就是第一个获得者），本地后颁发的同一徽章被替换。
const immutableSyncTables = {'dog_badges'};

final syncTableByName = {for (final t in syncTables) t.name: t};

/// SQLite 里生成"当前 UTC 毫秒 ISO 8601"的表达式。
const sqlNowIso = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";

/// 每张同步表三个触发器：本地插入 / 更新时补 client_updated_at 并入发件箱，
/// 删除时入发件箱为墓碑。sync_flags.applying = 1 时（应用下行、本地重算派生字段）不触发。
List<String> syncTriggerStatements(SyncTableSpec t) {
  const when = 'WHEN (SELECT applying FROM sync_flags WHERE id = 1) = 0';
  String queue(String row, int deleted) => '''
    INSERT OR IGNORE INTO sync_outbox (table_name, pk, deleted, version) VALUES ('${t.name}', ${t.pkSql(row)}, $deleted, 0);
    UPDATE sync_outbox SET version = version + 1, deleted = $deleted, changed_at = $sqlNowIso WHERE table_name = '${t.name}' AND pk = ${t.pkSql(row)};''';
  return [
    '''CREATE TRIGGER IF NOT EXISTS sync_ins_${t.name} AFTER INSERT ON ${t.name} $when BEGIN
    UPDATE ${t.name} SET client_updated_at = $sqlNowIso WHERE rowid = NEW.rowid;${queue('NEW', 0)}
  END;''',
    '''CREATE TRIGGER IF NOT EXISTS sync_upd_${t.name} AFTER UPDATE ON ${t.name} $when BEGIN
    UPDATE ${t.name} SET client_updated_at = $sqlNowIso WHERE rowid = NEW.rowid;${queue('NEW', 0)}
  END;''',
    '''CREATE TRIGGER IF NOT EXISTS sync_del_${t.name} AFTER DELETE ON ${t.name} $when BEGIN${queue('OLD', 1)}
  END;''',
  ];
}
