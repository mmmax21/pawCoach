/// M4 批次 B 设备实测截图：由 server/m4_device_tour.py --test 本文件 --out m4b_screenshots 驱动。
/// 每完成一项批次 B 功能，在这里加对应的截图步骤。
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
import 'package:puppy_trainer/data/repositories/reminder_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/data/repositories/session_repository.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/domain/diagnosis.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/shell/app_effects.dart';
import 'package:puppy_trainer/domain/nudges.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  /// 同步重算后可能弹出徽章祝贺，先逐个点掉（等最多 [seconds] 秒没有新弹窗）。
  Future<void> dismissBadges(WidgetTester t, {int seconds = 3}) async {
    var quiet = 0;
    while (quiet < seconds * 10) {
      await t.pump(const Duration(milliseconds: 100));
      final ok = find.byKey(const Key('badge_popup_ok'));
      if (ok.evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(ok);
        await t.pump(const Duration(milliseconds: 400));
        quiet = 0;
      } else {
        quiet++;
      }
    }
  }

  testWidgets('M4 批次 B 设备实测', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(FakeAudio()),
      appEffectsEnabledProvider.overrideWithValue(false), // 不开调度器，副作用在需要时手动触发
    ]);
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    await (db.update(db.users)..where((u) => u.id.equals('local_user'))).write(const UsersCompanion(nickname: Value('妈妈')));
    final now = DateTime.now();
    final birth = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 98)); // 14 周
    final onb = await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed_or_unknown',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const ['jumping_on_people'],
        dailyMinutes: 15,
        trainerCount: 2,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {'marker_intro', 'name_response', 'lure_follow', 'potty_training'},
      ),
      content: lib,
    );
    for (final id in ['sit', 'crate_intro']) {
      await (db.update(db.dogSkillStatuses)..where((s) => s.skillId.equals(id)))
          .write(const DogSkillStatusesCompanion(status: Value('in_progress')));
    }
    final dogId = onb.dogId;
    // AI-5 受每日提醒开关控制（Fable 2026-11-17 裁定），设备实测先打开。
    await ReminderRepository(db).save(dogId, const ReminderConfig(enabled: true, hour: 19, minute: 0));
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const PuppyTrainerApp()));
    await waitFor(t, find.byKey(const Key('nav_skills')));
    final router = c.read(routerProvider);

    // ST-3 技能树
    router.go('/skills');
    await waitFor(t, find.byKey(const Key('skill_tree_canvas')));
    await shot(t, 'b01_skill_tree');
    await t.tap(find.byKey(const Key('skill_tree_sit')));
    await waitFor(t, find.byKey(const Key('nav_skills')).hitTestable(), seconds: 2).catchError((_) {});
    await shot(t, 'b02_skill_tree_tap_sit');
    router.go('/skills');
    await t.pump(const Duration(milliseconds: 500));

    // FM-4：建家上传 → B（API 身份）加入 → 创建者在家庭成员页移除 B
    router.go('/me');
    await waitFor(t, find.byKey(const Key('me_family')));
    await t.tap(find.byKey(const Key('me_family')));
    await waitFor(t, find.byKey(const Key('invite_code')));
    final hh = await t.runAsync(() => db.select(db.households).getSingle());
    await t.runAsync(() => DioSyncApi().join(bToken, hh!.inviteCode!, '爸爸'));
    await t.runAsync(() => c.read(httpSyncServiceProvider).pull());
    await dismissBadges(t);
    await waitFor(t, find.byKey(const Key('member_remove_$bUser')));
    await shot(t, 'b03_family_remove_button');
    await t.tap(find.byKey(const Key('member_remove_$bUser')));
    await waitFor(t, find.byKey(const Key('member_remove_confirm')));
    await shot(t, 'b04_family_remove_confirm');
    await t.tap(find.byKey(const Key('member_remove_confirm')));
    for (var i = 0; i < 200 && find.byKey(const Key('member_remove_$bUser')).evaluate().isNotEmpty; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('member_remove_$bUser')), findsNothing);
    final bPull = await t.runAsync(() async {
      try {
        await DioSyncApi().pull(bToken, hh!.id, 0);
        return 'ok';
      } on SyncException catch (e) {
        return '${e.status}';
      }
    });
    expect(bPull, '403');
    await shot(t, 'b05_family_after_remove');

    // M3-D6：诊断结果页顶部"不是这个问题？"
    final issue = lib.issueById['jumping_on_people']!;
    router.go('/coach/diagnosis?issue=${issue.id}');
    for (final i in allDiagnosisPaths(issue).first) {
      await waitFor(t, find.byKey(Key('diagnosis_option_$i')));
      await t.tap(find.byKey(Key('diagnosis_option_$i')));
      await t.pump(const Duration(milliseconds: 300));
    }
    await waitFor(t, find.byKey(const Key('diagnosis_not_this')));
    await shot(t, 'b06_diagnosis_not_this');
    await t.tap(find.byKey(const Key('diagnosis_not_this')));
    await waitFor(t, find.byKey(Key('issue_${lib.issues.first.id}')));
    await shot(t, 'b07_back_to_issue_list');

    // 常见错误折叠
    router.go('/coach/chat?skill=sit');
    await waitFor(t, find.byKey(const Key('chat_input')));
    await t.enterText(find.byKey(const Key('chat_input')), '坐下总是做不好');
    await t.tap(find.byKey(const Key('chat_send')));
    await waitFor(t, find.byKey(const Key('answer_mistakes_fold')));
    await t.ensureVisible(find.byKey(const Key('answer_mistakes_fold')));
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'b08_mistakes_folded');
    await t.tap(find.textContaining('【常见错误】（'));
    await t.pump(const Duration(milliseconds: 600));
    await t.ensureVisible(find.text(lib.skillById['sit']!.tutorial.commonMistakes.last));
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'b09_mistakes_expanded');
    FocusManager.instance.primaryFocus?.unfocus();

    // RC-5 + AI-5：坐下连续两次"没做到"（经记录页 UI）→ 记录两种视图 → 通知栏出现降级建议
    final me = (await t.runAsync(() => currentUserId(db)))!;
    for (var k = 0; k < 2; k++) {
      router.push('/record',
          extra: SessionDraft(
            dogId: dogId,
            userId: me,
            skillId: 'sit',
            scriptPart: 1,
            startedAt: DateTime.now().subtract(Duration(minutes: 10 - k)),
            endedAt: DateTime.now(),
            durationSec: 180,
            clickerCount: 0,
            skippedSteps: const [],
          ));
      await waitFor(t, find.byKey(const Key('record_score')));
      await t.tap(find.text('没做到'));
      await t.pump();
      await t.tap(find.byKey(const Key('record_save')));
      await waitFor(t, find.byKey(const Key('nav_home')));
      await t.pump(const Duration(milliseconds: 500));
    }
    await t.runAsync(() => c.read(appEffectsProvider).runFor({'training_sessions'}));
    await dismissBadges(t);
    router.go('/records');
    await waitFor(t, find.byKey(const Key('sessions_view')));
    await shot(t, 'b10_records_by_date');
    await t.tap(find.text('按技能'));
    await t.pump(const Duration(milliseconds: 500));
    await shot(t, 'b11_records_by_skill');
    // 降级建议在发现后约 5 秒推送（inexact 闹钟，系统可能合并延后）：打印待发队列，等它真正出现在通知栏
    final plugin = FlutterLocalNotificationsPlugin();
    final pending = await t.runAsync(() => plugin.pendingNotificationRequests());
    for (final r in pending!) {
      debugPrint('M4TOUR pending id=${r.id} title=${r.title}');
    }
    expect(pending.any((r) => r.id == nudgeRestartId), isTrue, reason: '连续 3 天无打卡提醒应已预排');
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    var shown = false;
    for (var i = 0; i < 120 && !shown; i++) {
      await t.pump(const Duration(seconds: 1));
      final active = await t.runAsync(() => android.getActiveNotifications());
      shown = active!.any((n) => (n.id ?? 0) >= nudgeDowngradeIdBase && (n.id ?? 0) <= nudgeIdMax);
    }
    debugPrint('M4TOUR nudge_shown=$shown');
    expect(shown, isTrue, reason: 'AI-5 降级建议应出现在通知栏');
    debugPrint('M4CMD expand');
    await t.pump(const Duration(seconds: 2));
    await shot(t, 'b12_nudge_notification');
    debugPrint('M4CMD collapse');
    await t.pump(const Duration(seconds: 1));

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    c.dispose();
    await db.close();
  });
}
