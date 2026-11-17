/// FM-4：本机被创建者移出家庭后，回到建档页并提示一次。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';

class RemovedNoticeHost extends ConsumerStatefulWidget {
  const RemovedNoticeHost({super.key, required this.navigatorKey, required this.router, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<RemovedNoticeHost> createState() => _RemovedNoticeHostState();
}

class _RemovedNoticeHostState extends ConsumerState<RemovedNoticeHost> {
  late final ValueNotifier<String?> _notice;

  @override
  void initState() {
    super.initState();
    _notice = ref.read(httpSyncServiceProvider).removedNotice;
    _notice.addListener(_onNotice);
  }

  @override
  void dispose() {
    _notice.removeListener(_onNotice);
    super.dispose();
  }

  Future<void> _onNotice() async {
    final name = _notice.value;
    if (name == null) return;
    _notice.value = null;
    widget.router.go('/onboarding');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        key: const Key('removed_notice'),
        title: const Text('你已被移出家庭'),
        content: Text('创建者已把你移出${name.isEmpty ? '家庭' : '「$name」'}。这台手机上的家庭数据已清除。'
            '\n\n你可以用新的邀请码重新加入，或者给自己的狗建档。'),
        actions: [
          TextButton(key: const Key('removed_notice_ok'), onPressed: () => Navigator.pop(c), child: const Text('知道了')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
