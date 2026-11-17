/// 本地副作用（M4）：本地写入后判定徽章、出生日期变化后重算养护日历、养护条目变化后重排推送。
///
/// 徽章判定时机（简报第 7 节）：打卡后、技能状态变化后、诊断完成后、成员加入后、下行同步后
/// ——都表现为对应表的写入，这里统一监听；下行同步另由 DerivedState.recompute 判定一次。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

const _badgeTables = {
  'training_sessions',
  'diagnosis_results',
  'weekly_reports',
  'household_members',
  'dog_skill_statuses',
};

class AppEffects {
  AppEffects(this.ref);
  final Ref ref;

  StreamSubscription<Object?>? _sub;
  final _pending = <String>{};
  bool _running = false;

  void start() {
    if (_sub != null) return;
    final db = ref.read(databaseProvider);
    _sub = db.tableUpdates().listen((updates) {
      _pending.addAll(updates.map((u) => u.table));
      scheduleMicrotask(_drain);
    });
    unawaited(boot());
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// 启动时：补齐默认养护条目（含 M4 升级后老用户首次启动）、重排养护推送、判定一次徽章。
  Future<void> boot() async {
    try {
      final content = await ref.read(contentLibraryProvider.future);
      final dog = await ref.read(dogRepositoryProvider).currentDog();
      if (dog == null) return;
      await ref.read(careRepositoryProvider).syncDefaults(dog, content.careCalendar);
      await ref.read(careReminderServiceProvider).refresh(dog.id);
      await ref.read(badgeRepositoryProvider).evaluate(dog.id, content.badges);
      await ref.read(nudgeServiceProvider).refresh(dog.id, content);
    } catch (e) {
      debugPrint('启动副作用失败：$e');
    }
  }

  Future<void> _drain() async {
    if (_running || _pending.isEmpty) return;
    _running = true;
    try {
      while (_pending.isNotEmpty) {
        final tables = {..._pending};
        _pending.clear();
        await runFor(tables);
      }
    } finally {
      _running = false;
    }
  }

  /// 可测性入口：按"哪些表变了"执行一次副作用。
  Future<void> runFor(Set<String> tables) async {
    try {
      final content = await ref.read(contentLibraryProvider.future);
      final dog = await ref.read(dogRepositoryProvider).currentDog();
      if (dog == null) return;
      if (tables.contains('dogs')) {
        // 建档完成 / 修改出生日期：只重算 source = default 且未完成、未跳过的条目。
        await ref.read(careRepositoryProvider).syncDefaults(dog, content.careCalendar);
      }
      if (tables.contains('dogs') || tables.contains('care_reminders')) {
        await ref.read(careReminderServiceProvider).refresh(dog.id);
      }
      if (tables.any(_badgeTables.contains)) {
        await ref.read(badgeRepositoryProvider).evaluate(dog.id, content.badges);
      }
      // AI-5：训练记录变化（本机打卡或同步过来）后重新判定主动干预。
      // 每日提醒开关变化时同样重排（关闭即取消，重新打开按当前状态重排）。
      if (tables.contains('training_sessions') || tables.contains('reminder_settings')) {
        await ref.read(nudgeServiceProvider).refresh(dog.id, content);
      }
    } catch (e) {
      debugPrint('本地副作用失败：$e');
    }
  }
}

final appEffectsProvider = Provider<AppEffects>((ref) {
  final e = AppEffects(ref);
  ref.onDispose(e.stop);
  return e;
});
