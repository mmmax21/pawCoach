import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/training/training_page.dart';
import 'package:puppy_trainer/services/training_audio_service.dart';

/// 假音频后端：记录朗读与响片，不碰 audio_service / TTS。
class FakeAudio implements TrainingAudioPort {
  final spoken = <String>[];
  int clicks = 0;
  bool began = false;
  bool ended = false;

  @override
  Future<void> beginSession(
      {required String skillName,
      required TrainingRemoteControls controls}) async {
    began = true;
  }

  @override
  Future<void> endSession() async => ended = true;

  @override
  void showProgress({
    required String skillName,
    required int stepNumber,
    required int stepCount,
    required int remainingSec,
    required bool paused,
  }) {}

  @override
  Future<void> speakSequence(List<String> lines) async => spoken.addAll(lines);

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> playClicker() async => clicks++;
}

/// M2 简报第 11 节集成测试：跟练一次 → 记录页 → 首页完成次数 +1、连续天数 1。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('跟练一次 → 记录页 → 首页完成次数 +1、连续天数 1', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    final audio = FakeAudio();
    final c = ProviderContainer(overrides: [
      // M4：M1-M3 回归用例不启动同步调度与徽章弹窗，保持原有界面路径。
      appEffectsEnabledProvider.overrideWithValue(false),
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(audio),
    ]);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });

    // 直接建档（跳过建档 UI，M1 集成测试已覆盖）。
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    final now = DateTime.now();
    final birth = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 70));
    await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed_or_unknown',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const [],
        dailyMinutes: 10,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {},
      ),
      content: lib,
    );

    await t.pumpWidget(UncontrolledProviderScope(
        container: c, child: const PuppyTrainerApp()));
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      // 等计划区域加载完（目标计数出现），不只是等头部。
      if (find
          .byKey(const Key('home_goal_count_marker_intro'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('home_dog_name')), findsOneWidget);
    expect(find.byKey(const Key('home_streak')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('home_streak'))).data, '0');
    expect(t.widget<Text>(find.byKey(const Key('home_goal_count_marker_intro'))).data,
        '0 / 3');

    // 首页进入第一个目标 → 教程页 → 开始跟练。
    await t.tap(find.byKey(const Key('home_goal_marker_intro')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('start_training')));
    for (var i = 0; i < 50; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('training_instruction')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('training_cue')), findsOneWidget);
    expect(audio.began, isTrue);
    // 口令词不替换：朗读的是内容库原文。
    final steps = lib.skillById['marker_intro']!.stepsForPart(1);
    expect(audio.spoken.first, steps.first.instruction);

    // 按响片 2 次。
    await t.tap(find.byKey(const Key('training_clicker')));
    await t.tap(find.byKey(const Key('training_clicker')));
    await t.pump();
    expect(audio.clicks, 2);

    // 第 2 步跳过，其余手动下一步，直到结束。
    await t.tap(find.byKey(const Key('training_next')));
    await t.pump();
    await t.tap(find.byKey(const Key('training_skip')));
    await t.pump();
    for (var i = 0; i < steps.length; i++) {
      if (find.byKey(const Key('record_score')).evaluate().isNotEmpty) break;
      final next = find.byKey(const Key('training_next'));
      if (next.evaluate().isEmpty) break;
      await t.tap(next);
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.pumpAndSettle();

    // 记录页：评分、备注、显示是谁练的、跳过的步骤。
    expect(find.byKey(const Key('record_score')), findsOneWidget);
    expect(find.byKey(const Key('record_trainer')), findsOneWidget);
    expect(find.textContaining('我'), findsWidgets);
    expect(find.byKey(const Key('record_skipped')), findsOneWidget);
    expect(audio.ended, isTrue);
    // 未评分时不能保存。
    expect(t.widget<FilledButton>(find.byKey(const Key('record_save'))).onPressed,
        isNull);
    await t.tap(find.text('完全做到'));
    await t.pump();
    await t.enterText(find.byKey(const Key('record_note')), '今天很专心');
    await t.tap(find.byKey(const Key('record_save')));
    await t.pumpAndSettle();

    // 回首页：完成次数 +1，连续天数 1，进度条更新。
    expect(find.byKey(const Key('home_dog_name')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('home_streak'))).data, '1');
    expect(t.widget<Text>(find.byKey(const Key('home_goal_count_marker_intro'))).data,
        '1 / 3');
    expect(t.widget<Text>(find.byKey(const Key('home_week_progress_text'))).data,
        '1 / 9');

    final rows = await db.select(db.trainingSessions).get();
    expect(rows.length, 1);
    expect(rows.single.score, 'full');
    expect(rows.single.clickerCount, 2);
    expect(rows.single.noteText, contains('跳过步骤'));
    expect(rows.single.noteText, contains('今天很专心'));
  });

  testWidgets('中途退出：确认后丢弃，不写记录，不算打卡', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    final audio = FakeAudio();
    final c = ProviderContainer(overrides: [
      // M4：M1-M3 回归用例不启动同步调度与徽章弹窗，保持原有界面路径。
      appEffectsEnabledProvider.overrideWithValue(false),
      databaseProvider.overrideWithValue(db),
      trainingAudioPortProvider.overrideWithValue(audio),
    ]);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    final now = DateTime.now();
    final birth = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 70));
    await OnboardingRepository(db).complete(
      form: OnboardingResult(
        dogName: '豆豆',
        birthDate: birth,
        breedId: 'mixed_or_unknown',
        breedText: '混种 / 不确定',
        sex: Sex.male,
        homeDate: birth,
        concerns: const [],
        dailyMinutes: 10,
        trainerCount: 1,
        livingEnv: LivingEnv.apartment,
        masteredSkills: const {},
      ),
      content: lib,
    );
    await t.pumpWidget(UncontrolledProviderScope(
        container: c, child: const PuppyTrainerApp()));
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('home_mini_task')).evaluate().isNotEmpty) break;
    }
    // 从保底任务进入：part 0，读 mini_script。
    await t.tap(find.byKey(const Key('home_mini_task')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('start_training_mini')));
    for (var i = 0; i < 50; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('training_instruction')).evaluate().isNotEmpty) {
        break;
      }
    }
    // 保底技能由本周计划规则决定，不假定固定 skill id；以数据库生成的 mini task 为准。
    final miniRow = await db.select(db.dailyMiniTasks).getSingle();
    final skill = lib.skillById[miniRow.skillId]!;
    expect(t.widget<Text>(find.byKey(const Key('training_instruction'))).data,
        skill.miniScript.first.instruction);
    await t.tap(find.byKey(const Key('training_quit')));
    await t.pumpAndSettle();
    expect(find.text('现在退出会丢弃本次，不计入打卡。'), findsOneWidget);
    // 先点"继续练"：不退出。
    await t.tap(find.byKey(const Key('quit_cancel')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('training_instruction')), findsOneWidget);
    await t.tap(find.byKey(const Key('training_quit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quit_confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('home_dog_name')), findsOneWidget);
    expect(await db.select(db.trainingSessions).get(), isEmpty);
    expect(await db.select(db.streaks).get(), isEmpty);
    expect(t.widget<Text>(find.byKey(const Key('home_streak'))).data, '0');
  });
}
