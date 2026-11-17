/// 计划预览列表。建档预览页（ON-5）与周报页的"下周计划预览"共用（M2 简报第 9 节）。
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import 'plan_view.dart';

class PlanPreviewList extends StatelessWidget {
  const PlanPreviewList({super.key, required this.view, this.padding});
  final PlanView view;
  final EdgeInsetsGeometry? padding;

  String? _sourceLabel(String source) => switch (source) {
        'concern' => '针对困扰',
        'carryover' => '继续练',
        'downgrade' => '降一档',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      shrinkWrap: padding == EdgeInsets.zero,
      physics: padding == EdgeInsets.zero
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: padding ?? const EdgeInsets.all(16),
      children: [
        if (view.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('按当前档案暂时没有可安排的技能，去狗档案调整信息。'),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('empty_plan_profile'),
                    onPressed: () => context.push('/dog-profile'),
                    child: const Text('去狗档案'),
                  ),
                ],
              ),
            ),
          ),
        if (view.goals.isNotEmpty) ...[
          Text('本周目标', style: t.titleMedium),
          const SizedBox(height: 8),
          ...view.goals.map(
            (g) => Card(
              child: ListTile(
                title: Text(g.skill.name),
                subtitle: Text(
                    '${difficultyStars(g.skill.difficulty)} · 本周目标 ${g.targetSessions} 次'),
                trailing: _sourceLabel(g.source) == null
                    ? null
                    : Chip(label: Text(_sourceLabel(g.source)!)),
              ),
            ),
          ),
        ],
        if (view.miniTask != null) ...[
          const SizedBox(height: 16),
          Text('每日保底任务', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(view.miniTask!.skill.name),
              subtitle: Text('约 ${view.miniTask!.minutes} 分钟'),
            ),
          ),
        ],
      ],
    );
  }
}
