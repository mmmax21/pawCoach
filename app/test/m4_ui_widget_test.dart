/// M4 界面：5 Tab、记录页显示操作者、养护页、徽章墙与祝贺弹窗、家庭成员邀请码、加入家庭。
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/care_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'fake_sync_server.dart';
import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

void main() {
  late AppDatabase db;
  late ContentLibrary lib;
  late String dogId;
  final fakeNow = DateTime(2026, 11, 17, 9);
  late FakeSyncServer server;

  setUpAll(() async => lib = await loadRepoContent());

  Future<void> seed(WidgetTester t, {bool onboard = true}) async {
    db = memoryDb();
    server = FakeSyncServer();
    if (!onboard) return;
    await t.runAsync(() async {
      await HouseholdRepository(db).ensureLocalUser();
      await (db.update(db.users)..where((u) => u.id.equals('local_user'))).write(const UsersCompanion(nickname: Value('妈妈')));
      final r = await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: '豆豆',
          birthDate: DateTime(2026, 4, 20), // 约 30 周，有过期条目
          breedId: 'mixed_or_unknown',
          breedText: '混种 / 不确定',
          sex: Sex.male,
          homeDate: DateTime(2026, 9, 7),
          concerns: const [],
          dailyMinutes: 10,
          trainerCount: 1,
          livingEnv: LivingEnv.apartment,
          masteredSkills: const {},
        ),
        content: lib,
        now: fakeNow,
      );
      dogId = r.dogId;
      await CareRepository(db).syncDefaults((await DogRepository(db).currentDog())!, lib.careCalendar);
    });
  }

  Future<void> pumpApp(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
        clockProvider.overrideWithValue(() => fakeNow),
        reminderNotifierProvider.overrideWithValue(FakeNotifier()),
        syncApiProvider.overrideWithValue(server),
        appEffectsEnabledProvider.overrideWithValue(false),
      ],
      child: const PuppyTrainerApp(),
    ));
  }

  GoRouter router(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp))).read(routerProvider);

  Future<void> settle(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('超时未出现: $f');
  }

  Future<void> teardownApp(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.runAsync(() => db.close());
  }

  testWidgets('底部 5 Tab：首页 / 技能树 / AI 教练 / 记录 / 我的，各自可进入', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_skills')));
    for (final k in ['nav_home', 'nav_skills', 'nav_coach', 'nav_records', 'nav_me']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    await t.tap(find.byKey(const Key('nav_skills')));
    await settle(t, find.byKey(const Key('skill_tree_marker_intro')));
    expect(find.byKey(const Key('skill_status_marker_intro')), findsOneWidget);
    await t.tap(find.byKey(const Key('nav_records')));
    await settle(t, find.byKey(const Key('records_tab_care')));
    await t.tap(find.byKey(const Key('nav_me')));
    await settle(t, find.byKey(const Key('me_family')));
    for (final k in ['me_dog_profile', 'me_cues', 'me_badges', 'me_reminder']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    expect(find.byKey(const Key('me_subscription')), findsNothing); // 首版隐藏
    await t.tap(find.byKey(const Key('me_cues')));
    await settle(t, find.byKey(const Key('cue_editor')));
    await teardownApp(t);
  });

  testWidgets('训练记录按日期倒序、显示练习者昵称；他人的视频备注显示"保存在录制者的手机上"', (t) async {
    await seed(t);
    await t.runAsync(() async {
      await db.into(db.users).insert(UsersCompanion.insert(id: 'u_b', nickname: '爸爸', createdAt: '2026-11-17T00:00:00Z'));
      for (final (id, user, at, video) in [
        ('s1', 'local_user', '2026-11-16T01:00:00.000Z', null),
        ('s2', 'u_b', '2026-11-17T00:30:00.000Z', '/sdcard/x.mp4'),
      ]) {
        await db.into(db.trainingSessions).insert(TrainingSessionsCompanion.insert(
              id: id,
              dogId: dogId,
              userId: user,
              skillId: 'marker_intro',
              scriptPart: 1,
              startedAt: at,
              endedAt: at,
              durationSec: 60,
              score: 'full',
              noteVideoUrl: Value(video),
            ));
      }
    });
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_records')));
    router(t).go('/records');
    await settle(t, find.byKey(const Key('session_s2')));
    expect(find.text('练习者：爸爸'), findsOneWidget);
    expect(find.text('练习者：妈妈（我）'), findsOneWidget);
    expect(find.text('视频保存在录制者的手机上'), findsOneWidget);
    final y1 = t.getTopLeft(find.byKey(const Key('session_s1'))).dy;
    final y2 = t.getTopLeft(find.byKey(const Key('session_s2'))).dy;
    expect(y2, lessThan(y1)); // 新的在上
    await teardownApp(t);
  });

  testWidgets('养护页：disclaimer 原文置顶、分组、标记完成后进入已完成', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_records')));
    router(t).go('/records?tab=care');
    await settle(t, find.byKey(const Key('care_disclaimer')));
    expect(find.text(lib.careCalendar.disclaimer), findsOneWidget);
    expect(find.byKey(const Key('care_group_overdue')), findsOneWidget);
    final v1 = 'care_${dogId}_vaccine_1_0';
    await t.scrollUntilVisible(find.byKey(Key('care_menu_$v1')), 200,
        scrollable: find.descendant(of: find.byKey(const Key('care_list')), matching: find.byType(Scrollable)));
    await t.tap(find.byKey(Key('care_menu_$v1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('care_done_$v1')));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    await t.scrollUntilVisible(find.byKey(const Key('care_group_done')), 300,
        scrollable: find.descendant(of: find.byKey(const Key('care_list')), matching: find.byType(Scrollable)));
    final row = await t.runAsync(() => (db.select(db.careReminders)..where((c) => c.id.equals(v1))).getSingle());
    expect(row!.doneAt, isNotNull);
    await teardownApp(t);
  });

  testWidgets('徽章：新获得时弹一次祝贺（名称 + description 原文 + 获得者），徽章墙彩色 / 灰色', (t) async {
    await seed(t);
    await t.runAsync(() async {
      await db.into(db.users).insert(UsersCompanion.insert(id: 'u_b', nickname: '爸爸', createdAt: '2026-11-17T00:00:00Z'));
      await db.into(db.dogBadges).insert(DogBadgesCompanion.insert(
          dogId: dogId, badgeId: 'first_step', earnedAt: '2026-11-17T01:00:00.000Z', earnedByUserId: 'u_b'));
    });
    await pumpApp(t);
    await settle(t, find.byKey(const Key('badge_popup')));
    final def = lib.badges.firstWhere((b) => b.id == 'first_step');
    expect(find.text('获得徽章：${def.name}'), findsOneWidget);
    expect(find.text(def.description), findsOneWidget);
    expect(find.text('爸爸获得了这枚徽章'), findsOneWidget);
    await t.tap(find.byKey(const Key('badge_popup_ok')));
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(find.byKey(const Key('badge_popup')), findsNothing);
    final seen = await t.runAsync(() => db.select(db.badgePopupsSeen).get());
    expect(seen!.single.badgeId, 'first_step');

    router(t).push('/me/badges');
    await settle(t, find.byKey(const Key('badge_first_step_earned')));
    expect(find.byKey(const Key('badge_streak_7_locked')), findsOneWidget);
    expect(find.textContaining('爸爸 获得'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('家庭成员页：建家上传后显示 6 位邀请码，可重新生成（旧码失效）', (t) async {
    await seed(t);
    await pumpApp(t);
    await settle(t, find.byKey(const Key('nav_me')));
    router(t).push('/me/family');
    await settle(t, find.byKey(const Key('invite_code')));
    final code1 = t.widget<SelectableText>(find.byKey(const Key('invite_code'))).data!;
    expect(server.invite[code1], isNotNull);
    expect(find.textContaining('妈妈（我）'), findsOneWidget);
    await t.tap(find.byKey(const Key('invite_regen')));
    await settle(t, find.byKey(const Key('invite_regen_confirm')));
    await t.tap(find.byKey(const Key('invite_regen_confirm')));
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end) &&
        t.widget<SelectableText>(find.byKey(const Key('invite_code'))).data == code1) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    final code2 = t.widget<SelectableText>(find.byKey(const Key('invite_code'))).data!;
    expect(code2, isNot(code1));
    expect(server.invite.containsKey(code1), isFalse);
    await teardownApp(t);
  });

  testWidgets('加入家庭：建档第一屏有入口；错误邀请码提示；正确邀请码直接进首页（不走建档）', (t) async {
    // 先由另一台设备建家
    await seed(t);
    final other = db;
    final s = await t.runAsync(() async {
      final svc = (await _svc(other, server));
      await svc.ensureHouseholdUploaded();
      return (await other.select(other.households).getSingle()).inviteCode!;
    });
    // 本机：空库
    db = memoryDb();
    await pumpApp(t);
    await settle(t, find.byKey(const Key('onboarding_join')));
    await t.tap(find.byKey(const Key('onboarding_join')));
    await settle(t, find.byKey(const Key('join_code')));
    await t.enterText(find.byKey(const Key('join_code')), 'ZZZZZZ');
    await t.enterText(find.byKey(const Key('join_nickname')), '爸爸');
    await t.pump();
    await t.tap(find.byKey(const Key('join_submit')));
    await settle(t, find.byKey(const Key('join_error')));
    expect(find.text('邀请码不正确或已失效'), findsOneWidget);
    await t.enterText(find.byKey(const Key('join_code')), s!.toLowerCase());
    await t.pump();
    await t.tap(find.byKey(const Key('join_submit')));
    await settle(t, find.byKey(const Key('home_goal_count_marker_intro')));
    final dog = await t.runAsync(() => DogRepository(db).currentDog());
    expect(dog!.id, dogId);
    await teardownApp(t);
    await t.runAsync(() => other.close());
  });
}

Future<dynamic> _svc(AppDatabase db, FakeSyncServer server) async {
  final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db), syncApiProvider.overrideWithValue(server)]);
  return c.read(httpSyncServiceProvider);
}
