/// M4 简报第 10 节第 5 条：双端可见性（PRD 第 6 节验收口径第 5 条）。
///
/// 由 server/e2e_visibility.py 驱动（起真实 server/、注册成员 B、轮询 pull、计时），不要单独跑。
/// 本文件是设备 A：真实 App + 真实同步（DioSyncApi → SYNC_BASE_URL），内存数据库。
///   方向 1：A 在记录页点"完全做到 → 保存"打卡，B（主机进程）轮询 pull 直到拉到这条记录；
///   方向 2：B 用 API 推一条训练记录，A 的首页目标次数在 10 秒内变化。
/// 输出 E2E_* 行供脚本计时。B 的 token 由脚本经 --dart-define=E2E_B_TOKEN 传入，不打印；
/// 邀请码只在本进程内使用，不打印。
library;

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
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/training/training_page.dart';

import 'm2_training_test.dart' show FakeAudio;

const bToken = String.fromEnvironment('E2E_B_TOKEN');

void e2e(String line) => debugPrint('E2E_$line');
int nowMs() => DateTime.now().millisecondsSinceEpoch;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester t, bool Function() ok, {Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 50));
      if (ok()) return;
    }
    throw TestFailure('等待超时');
  }

  testWidgets('双端可见性：A 打卡 → B 拉到；B 推送 → A 首页更新', (t) async {
    expect(bToken, isNotEmpty, reason: '由 server/e2e_visibility.py 传入');
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(FakeAudio()),
      appEffectsEnabledProvider.overrideWithValue(true),
    ]);
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    final now = DateTime.now();
    final birth = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 70));
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
    await waitFor(t, () => find.byKey(const Key('home_goal_count_marker_intro')).evaluate().isNotEmpty);

    // 建家上传（调度器也会做，这里显式等它完成），B 用邀请码加入。
    final sync = c.read(httpSyncServiceProvider);
    await t.runAsync(() => sync.ensureHouseholdUploaded());
    final hh = await t.runAsync(() => db.select(db.households).getSingle());
    final hid = await t.runAsync(() => DioSyncApi().join(bToken, hh!.inviteCode!, '爸爸'));
    expect(hid, hh!.id);
    e2e('JOINED household=$hid dog=${o.dogId}');
    // 给主机进程开始轮询留一点时间
    await t.pump(const Duration(seconds: 2));

    // ---- 方向 1：A 在记录页打卡 ----
    final me = await t.runAsync(() => currentUserId(db));
    final started = DateTime.now().subtract(const Duration(minutes: 3));
    c.read(routerProvider).push('/record',
        extra: SessionDraft(
          dogId: o.dogId,
          userId: me!,
          skillId: 'marker_intro',
          scriptPart: 1,
          startedAt: started,
          endedAt: DateTime.now(),
          durationSec: 180,
          clickerCount: 3,
          skippedSteps: const [],
        ));
    await waitFor(t, () => find.byKey(const Key('record_score')).evaluate().isNotEmpty);
    await t.tap(find.text('完全做到'));
    await t.pump();
    await t.tap(find.byKey(const Key('record_save')));
    final tapAt = nowMs();
    await waitFor(t, () => find.byKey(const Key('home_goal_count_marker_intro')).evaluate().isNotEmpty);
    final sessions = await t.runAsync(() => SessionRepository(db).sessionsOf(o.dogId));
    e2e('CHECKIN session=${sessions!.single.id} tap_ms=$tapAt');

    // ---- 方向 2：等 B 推送，A 首页 name_response 目标次数变化 ----
    String count(String skill) =>
        (t.widget<Text>(find.byKey(Key('home_goal_count_$skill'))).data ?? '');
    final before = count('name_response');
    e2e('WAIT_B skill=name_response before="$before"');
    await waitFor(t, () => count('name_response') != before, timeout: const Duration(seconds: 60));
    e2e('SEEN_B at_ms=${nowMs()} after="${count('name_response')}"');

    // 同步过来的记录在记录页显示 B 的昵称
    c.read(routerProvider).go('/records');
    await waitFor(t, () => find.textContaining('练习者：爸爸').evaluate().isNotEmpty);
    e2e('RECORDS_SHOW_B ok');

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    c.dispose();
    await db.close();
  });
}
