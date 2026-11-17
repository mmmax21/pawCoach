// Astra M4: exercise the documented notification/lifecycle hooks on Android.
// Screenshots are captured by tests/regression/.../run_carryover.py at M4SHOT.
import 'package:drift/native.dart';
import 'package:puppy_trainer/services/reminder_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/training/training_controller.dart';
import 'package:puppy_trainer/features/training/training_page.dart';
import 'package:puppy_trainer/features/training/training_runner.dart';
import 'm2_training_test.dart' show FakeAudio;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Astra M4 M3 carryovers: notification, remote controls, lifecycle, keyboard',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    var clock = DateTime(2026, 11, 17, 12);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => clock),
      trainingAudioPortProvider.overrideWithValue(FakeAudio()),
      appEffectsEnabledProvider.overrideWithValue(false),
    ]);
    final lib = await c.read(contentLibraryProvider.future);
    await HouseholdRepository(db).ensureLocalUser();
    await OnboardingRepository(db).complete(
        form: OnboardingResult(
          dogName: '豆豆',
          birthDate: clock.subtract(const Duration(days: 70)),
          breedId: 'mixed_or_unknown',
          breedText: '混种 / 不确定',
          sex: Sex.male,
          homeDate: clock.subtract(const Duration(days: 70)),
          concerns: const [],
          dailyMinutes: 10,
          trainerCount: 1,
          livingEnv: LivingEnv.apartment,
          masteredSkills: const {},
        ),
        content: lib,
        now: clock);
    late WidgetRef appRef;
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: Consumer(builder: (context, ref, _) {
          appRef = ref;
          return const PuppyTrainerApp();
        })));
    Future<void> waitFor(Finder f) async {
      for (var i = 0; i < 400; i++) {
        await t.pump(const Duration(milliseconds: 50));
        if (f.evaluate().isNotEmpty) return;
      }
      throw TestFailure('timeout waiting for $f');
    }

    Future<void> shot(String name) async {
      await t.pump();
      debugPrint('M4SHOT $name');
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull, reason: name);
    }

    final router = c.read(routerProvider);
    await waitFor(find.byKey(const Key('home_goal_count_marker_intro')));
    router.go('/me');
    await waitFor(find.byKey(const Key('me_family')));
    onReminderNotificationTap(appRef);
    await waitFor(find.byKey(const Key('home_goal_count_marker_intro')));
    expect(router.routeInformationProvider.value.uri.path, '/home');
    await shot('carry_01_notification_home');
    router.push('/training/marker_intro/1');
    await waitFor(find.byKey(const Key('training_remaining')));
    final r = TrainingRunner.active.value!;
    expect(r.machine.phase, TrainingPhase.running);
    r.remoteControls.onPauseResume();
    final paused = r.machine.remainingMs();
    clock = clock.add(const Duration(seconds: 5));
    r.tick();
    expect(r.machine.remainingMs(), paused);
    expect(r.machine.phase, TrainingPhase.paused);
    await shot('carry_02_remote_paused_5s');
    r.remoteControls.onPauseResume();
    clock = clock.add(const Duration(seconds: 2));
    r.tick();
    expect(r.machine.remainingMs(), paused - 2000);
    await shot('carry_03_remote_resumed');
    final step = r.machine.stepIndex;
    r.remoteControls.onNext();
    expect(r.machine.stepIndex, step + 1);
    expect(r.machine.phase, TrainingPhase.running);
    await shot('carry_04_remote_next');
    for (final name in ['lock', 'background']) {
      final before = r.machine.remainingMs();
      final beforeStep = r.machine.stepIndex;
      await t.tap(find.byKey(const Key('training_ask_coach')));
      await waitFor(find.byKey(const Key('chat_input')));
      expect(r.machine.phase, TrainingPhase.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = clock.add(const Duration(seconds: 10));
      expect(r.machine.remainingMs(), before);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      router.pop();
      await waitFor(find.byKey(const Key('training_remaining')));
      expect(r.machine.phase, TrainingPhase.running);
      expect(r.machine.stepIndex, beforeStep);
      expect(r.machine.remainingMs(), before);
      clock = clock.add(const Duration(seconds: 1));
      r.tick();
      expect(r.machine.remainingMs(), before - 1000);
      debugPrint(
          'ASTRA $name paused_10s=$before resumed=${r.machine.remainingMs()}');
      await shot('carry_05_${name}_return');
    }
    await t.tap(find.byKey(const Key('training_ask_coach')));
    await waitFor(find.byKey(const Key('chat_input')));
    await t.showKeyboard(find.byType(TextField));
    await t.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 100 && t.view.viewInsets.bottom == 0; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(t.view.viewInsets.bottom, greaterThan(0),
        reason: 'Android native keyboard must be visible');
    await shot('carry_06_keyboard_open');
    router.pop();
    await waitFor(find.byKey(const Key('training_remaining')));
    await shot('carry_07_keyboard_return_no_overflow');
    expect(t.takeException(), isNull);
    expect(r.machine.phase, TrainingPhase.running);
    // Verify real Android care schedules while the test APK is still installed.
    await LocalReminderNotifier().init();
    final dog = (await c.read(dogRepositoryProvider).currentDog())!;
    await c.read(careRepositoryProvider).syncDefaults(dog, lib.careCalendar);
    final plans = await c.read(careReminderServiceProvider).refresh(dog.id);
    expect(plans, isNotEmpty);
    for (final p in plans) {
      expect(p.id, inInclusiveRange(2000, 2999));
      expect(p.at.isAfter(clock), isTrue);
      debugPrint('ASTRA_CARE id=${p.id} at=${p.at.toIso8601String()}');
    }
    router.go('/records?tab=care');
    await waitFor(find.byKey(const Key('care_disclaimer')));
    await shot('carry_08_care_scheduled');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    c.dispose();
    await db.close();
  });
}
