/// 首页的真实数据：连续天数（Streak 表）、未读周报。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/streak.dart';
import 'plan_view.dart';

/// 当前连续打卡天数。读 Streak 表，不扫训练记录（M2 简报第 10 节）。
/// 隔天没练则显示 0：只比较 last_checkin_date，不重新算。
final streakDaysProvider = StreamProvider<int>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield 0;
    return;
  }
  final db = ref.watch(databaseProvider);
  final clock = ref.read(clockProvider);
  await for (final row in (db.select(db.streaks)
        ..where((t) => t.dogId.equals(dog.id)))
      .watchSingleOrNull()) {
    if (row == null) {
      yield 0;
      continue;
    }
    yield effectiveCurrentDays(
      storedCurrentDays: row.currentDays,
      lastCheckinDate: row.lastCheckinDate == null
          ? null
          : parseDateOnly(row.lastCheckinDate!),
      today: clock(),
    );
  }
});

/// 最近一份未读周报；补跑生成新周报后会随 [weeklyCatchUpProvider] 重新计算。
final unreadReportProvider = FutureProvider<WeeklyReport?>((ref) async {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) return null;
  await ref.watch(weeklyCatchUpProvider.future);
  return ref.watch(reportRepositoryProvider).latestUnread(dog.id);
});

/// 本周进度 = 所有目标 completed 之和 / target 之和，保底任务不计入。
({int completed, int target}) weekProgress(PlanView view) {
  var c = 0;
  var t = 0;
  for (final g in view.goals) {
    // 超额完成不让进度条超过 100%。
    c += g.completedSessions > g.targetSessions
        ? g.targetSessions
        : g.completedSessions;
    t += g.targetSessions;
  }
  return (completed: c, target: t);
}
