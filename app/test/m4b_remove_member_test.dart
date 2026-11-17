/// M4 批次 B · FM-4 创建者移除成员：被移除设备下次同步收到 403 → 清空本地家庭数据、回到未加入状态并提示。
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'fake_sync_server.dart';
import 'helpers.dart';
import 'm3_plan_reminder_test.dart' show FakeNotifier;

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  Future<AppDatabase> onboarded() async {
    final db = memoryDb();
    await HouseholdRepository(db).ensureLocalUser();
    await (db.update(db.users)..where((u) => u.id.equals('local_user'))).write(const UsersCompanion(nickname: Value('妈妈')));
    await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: DateTime(2026, 9, 7),
        breedId: 'mixed',
        breedText: '混种',
        sex: Sex.male,
        homeDate: DateTime(2026, 9, 7),
        concerns: const [],
        dailyMinutes: 10,
        trainerCount: 2,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {},
      ),
      content: lib,
      now: DateTime(2026, 11, 16, 9),
    );
    return db;
  }

  Future<({AppDatabase a, AppDatabase b, HttpSyncService sa, HttpSyncService sb, FakeSyncServer server})> family() async {
    final server = FakeSyncServer();
    final a = await onboarded();
    final sa = HttpSyncService(db: a, api: server);
    await sa.ensureHouseholdUploaded();
    final b = memoryDb();
    final sb = HttpSyncService(db: b, api: server);
    await sb.joinHousehold(inviteCode: (await a.select(a.households).getSingle()).inviteCode!, nickname: '爸爸');
    await sb.pushPending();
    await sa.pull();
    return (a: a, b: b, sa: sa, sb: sb, server: server);
  }

  test('创建者移除成员：创建者本机成员列表减少；被移除者下次拉取清空本地数据并提示', () async {
    final f = await family();
    expect((await f.a.select(f.a.householdMembers).get()).length, 2);
    final bUser = await currentUserId(f.b);
    await loadRepoContent(db: f.b); // B 本机有内容库缓存
    var cleaned = false;
    f.sb.onRemoved = () async => cleaned = true;

    await f.sa.removeMember(bUser);
    expect((await f.a.select(f.a.householdMembers).get()).map((m) => m.userId), isNot(contains(bUser)));

    await expectLater(f.sb.pull(), throwsA(isA<SyncException>().having((e) => e.code, 'code', 'removed_from_household')));
    expect(f.sb.removedNotice.value, '豆豆的家');
    expect(cleaned, isTrue);
    expect(await DogRepository(f.b).currentDog(), isNull);
    for (final t in ['households', 'household_members', 'training_sessions', 'weekly_plans', 'sync_states', 'sync_outbox', 'streaks']) {
      final n = (await f.b.customSelect('SELECT COUNT(*) AS n FROM $t').getSingle()).read<int>('n');
      expect(n, 0, reason: t);
    }
    // 内容库缓存与本机账号保留，可用当前邀请码重新加入
    expect((await f.b.select(f.b.contentSkills).get()), isNotEmpty);
    expect(await currentUserId(f.b), bUser);
    final code = (await f.a.select(f.a.households).getSingle()).inviteCode!;
    await f.sb.joinHousehold(inviteCode: code, nickname: '爸爸');
    expect((await DogRepository(f.b).currentDog()), isNotNull);
  });

  test('推送时收到 403 同样视为被移出', () async {
    final f = await family();
    await f.sa.removeMember(await currentUserId(f.b));
    await (f.b.update(f.b.dogCues)..where((c) => c.skillId.equals('sit'))).write(const DogCuesCompanion(cueWord: Value('x')));
    await expectLater(f.sb.pushPending(), throwsA(isA<SyncException>()));
    expect(await DogRepository(f.b).currentDog(), isNull);
  });

  test('只有创建者可移除，且不能移除自己', () async {
    final f = await family();
    final aUser = await currentUserId(f.a);
    await expectLater(f.sb.removeMember(aUser), throwsA(isA<SyncException>().having((e) => e.code, 'code', 'not_creator')));
    await expectLater(f.sa.removeMember(aUser), throwsA(isA<SyncException>().having((e) => e.code, 'code', 'cannot_remove_self')));
    // 网络错误等非 403 不清数据
    f.server.offline = true;
    await expectLater(f.sb.pull(), throwsA(isA<SyncException>().having((e) => e.code, 'code', 'network')));
    expect(await DogRepository(f.b).currentDog(), isNotNull);
  });

  testWidgets('界面：创建者在家庭成员页看到移除按钮；被移除设备回到建档页并弹提示', (t) async {
    final f = (await t.runAsync(family))!;
    final bUser = (await t.runAsync(() => currentUserId(f.b)))!;
    Future<void> pump(AppDatabase db) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(ProviderScope(overrides: [
        databaseProvider.overrideWithValue(db),
        contentSourceProvider.overrideWithValue(FileContentSource(repoContentDir())),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 16, 9)),
        reminderNotifierProvider.overrideWithValue(FakeNotifier()),
        syncApiProvider.overrideWithValue(f.server),
        appEffectsEnabledProvider.overrideWithValue(false),
      ], child: const PuppyTrainerApp()));
    }

    Future<void> settle(Finder x) async {
      for (var i = 0; i < 300; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump();
        if (x.evaluate().isNotEmpty) return;
      }
      throw TestFailure('超时：$x');
    }

    GoRouter router() => ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp))).read(routerProvider);
    ProviderContainer container() => ProviderScope.containerOf(t.element(find.byType(PuppyTrainerApp)));

    // B 的设备：成员页没有移除按钮（不是创建者）
    await pump(f.b);
    await settle(find.byKey(const Key('nav_me')));
    router().push('/me/family');
    await settle(find.textContaining('妈妈'));
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 500));

    // A 的设备：移除 B
    await pump(f.a);
    await settle(find.byKey(const Key('nav_me')));
    router().push('/me/family');
    await settle(find.byKey(Key('member_remove_$bUser')));
    await t.tap(find.byKey(Key('member_remove_$bUser')));
    await settle(find.byKey(const Key('member_remove_confirm')));
    await t.tap(find.byKey(const Key('member_remove_confirm')));
    for (var i = 0; i < 100 && find.byKey(Key('member_remove_$bUser')).evaluate().isNotEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    expect(find.byKey(Key('member_remove_$bUser')), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 500));

    // B 的设备：下次同步 → 回到建档页 + 提示
    await pump(f.b);
    await settle(find.byKey(const Key('nav_home')));
    final svc = container().read(httpSyncServiceProvider);
    await t.runAsync(() => svc.pull().catchError((_) => <String>{}));
    await settle(find.byKey(const Key('removed_notice')));
    expect(find.textContaining('豆豆的家'), findsOneWidget);
    await t.tap(find.byKey(const Key('removed_notice_ok')));
    await settle(find.byKey(const Key('onboarding_join')));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 500));
    await t.runAsync(() async {
      await f.a.close();
      await f.b.close();
    });
  });
}
