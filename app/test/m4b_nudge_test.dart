/// M4 批次 B · AI-5 主动干预：规则（纯函数）、正文只由内容库原文 + 固定模板组成、通知 ID 区间、去重。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/repositories/reminder_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/domain/answer_composer.dart' show tplDowngradeGuide;
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/nudges.dart';
import 'package:puppy_trainer/services/care_reminder_service.dart';
import 'package:puppy_trainer/services/nudge_service.dart';

import 'helpers.dart';

class FakeNotif implements CareNotifier {
  final scheduled = <({int id, DateTime at, String title, String body})>[];
  final cancelled = <int>[];

  /// 操作顺序：`S{id}` 排期、`C{id}` 取消。
  final log = <String>[];
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    log.add('C$id');
  }

  @override
  Future<void> scheduleOnce({required int id, required DateTime at, required String title, required String body}) async {
    scheduled.add((id: id, at: at, title: title, body: body));
    log.add('S$id');
  }
}

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  NudgeSession s(String skill, Score score, int day, {int part = 1}) =>
      NudgeSession(skillId: skill, scriptPart: part, score: score, startedAt: DateTime(2026, 11, day, 10));

  group('规则 1：同一技能连续 2 次没做到', () {
    test('最近两次都没做到 → 推降级技能名 + 其 tutorial.summary 原文', () {
      final sit = lib.skillById['sit']!;
      final down = lib.skillById[sit.downgradeTo]!;
      final n = downgradeNudges(sessions: [s('sit', Score.full, 1), s('sit', Score.none, 2), s('sit', Score.none, 3)], skills: lib.skills);
      expect(n.single.title, tplDowngradeGuide);
      expect(n.single.body, '${down.name}：${down.tutorial.summary}');
      expect(n.single.id, inInclusiveRange(nudgeDowngradeIdBase, nudgeIdMax));
    });

    test('不连续 / 只有一次 / 保底任务不算', () {
      expect(downgradeNudges(sessions: [s('sit', Score.none, 1), s('sit', Score.partial, 2), s('sit', Score.none, 3)], skills: lib.skills), isEmpty);
      expect(downgradeNudges(sessions: [s('sit', Score.none, 1)], skills: lib.skills), isEmpty);
      expect(downgradeNudges(sessions: [s('sit', Score.none, 1, part: 0), s('sit', Score.none, 2, part: 0)], skills: lib.skills), isEmpty);
      // 两次分属不同技能
      expect(downgradeNudges(sessions: [s('sit', Score.none, 1), s('down', Score.none, 2)], skills: lib.skills), isEmpty);
    });

    test('没有降级技能 → 固定模板正文', () {
      final noDown = lib.skills.firstWhere((x) => x.downgradeTo == null);
      final n = downgradeNudges(sessions: [s(noDown.id, Score.none, 1), s(noDown.id, Score.none, 2)], skills: lib.skills);
      expect(n.single.body, nudgeNoDowngradeBody);
    });

    test('每个技能的正文都只由内容库原文与固定模板组成；ID 互不相同且在 3001–3099', () {
      final ids = <int>{};
      for (final sk in lib.skills) {
        final n = downgradeNudges(sessions: [s(sk.id, Score.none, 1), s(sk.id, Score.none, 2)], skills: lib.skills).single;
        expect(nudgeTemplates, contains(n.title));
        if (sk.downgradeTo == null) {
          expect(n.body, nudgeNoDowngradeBody);
        } else {
          final d = lib.skillById[sk.downgradeTo]!;
          expect(n.body, '${d.name}：${d.tutorial.summary}');
        }
        expect(ids.add(n.id), isTrue);
        expect(n.id, inInclusiveRange(3001, 3099));
        expect(n.id < 1001 || n.id > 1014, isTrue);
        expect(n.id < 2000 || n.id > 2999, isTrue);
      }
    });
  });

  group('规则 2：家庭连续 3 天无打卡', () {
    test('最近打卡日 + 4 天 10:00 推送；已过则一分钟后', () {
      final n = restartNudge(lastActiveDay: DateTime(2026, 11, 14), now: DateTime(2026, 11, 15, 8), miniSkillName: '跟随零食');
      expect(n.at, DateTime(2026, 11, 18, 10));
      expect(n.id, nudgeRestartId);
      expect(n.title, nudgeRestartTitle);
      expect(n.body, '$nudgeRestartBody跟随零食');
      final late = restartNudge(lastActiveDay: DateTime(2026, 11, 1), now: DateTime(2026, 11, 15, 8), miniSkillName: null);
      expect(late.at, DateTime(2026, 11, 15, 8, 1));
    });
  });

  group('NudgeService：写库 → 排期 → 去重', () {
    test('任一成员连续两次没做到 → 推一次；再刷新不重复；新的"没做到"组合再推', () async {
      final db = memoryDb();
      await HouseholdRepository(db).ensureLocalUser();
      final o = await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: '豆豆', birthDate: DateTime(2026, 9, 7), breedId: 'mixed', breedText: '混种', sex: Sex.male,
          homeDate: DateTime(2026, 9, 7), concerns: const [], dailyMinutes: 10, trainerCount: 2,
          livingEnv: LivingEnv.apartment, masteredSkills: const {}),
        content: lib,
        now: DateTime(2026, 11, 16, 9),
      );
      Future<void> save(String user, Score score, DateTime at) => SessionRepository(db).save(
            draft: SessionDraft(dogId: o.dogId, userId: user, skillId: 'sit', scriptPart: 1, startedAt: at,
                endedAt: at.add(const Duration(minutes: 3)), durationSec: 180, clickerCount: 0, skippedSteps: const []),
            score: score,
            now: at,
          );
      // AI-5 受每日提醒开关控制（默认关闭），本用例先打开。
      await ReminderRepository(db).save(o.dogId, const ReminderConfig(enabled: true, hour: 19, minute: 0));
      final notif = FakeNotif();
      final store = MemoryNudgeStore();
      var now = DateTime(2026, 11, 16, 20);
      final svc = NudgeService(db: db, notifier: notif, store: store, clock: () => now);

      await save('local_user', Score.none, DateTime(2026, 11, 16, 10));
      await save('u_b', Score.none, DateTime(2026, 11, 16, 18)); // 另一位成员
      final r1 = await svc.refresh(o.dogId, lib);
      expect(r1.where((n) => n.key.startsWith('downgrade:sit')).length, 1);
      // 连续 3 天无打卡预排在 11-20 10:00
      expect(notif.scheduled.firstWhere((x) => x.id == nudgeRestartId).at, DateTime(2026, 11, 20, 10));

      final before = notif.scheduled.length;
      final cancelsBefore = notif.cancelled.length;
      await svc.refresh(o.dogId, lib);
      expect(notif.scheduled.length, before, reason: '同一触发不重复推、预排不重复');
      expect(notif.cancelled.length, cancelsBefore, reason: '键没变时不取消已排的提醒');

      // 第二天又打卡（成功）→ 预排顺延，旧的取消；之后又连续两次没做到 → 再推
      now = DateTime(2026, 11, 17, 20);
      await save('local_user', Score.full, DateTime(2026, 11, 17, 9));
      await save('local_user', Score.none, DateTime(2026, 11, 17, 10));
      await save('local_user', Score.none, DateTime(2026, 11, 17, 11));
      final c2 = notif.cancelled.length;
      final r2 = await svc.refresh(o.dogId, lib);
      expect(notif.cancelled.sublist(c2), contains(nudgeRestartId));
      expect(notif.scheduled.last.id, anyOf(nudgeRestartId, inInclusiveRange(3001, 3099)));
      expect(r2.where((n) => n.key.startsWith('downgrade:sit')).length, 1);
      expect(notif.scheduled.where((x) => x.id == nudgeRestartId).last.at, DateTime(2026, 11, 21, 10));
      await db.close();
    });
  });

  group('AI-5 受每日提醒开关控制（Fable 2026-11-17 裁定）', () {
    late dynamic db;
    late String dogId;
    late FakeNotif notif;
    late MemoryNudgeStore store;
    late NudgeService svc;
    var now = DateTime(2026, 11, 16, 20);

    Future<void> noneTwice(DateTime day) async {
      for (final h in [9, 10]) {
        final at = DateTime(day.year, day.month, day.day, h);
        await SessionRepository(db).save(
          draft: SessionDraft(dogId: dogId, userId: 'local_user', skillId: 'sit', scriptPart: 1, startedAt: at,
              endedAt: at.add(const Duration(minutes: 3)), durationSec: 180, clickerCount: 0, skippedSteps: const []),
          score: Score.none,
          now: at,
        );
      }
    }

    Future<void> setEnabled(bool on) =>
        ReminderRepository(db).save(dogId, ReminderConfig(enabled: on, hour: 19, minute: 0));

    bool pendingRestart() {
      // 最后一次对 3000 的操作是排期而不是取消
      final lastSchedule = notif.log.lastIndexWhere((e) => e == 'S$nudgeRestartId');
      final lastCancel = notif.log.lastIndexWhere((e) => e == 'C$nudgeRestartId');
      return lastSchedule > lastCancel;
    }

    setUp(() async {
      db = memoryDb();
      await HouseholdRepository(db).ensureLocalUser();
      final o = await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: '豆豆', birthDate: DateTime(2026, 9, 7), breedId: 'mixed', breedText: '混种', sex: Sex.male,
          homeDate: DateTime(2026, 9, 7), concerns: const [], dailyMinutes: 10, trainerCount: 1,
          livingEnv: LivingEnv.apartment, masteredSkills: const {}),
        content: lib,
        now: DateTime(2026, 11, 16, 9),
      );
      dogId = o.dogId;
      notif = FakeNotif();
      store = MemoryNudgeStore();
      now = DateTime(2026, 11, 16, 20);
      svc = NudgeService(db: db, notifier: notif, store: store, clock: () => now);
    });
    tearDown(() async => db.close());

    test('开：两类推送都排', () async {
      await setEnabled(true);
      await noneTwice(DateTime(2026, 11, 16));
      final r = await svc.refresh(dogId, lib);
      expect(r.map((n) => n.id), containsAll([nudgeRestartId, nudgeDowngradeIdBase + lib.skills.indexWhere((s) => s.id == 'sit')]));
      expect(pendingRestart(), isTrue);
    });

    test('关：不排；之前已排的 3000–3099 全部取消；关闭期间出现的触发也不排', () async {
      await setEnabled(true);
      await svc.refresh(dogId, lib);
      expect(pendingRestart(), isTrue);
      await setEnabled(false);
      final scheduledBefore = notif.scheduled.length;
      final r = await svc.refresh(dogId, lib);
      expect(r, isEmpty);
      for (var id = nudgeRestartId; id <= nudgeIdMax; id++) {
        expect(notif.cancelled, contains(id));
      }
      expect(pendingRestart(), isFalse);
      await noneTwice(DateTime(2026, 11, 16));
      expect(await svc.refresh(dogId, lib), isEmpty);
      expect(notif.scheduled.length, scheduledBefore, reason: '关闭期间一条都不排');
      // 默认（从未设置过）也视为关闭
      await ReminderRepository(db).save(dogId, const ReminderConfig.defaults());
      expect(await svc.refresh(dogId, lib), isEmpty);
    });

    test('再开：按当前状态重排（未到点的连续未打卡提醒重新预排；关闭期间的降级建议补推一次，之后不重复）', () async {
      await setEnabled(true);
      await svc.refresh(dogId, lib);
      await setEnabled(false);
      await svc.refresh(dogId, lib);
      await noneTwice(DateTime(2026, 11, 16));
      await svc.refresh(dogId, lib);
      expect(pendingRestart(), isFalse);

      await setEnabled(true);
      final r = await svc.refresh(dogId, lib);
      expect(pendingRestart(), isTrue);
      expect(notif.scheduled.lastWhere((x) => x.id == nudgeRestartId).at, DateTime(2026, 11, 20, 10));
      expect(r.where((n) => n.key.startsWith('downgrade:sit')).length, 1);
      expect(await svc.refresh(dogId, lib), isEmpty, reason: '再刷新不重复');
    });

    test('已经推过的连续未打卡提醒，关了再开不补推', () async {
      await setEnabled(true);
      now = DateTime(2026, 11, 25, 9); // 已过 11-20 10:00，立即补推一次
      final r1 = await svc.refresh(dogId, lib);
      expect(r1.map((n) => n.id), contains(nudgeRestartId));
      await setEnabled(false);
      await svc.refresh(dogId, lib);
      await setEnabled(true);
      final r2 = await svc.refresh(dogId, lib);
      expect(r2.map((n) => n.id), isNot(contains(nudgeRestartId)));
    });
  });
}
