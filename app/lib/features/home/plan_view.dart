/// 首页 / 计划预览共用的"本周计划视图"数据。
library;

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../../services/weekly_job.dart';

class GoalView {
  const GoalView({
    required this.skill,
    required this.targetSessions,
    required this.completedSessions,
    required this.source,
  });
  final Skill skill;
  final int targetSessions;
  final int completedSessions;
  final String source;
}

class MiniTaskView {
  const MiniTaskView({required this.skill, required this.scriptPart});
  final Skill skill;
  final int scriptPart;
  /// 保底任务（script_part == 0）按 mini_script 求和（M2 简报第 7 节）。
  int get minutes => skill.partDurationMinutes(scriptPart);
}

class PlanView {
  const PlanView({
    required this.plan,
    required this.goals,
    required this.miniTask,
  });
  final WeeklyPlan plan;
  final List<GoalView> goals;
  final MiniTaskView? miniTask;

  /// 目标与保底都空：首页提示"去狗档案调整信息"。
  bool get isEmpty => goals.isEmpty && miniTask == null;
}

/// 计划视图。监听 weekly_plans / plan_goals / daily_mini_tasks 三张表，
/// 任何写入（打卡 +1、档案重新生成、周报生成下周计划）都会让界面自动刷新，
/// 不依赖各个写入点手动 invalidate。
final planViewProvider =
    StreamProvider.family<PlanView?, String>((ref, planId) async* {
  final content = await ref.watch(contentLibraryProvider.future);
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(planRepositoryProvider);

  Future<PlanView?> load() async {
    final plan = await (db.select(db.weeklyPlans)
          ..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null) return null;
    final goals = await repo.goals(planId);
    final mini = await repo.miniTask(planId);
    return PlanView(
      plan: plan,
      goals: [
        for (final g in goals)
          if (content.skillById[g.skillId] case final s?)
            GoalView(
              skill: s,
              targetSessions: g.targetSessions,
              completedSessions: g.completedSessions,
              source: g.source,
            ),
      ],
      miniTask: mini == null
          ? null
          : switch (content.skillById[mini.skillId]) {
              final s? => MiniTaskView(skill: s, scriptPart: mini.scriptPart),
              null => null,
            },
    );
  }

  yield await load();
  // 三张表任一变化就重读。
  final changes = db.tableUpdates(TableUpdateQuery.onAllTables(
      [db.weeklyPlans, db.planGoals, db.dailyMiniTasks]));
  await for (final _ in changes) {
    yield await load();
  }
});

/// 冷启动 / 回前台补跑：活动计划早于本周（或周日 21:00 已过）则生成周报与下周计划。
/// 与 workmanager 的周日任务调用同一个幂等函数（services/weekly_job.dart）。
final weeklyCatchUpProvider = FutureProvider<List<String>>((ref) async {
  final content = await ref.watch(contentLibraryProvider.future);
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) return const [];
  return runWeeklyReportJob(
    db: ref.watch(databaseProvider),
    content: content,
    now: ref.read(clockProvider)(),
  );
});

/// 当前狗的活动计划 id。活动计划换了（周报生成、重新生成）会自动跟着变。
final activePlanIdProvider = StreamProvider<String?>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  // 先补跑再读计划，跨周后首页直接显示新一周。
  await ref.watch(weeklyCatchUpProvider.future);
  if (dog == null) {
    yield null;
    return;
  }
  final repo = ref.watch(planRepositoryProvider);
  await for (final plan in repo.watchActivePlan(dog.id)) {
    yield plan?.id;
  }
});

/// 当前狗的活动计划视图。
final activePlanViewProvider = Provider<AsyncValue<PlanView?>>((ref) {
  final id = ref.watch(activePlanIdProvider);
  return id.when(
    loading: () => const AsyncLoading<PlanView?>(),
    error: (e, st) => AsyncError<PlanView?>(e, st),
    data: (planId) => planId == null
        ? const AsyncData<PlanView?>(null)
        : ref.watch(planViewProvider(planId)),
  );
});
