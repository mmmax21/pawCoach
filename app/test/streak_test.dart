import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/streak.dart';

/// M2 简报第 11 节 streak 单测：连续 3 天、中断、今天未练但昨天练了、跨月。
void main() {
  // 用本地时间构造，避免时区把日期推到前一天。
  DateTime at(int y, int m, int d, [int h = 10]) => DateTime(y, m, d, h);

  group('computeStreak', () {
    test('没有记录', () {
      final r = computeStreak(startedAt: const [], today: at(2026, 11, 16));
      expect(r.currentDays, 0);
      expect(r.longestDays, 0);
      expect(r.lastCheckinDate, isNull);
    });

    test('连续 3 天，今天练了', () {
      final r = computeStreak(
        startedAt: [at(2026, 11, 14), at(2026, 11, 15), at(2026, 11, 16)],
        today: at(2026, 11, 16, 20),
      );
      expect(r.currentDays, 3);
      expect(r.longestDays, 3);
      expect(r.lastCheckinDate, DateTime.utc(2026, 11, 16));
    });

    test('一天多次只计一次', () {
      final r = computeStreak(
        startedAt: [
          at(2026, 11, 16, 7),
          at(2026, 11, 16, 12),
          at(2026, 11, 16, 21),
        ],
        today: at(2026, 11, 16, 22),
      );
      expect(r.currentDays, 1);
      expect(r.longestDays, 1);
    });

    test('中断：昨天没练，今天练了 → 当前 1，历史最长保留', () {
      final r = computeStreak(
        startedAt: [
          at(2026, 11, 10),
          at(2026, 11, 11),
          at(2026, 11, 12),
          at(2026, 11, 16),
        ],
        today: at(2026, 11, 16),
      );
      expect(r.currentDays, 1);
      expect(r.longestDays, 3);
    });

    test('今天还没练但昨天练了 → 连续不断', () {
      final r = computeStreak(
        startedAt: [at(2026, 11, 14), at(2026, 11, 15)],
        today: at(2026, 11, 16, 8),
      );
      expect(r.currentDays, 2);
    });

    test('前天练了、昨天和今天都没练 → 当前 0', () {
      final r = computeStreak(
        startedAt: [at(2026, 11, 13), at(2026, 11, 14)],
        today: at(2026, 11, 16),
      );
      expect(r.currentDays, 0);
      expect(r.longestDays, 2);
      expect(r.lastCheckinDate, DateTime.utc(2026, 11, 14));
    });

    test('跨月：10-30、10-31、11-01、11-02 连续', () {
      final r = computeStreak(
        startedAt: [
          at(2026, 10, 30),
          at(2026, 10, 31),
          at(2026, 11, 1),
          at(2026, 11, 2),
        ],
        today: at(2026, 11, 2, 23),
      );
      expect(r.currentDays, 4);
      expect(r.longestDays, 4);
    });

    test('跨年：12-31 与 01-01 连续', () {
      final r = computeStreak(
        startedAt: [at(2026, 12, 31), at(2027, 1, 1)],
        today: at(2027, 1, 1),
      );
      expect(r.currentDays, 2);
    });

    test('UTC 时间戳按本地日期归日：深夜 23:50 与次日 00:10 是两天', () {
      final r = computeStreak(
        startedAt: [
          DateTime(2026, 11, 15, 23, 50).toUtc(),
          DateTime(2026, 11, 16, 0, 10).toUtc(),
        ],
        today: DateTime(2026, 11, 16, 9),
      );
      expect(r.currentDays, 2);
    });

    test('乱序输入', () {
      final r = computeStreak(
        startedAt: [at(2026, 11, 16), at(2026, 11, 14), at(2026, 11, 15)],
        today: at(2026, 11, 16),
      );
      expect(r.currentDays, 3);
    });
  });

  group('effectiveCurrentDays', () {
    test('今天 / 昨天打过卡：显示存储值', () {
      expect(
          effectiveCurrentDays(
            storedCurrentDays: 5,
            lastCheckinDate: DateTime.utc(2026, 11, 15),
            today: at(2026, 11, 16),
          ),
          5);
    });

    test('隔了一天以上：显示 0', () {
      expect(
          effectiveCurrentDays(
            storedCurrentDays: 5,
            lastCheckinDate: DateTime.utc(2026, 11, 14),
            today: at(2026, 11, 16),
          ),
          0);
    });

    test('从未打卡：0', () {
      expect(
          effectiveCurrentDays(
            storedCurrentDays: 0,
            lastCheckinDate: null,
            today: at(2026, 11, 16),
          ),
          0);
    });
  });
}
