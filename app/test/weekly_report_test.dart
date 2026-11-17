import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/weekly_report.dart';

/// M2 简报第 11 节 weekly_report 单测：汇总计数正确，comment 取最低分技能。
void main() {
  final monday = DateTime.utc(2026, 11, 16);
  DateTime day(int d, [int h = 10]) => DateTime(2026, 11, 16 + d, h);

  ReportSession s(String skill, int d, Score score, {int part = 1, int h = 10}) =>
      ReportSession(
        skillId: skill,
        scriptPart: part,
        startedAt: day(d, h),
        score: score,
      );

  const goals = [
    ReportGoal(skillId: 'sit', targetSessions: 3, scoringHint: '坐下的评分标准'),
    ReportGoal(skillId: 'down', targetSessions: 3, scoringHint: '趴下的评分标准'),
    ReportGoal(skillId: 'stay_short', targetSessions: 3, scoringHint: '等待的评分标准'),
  ];

  test('汇总计数：目标完成次数、三档评分、打卡天数', () {
    final r = summarizeWeek(
      weekStart: monday,
      goals: goals,
      sessions: [
        s('sit', 0, Score.full),
        s('sit', 1, Score.full),
        s('sit', 1, Score.partial, h: 18),
        s('down', 2, Score.none),
        s('down', 4, Score.partial),
      ],
    );
    expect(r.checkinDays, 4); // 周一、周二（两次）、周三、周五
    expect(r.sessionsTotal, 5);
    final sit = r.goals.firstWhere((g) => g.skillId == 'sit');
    expect([sit.completed, sit.full, sit.partial, sit.none], [3, 2, 1, 0]);
    expect(sit.target, 3);
    expect(sit.outcome, GoalOutcome.mastered);
    final down = r.goals.firstWhere((g) => g.skillId == 'down');
    expect([down.completed, down.full, down.partial, down.none], [2, 0, 1, 1]);
    expect(down.outcome, GoalOutcome.carryover);
    final stay = r.goals.firstWhere((g) => g.skillId == 'stay_short');
    expect(stay.completed, 0);
    expect(stay.outcome, GoalOutcome.carryover);
  });

  test('comment 取评分最低的目标技能的 scoring_hint', () {
    final r = summarizeWeek(
      weekStart: monday,
      goals: goals,
      sessions: [
        s('sit', 0, Score.full),
        s('sit', 1, Score.full),
        s('down', 2, Score.none),
        s('down', 3, Score.partial),
        s('stay_short', 4, Score.partial),
      ],
    );
    // 平均分：sit 2.0，down 0.5，stay_short 1.0 → down 最低。
    expect(r.comment, '趴下的评分标准');
  });

  test('没有记录时 comment 为固定文案', () {
    final r = summarizeWeek(weekStart: monday, goals: goals, sessions: const []);
    expect(r.comment, emptyWeekComment);
    expect(r.comment, '这周还没开始，下周从保底任务做起');
    expect(r.checkinDays, 0);
    expect(r.sessionsTotal, 0);
  });

  test('保底任务单独计天数，不计入目标完成次数', () {
    final r = summarizeWeek(
      weekStart: monday,
      goals: goals,
      sessions: [
        s('sit', 0, Score.full, part: miniScriptPart),
        s('sit', 1, Score.full, part: miniScriptPart),
        s('lure_follow', 1, Score.partial, part: miniScriptPart, h: 19),
        s('sit', 2, Score.full),
      ],
    );
    expect(r.miniTaskDays, 2);
    expect(r.checkinDays, 3);
    expect(r.sessionsTotal, 4);
    final sit = r.goals.firstWhere((g) => g.skillId == 'sit');
    expect(sit.completed, 1);
    expect(sit.full, 1);
  });

  test('只做了保底任务：comment 用固定文案以外的情况——没有目标记录时不取 hint', () {
    final r = summarizeWeek(
      weekStart: monday,
      goals: goals,
      sessions: [s('sit', 0, Score.full, part: miniScriptPart)],
    );
    // 有打卡但没有任何目标记录：不能凭空取某个目标的 hint。
    expect(r.checkinDays, 1);
    expect(r.comment, emptyWeekComment);
  });

  test('不在本周的记录不统计', () {
    final r = summarizeWeek(
      weekStart: monday,
      goals: goals,
      sessions: [
        ReportSession(
            skillId: 'sit',
            scriptPart: 1,
            startedAt: DateTime(2026, 11, 15, 23, 59), // 上周日
            score: Score.full),
        ReportSession(
            skillId: 'sit',
            scriptPart: 1,
            startedAt: DateTime(2026, 11, 23, 0, 1), // 下周一
            score: Score.full),
        s('sit', 6, Score.partial), // 本周日
      ],
    );
    expect(r.sessionsTotal, 1);
    expect(r.goals.first.full, 0);
  });

  test('summary_json 结构与简报第 4 节一致，可往返', () {
    final r = summarizeWeek(
      weekStart: monday,
      goals: goals,
      sessions: [s('sit', 0, Score.full), s('sit', 1, Score.full)],
    );
    final j = r.toJson();
    expect(j['week_start'], '2026-11-16');
    expect(j.keys, containsAll(<String>[
      'week_start',
      'checkin_days',
      'sessions_total',
      'goals',
      'mini_task_days',
      'comment',
    ]));
    final g0 = (j['goals'] as List).first as Map;
    expect(g0.keys,
        containsAll(<String>['skill_id', 'target', 'completed', 'scores', 'outcome']));
    expect((g0['scores'] as Map).keys, containsAll(<String>['full', 'partial', 'none']));
    expect(g0['outcome'], 'mastered');
    final back = WeeklySummary.fromJson(j);
    expect(back.toJson(), j);
  });

  group('触发时机', () {
    test('周日 21:00 前不到点，之后到点', () {
      final sunday = DateTime(2026, 11, 22);
      expect(isReportDue(planWeekStart: monday, now: DateTime(2026, 11, 22, 20, 59)),
          isFalse);
      expect(isReportDue(planWeekStart: monday, now: DateTime(2026, 11, 22, 21, 0)),
          isTrue);
      expect(reportInstantOf(monday), DateTime(sunday.year, sunday.month, sunday.day, 21));
    });

    test('计划周早于本周：立即补跑', () {
      expect(isReportDue(planWeekStart: monday, now: DateTime(2026, 11, 23, 0, 5)),
          isTrue);
      expect(isReportDue(planWeekStart: monday, now: DateTime(2026, 12, 8, 9)),
          isTrue);
    });

    test('计划周在未来：不生成', () {
      expect(
          isReportDue(
              planWeekStart: DateTime.utc(2026, 11, 23),
              now: DateTime(2026, 11, 22, 22)),
          isFalse);
    });

    test('nextReportInstant：本周日 21:00 之前取本周，之后取下周', () {
      expect(nextReportInstant(DateTime(2026, 11, 18, 9)), DateTime(2026, 11, 22, 21));
      expect(nextReportInstant(DateTime(2026, 11, 22, 21, 0, 1)),
          DateTime(2026, 11, 29, 21));
    });
  });
}
