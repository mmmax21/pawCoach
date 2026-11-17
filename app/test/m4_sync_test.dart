/// M4 简报第 10 节第 4 条（客户端）：codec 往返、两个内存库经同一服务端替身互相同步、
/// 同一周计划合并为一条、离线写入后联网补推；以及确定性主键、后写胜、软删除、徽章不覆盖。
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/db/sync_tables.dart';
import 'package:puppy_trainer/data/repositories/badge_repository.dart';
import 'package:puppy_trainer/data/repositories/care_repository.dart';
import 'package:puppy_trainer/data/repositories/profile_repository.dart';
import 'package:puppy_trainer/data/repositories/report_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/data/sync/derived_state.dart';
import 'package:puppy_trainer/data/sync/sync_codec.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'fake_sync_server.dart';
import 'helpers.dart';

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  final now = DateTime.now();
  final birth = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 70));

  Future<({AppDatabase db, String dogId, String planId})> onboard({String nick = '妈妈'}) async {
    final db = memoryDb();
    await HouseholdRepository(db).ensureLocalUser();
    await (db.update(db.users)..where((t) => t.id.equals('local_user')))
        .write(UsersCompanion(nickname: Value(nick)));
    final r = await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const ['jumping_on_people'],
        dailyMinutes: 10,
        trainerCount: 2,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {'marker_intro'},
      ),
      content: lib,
      now: now,
    );
    await CareRepository(db).syncDefaults((await DogRepository(db).currentDog())!, lib.careCalendar);
    return (db: db, dogId: r.dogId, planId: r.planId);
  }

  HttpSyncService service(AppDatabase db, SyncApi api) {
    final s = HttpSyncService(db: db, api: api);
    s.onRemoteChange = (_) => DerivedState(db).recompute(content: lib);
    return s;
  }

  Future<String> saveSession(AppDatabase db, String dogId, String skill, {int part = 1, Score score = Score.full, DateTime? at}) async {
    final t = at ?? DateTime.now();
    final r = await SessionRepository(db).save(
      draft: SessionDraft(
        dogId: dogId,
        userId: await currentUserId(db),
        skillId: skill,
        scriptPart: part,
        startedAt: t.subtract(const Duration(minutes: 3)),
        endedAt: t,
        durationSec: 180,
        clickerCount: 0,
        skippedSteps: const [],
      ),
      score: score,
      now: t,
    );
    return r.sessionId;
  }

  Future<Map<String, Map<String, Object?>>> snapshot(AppDatabase db, {Set<String> skip = const {}}) async {
    final out = <String, Map<String, Object?>>{};
    for (final r in await SyncCodec(db).readAll()) {
      if (skip.contains(r.table)) continue;
      out['${r.table}/${r.pk}'] = {...r.payload, '_deleted': r.deleted};
    }
    return out;
  }

  test('codec 往返一致：16 张同步表全部行读出 → 应用到空库 → 再读出完全相同', () async {
    final a = await onboard();
    await saveSession(a.db, a.dogId, 'name_response');
    await BadgeRepository(a.db).evaluate(a.dogId, lib.badges);
    final records = await SyncCodec(a.db).readAll();
    expect({for (final r in records) r.table}, containsAll(['households', 'dogs', 'dog_cues', 'weekly_plans',
        'plan_goals', 'training_sessions', 'care_reminders', 'dog_badges', 'users', 'household_members']));
    for (final r in records) {
      expect(SyncRecord.fromJson(r.toJson()).toJson(), r.toJson());
    }
    final c = memoryDb();
    await c.untracked(() async {
      for (final r in records) {
        expect(await SyncCodec(c).apply(r), ApplyOutcome.inserted, reason: '$r');
      }
    });
    expect(await snapshot(c), await snapshot(a.db));
    final readBack = {for (final r in await SyncCodec(c).readAll()) '${r.table}/${r.pk}': r.clientUpdatedAt};
    for (final r in records) {
      expect(readBack['${r.table}/${r.pk}'], r.clientUpdatedAt);
    }
    // 本地写入都有 client_updated_at，格式为 UTC 毫秒
    for (final r in records) {
      expect(r.clientUpdatedAt, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$')), reason: '$r');
    }
    // users 只同步 id、昵称（与 created_at）
    expect(records.firstWhere((r) => r.table == 'users').payload.keys.toSet(), {'id', 'nickname', 'created_at'});
    expect(records.firstWhere((r) => r.table == 'households').payload.containsKey('invite_code'), isFalse);
    await a.db.close();
    await c.close();
  });

  test('A 建家上传、B 加入后全量拉取：两库内容一致，B 不走建档，看到同一只狗', () async {
    final server = FakeSyncServer();
    final a = await onboard();
    final sa = service(a.db, server);
    expect(await sa.ensureHouseholdUploaded(), isTrue);
    final hh = (await (a.db.select(a.db.households)).getSingle());
    expect(hh.inviteCode, isNotNull);
    // local_user 已换成服务端 id
    expect(await (a.db.select(a.db.users)..where((t) => t.id.equals('local_user'))).get(), isEmpty);
    expect((await a.db.select(a.db.householdMembers).getSingle()).userId, startsWith('u_'));

    final b = memoryDb();
    final sb = service(b, server);
    await sb.joinHousehold(inviteCode: hh.inviteCode!.toLowerCase(), nickname: '爸爸');
    await sa.pull(); // A 拿到 B 的成员记录
    await sb.pushPending();
    await sa.pull();
    expect((await DogRepository(b).currentDog())!.id, a.dogId);
    // 派生表不同步，比较同步表
    expect(await snapshot(b), await snapshot(a.db));
    expect((await b.select(b.householdMembers).get()).length, 2);
    // B 本地重算了技能状态：建档勾选的 marker_intro 为已掌握
    final st = await (b.select(b.dogSkillStatuses)..where((t) => t.skillId.equals('marker_intro'))).getSingle();
    expect(st.status, 'mastered');
    expect(server.memberOf.length, 2);
  });

  test('已有狗的设备不能加入别的家庭', () async {
    final server = FakeSyncServer();
    final a = await onboard();
    await service(a.db, server).ensureHouseholdUploaded();
    final code = (await a.db.select(a.db.households).getSingle()).inviteCode!;
    final c = await onboard();
    expect(() => service(c.db, server).joinHousehold(inviteCode: code, nickname: 'x'),
        throwsA(isA<SyncException>().having((e) => e.code, 'code', 'already_has_dog')));
  });

  Future<({dynamic a, dynamic b, HttpSyncService sa, HttpSyncService sb, FakeSyncServer server})> family() async {
    final server = FakeSyncServer();
    final a = await onboard();
    final sa = service(a.db, server);
    await sa.ensureHouseholdUploaded();
    final b = memoryDb();
    final sb = service(b, server);
    await sb.joinHousehold(inviteCode: (await a.db.select(a.db.households).getSingle()).inviteCode!, nickname: '爸爸');
    await sb.pushPending();
    await sa.pull();
    return (a: a, b: b, sa: sa, sb: sb, server: server);
  }

  test('双向：A 打卡 → B 拉到记录、目标进度与连续天数重算；B 打卡 → A 拉到，操作者为 B', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    final AppDatabase b = f.b;
    final String dogId = f.a.dogId;
    final goal = (await PlanRepository(a).goals(f.a.planId)).first;
    final sid = await saveSession(a, dogId, goal.skillId);
    await f.sa.pushPending();
    final changed = await f.sb.pull();
    expect(changed, contains('training_sessions'));
    final bs = await SessionRepository(b).sessionsOf(dogId);
    expect(bs.single.id, sid);
    expect((await SessionRepository(b).streakOf(dogId))!.currentDays, 1);
    final bGoal = (await PlanRepository(b).goals(f.a.planId)).firstWhere((g) => g.skillId == goal.skillId);
    expect(bGoal.completedSessions, 1);

    final sid2 = await saveSession(b, dogId, goal.skillId, score: Score.partial);
    await f.sb.pushPending();
    await f.sa.pull();
    final as_ = await SessionRepository(a).sessionsOf(dogId);
    expect(as_.map((s) => s.id), containsAll([sid, sid2]));
    final bUser = await currentUserId(b);
    expect(as_.firstWhere((s) => s.id == sid2).userId, bUser);
    // 两边的本周目标完成次数都是 2（A 的增量 + B 的记录）
    expect((await PlanRepository(a).goals(f.a.planId)).firstWhere((g) => g.skillId == goal.skillId).completedSessions, 2);
    await f.sb.pull();
    expect((await PlanRepository(b).goals(f.a.planId)).firstWhere((g) => g.skillId == goal.skillId).completedSessions, 2);
    // 两边记录完全一致，没有记录丢失
    expect((await SessionRepository(b).sessionsOf(dogId)).length, 2);
  });

  test('徽章：全家总动员需两位成员各自打卡；同一徽章只颁发一次，获得者不被覆盖', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    final AppDatabase b = f.b;
    final String dogId = f.a.dogId;
    await saveSession(a, dogId, 'name_response');
    await BadgeRepository(a).evaluate(dogId, lib.badges);
    await f.sa.pushPending();
    await f.sb.pull();
    expect((await BadgeRepository(b).earned(dogId)).map((x) => x.badgeId), isNot(contains('team_effort')));
    final aUser = await currentUserId(a);
    final first = (await BadgeRepository(b).earned(dogId)).firstWhere((x) => x.badgeId == 'first_step');
    expect(first.earnedByUserId, aUser);

    await saveSession(b, dogId, 'name_response');
    final newOnB = await BadgeRepository(b).evaluate(dogId, lib.badges);
    expect(newOnB, contains('team_effort'));
    expect(newOnB, isNot(contains('first_step')));
    // A 在拉取前也独立判定出 team_effort？A 还没有 B 的记录，不会
    expect(await BadgeRepository(a).evaluate(dogId, lib.badges), isNot(contains('team_effort')));
    await f.sb.pushPending();
    await f.sa.pull();
    final team = (await BadgeRepository(a).earned(dogId)).where((x) => x.badgeId == 'team_effort').toList();
    expect(team.length, 1);
    expect(team.single.earnedByUserId, await currentUserId(b));
    // 再判定不重复颁发
    expect(await BadgeRepository(a).evaluate(dogId, lib.badges), isEmpty);
    final hid = (await a.select(a.households).getSingle()).id;
    final serverBadges = f.server.recordsOf(hid, 'dog_badges');
    expect(serverBadges.where((r) => r.pk.endsWith('|first_step')).length, 1);
  });

  test('A、B 同时生成同一周的下周计划与周报：合并为一份计划、一份周报', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    final AppDatabase b = f.b;
    final sunday = weekStartOf(DateTime.now()).add(const Duration(days: 6, hours: 21, minutes: 30));
    final ra = await ReportRepository(a).generate(planId: f.a.planId, content: lib, now: sunday.toLocal());
    final rb = await ReportRepository(b).generate(planId: f.a.planId, content: lib, now: sunday.toLocal());
    expect(ra.nextPlanId, rb.nextPlanId);
    expect(ra.reportId, rb.reportId);
    await f.sa.pushPending();
    await f.sb.pushPending();
    await f.sa.pull();
    await f.sb.pull();
    for (final db in [a, b]) {
      final plans = await db.select(db.weeklyPlans).get();
      final weeks = plans.map((p) => p.weekStart).toList();
      expect(weeks.toSet().length, weeks.length, reason: '同一周只有一份计划');
      expect(plans.length, 2);
      expect((await db.select(db.weeklyReports).get()).length, 1);
    }
    expect(await snapshot(a), await snapshot(b));
  });

  test('离线写入后联网补推：发件箱保留，恢复网络后推送成功', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    f.server.offline = true;
    final sid = await saveSession(a, f.a.dogId, 'name_response');
    await expectLater(f.sa.pushPending(), throwsA(isA<SyncException>()));
    final pending = await a.select(a.syncOutbox).get();
    expect(pending.any((q) => q.tbl == 'training_sessions' && q.pk == sid), isTrue);
    f.server.offline = false;
    expect(await f.sa.pushPending(), greaterThan(0));
    expect(await a.select(a.syncOutbox).get(), isEmpty);
    await f.sb.pull();
    expect((await SessionRepository(f.b).sessionsOf(f.a.dogId)).map((s) => s.id), contains(sid));
  });

  test('后写胜：两边改同一条口令，较晚的那次在两边都生效；旧数据不覆盖新数据', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    final AppDatabase b = f.b;
    await ProfileRepository(a).updateCue(dogId: f.a.dogId, skillId: 'sit', cueWord: '旧口令', gestureText: 'g');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await ProfileRepository(b).updateCue(dogId: f.a.dogId, skillId: 'sit', cueWord: '新口令', gestureText: 'g');
    await f.sb.pushPending(); // 新的先到
    await f.sa.pushPending(); // 旧的后到，被服务端拒绝
    await f.sa.pull();
    await f.sb.pull();
    for (final db in [a, b]) {
      final cue = (await ProfileRepository(db).cues(f.a.dogId)).firstWhere((c) => c.skillId == 'sit');
      expect(cue.cueWord, '新口令');
    }
  });

  test('软删除传播：A 删除手动养护条目，B 同步后消失', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    final AppDatabase b = f.b;
    final id = await CareRepository(a).addManual(dogId: f.a.dogId, type: 'vaccine', title: '手动', dueDate: DateTime.now());
    await f.sa.pushPending();
    await f.sb.pull();
    expect((await CareRepository(b).all(f.a.dogId)).map((c) => c.id), contains(id));
    await CareRepository(a).deleteManual(id);
    await f.sa.pushPending();
    await f.sb.pull();
    expect((await CareRepository(b).all(f.a.dogId)).map((c) => c.id), isNot(contains(id)));
    expect((await CareRepository(a).all(f.a.dogId)).map((c) => c.id), isNot(contains(id)));
  });

  test('确定性主键：两台设备各自展开默认养护日历，主键一致、合并后不重复', () async {
    final f = await family();
    final AppDatabase a = f.a.db;
    final AppDatabase b = f.b;
    final before = (await CareRepository(b).all(f.a.dogId)).length;
    // B 也"首次启动生成"一遍：全部已存在，不新增
    final r = await CareRepository(b).syncDefaults((await DogRepository(b).currentDog())!, lib.careCalendar);
    expect(r.inserted, 0);
    expect((await CareRepository(b).all(f.a.dogId)).length, before);
    expect(before, (await CareRepository(a).all(f.a.dogId)).length);
    final plan = await PlanRepository(a).activePlan(f.a.dogId);
    expect(plan!.id, weeklyPlanId(f.a.dogId, plan.weekStart));
  });

  test('下行应用不入发件箱（不回推），本地写入才入发件箱', () async {
    final f = await family();
    final AppDatabase b = f.b;
    await f.sb.pushPending();
    expect(await b.select(b.syncOutbox).get(), isEmpty);
    await saveSession(f.a.db, f.a.dogId, 'name_response');
    await f.sa.pushPending();
    await f.sb.pull();
    expect((await b.select(b.syncOutbox).get()).where((q) => q.tbl == 'training_sessions'), isEmpty);
  });

  test('同步表清单与简报 5.3 一致（16 张），每张都有 client_updated_at 与 deleted 列', () async {
    final db = memoryDb();
    expect(syncTables.map((t) => t.name).toSet(), {
      'households', 'household_members', 'users', 'dogs', 'dog_concerns', 'dog_cues', 'weekly_plans',
      'plan_goals', 'daily_mini_tasks', 'training_sessions', 'weekly_reports', 'ai_conversations',
      'ai_messages', 'diagnosis_results', 'care_reminders', 'dog_badges',
    });
    for (final t in syncTables) {
      final cols = await db.customSelect('PRAGMA table_info(${t.name})').get();
      final names = cols.map((c) => c.data['name']).toSet();
      expect(names, containsAll(['client_updated_at', 'deleted']), reason: t.name);
    }
    await db.close();
  });
}
