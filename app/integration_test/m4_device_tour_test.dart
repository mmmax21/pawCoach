/// M4 设备实测（交接单"Android 模拟器实测"）：由 server/m4_device_tour.py 驱动，
/// 起真实 server/、注册成员 B（API 身份，替代第二台模拟器），每个 M4SHOT 行截一张图到
/// app/build/m4_screenshots/。不要单独跑。
///
/// 覆盖：建档后拿到邀请码 → B 加入（成员列表两人）→ A 记录页打卡 → 徽章弹窗 → B 打卡后 A 首页
/// 自动更新、记录页显示"爸爸"、全家总动员弹窗写明获得者 → 徽章墙 → "扑人"诊断加入本周的弹窗
/// （10 周龄、10 分钟档：不新增、写明打基础与解锁条件）→ 养护页（待确认分组）→ 技能树 Tab。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/data/sync/sync_codec.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/domain/diagnosis.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/training/training_page.dart';

import 'm2_training_test.dart' show FakeAudio;

const bToken = String.fromEnvironment('E2E_B_TOKEN');
const bUser = String.fromEnvironment('E2E_B_USER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump();
    debugPrint('M4SHOT $name');
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 30}) async {
    for (var i = 0; i < seconds * 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('超时未出现：$f');
  }

  testWidgets('M4 设备实测', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(FakeAudio()),
      appEffectsEnabledProvider.overrideWithValue(true),
    ]);
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    await (db.update(db.users)..where((u) => u.id.equals('local_user'))).write(const UsersCompanion(nickname: Value('妈妈')));
    final now = DateTime.now();
    final birth = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 70)); // 10 周
    final o = await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed_or_unknown',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const [],
        dailyMinutes: 10,
        trainerCount: 2,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {},
      ),
      content: lib,
    );
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const PuppyTrainerApp()));
    await waitFor(t, find.byKey(const Key('home_goal_count_marker_intro')));
    await shot(t, '01_home');
    final router = c.read(routerProvider);

    // 1. 建档后拿到邀请码
    router.go('/me');
    await waitFor(t, find.byKey(const Key('me_family')));
    await shot(t, '02_me');
    await t.tap(find.byKey(const Key('me_family')));
    await waitFor(t, find.byKey(const Key('invite_code')));
    await shot(t, '03_family_invite_code');

    // 2. B（API 身份）用邀请码加入，A 拉取后成员列表两人
    final hh = await t.runAsync(() => db.select(db.households).getSingle());
    await t.runAsync(() => DioSyncApi().join(bToken, hh!.inviteCode!, '爸爸'));
    await waitFor(t, find.textContaining('爸爸'), seconds: 15);
    await shot(t, '04_family_two_members');

    // 3. A 在记录页打卡 → 首次打卡徽章弹窗
    router.go('/home');
    await waitFor(t, find.byKey(const Key('home_goal_count_marker_intro')));
    router.push('/record',
        extra: SessionDraft(
          dogId: o.dogId,
          userId: (await t.runAsync(() => currentUserId(db)))!,
          skillId: 'marker_intro',
          scriptPart: 1,
          startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
          endedAt: DateTime.now(),
          durationSec: 180,
          clickerCount: 3,
          skippedSteps: const [],
        ));
    await waitFor(t, find.byKey(const Key('record_score')));
    await t.tap(find.text('完全做到'));
    await t.pump();
    await t.tap(find.byKey(const Key('record_save')));
    // 记录页上不弹，回到首页后再弹
    await waitFor(t, find.byKey(const Key('home_goal_count_marker_intro')));
    await waitFor(t, find.byKey(const Key('badge_popup_first_step')));
    await shot(t, '05_badge_popup_first_step');
    await waitFor(t, find.byKey(const Key('badge_popup_ok')));
    await t.tap(find.byKey(const Key('badge_popup_ok')));
    await t.pump(const Duration(milliseconds: 500));

    // 4. B 推一条训练记录 → A 首页自动更新（不手动刷新），全家总动员弹窗写明获得者
    final before = t.widget<Text>(find.byKey(const Key('home_goal_count_name_response'))).data;
    final ts = DateTime.now().toUtc();
    await t.runAsync(() => DioSyncApi().push(bToken, hh!.id, [
          SyncRecord(
            table: 'training_sessions',
            pk: 'ses_tour_b',
            clientUpdatedAt: ts.toIso8601String(),
            payload: {
              'id': 'ses_tour_b', 'dog_id': o.dogId, 'user_id': bUser, 'skill_id': 'name_response',
              'script_part': 1, 'started_at': ts.subtract(const Duration(minutes: 3)).toIso8601String(),
              'ended_at': ts.toIso8601String(), 'duration_sec': 180, 'score': 'full', 'note_text': null,
              'note_video_url': '/sdcard/DCIM/b.mp4', 'skipped_steps': '[]', 'clicker_count': 0,
            },
          ),
        ]));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 300; i++) {
      await t.pump(const Duration(milliseconds: 50));
      final popup = find.byKey(const Key('badge_popup_team_effort'));
      if (popup.evaluate().isNotEmpty) break;
    }
    debugPrint('M4TOUR b_visible_ms=${sw.elapsedMilliseconds}');
    await waitFor(t, find.byKey(const Key('badge_popup_team_effort')));
    await shot(t, '06_badge_popup_team_effort_by_b');
    await waitFor(t, find.byKey(const Key('badge_popup_ok')));
    await t.tap(find.byKey(const Key('badge_popup_ok')));
    await t.pump(const Duration(milliseconds: 500));
    final after = t.widget<Text>(find.byKey(const Key('home_goal_count_name_response'))).data;
    expect(after, isNot(before));
    await shot(t, '07_home_updated_by_b');

    router.go('/records');
    await waitFor(t, find.textContaining('练习者：爸爸'));
    await shot(t, '08_records_show_b');

    router.push('/me/badges');
    await waitFor(t, find.byKey(const Key('badge_first_step_earned')));
    await shot(t, '09_badge_wall');

    // 5. "扑人"诊断 → 加入本周
    final issue = lib.issueById['jumping_on_people']!;
    final path = allDiagnosisPaths(issue)
        .firstWhere((p) => (diagnosisNext(issue, p) as DiagnosisOutcome).resultKey == 'greeting_jumping');
    router.go('/coach/diagnosis?issue=jumping_on_people');
    for (final i in path) {
      await waitFor(t, find.byKey(Key('diagnosis_option_$i')));
      await t.tap(find.byKey(Key('diagnosis_option_$i')));
      await t.pump(const Duration(milliseconds: 300));
    }
    await waitFor(t, find.byKey(const Key('diagnosis_result')));
    // 诊断完成即判定"对症下药"徽章
    await waitFor(t, find.byKey(const Key('badge_popup_first_diagnosis')));
    await shot(t, '10a_badge_popup_first_diagnosis');
    await t.tap(find.byKey(const Key('badge_popup_ok')));
    await t.pump(const Duration(milliseconds: 500));
    await t.scrollUntilVisible(find.byKey(const Key('diagnosis_add_this_week')), 300,
        scrollable: find.descendant(of: find.byKey(const Key('diagnosis_result')), matching: find.byType(Scrollable)).first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('diagnosis_add_this_week')));
    await waitFor(t, find.byKey(const Key('diagnosis_add_result')));
    await shot(t, '10_diagnosis_jumping_add_this_week');
    await t.tap(find.byKey(const Key('diagnosis_add_ok')));
    await t.pump(const Duration(milliseconds: 500));

    // 6. 养护页（10 周龄：第一针、早期驱虫已过期 → 待确认）
    router.go('/records?tab=care');
    await waitFor(t, find.byKey(const Key('care_disclaimer')));
    await waitFor(t, find.byKey(const Key('care_group_overdue')));
    await shot(t, '11_care_page');

    // 7. 技能树 Tab
    router.go('/skills');
    await waitFor(t, find.byKey(const Key('skill_tree_marker_intro')));
    await shot(t, '12_skill_tree');

    final sessions = await t.runAsync(() => SessionRepository(db).sessionsOf(o.dogId));
    expect(sessions!.length, 2);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    c.dispose();
    await db.close();
  });
}
