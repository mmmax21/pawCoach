import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import 'onboarding_controller.dart';

/// 第二步：当前困扰，最多 3 项，可跳过（ON-3）。
class Step2Concerns extends ConsumerWidget {
  const Step2Concerns({super.key, required this.issues});
  final List<Issue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('最近最让你头疼的是什么？最多选 3 项，也可以跳过。',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text('已选 ${form.concerns.length} / 3',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        ...issues.map(
          (i) => CheckboxListTile(
            key: Key('concern_${i.id}'),
            title: Text(i.name),
            subtitle: Text(typicalAgeLabel(i.typicalAgeWeeks)),
            value: form.concerns.contains(i.id),
            onChanged: (_) {
              final ok = ctrl.toggleConcern(i.id);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('最多选 3 项')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
