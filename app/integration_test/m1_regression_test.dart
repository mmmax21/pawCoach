import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:puppy_trainer/app.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/features/onboarding/onboarding_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Inject deterministic text, avoiding Android IME composing-text races.
  binding.testTextInput.register();
  testWidgets('M1 Android: boundaries, search, selection, preview and home',
      (t) async {
    for (final scenario in [
      (7, 5, 0),
      (8, 10, 3),
      (52, 15, 3),
      (53, 30, 4),
      (8, 5, 2)
    ]) {
      final (age, minutes, count) = scenario;
      final db = AppDatabase(NativeDatabase.memory());
      final c = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db), appEffectsEnabledProvider.overrideWithValue(false)]);
      await t.pumpWidget(UncontrolledProviderScope(
          container: c, child: const PuppyTrainerApp()));
      Future<void> until(Finder f) async {
        for (var i = 0; i < 200; i++) {
          await t.pump(const Duration(milliseconds: 50));
          if (f.evaluate().isNotEmpty) return;
        }
        fail('Timeout: $f');
      }

      Future<void> key(String k) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await t.pump(const Duration(milliseconds: 500));
        final f = find.byKey(Key(k));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pumpAndSettle();
      }

      await until(find.byKey(const Key('dog_name')));
      await key('birth_date');
      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pumpAndSettle();
      final birth = DateTime.now().subtract(Duration(days: age * 7));
      await t.enterText(
          find.descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(EditableText)),
          '${birth.month}/${birth.day}/${birth.year}');
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      if (age == 7) expect(find.textContaining('周龄不足 8 周'), findsOneWidget);
      if (age == 53) expect(find.textContaining('已超过 52 周'), findsOneWidget);
      expect(
          t
              .widget<FilledButton>(find.byKey(const Key('onboarding_next')))
              .onPressed,
          isNull);
      await t.drag(find.byType(ListView).first, const Offset(0, 1000));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('dog_name')), '一二三四五六七八九十一');
      await t.pumpAndSettle();
      expect(c.read(onboardingControllerProvider).dogName, '一二三四五六七八九十');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('sex')));
      await t.tap(find.text('公'));
      await t.pumpAndSettle();
      final query = find.byKey(const Key('breed_search'));
      for (final entry in [
        ('金毛', 'golden_retriever'),
        ('taidi', 'poodle'),
        ('corgi', 'corgi'),
        ('CoRgI', 'corgi'),
        ('zzzz', 'mixed_or_unknown')
      ]) {
        await t.ensureVisible(query);
        await t.enterText(query, entry.$1);
        await t.pumpAndSettle();
        final radios = t
            .widgetList<RadioListTile<String>>(
                find.byType(RadioListTile<String>))
            .toList();
        expect(radios.last.value, 'mixed_or_unknown');
        expect(find.byKey(Key('breed_${entry.$2}')), findsOneWidget);
        expect(t.widget<TextField>(query).controller!.text, entry.$1);
        if (entry.$1 == 'zzzz') {
          expect(radios.length, 1,
              reason:
                  'no match query=${t.widget<TextField>(query).controller!.text}');
        }
        if (entry.$1 == 'corgi') await key('breed_corgi');
      }
      expect(find.text('已选：柯基'), findsOneWidget);
      await t.enterText(query, '');
      await t.pumpAndSettle();
      expect(
          t
              .widgetList<RadioListTile<String>>(
                  find.byType(RadioListTile<String>))
              .length,
          31);
      await key('onboarding_next');
      for (final id in [
        'biting_hands',
        'potty_accidents',
        'chewing_furniture',
        'not_coming'
      ]) {
        await key('concern_$id');
      }
      expect(c.read(onboardingControllerProvider).concerns.length, 3);
      expect(c.read(onboardingControllerProvider).concerns,
          isNot(contains('not_coming')));
      expect(find.text('最多选 3 项'), findsOneWidget);
      await key('concern_biting_hands');
      await key('concern_not_coming');
      expect(c.read(onboardingControllerProvider).concerns,
          contains('not_coming'));
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await key('onboarding_next');
      await t.tap(find.text('$minutes 分钟'));
      await t.pumpAndSettle();
      await t.tap(find.text('1'));
      await t.pumpAndSettle();
      await t.tap(find.text('公寓'));
      await t.pumpAndSettle();
      await key('onboarding_next');
      await until(find.text('你的首周计划'));
      await t.pumpAndSettle();
      final goals = await db.select(db.planGoals).get();
      expect(goals.length, count);
      if (count > 0) {
        expect(goals.take(2).map((g) => g.skillId),
            ['marker_intro', 'name_response']);
      }
      if (age == 7) expect(find.textContaining('去狗档案调整信息'), findsOneWidget);
      await key('go_home');
      await until(find.byKey(const Key('home_dog_name')));
      await t.pumpAndSettle();
      expect(find.textContaining('$age 周'), findsOneWidget);
      if (age == 7) {
        expect(find.textContaining('去狗档案调整信息'), findsOneWidget);
      } else {
        final lib = await c.read(contentLibraryProvider.future);
        final mini = (await db.select(db.dailyMiniTasks).get()).single;
        // M2 起保底任务读 mini_script，script_part = 0（M2 简报第 7 节）。
        expect(mini.scriptPart, 0);
        final seconds = lib.skillById[mini.skillId]!.miniDurationSec;
        expect(seconds, lessThanOrEqualTo(300));
        expect(find.text('约 ${(seconds + 59) ~/ 60} 分钟'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
      debugPrint('ASTRA scenario age=$age minutes=$minutes goals=$count PASS');
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      c.dispose();
      await db.close();
    }
  });
}
