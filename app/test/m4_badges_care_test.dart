/// M4 简报第 10 节第 1、2 条：徽章判定、疫苗 / 驱虫日历（纯函数），以及通知排期。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/badges.dart';
import 'package:puppy_trainer/domain/care_calendar.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  BadgeInput input({
    List<BadgeSession> sessions = const [],
    int streak = 0,
    int mastered = 0,
    int diag = 0,
    List<String> members = const ['a'],
  }) =>
      BadgeInput(
        sessions: sessions,
        longestStreakDays: streak,
        masteredCount: mastered,
        diagnosisCount: diag,
        memberIds: members,
      );

  Set<String> ids(List<BadgeAward> a) => {for (final x in a) x.badgeId};
  BadgeSession s(String u, int day) => BadgeSession(userId: u, startedAt: DateTime(2026, 11, 1 + day, 10));

  group('徽章：每种 condition_type 达成与未达成', () {
    test('内容库里出现的 condition_type 全部被覆盖', () {
      expect({for (final b in lib.badges) b.conditionType},
          {'first_checkin', 'streak_days', 'skills_mastered', 'first_diagnosis', 'sessions_total', 'household_members'});
    });

    test('first_checkin', () {
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(), alreadyEarned: {})), isNot(contains('first_step')));
      final a = newBadgeAwards(defs: lib.badges, input: input(sessions: [s('a', 0)]), alreadyEarned: {});
      expect(ids(a), contains('first_step'));
      expect(a.firstWhere((x) => x.badgeId == 'first_step').earnedByUserId, 'a');
    });

    test('streak_days 7 / 30 / 100（按历史最长）', () {
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(streak: 6), alreadyEarned: {})), isNot(contains('streak_7')));
      final r = ids(newBadgeAwards(defs: lib.badges, input: input(streak: 30), alreadyEarned: {}));
      expect(r, containsAll(['streak_7', 'streak_30']));
      expect(r, isNot(contains('streak_100')));
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(streak: 100), alreadyEarned: {})), contains('streak_100'));
    });

    test('streak 获得者：第 7 天那次记录的练习者', () {
      final sessions = [for (var d = 0; d < 7; d++) s(d == 6 ? 'b' : 'a', d)];
      final a = newBadgeAwards(defs: lib.badges, input: input(sessions: sessions, streak: 7, members: ['a', 'b']), alreadyEarned: {});
      expect(a.firstWhere((x) => x.badgeId == 'streak_7').earnedByUserId, 'b');
    });

    test('skills_mastered 1 / 5 / 10 / 18', () {
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(mastered: 0), alreadyEarned: {})), isNot(contains('first_skill')));
      final r5 = ids(newBadgeAwards(defs: lib.badges, input: input(mastered: 5), alreadyEarned: {}));
      expect(r5, containsAll(['first_skill', 'skills_5']));
      expect(r5, isNot(contains('skills_10')));
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(mastered: 17), alreadyEarned: {})), isNot(contains('skills_all')));
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(mastered: 18), alreadyEarned: {})), contains('skills_all'));
    });

    test('first_diagnosis', () {
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(), alreadyEarned: {})), isNot(contains('first_diagnosis')));
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(diag: 1), alreadyEarned: {})), contains('first_diagnosis'));
    });

    test('sessions_total 50：第 50 次的练习者获得', () {
      final s49 = [for (var i = 0; i < 49; i++) s('a', i % 20)];
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(sessions: s49), alreadyEarned: {})), isNot(contains('sessions_50')));
      final a = newBadgeAwards(
          defs: lib.badges,
          input: input(sessions: [...s49, BadgeSession(userId: 'b', startedAt: DateTime(2026, 12, 30))], members: ['a', 'b']),
          alreadyEarned: {});
      expect(a.firstWhere((x) => x.badgeId == 'sessions_50').earnedByUserId, 'b');
    });

    test('household_members：两位成员都打过卡才颁发；只有成员数达到不算', () {
      final two = ['a', 'b'];
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(members: two), alreadyEarned: {})), isNot(contains('team_effort')));
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(members: two, sessions: [s('a', 0), s('a', 1)]), alreadyEarned: {})),
          isNot(contains('team_effort')));
      final a = newBadgeAwards(defs: lib.badges, input: input(members: two, sessions: [s('a', 0), s('b', 1)]), alreadyEarned: {});
      expect(a.firstWhere((x) => x.badgeId == 'team_effort').earnedByUserId, 'b');
      // 非成员的记录不算
      expect(ids(newBadgeAwards(defs: lib.badges, input: input(members: ['a'], sessions: [s('a', 0), s('x', 1)]), alreadyEarned: {})),
          isNot(contains('team_effort')));
    });

    test('重复判定不重复颁发', () {
      final inp = input(sessions: [s('a', 0)], mastered: 1, diag: 1);
      final first = ids(newBadgeAwards(defs: lib.badges, input: inp, alreadyEarned: {}));
      expect(newBadgeAwards(defs: lib.badges, input: inp, alreadyEarned: first), isEmpty);
    });

    test('未知 condition_type 永不颁发', () {
      const b = Badge(id: 'x', name: 'x', icon: '', conditionType: 'mystery', conditionValue: 0, description: '');
      expect(newBadgeAwards(defs: const [b], input: input(sessions: [s('a', 0)]), alreadyEarned: {}), isEmpty);
    });
  });

  group('疫苗 / 驱虫日历', () {
    final birth = DateTime.utc(2026, 9, 7);
    List<CareEntry> expand([DateTime? b]) =>
        expandCareCalendar(dogId: 'd', birthDate: b ?? birth, calendar: lib.careCalendar);

    test('一次性项：中点周向下取整', () {
      final e = expand();
      final v1 = e.singleWhere((x) => x.templateId == 'vaccine_1'); // 6-8 → 7
      expect(v1.dueDate, birth.add(const Duration(days: 49)));
      final rabies = e.singleWhere((x) => x.templateId == 'rabies_1'); // 12-16 → 14
      expect(rabies.dueDate, birth.add(const Duration(days: 98)));
      final annual = e.singleWhere((x) => x.templateId == 'vaccine_annual'); // 52-56 → 54
      expect(annual.dueDate, birth.add(const Duration(days: 54 * 7)));
      // (a+b)/2 非整数时向下取整：构造 6-9 → 7
      const cal = CareCalendar(disclaimer: '', milestones: [], items: [
        CareItem(id: 't', type: 'vaccine', title: 'T', weekFrom: 6, weekTo: 9, repeatEveryWeeks: null, note: 'n'),
      ]);
      expect(expandCareCalendar(dogId: 'd', birthDate: birth, calendar: cal).single.dueDate,
          birth.add(const Duration(days: 49)));
    });

    test('重复项：从 week_from 起每 every_weeks 周，不超过 week_to', () {
      final e = expand();
      final early = e.where((x) => x.templateId == 'deworm_internal_early').toList(); // 2,4,...,12
      expect(early.length, 6);
      expect(early.first.dueDate, birth.add(const Duration(days: 14)));
      expect(early.last.dueDate, birth.add(const Duration(days: 84)));
      final ext = e.where((x) => x.templateId == 'deworm_external').toList(); // 8,12,...,52
      expect(ext.length, 12);
      expect(ext.last.dueDate, birth.add(const Duration(days: 52 * 7)));
      expect({for (final x in early) x.id}.length, 6);
      expect(early[2].id, careReminderId('d', 'deworm_internal_early', 2));
    });

    test('标题、说明为内容库原文；milestones 不生成条目', () {
      final byTpl = {for (final i in lib.careCalendar.items) i.id: i};
      for (final x in expand()) {
        expect(x.title, byTpl[x.templateId]!.title);
        expect(x.note, byTpl[x.templateId]!.note);
        expect(x.type, byTpl[x.templateId]!.type);
      }
      final ms = {for (final m in lib.careCalendar.milestones) m.id};
      expect(expand().where((x) => ms.contains(x.templateId)), isEmpty);
    });

    test('出生在 30 周前的狗：过期的一次性项照常生成并归入"待确认"', () {
      final today = DateTime.utc(2026, 11, 17);
      final b = today.subtract(const Duration(days: 30 * 7));
      final e = expand(b);
      final v1 = e.singleWhere((x) => x.templateId == 'vaccine_1');
      expect(careGroupOf(dueDate: v1.dueDate, done: false, skipped: false, today: today), CareGroup.overdue);
      final annual = e.singleWhere((x) => x.templateId == 'vaccine_annual');
      expect(careGroupOf(dueDate: annual.dueDate, done: false, skipped: false, today: today), CareGroup.later);
      expect(careGroupOf(dueDate: v1.dueDate, done: true, skipped: false, today: today), CareGroup.done);
      expect(careGroupOf(dueDate: v1.dueDate, done: false, skipped: true, today: today), CareGroup.done);
      expect(careGroupOf(dueDate: today.add(const Duration(days: 30)), done: false, skipped: false, today: today),
          CareGroup.upcoming);
      // 过期条目不推送
      final plans = planCareNotifications(
        items: [for (final x in e) (id: x.id, dueDate: x.dueDate, done: false, skipped: false)],
        now: DateTime(2026, 11, 17, 10),
      );
      final overdueIds = {for (final x in e) if (x.dueDate.isBefore(today)) x.id};
      expect(plans.where((p) => overdueIds.contains(p.reminderId)), isEmpty);
    });

    test('修改出生日期：只重算 source = default 且未完成、未跳过的条目', () {
      final old = expand();
      final existing = [
        for (final x in old)
          CareExisting(
            id: x.id,
            source: x.templateId == 'vaccine_2' ? 'user' : 'default',
            done: x.templateId == 'vaccine_1',
            skipped: x.templateId == 'rabies_1',
            dueDate: x.dueDate,
          ),
      ];
      final moved = expand(birth.add(const Duration(days: 7)));
      final plan = planCareRegeneration(expanded: moved, existing: existing);
      expect(plan.insert, isEmpty);
      final updated = {for (final x in plan.update) x.templateId};
      expect(updated, isNot(contains('vaccine_1'))); // 已完成
      expect(updated, isNot(contains('vaccine_2'))); // 用户改过
      expect(updated, isNot(contains('rabies_1'))); // 已跳过
      expect(updated, containsAll(['vaccine_3', 'deworm_external']));
      // 日期没变时不更新
      expect(planCareRegeneration(expanded: old, existing: existing).update, isEmpty);
    });
  });

  group('养护通知排期', () {
    test('09:00、只排 60 天内、未完成未跳过；ID 在 2000–2999，不与 1001–1014 冲突', () {
      final now = DateTime(2026, 11, 17, 10);
      final items = [
        (id: 'today_passed', dueDate: DateTime.utc(2026, 11, 17), done: false, skipped: false),
        (id: 'tomorrow', dueDate: DateTime.utc(2026, 11, 18), done: false, skipped: false),
        (id: 'done', dueDate: DateTime.utc(2026, 11, 19), done: true, skipped: false),
        (id: 'skipped', dueDate: DateTime.utc(2026, 11, 20), done: false, skipped: true),
        (id: 'day60', dueDate: DateTime.utc(2027, 1, 15), done: false, skipped: false),
        (id: 'far', dueDate: DateTime.utc(2027, 3, 1), done: false, skipped: false),
        (id: 'overdue', dueDate: DateTime.utc(2026, 11, 1), done: false, skipped: false),
      ];
      final p = planCareNotifications(items: items, now: now);
      expect(p.map((x) => x.reminderId), ['tomorrow', 'day60']);
      expect(p.first.at, DateTime(2026, 11, 18, 9));
      for (final x in p) {
        expect(x.id, inInclusiveRange(careNotificationIdBase, careNotificationIdMax));
        expect(x.id < 1001 || x.id > 1014, isTrue);
      }
    });
  });
}
