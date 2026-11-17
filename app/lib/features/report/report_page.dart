/// 周报页（WP-5）：评分汇总表、打卡天数、comment、下周计划预览。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/repositories/household_repository.dart' show displayNickname;
import '../../domain/streak.dart' show localDateOf;

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../../domain/weekly_report.dart';
import '../home/home_providers.dart';
import '../home/plan_preview_list.dart';
import '../home/plan_view.dart';

class ReportStrings {
  const ReportStrings._();
  static const title = '上周周报';
  static const checkinDays = '打卡天数';
  static const sessions = '练习次数';
  static const miniDays = '保底任务天数';
  static const tableTitle = '各目标评分';
  static const comment = '一句话点评';
  static const nextPlan = '下周计划预览';
  static const goHome = '回首页';
  static const mastered = '已掌握';
  static const downgrade = '下周降一档';
  static const carryover = '下周继续练';
}

String outcomeLabel(GoalOutcome o) => switch (o) {
      GoalOutcome.mastered => ReportStrings.mastered,
      GoalOutcome.downgrade => ReportStrings.downgrade,
      GoalOutcome.carryover => ReportStrings.carryover,
    };

final reportProvider =
    FutureProvider.family<WeeklyReport?, String>((ref, id) async {
  return ref.watch(reportRepositoryProvider).byId(id);
});

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key, required this.reportId});
  final String reportId;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  @override
  void initState() {
    super.initState();
    // 打开即视为已读，首页入口消失。
    Future.microtask(() async {
      await ref.read(reportRepositoryProvider).markRead(widget.reportId,
          now: ref.read(clockProvider)());
      ref.invalidate(unreadReportProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportProvider(widget.reportId));
    final content = ref.watch(contentLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(ReportStrings.title)),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取周报失败：$e')),
        data: (r) {
          if (r == null) return const Center(child: Text('周报不存在'));
          final summary = WeeklySummary.fromJson(
              (jsonDecode(r.summaryJson) as Map).cast<String, Object?>());
          final lib = content.valueOrNull;
          return _ReportBody(
            summary: summary,
            lib: lib,
            nextPlanId: r.nextPlanId,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('report_home'),
            onPressed: () => context.go('/home'),
            child: const Text(ReportStrings.goHome),
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({
    required this.summary,
    required this.lib,
    required this.nextPlanId,
  });
  final WeeklySummary summary;
  final ContentLibrary? lib;
  final String? nextPlanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    String name(String id) => lib?.skillById[id]?.name ?? id;
    String two(int n) => n.toString().padLeft(2, '0');
    final ws = summary.weekStart;
    final we = ws.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${ws.year}-${two(ws.month)}-${two(ws.day)} ~ '
            '${we.year}-${two(we.month)}-${two(we.day)}',
            style: t.labelLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
                keyName: 'report_checkin_days',
                label: ReportStrings.checkinDays,
                value: '${summary.checkinDays}'),
            _Stat(
                keyName: 'report_sessions',
                label: ReportStrings.sessions,
                value: '${summary.sessionsTotal}'),
            _Stat(
                keyName: 'report_mini_days',
                label: ReportStrings.miniDays,
                value: '${summary.miniTaskDays}'),
          ],
        ),
        _MemberBreakdown(weekStart: summary.weekStart),
        const SizedBox(height: 16),
        Text(ReportStrings.tableTitle, style: t.titleMedium),
        const SizedBox(height: 8),
        if (summary.goals.isEmpty) const Text('上周没有目标技能'),
        for (final g in summary.goals)
          Card(
            key: Key('report_goal_${g.skillId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(name(g.skillId), style: t.titleSmall)),
                      Text('${g.completed} / ${g.target}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('完全做到 ${g.full} · 部分做到 ${g.partial} · 没做到 ${g.none}'),
                  const SizedBox(height: 4),
                  Text(outcomeLabel(g.outcome),
                      key: Key('report_outcome_${g.skillId}'),
                      style: t.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(ReportStrings.comment, style: t.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(summary.comment, key: const Key('report_comment')),
          ),
        ),
        const SizedBox(height: 16),
        Text(ReportStrings.nextPlan, style: t.titleMedium),
        const SizedBox(height: 8),
        if (nextPlanId == null)
          const Text('下周计划尚未生成')
        else
          ref.watch(planViewProvider(nextPlanId!)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('读取下周计划失败：$e'),
                data: (v) => v == null
                    ? const Text('下周计划不存在')
                    : PlanPreviewList(view: v, padding: EdgeInsets.zero),
              ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.keyName, required this.label, required this.value});
  final String keyName;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, key: Key(keyName), style: t.headlineMedium),
          Text(label, style: t.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}


/// FM-5：周报显示本周各成员练习次数（按昵称）。
class _MemberBreakdown extends ConsumerWidget {
  const _MemberBreakdown({required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(nicknamesProvider).valueOrNull ?? const {};
    final me = ref.watch(currentUserIdProvider).valueOrNull;
    final dog = ref.watch(currentDogProvider).valueOrNull;
    if (dog == null) return const SizedBox.shrink();
    return FutureBuilder(
      future: ref.read(sessionRepositoryProvider).sessionsOf(dog.id),
      builder: (_, snap) {
        final start = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
        final end = start.add(const Duration(days: 7));
        final count = <String, int>{};
        for (final s in snap.data ?? const []) {
          final d = localDateOf(DateTime.parse(s.startedAt));
          if (d.isBefore(start) || !d.isBefore(end)) continue;
          count[s.userId] = (count[s.userId] ?? 0) + 1;
        }
        if (count.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '本周练习：${count.entries.map((e) => '${displayNickname(names, e.key, meId: me)} ${e.value} 次').join('、')}',
            key: const Key('report_members'),
          ),
        );
      },
    );
  }
}
