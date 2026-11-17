/// 新徽章祝贺弹窗（简报第 7 节）：名称 + description 原文；同一徽章在同一设备只弹一次；
/// 其他成员获得的写明是谁获得的。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import 'badge_icons.dart';

class BadgeCelebrationHost extends ConsumerStatefulWidget {
  const BadgeCelebrationHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.currentPath,
    this.routeChanges,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// 当前路由路径；在跟练 / 记录页时先不弹，离开后再弹（避免盖住保存流程或被跳转冲掉）。
  final String Function()? currentPath;
  final Listenable? routeChanges;

  @override
  ConsumerState<BadgeCelebrationHost> createState() => _BadgeCelebrationHostState();
}

class _BadgeCelebrationHostState extends ConsumerState<BadgeCelebrationHost> {
  StreamSubscription<List<DogBadge>>? _sub;
  String? _dogId;
  bool _showing = false;
  List<DogBadge> _queue = const [];

  static const _quietPrefixes = ['/training', '/record'];

  @override
  void initState() {
    super.initState();
    widget.routeChanges?.addListener(_onRoute);
  }

  Timer? _retry;

  void _later(Duration d) {
    _retry?.cancel();
    _retry = Timer(d, () {
      if (mounted) _next();
    });
  }

  void _onRoute() {
    if (_queue.isNotEmpty) _later(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    widget.routeChanges?.removeListener(_onRoute);
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _watch(String? dogId) {
    if (dogId == _dogId) return;
    _dogId = dogId;
    _sub?.cancel();
    if (dogId == null) return;
    _sub = ref.read(badgeRepositoryProvider).watchUnseen(dogId).listen((list) {
      _queue = list;
      _next();
    });
  }

  Future<void> _next() async {
    if (_showing || _queue.isEmpty) return;
    final path = widget.currentPath?.call() ?? '';
    if (_quietPrefixes.any(path.startsWith)) return;
    if (widget.navigatorKey.currentContext == null) return;
    _showing = true;
    try {
      await _showFirst();
    } finally {
      _showing = false;
    }
    if (mounted && _queue.isNotEmpty) _later(const Duration(milliseconds: 300));
  }

  Future<void> _showFirst() async {
    final b = _queue.first;
    final lib = await ref.read(contentLibraryProvider.future);
    final def = lib.badges.where((d) => d.id == b.badgeId).firstOrNull;
    if (def == null) {
      await ref.read(badgeRepositoryProvider).markSeen(b.dogId, b.badgeId);
      return;
    }
    final me = await ref.read(currentUserIdProvider.future);
    final names = await ref.read(familyRepositoryProvider).nicknames();
    final who = b.earnedByUserId == me ? '你' : (names[b.earnedByUserId]?.isNotEmpty == true ? names[b.earnedByUserId]! : '家庭成员');
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        key: const Key('badge_popup'),
        icon: Icon(badgeIcon(def.conditionType), size: 48, color: Theme.of(c).colorScheme.primary),
        title: Text('获得徽章：${def.name}', key: Key('badge_popup_${def.id}')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(def.description),
            const SizedBox(height: 8),
            Text('$who获得了这枚徽章', key: const Key('badge_popup_who')),
          ],
        ),
        actions: [
          TextButton(key: const Key('badge_popup_ok'), onPressed: () => Navigator.pop(c, true), child: const Text('好的')),
        ],
      ),
    );
    // 只有用户点了"好的"才算弹过；被页面跳转冲掉的留在队列里，稍后重弹。
    if (ok != true) return;
    await ref.read(badgeRepositoryProvider).markSeen(b.dogId, b.badgeId);
    _queue = _queue.where((x) => x.badgeId != b.badgeId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dog = ref.watch(currentDogProvider).valueOrNull;
    _watch(dog?.id);
    return widget.child;
  }
}
