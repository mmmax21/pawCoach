import 'package:drift/drift.dart';

import 'sync_tables.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  ContentVersions,
  ContentSkills,
  ContentIssues,
  ContentBadges,
  ContentCareItems,
  ContentAiLexicons,
  Users,
  Households,
  HouseholdMembers,
  Dogs,
  DogConcerns,
  DogCues,
  DogSkillStatuses,
  WeeklyPlans,
  PlanGoals,
  DailyMiniTasks,
  OnboardingDrafts,
  TrainingSessions,
  Streaks,
  WeeklyReports,
  AiConversations,
  AiMessages,
  DiagnosisResults,
  ReminderSettings,
  CareReminders,
  DogBadges,
  LocalAccounts,
  SyncStates,
  SyncOutbox,
  SyncFlags,
  BadgePopupsSeen,
  VideoAnalyses,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2 && to >= 2) {
            // M1 → M2
            await m.createTable(trainingSessions);
            await m.createTable(streaks);
            await m.createTable(weeklyReports);
            await m.addColumn(weeklyPlans, weeklyPlans.regenerateNext);
            // M1 的保底任务写的是 script_part = 1；M2 起 0 表示 mini_script。
            await customStatement('UPDATE daily_mini_tasks SET script_part = 0');
          }
          if (from < 3 && to >= 3) {
            // M2 → M3
            await m.addColumn(weeklyPlans, weeklyPlans.pendingDiagnosisSkills);
            await m.createTable(aiConversations);
            await m.createTable(aiMessages);
            await m.createTable(diagnosisResults);
            await m.createTable(reminderSettings);
            await m.createTable(contentAiLexicons);
          }
          if (from < 4 && to >= 4) {
            await migrateToV4(m);
          }
          if (from < 5 && to >= 5) {
            // M4 → M5：视频纠错结果表（本机，不同步）。不动任何现有数据。
            await m.createTable(videoAnalyses);
          }
        },
        beforeOpen: (details) async {
          await ensureSyncInfrastructure();
        },
      );

  /// M3 → M4（简报第 6 节）：同步表加 client_updated_at / deleted 并补值，
  /// dogs 加 initial_mastered，新建养护、徽章、本地账号、同步状态各表。保留全部现有数据。
  Future<void> migrateToV4(Migrator m) async {
    final synced = <TableInfo>[
      users, households, householdMembers, dogs, dogConcerns, dogCues, weeklyPlans,
      planGoals, dailyMiniTasks, trainingSessions, weeklyReports, aiConversations,
      aiMessages, diagnosisResults,
    ];
    for (final t in synced) {
      final cols = {for (final c in t.$columns) c.name: c};
      await m.addColumn(t, cols['client_updated_at']!);
      await m.addColumn(t, cols['deleted']!);
      final spec = syncTableByName[t.actualTableName]!;
      final from = spec.timeColumn == null
          ? sqlNowIso
          : "COALESCE(strftime('%Y-%m-%dT%H:%M:%fZ', ${spec.timeColumn}), $sqlNowIso)";
      await customStatement('UPDATE ${t.actualTableName} SET client_updated_at = $from');
    }
    await m.addColumn(dogs, dogs.initialMastered);
    await m.addColumn(diagnosisResults, diagnosisResults.userId);
    // 建档勾选的"已会"技能：现有已掌握状态里去掉周报判定掌握的。
    await customStatement('''
      UPDATE dogs SET initial_mastered = COALESCE((
        SELECT json_group_array(s.skill_id) FROM dog_skill_statuses s
        WHERE s.dog_id = dogs.id AND s.status = 'mastered'
          AND NOT EXISTS (
            SELECT 1 FROM weekly_reports r, json_each(r.summary_json, '\$.goals') g
            WHERE r.dog_id = dogs.id
              AND json_extract(g.value, '\$.skill_id') = s.skill_id
              AND json_extract(g.value, '\$.outcome') = 'mastered')
      ), '[]')''');
    for (final t in <TableInfo>[careReminders, dogBadges, localAccounts, syncStates, syncOutbox, syncFlags, badgePopupsSeen]) {
      await m.createTable(t);
    }
  }

  /// 同步触发器与开关行。每次打开都执行（IF NOT EXISTS），新装与升级共用。
  Future<void> ensureSyncInfrastructure() async {
    await customStatement('INSERT OR IGNORE INTO sync_flags (id, applying) VALUES (1, 0)');
    await customStatement('UPDATE sync_flags SET applying = 0 WHERE id = 1');
    for (final t in syncTables) {
      for (final sql in syncTriggerStatements(t)) {
        await customStatement(sql);
      }
    }
  }

  /// 在 [body] 执行期间关闭变更记录（应用下行数据、本地重算派生字段）。
  Future<T> untracked<T>(Future<T> Function() body) => transaction(() async {
        await customStatement('UPDATE sync_flags SET applying = 1 WHERE id = 1');
        try {
          return await body();
        } finally {
          await customStatement('UPDATE sync_flags SET applying = 0 WHERE id = 1');
        }
      });
}
