/// M4 简报第 10 节第 6 条：带 M3 数据的数据库升级到 schema 4 后数据完整，
/// 现有记录都有 client_updated_at；建档勾选的已会技能回填到 dogs.initial_mastered。
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/db/sync_tables.dart';
import 'package:puppy_trainer/data/repositories/ai_repository.dart';
import 'package:puppy_trainer/data/repositories/report_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'helpers.dart';

void main() {
  test('M3（schema 3）→ M4 覆盖安装：全部数据保留，同步表都补了 client_updated_at', () async {
    final lib = await loadRepoContent();
    final dir = await Directory.systemTemp.createTemp('m4mig');
    final file = File('${dir.path}/app.sqlite');
    final monday = DateTime(2026, 11, 9, 9);

    // 1) 用当前代码写一份 M3 形态的数据
    var db = AppDatabase(NativeDatabase(file));
    await HouseholdRepository(db).ensureLocalUser();
    final o = await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: DateTime(2026, 8, 31),
        breedId: 'mixed',
        breedText: '混种',
        sex: Sex.female,
        homeDate: DateTime(2026, 8, 31),
        concerns: const ['biting_hands'],
        dailyMinutes: 10,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {'marker_intro', 'name_response'},
      ),
      content: lib,
      now: monday,
    );
    final goals = await PlanRepository(db).goals(o.planId);
    for (var i = 0; i < 2; i++) {
      await SessionRepository(db).save(
        draft: SessionDraft(
          dogId: o.dogId,
          userId: 'local_user',
          skillId: goals.first.skillId,
          scriptPart: 1,
          startedAt: monday.add(Duration(days: i, hours: 1)),
          endedAt: monday.add(Duration(days: i, hours: 1, minutes: 3)),
          durationSec: 180,
          clickerCount: 1,
          skippedSteps: const [],
        ),
        score: Score.full,
        now: monday.add(Duration(days: i, hours: 1, minutes: 3)),
      );
    }
    final ai = AiRepository(db, clock: () => monday);
    final conv = await ai.newDiagnosisConversation(o.dogId, 'biting_hands');
    await ai.saveDiagnosisResult(
        conversationId: conv.id, dogId: o.dogId, issueId: 'biting_hands', resultKey: 'k', solutionSkills: const ['sit']);
    await ReportRepository(db).generate(planId: o.planId, content: lib, now: DateTime(2026, 11, 15, 21, 30));

    final before = <String, int>{};
    for (final t in syncTables.where((t) => !{'care_reminders', 'dog_badges'}.contains(t.name))) {
      before[t.name] = (await db.customSelect('SELECT COUNT(*) AS n FROM ${t.name}').getSingle()).read<int>('n');
    }
    final sessionsBefore = await SessionRepository(db).sessionsOf(o.dogId);

    // 2) 退回 schema 3 的表结构：去掉 M4 的列、表与触发器
    for (final t in syncTables) {
      await db.customStatement('DROP TRIGGER IF EXISTS sync_ins_${t.name}');
      await db.customStatement('DROP TRIGGER IF EXISTS sync_upd_${t.name}');
      await db.customStatement('DROP TRIGGER IF EXISTS sync_del_${t.name}');
    }
    for (final t in ['care_reminders', 'dog_badges', 'local_accounts', 'sync_states', 'sync_outbox', 'sync_flags', 'badge_popups_seen']) {
      await db.customStatement('DROP TABLE $t');
    }
    for (final t in syncTables.where((t) => !{'care_reminders', 'dog_badges'}.contains(t.name))) {
      await db.customStatement('ALTER TABLE ${t.name} DROP COLUMN client_updated_at');
      await db.customStatement('ALTER TABLE ${t.name} DROP COLUMN deleted');
    }
    await db.customStatement('ALTER TABLE dogs DROP COLUMN initial_mastered');
    await db.customStatement('ALTER TABLE diagnosis_results DROP COLUMN user_id');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    // 3) M4 代码打开 → onUpgrade(3 → 4)
    db = AppDatabase(NativeDatabase(file));
    for (final e in before.entries) {
      final n = (await db.customSelect('SELECT COUNT(*) AS n FROM ${e.key}').getSingle()).read<int>('n');
      expect(n, e.value, reason: '${e.key} 行数');
    }
    for (final t in syncTables) {
      final empty = await db
          .customSelect("SELECT COUNT(*) AS n FROM ${t.name} WHERE client_updated_at IS NULL OR client_updated_at = ''")
          .getSingle();
      expect(empty.read<int>('n'), 0, reason: '${t.name} 缺 client_updated_at');
      final del = await db.customSelect('SELECT COUNT(*) AS n FROM ${t.name} WHERE deleted != 0').getSingle();
      expect(del.read<int>('n'), 0);
    }
    final sessionsAfter = await SessionRepository(db).sessionsOf(o.dogId);
    expect([for (final s in sessionsAfter) s.id], [for (final s in sessionsBefore) s.id]);
    expect(sessionsAfter.first.clientUpdatedAt, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$')));
    // client_updated_at 取自现有时间列
    final dogRow = (await DogRepository(db).currentDog())!;
    expect(DateTime.parse(dogRow.clientUpdatedAt), DateTime.parse(dogRow.updatedAt));
    // 建档勾选的已会技能回填（周报判定掌握的不算）
    expect(decodeIdList(dogRow.initialMastered).toSet(), {'marker_intro', 'name_response'});
    // 新表可用、触发器生效：迁移后的本地写入进发件箱
    expect(await db.select(db.careReminders).get(), isEmpty);
    await (db.update(db.dogs)..where((t) => t.id.equals(o.dogId))).write(const DogsCompanion(name: Value('豆豆2')));
    expect((await db.select(db.syncOutbox).get()).map((q) => q.tbl), contains('dogs'));
    expect(db.schemaVersion, 4);
    await db.close();
    await dir.delete(recursive: true);
  });
}
