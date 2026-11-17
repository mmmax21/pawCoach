// Astra: real HTTP transport + SQLite server, including offline replay.
import 'package:drift/native.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/badge_repository.dart';
import 'package:puppy_trainer/data/repositories/report_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/data/sync/derived_state.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'helpers.dart';

void main() {
  test(
      'Astra real HTTP: offline onboarding/checkin replay, weekly uniqueness and badge owner',
      () async {
    final temp = await Directory.systemTemp.createTemp('astra-m4-http-');
    final server = Directory('../server').absolute.path;
    final proc = await Process.start(
        '$server/.venv/bin/uvicorn',
        [
          'main:app',
          '--host',
          '127.0.0.1',
          '--port',
          '8778',
          '--log-level',
          'warning'
        ],
        workingDirectory: server,
        environment: {
          'DB_PATH': '${temp.path}/server.sqlite',
          'FAKE_UPSTREAM': '1'
        });
    final output = <int>[];
    proc.stdout.listen(output.addAll);
    proc.stderr.listen(output.addAll);
    addTearDown(() async {
      proc.kill();
      await proc.exitCode;
      File('../tests/regression/m4a-2026-11-17/http-server.log')
          .writeAsBytesSync(output);
      await temp.delete(recursive: true);
    });
    for (var i = 0; i < 100; i++) {
      try {
        final socket = await Socket.connect('127.0.0.1', 8778);
        socket.destroy();
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (i == 99) rethrow;
      }
    }
    // The real archived M3 database also survives first upload and a new member pull.
    final legacyFile =
        File('../tests/regression/m3-2026-11-17-r2/weekly-after.sqlite')
            .copySync('${temp.path}/legacy.sqlite');
    final legacy = AppDatabase(NativeDatabase(legacyFile));
    final legacyB = memoryDb();
    addTearDown(() async {
      await legacy.close();
      await legacyB.close();
    });
    final legacySync = HttpSyncService(
        db: legacy, api: DioSyncApi(baseUrl: 'http://127.0.0.1:8778'));
    await legacySync.ensureHouseholdUploaded();
    final legacyCode =
        (await legacy.select(legacy.households).getSingle()).inviteCode;
    expect(legacyCode, isNotNull);
    await HttpSyncService(
            db: legacyB, api: DioSyncApi(baseUrl: 'http://127.0.0.1:8778'))
        .joinHousehold(inviteCode: legacyCode!, nickname: '升级验证成员');
    for (final name in [
      'training_sessions',
      'weekly_plans',
      'weekly_reports',
      'diagnosis_results',
      'ai_messages'
    ]) {
      final source = await legacy.customSelect('SELECT * FROM $name').get();
      final target = await legacyB.customSelect('SELECT * FROM $name').get();
      expect(target.map((r) => r.data).toList(),
          source.map((r) => r.data).toList(),
          reason: 'M3 first upload $name');
    }
    final lib = await loadRepoContent();
    final a = memoryDb();
    final b = memoryDb();
    addTearDown(() async {
      await a.close();
      await b.close();
    });
    final now = DateTime.now();
    final birth = now.subtract(const Duration(days: 70));
    await HouseholdRepository(a).ensureLocalUser();
    final o = await OnboardingRepository(a).complete(
        form: OnboardingResult(
          dogName: '豆豆',
          birthDate: birth,
          breedId: 'mixed',
          breedText: '混种',
          sex: Sex.male,
          homeDate: birth,
          concerns: const [],
          dailyMinutes: 10,
          trainerCount: 2,
          livingEnv: LivingEnv.apartment,
          masteredSkills: const {},
        ),
        content: lib,
        now: now);
    Future<String> checkin(AppDatabase db) async {
      final result = await SessionRepository(db).save(
          draft: SessionDraft(
            dogId: o.dogId,
            userId: await currentUserId(db),
            skillId: 'marker_intro',
            scriptPart: 1,
            startedAt: now.subtract(const Duration(minutes: 1)),
            endedAt: now,
            durationSec: 60,
            clickerCount: 0,
            skippedSteps: const [],
          ),
          score: Score.full,
          now: now);
      return result.sessionId;
    }

    final firstId = await checkin(a);
    final offline =
        HttpSyncService(db: a, api: DioSyncApi(baseUrl: 'http://127.0.0.1:1'));
    await expectLater(
        offline.ensureHouseholdUploaded(), throwsA(isA<SyncException>()));
    expect((await SessionRepository(a).sessionsOf(o.dogId)).single.id, firstId);
    expect(await a.select(a.syncOutbox).get(), isNotEmpty);
    HttpSyncService online(AppDatabase db) => HttpSyncService(
        db: db,
        api: DioSyncApi(baseUrl: 'http://127.0.0.1:8778'),
        onRemoteChange: (_) => DerivedState(db).recompute(content: lib));
    final sa = online(a);
    final sb = online(b);
    await sa.ensureHouseholdUploaded();
    final oldCode = (await a.select(a.households).getSingle()).inviteCode!;
    final newCode = await sa.regenerateInvite();
    expect(newCode, isNot(oldCode));
    await expectLater(sb.joinHousehold(inviteCode: oldCode, nickname: '爸爸'),
        throwsA(isA<SyncException>().having((e) => e.status, 'status', 404)));
    await sb.joinHousehold(inviteCode: newCode, nickname: '爸爸');
    await sa.pull();
    expect((await SessionRepository(b).sessionsOf(o.dogId)).single.id, firstId);
    final secondId = await checkin(b);
    final offB =
        HttpSyncService(db: b, api: DioSyncApi(baseUrl: 'http://127.0.0.1:1'));
    await expectLater(offB.pushPending(), throwsA(isA<SyncException>()));
    expect(await b.select(b.syncOutbox).get(), isNotEmpty);
    await BadgeRepository(b).evaluate(o.dogId, lib.badges);
    await sb.pushPending();
    await sa.pull();
    await sa.pushPending();
    await sb.pull();
    for (final db in [a, b]) {
      expect(
          (await SessionRepository(db).sessionsOf(o.dogId))
              .map((r) => r.id)
              .toSet(),
          {firstId, secondId});
      final badges = await BadgeRepository(db).earned(o.dogId);
      expect(
          badges.where((x) => x.badgeId == 'team_effort').single.earnedByUserId,
          await currentUserId(b));
      expect(await BadgeRepository(db).evaluate(o.dogId, lib.badges), isEmpty);
      await BadgeRepository(db).markSeen(o.dogId, 'team_effort');
      expect(
          (await BadgeRepository(db).watchUnseen(o.dogId).first)
              .map((x) => x.badgeId),
          isNot(contains('team_effort')));
    }
    final sunday =
        weekStartOf(now).add(const Duration(days: 6, hours: 21, minutes: 30));
    final ra = await ReportRepository(a)
        .generate(planId: o.planId, content: lib, now: sunday);
    final rb = await ReportRepository(b)
        .generate(planId: o.planId, content: lib, now: sunday);
    expect(ra.nextPlanId, rb.nextPlanId);
    expect(ra.reportId, rb.reportId);
    await sa.pushPending();
    await sb.pushPending();
    await sa.pull();
    await sb.pull();
    for (final db in [a, b]) {
      final plans = await db.select(db.weeklyPlans).get();
      expect(plans.length, 2);
      expect(plans.map((p) => p.weekStart).toSet().length, 2);
      expect((await db.select(db.weeklyReports).get()).length, 1);
      expect((await db.select(db.trainingSessions).get()).length, 2);
    }
  });
}
