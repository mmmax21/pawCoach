/// 周日晚周报任务（WP-5，M2 简报第 9 节）。
///
/// 两条触发路径，调用同一个幂等函数 [runWeeklyReportJob]：
/// 1. workmanager：Android WorkManager / iOS BGTaskScheduler，每周日本地 21:00 前后；
/// 2. 冷启动补跑：App 启动时检查"活动计划的 week_start 是否早于本周一"（及周日 21:00 已过）。
///
/// 幂等靠数据库约束：weekly_reports.plan_id 唯一、weekly_plans (dog_id, week_start) 唯一，
/// 并且 [ReportRepository.generate] 先查后写、同一事务内完成。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../data/content/content_repository.dart';
import '../data/content/content_sources.dart';
import '../data/db/database.dart';
import '../data/repositories/report_repository.dart';
import '../domain/models.dart';
import '../domain/weekly_report.dart';

const weeklyTaskUniqueName = 'weekly_report';
const weeklyTaskName = 'weekly_report_task';

/// 检查当前狗的活动计划，到点就生成周报与下周计划。返回新建的周报 id 列表
/// （已存在或未到点返回空）。可重复调用。
///
/// 周期任务可能晚了好几周才被系统唤醒（用户久未打开 App），所以循环处理：
/// 每生成一份，新的活动计划成为下一轮的检查对象，直到追到本周。
Future<List<String>> runWeeklyReportJob({
  required AppDatabase db,
  required ContentLibrary content,
  DateTime? now,
}) async {
  final repo = ReportRepository(db);
  final created = <String>[];
  final at = now ?? DateTime.now();
  for (var guard = 0; guard < 60; guard++) {
    final plan = await (db.select(db.weeklyPlans)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm.desc(t.weekStart)])
          ..limit(1))
        .getSingleOrNull();
    if (plan == null) break;
    final parts = plan.weekStart.split('-').map(int.parse).toList();
    final weekStart = DateTime.utc(parts[0], parts[1], parts[2]);
    if (!isReportDue(planWeekStart: weekStart, now: at)) break;
    final r = await repo.generate(planId: plan.id, content: content, now: at);
    if (r.created) created.add(r.reportId);
    // 周报已存在但计划仍是 active（上次写到一半的异常残留）：不再循环，避免死循环。
    if (!r.created) break;
  }
  return created;
}

/// workmanager 的后台入口（独立 isolate），必须是顶层函数。
@pragma('vm:entry-point')
void weeklyCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != weeklyTaskName && task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    AppDatabase? db;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'puppy_trainer.sqlite'));
      if (!file.existsSync()) return true; // 还没建档
      db = AppDatabase(NativeDatabase.createInBackground(file));
      final repo = ContentRepository(db: db, source: AssetContentSource());
      final content = await repo.ensureLoaded();
      final ids = await runWeeklyReportJob(db: db, content: content);
      debugPrint('weekly_job: 新生成周报 ${ids.length} 份');
      return true;
    } catch (e, st) {
      debugPrint('weekly_job 失败：$e\n$st');
      return false; // 让系统按退避策略重试
    } finally {
      await db?.close();
    }
  });
}

/// 注册周日 21:00 的周期任务。每周一次，首次延迟到下一个周日 21:00。
/// 重复调用安全：用 keep 策略，不会叠加。
Future<void> registerWeeklyJob({DateTime? now}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  await Workmanager().initialize(weeklyCallbackDispatcher);
  final at = now ?? DateTime.now();
  final delay = nextReportInstant(at).difference(at);
  await Workmanager().registerPeriodicTask(
    weeklyTaskUniqueName,
    weeklyTaskName,
    frequency: const Duration(days: 7),
    initialDelay: delay,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
}
