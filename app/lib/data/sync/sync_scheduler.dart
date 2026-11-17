/// 同步节奏（M4 简报第 5.3 节）：本地写入后立即推送（失败排队、下一轮重试）；
/// App 在前台时每 5 秒拉一次；从后台回到前台立即拉一次；后台不轮询。
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import '../db/database.dart';
import 'sync_service.dart';

class SyncScheduler with WidgetsBindingObserver {
  SyncScheduler({
    required this.db,
    required this.service,
    this.pullInterval = const Duration(seconds: 5),
    this.pushDebounce = const Duration(milliseconds: 150),
  });

  final AppDatabase db;
  final HttpSyncService service;
  final Duration pullInterval;
  final Duration pushDebounce;

  Timer? _timer;
  Timer? _pushTimer;
  StreamSubscription<Set<TableUpdate>>? _sub;
  bool _foreground = true;
  bool _ticking = false;
  bool _started = false;

  /// 最近一次同步异常（可测性入口 / 我的页显示"未连接"）。
  final ValueNotifier<Object?> lastError = ValueNotifier(null);

  /// 最近一次成功拉取的时刻。
  final ValueNotifier<DateTime?> lastPullAt = ValueNotifier(null);

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _sub = db.tableUpdates().listen((updates) {
      if (updates.any((u) => isSyncedTable(u.table))) schedulePush();
    });
    _startTimer();
    unawaited(tick());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _timer?.cancel();
    _pushTimer?.cancel();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(pullInterval, (_) => unawaited(tick()));
  }

  /// 本地写入后调用：短暂合并后推送。
  void schedulePush() {
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDebounce, () async {
      try {
        await service.ensureHouseholdUploaded();
        await service.pushPending();
        lastError.value = null;
      } catch (e) {
        lastError.value = e; // 发件箱保留，下一轮 tick 重试
      }
    });
  }

  /// 一轮完整同步：补上传家庭 → 推发件箱 → 增量拉取。网络失败静默，下一轮重试。
  Future<void> tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      await service.ensureHouseholdUploaded();
      await service.pushPending();
      await service.pull();
      lastPullAt.value = DateTime.now();
      lastError.value = null;
    } catch (e) {
      lastError.value = e;
    } finally {
      _ticking = false;
    }
  }

  /// 生命周期（可测性入口：测试直接调用模拟前后台切换）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _startTimer();
      unawaited(tick());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _foreground = false;
      _timer?.cancel();
    }
  }

  bool get isForeground => _foreground;
}
