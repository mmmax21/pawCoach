import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mascot.dart';
import '../../core/app_nav.dart';
import '../../core/dog_avatar.dart';
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
        title: Text(_greeting(DateTime.now())),
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
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
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
              _Header(dogId: d.id, dogName: d.name, ageWeeks: ageWeeks, streakDays: streak),
              const SizedBox(height: AppSpace.lg),
              plan.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('读取计划失败：$e'),
                data: (v) => v == null
                    ? const EmptyState(title: '还没有计划')
                    : _PlanSection(
                        view: v,
                        streakDays: streak,
                        checkedInToday: ref.watch(checkedInTodayProvider).valueOrNull ?? false,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return '夜深了';
  if (h < 11) return '早上好';
  if (h < 14) return '中午好';
  if (h < 18) return '下午好';
  return '晚上好';
}

/// 顶部：狗的头像、名字、周龄，右侧连续打卡（琥珀色火苗）。
class _Header extends StatelessWidget {
  const _Header({
    required this.dogId,
    required this.dogName,
    required this.ageWeeks,
    required this.streakDays,
  });
  final String dogId;
  final String dogName;
  final int ageWeeks;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        DogAvatar(dogId: dogId, size: 56, editable: true),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dogName, key: const Key('home_dog_name'), style: t.titleLarge),
              const SizedBox(height: 2),
              Text(ageWeeksLabel(ageWeeks),
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        Tooltip(
          message: '连续打卡天数',
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
            decoration: BoxDecoration(
              color: streakDays > 0 ? AppColors.streakSoft : const Color(0xFFF5EEE8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department,
                    size: 22,
                    color: streakDays > 0 ? AppColors.streak : const Color(0xFFC9B8AA)),
                const SizedBox(width: 2),
                Text('$streakDays',
                    key: const Key('home_streak'),
                    style: t.titleLarge?.copyWith(height: 1.1)),
                const SizedBox(width: 2),
                Text('天', style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.view, required this.streakDays, this.checkedInToday = false});
  final PlanView view;
  final int streakDays;
  final bool checkedInToday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (view.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('按当前档案暂时没有可安排的技能，去狗档案调整信息。'),
              const SizedBox(height: AppSpace.sm),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mt != null) ...[
          _TodayHero(task: mt, streakDays: streakDays, checkedInToday: checkedInToday),
          const SizedBox(height: AppSpace.lg),
        ],
        if (progress.target > 0) ...[
          _WeekProgressCard(completed: progress.completed, target: progress.target, checkedInToday: checkedInToday),
          const SizedBox(height: AppSpace.xl),
        ],
        Row(
          children: [
            Text('本周目标', style: t.titleMedium),
            const SizedBox(width: AppSpace.sm),
            if (view.goals.isNotEmpty)
              Text('${view.goals.length} 个技能',
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        if (view.goals.isEmpty) const Text('本周没有目标技能'),
        ...view.goals.map((g) => _GoalTile(goal: g)),
      ],
    );
  }
}

/// 首页最显眼的一块：今天练什么（每日保底任务），一步进入。
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.task, required this.streakDays, this.checkedInToday = false});
  final MiniTaskView task;
  final int streakDays;
  final bool checkedInToday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    void open() => context.push('/skill/${task.skill.id}?part=${task.scriptPart}');
    const white70 = Color(0xB3FFFFFF);
    return Material(
      key: const Key('home_mini_task'),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE07B33), AppColors.primaryDeep],
          ),
        ),
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, size: 18, color: white70),
                    const SizedBox(width: 6),
                    Text('今日保底任务',
                        style: t.labelLarge?.copyWith(color: white70)),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(task.skill.name,
                    style: t.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: white70),
                    const SizedBox(width: 4),
                    Text('约 ${task.minutes} 分钟',
                        style: t.bodyMedium?.copyWith(color: white70)),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        checkedInToday
                            ? '今天已打卡，连续 $streakDays 天。想多练可以再来一次'
                            : streakDays > 0
                                ? '今天练完，连续打卡就到第 ${streakDays + 1} 天'
                                : '练完一次，就开始连续打卡',
                        style: t.bodySmall?.copyWith(color: white70),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    FilledButton.icon(
                      key: const Key('home_mini_task_start'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDeep,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: open,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('开始'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 本周进度：圆环 + 一句话。
class _WeekProgressCard extends StatelessWidget {
  const _WeekProgressCard({required this.completed, required this.target, this.checkedInToday = false});
  final int completed;
  final int target;
  final bool checkedInToday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ratio = completed / target;
    final left = target - completed;
    final hint = completed == 0
        ? (checkedInToday ? '保底任务不计入本周进度；练一次下面的目标技能，进度环就会亮起来' : '练一次下面的目标技能，进度环就会亮起来')
        : left <= 0
            ? '本周目标全部完成，做得好！'
            : '已练 $completed 次，还差 $left 次';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    key: const Key('home_week_progress'),
                    value: ratio,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: left <= 0 ? AppColors.success : AppColors.primary,
                  ),
                  Center(
                    child: Text('${(ratio * 100).round()}%',
                        style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('本周进度', style: t.titleMedium),
                      const Spacer(),
                      Text('$completed / $target',
                          key: const Key('home_week_progress_text'),
                          style: t.titleMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(hint, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});
  final GoalView goal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final g = goal;
    final done = g.completedSessions >= g.targetSessions;
    final ratio = g.targetSessions == 0 ? 0.0 : (g.completedSessions / g.targetSessions).clamp(0.0, 1.0);
    return Card(
      key: Key('home_goal_${g.skill.id}'),
      child: InkWell(
        onTap: () => context.push('/skill/${g.skill.id}?part=1'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: done
                    ? const CircleAvatar(
                        backgroundColor: AppColors.successSoft,
                        child: Icon(Icons.check_rounded, color: AppColors.success),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(value: ratio, strokeWidth: 4, strokeCap: StrokeCap.round),
                          const Center(
                            child: Icon(Icons.pets, size: 18, color: AppColors.primary),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.skill.name, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text('难度 ${difficultyStars(g.skill.difficulty)}',
                        style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text('${g.completedSessions} / ${g.targetSessions}',
                  key: Key('home_goal_count_${g.skill.id}'),
                  style: t.titleMedium?.copyWith(
                      color: done ? AppColors.success : AppColors.textSecondary)),
              const SizedBox(width: AppSpace.xs),
              const Icon(Icons.chevron_right, color: Color(0xFFC9B8AA)),
            ],
          ),
        ),
      ),
    );
  }
}
