import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import 'onboarding_controller.dart';

/// 第三步：主人条件 + 已掌握技能（ON-4）。
class Step3Owner extends ConsumerWidget {
  const Step3Owner({super.key, required this.skills});
  final List<Skill> skills;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final sorted = [...skills]..sort((a, b) {
        final c = a.minAgeWeeks.compareTo(b.minAgeWeeks);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _title(context, '每天可投入'),
        SegmentedButton<int>(
          key: const Key('daily_minutes'),
          segments: const [
            ButtonSegment(value: 5, label: Text('5 分钟')),
            ButtonSegment(value: 10, label: Text('10 分钟')),
            ButtonSegment(value: 15, label: Text('15 分钟')),
            ButtonSegment(value: 30, label: Text('30 分钟')),
          ],
          selected: form.dailyMinutes == null ? {} : {form.dailyMinutes!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) ctrl.setDailyMinutes(s.first);
          },
        ),
        const SizedBox(height: 16),
        _title(context, '家里几个人会训'),
        SegmentedButton<int>(
          key: const Key('trainer_count'),
          segments: const [
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3+')),
          ],
          selected: form.trainerCount == null ? {} : {form.trainerCount!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) ctrl.setTrainerCount(s.first);
          },
        ),
        const SizedBox(height: 16),
        _title(context, '居住环境'),
        SegmentedButton<LivingEnv>(
          key: const Key('living_env'),
          segments: const [
            ButtonSegment(value: LivingEnv.apartment, label: Text('公寓')),
            ButtonSegment(value: LivingEnv.houseWithYard, label: Text('带院子')),
          ],
          selected: form.livingEnv == null ? {} : {form.livingEnv!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) ctrl.setLivingEnv(s.first);
          },
        ),
        const SizedBox(height: 16),
        _title(context, '已经会的技能（没有就不选）'),
        ...sorted.map(
          (s) => CheckboxListTile(
            key: Key('mastered_${s.id}'),
            dense: true,
            title: Text(s.name),
            subtitle: Text('${s.minAgeWeeks} 周起 · ${difficultyStars(s.difficulty)}'),
            value: form.masteredSkills.contains(s.id),
            onChanged: (_) => ctrl.toggleMastered(s.id),
          ),
        ),
        const SizedBox(height: 16),
        _title(context, '你的昵称（家人在记录里看到的名字，可选）'),
        TextField(
          key: const Key('onboarding_nickname'),
          maxLength: 20,
          decoration: const InputDecoration(hintText: '例如：妈妈'),
          onChanged: (v) => ref.read(onboardingNicknameProvider.notifier).state = v,
        ),
      ],
    );
  }

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );
}
