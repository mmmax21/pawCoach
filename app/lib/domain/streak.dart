/// 连续打卡天数（RC-2 / RC-3 / ST-1，M2 简报第 10 节）。纯函数，无 IO，不依赖 Flutter。
library;

class StreakResult {
  const StreakResult({
    required this.currentDays,
    required this.longestDays,
    required this.lastCheckinDate,
  });

  /// 从今天（今天还没练则从昨天）往前连续有记录的天数。
  final int currentDays;

  /// 历史最长连续天数。
  final int longestDays;

  /// 最近一次打卡的本地日期（00:00，UTC 表示的纯日期）；从未打卡为 null。
  final DateTime? lastCheckinDate;

  @override
  String toString() =>
      'StreakResult(current: $currentDays, longest: $longestDays, last: $lastCheckinDate)';
}

/// 任意时刻 → 本地日历日期（纯日期，用 UTC 表示以避免夏令时干扰）。
DateTime localDateOf(DateTime t) {
  final l = t.toLocal();
  return DateTime.utc(l.year, l.month, l.day);
}

/// [startedAt]：所有 TrainingSession 的 started_at；转本地日期后去重。
/// [today]：当前时刻，取其本地日期。一天多次只计一次。
StreakResult computeStreak({
  required Iterable<DateTime> startedAt,
  required DateTime today,
}) {
  final days = {for (final t in startedAt) localDateOf(t)}.toList()..sort();
  if (days.isEmpty) {
    return const StreakResult(
        currentDays: 0, longestDays: 0, lastCheckinDate: null);
  }

  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i].difference(days[i - 1]).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }

  final last = days.last;
  final todayDate = localDateOf(today);
  final gap = todayDate.difference(last).inDays;
  var current = 0;
  if (gap == 0 || gap == 1) {
    // 末尾那段连续记录就是当前连续天数。
    current = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
      } else {
        break;
      }
    }
  }
  return StreakResult(
    currentDays: current,
    longestDays: longest,
    lastCheckinDate: last,
  );
}

/// 首页展示用：Streak 表里存的 current_days 是写入当时的值，
/// 隔天不练则应显示 0。不扫表，只比较 last_checkin_date。
int effectiveCurrentDays({
  required int storedCurrentDays,
  required DateTime? lastCheckinDate,
  required DateTime today,
}) {
  if (lastCheckinDate == null) return 0;
  final gap = localDateOf(today).difference(lastCheckinDate).inDays;
  return gap <= 1 ? storedCurrentDays : 0;
}
