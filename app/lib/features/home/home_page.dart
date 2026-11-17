import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_nav.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models.dart';
import 'home_providers.dart';
import 'plan_view.dart';

/// 首页（WP-3 / ST-1）：完成次数、连续打卡天数、本周进度条、保底任务，均为真实数据。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dog = ref.watch(currentDogProvider);
    final plan = ref.watch(activePlanViewProvider);
    final streak = ref.watch(streakDaysProvider).valueOrNull ?? 0;
    final unread = ref.watch(unreadReportProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            key: const Key('home_reminder'),
            tooltip: '提醒设置',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/settings/reminder'),
          ),
          IconButton(
            key: const Key('home_profile'),
            tooltip: '狗档案',
            icon: const Icon(Icons.pets),
            onPressed: () => context.push('/dog-profile'),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.home),
      body: dog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取档案失败：$e')),
        data: (d) {
          if (d == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/onboarding');
            });
            return const SizedBox.shrink();
          }
          final ageWeeks =
              ageWeeksOn(parseDateOnly(d.birthDate), DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (unread != null) ...[
                Card(
                  key: const Key('home_report_banner'),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.assessment_outlined),
                    title: const Text('上周周报已生成'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/report/${unread.id}'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Header(dogName: d.name, ageWeeks: ageWeeks, streakDays: streak),
              const SizedBox(height: 16),
              plan.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('读取计划失败：$e'),
                data: (v) => v == null
                    ? const Text('还没有计划')
                    : _PlanSection(view: v),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dogName,
    required this.ageWeeks,
    required this.streakDays,
  });
  final String dogName;
  final int ageWeeks;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.pets, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dogName, key: const Key('home_dog_name'), style: t.titleLarge),
                  Text(ageWeeksLabel(ageWeeks), style: t.bodyMedium),
                ],
              ),
            ),
            Column(
              children: [
                Text('$streakDays',
                    key: const Key('home_streak'), style: t.headlineSmall),
                Text('连续天数', style: t.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.view});
  final PlanView view;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (view.isEmpty) {
      return Card(
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
      );
    }
    final mt = view.miniTask;
    final progress = weekProgress(view);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress.target > 0) ...[
          Row(
            children: [
              Text('本周进度', style: t.titleMedium),
              const Spacer(),
              Text('${progress.completed} / ${progress.target}',
                  key: const Key('home_week_progress_text'),
                  style: t.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const Key('home_week_progress'),
            value: progress.completed / progress.target,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
        ],
        if (mt != null) ...[
          Text('今日保底任务', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            key: const Key('home_mini_task'),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(mt.skill.name),
              subtitle: Text('约 ${mt.minutes} 分钟'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/skill/${mt.skill.id}?part=${mt.scriptPart}'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('本周目标', style: t.titleMedium),
        const SizedBox(height: 8),
        if (view.goals.isEmpty) const Text('本周没有目标技能'),
        ...view.goals.map(
          (g) => Card(
            key: Key('home_goal_${g.skill.id}'),
            child: ListTile(
              title: Text(g.skill.name),
              subtitle: Text(difficultyStars(g.skill.difficulty)),
              trailing: Text('${g.completedSessions} / ${g.targetSessions}',
                  key: Key('home_goal_count_${g.skill.id}'),
                  style: t.titleMedium),
              onTap: () => context.push('/skill/${g.skill.id}?part=1'),
            ),
          ),
        ),
      ],
    );
  }
}
