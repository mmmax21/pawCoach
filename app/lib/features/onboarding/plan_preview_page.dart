import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../home/plan_preview_list.dart';
import '../home/plan_view.dart';

/// 建档完成后的首周计划预览（ON-5）。
class PlanPreviewPage extends ConsumerWidget {
  const PlanPreviewPage({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(planViewProvider(planId));
    return Scaffold(
      appBar: AppBar(title: const Text('你的首周计划')),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取计划失败：$e')),
        data: (v) {
          if (v == null) return const Center(child: Text('计划不存在'));
          return PlanPreviewList(view: v);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('go_home'),
            onPressed: () => context.go('/home'),
            child: const Text('进入首页'),
          ),
        ),
      ),
    );
  }
}
