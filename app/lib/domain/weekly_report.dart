/// 周报汇总（WP-5，M2 简报第 4、9 节）。纯函数，无 IO，不依赖 Flutter。
///
/// 输出结构即 `WeeklyReport.summary_json`。
library;

import 'models.dart';
import 'plan_generator.dart';
import 'streak.dart';

/// 本周没有任何记录时周报 comment 的固定文案（简报第 9 节指定）。
const emptyWeekComment = '这周还没开始，下周从保底任务做起';

/// 周报汇总用的一条跟练记录。
class ReportSession {
  const ReportSession({
    required this.skillId,
    required this.scriptPart,
    required this.startedAt,
    required this.score,
  });
  final String skillId;

  /// 0 表示 mini_script（保底任务）。
  final int scriptPart;
  final DateTime startedAt;
  final Score score;
}

/// 周报汇总用的一个本周目标。
class ReportGoal {
  const ReportGoal({
    required this.skillId,
    required this.targetSessions,
    required this.scoringHint,
  });
  final String skillId;
  final int targetSessions;

  /// 内容库该技能的 scoring_hint，用作周报一句话点评（M3 换 AI）。
  final String scoringHint;
}

class GoalSummary {
  const GoalSummary({
    required this.skillId,
    required this.target,
    required this.completed,
    required this.full,
    required this.partial,
    required this.none,
    required this.outcome,
  });
  final String skillId;
  final int target;
  final int completed;
  final int full;
  final int partial;
  final int none;
  final GoalOutcome outcome;

  GoalWeekStat toStat() =>
      GoalWeekStat(skillId: skillId, full: full, partial: partial, none: none);

  Map<String, Object?> toJson() => {
        'skill_id': skillId,
        'target': target,
        'completed': completed,
        'scores': {'full': full, 'partial': partial, 'none': none},
        'outcome': outcomeToJson(outcome),
      };

  static GoalSummary fromJson(Map<String, Object?> j) {
    final scores = (j['scores'] as Map).cast<String, Object?>();
    return GoalSummary(
      skillId: j['skill_id'] as String,
      target: j['target'] as int,
      completed: j['completed'] as int,
      full: scores['full'] as int,
      partial: scores['partial'] as int,
      none: scores['none'] as int,
      outcome: outcomeFromJson(j['outcome'] as String),
    );
  }
}

String outcomeToJson(GoalOutcome o) => switch (o) {
      GoalOutcome.mastered => 'mastered',
      GoalOutcome.downgrade => 'downgrade',
      GoalOutcome.carryover => 'carryover',
    };

GoalOutcome outcomeFromJson(String s) => switch (s) {
      'mastered' => GoalOutcome.mastered,
      'downgrade' => GoalOutcome.downgrade,
      'carryover' => GoalOutcome.carryover,
      _ => throw FormatException('未知 outcome：$s'),
    };

class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.checkinDays,
    required this.sessionsTotal,
    required this.goals,
    required this.miniTaskDays,
    required this.comment,
  });

  /// 周一，纯日期。
  final DateTime weekStart;
  final int checkinDays;
  final int sessionsTotal;
  final List<GoalSummary> goals;
  final int miniTaskDays;
  final String comment;

  Map<String, Object?> toJson() => {
        'week_start': _dateOnly(weekStart),
        'checkin_days': checkinDays,
        'sessions_total': sessionsTotal,
        'goals': [for (final g in goals) g.toJson()],
        'mini_task_days': miniTaskDays,
        'comment': comment,
      };

  static WeeklySummary fromJson(Map<String, Object?> j) {
    final p = (j['week_start'] as String).split('-').map(int.parse).toList();
    return WeeklySummary(
      weekStart: DateTime.utc(p[0], p[1], p[2]),
      checkinDays: j['checkin_days'] as int,
      sessionsTotal: j['sessions_total'] as int,
      goals: [
        for (final g in (j['goals'] as List))
          GoalSummary.fromJson((g as Map).cast<String, Object?>()),
      ],
      miniTaskDays: j['mini_task_days'] as int,
      comment: j['comment'] as String,
    );
  }
}

String _dateOnly(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

int _scoreRank(Score s) => switch (s) {
      Score.none => 0,
      Score.partial => 1,
      Score.full => 2,
    };

/// 汇总一周。
///
/// - [weekStart]：本周周一（纯日期）。只统计本地日期落在 [weekStart, weekStart+7) 的记录。
/// - 目标的 completed / 评分计数只数正式脚本（scriptPart ≥ 1）的记录；
///   保底任务（scriptPart == 0）单独计 `mini_task_days`，不计入目标进度。
/// - `checkin_days`、`sessions_total` 含保底任务记录。
/// - `comment`：取评分最低的目标技能（有记录的目标里平均分最低，并列取排在前面的）的
///   scoring_hint；本周没有任何记录时为 [emptyWeekComment]。
WeeklySummary summarizeWeek({
  required DateTime weekStart,
  required List<ReportGoal> goals,
  required List<ReportSession> sessions,
}) {
  final start = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
  final end = start.add(const Duration(days: 7));
  final inWeek = [
    for (final s in sessions)
      if (!localDateOf(s.startedAt).isBefore(start) &&
          localDateOf(s.startedAt).isBefore(end))
        s,
  ];

  final checkinDays = {for (final s in inWeek) localDateOf(s.startedAt)}.length;
  final miniDays = {
    for (final s in inWeek)
      if (s.scriptPart == miniScriptPart) localDateOf(s.startedAt),
  }.length;

  final summaries = <GoalSummary>[];
  final avg = <String, double>{};
  for (final g in goals) {
    final mine = inWeek
        .where((s) => s.skillId == g.skillId && s.scriptPart != miniScriptPart)
        .toList();
    final full = mine.where((s) => s.score == Score.full).length;
    final partial = mine.where((s) => s.score == Score.partial).length;
    final none = mine.where((s) => s.score == Score.none).length;
    summaries.add(GoalSummary(
      skillId: g.skillId,
      target: g.targetSessions,
      completed: mine.length,
      full: full,
      partial: partial,
      none: none,
      outcome: judgeGoalOutcome(full: full, none: none),
    ));
    if (mine.isNotEmpty) {
      avg[g.skillId] =
          mine.fold(0, (a, s) => a + _scoreRank(s.score)) / mine.length;
    }
  }

  var comment = emptyWeekComment;
  if (inWeek.isNotEmpty) {
    ReportGoal? lowest;
    for (final g in goals) {
      final a = avg[g.skillId];
      if (a == null) continue;
      if (lowest == null || a < avg[lowest.skillId]!) lowest = g;
    }
    // 有记录但都不属于任何目标（只做了保底任务）：同样给固定文案。
    if (lowest != null) comment = lowest.scoringHint;
  }

  return WeeklySummary(
    weekStart: start,
    checkinDays: checkinDays,
    sessionsTotal: inWeek.length,
    goals: summaries,
    miniTaskDays: miniDays,
    comment: comment,
  );
}


// ---------------------------------------------------------------------------
// 触发时机（M2 简报第 9 节）。两条路径（workmanager / 冷启动补跑）共用这里的判定。
// ---------------------------------------------------------------------------

/// 某周的周报生成时刻：该周周日本地时间 21:00。[weekStart] 为周一。
DateTime reportInstantOf(DateTime weekStart) =>
    DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 21);

/// 现在是否该为 [planWeekStart]（周一，纯日期）这份计划生成周报：
/// - 计划周早于本周 → 补跑，立即生成；
/// - 计划周就是本周 → 到了周日 21:00 才生成；
/// - 计划周在未来（周日晚已生成过下周计划）→ 不生成。
bool isReportDue({required DateTime planWeekStart, required DateTime now}) {
  final thisMonday = weekStartOf(now.toLocal());
  final ws = DateTime.utc(planWeekStart.year, planWeekStart.month, planWeekStart.day);
  if (ws.isBefore(thisMonday)) return true;
  if (ws.isAfter(thisMonday)) return false;
  return !now.toLocal().isBefore(reportInstantOf(ws));
}

/// 下一次周日 21:00（本地时间）。已过本周的 21:00 则取下周。
DateTime nextReportInstant(DateTime now) {
  final l = now.toLocal();
  final monday = weekStartOf(l);
  final thisWeek = reportInstantOf(monday);
  if (thisWeek.isAfter(l)) return thisWeek;
  return reportInstantOf(monday.add(const Duration(days: 7)));
}
