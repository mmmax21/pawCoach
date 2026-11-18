/// 技能树 Tab（ST-3，M4 批次 B）。
///
/// 2026-11-18 改版：默认显示"成长路径"——只突出现在能练的、下一个能解锁的（写明还差什么），
/// 已掌握的收在最后；原来的依赖树保留为"全图"视图（右上角切换）。
///
/// 全图：按内容库 prerequisites 画成从左到右的依赖树，
/// 四态（已掌握 / 进行中 / 可解锁 / 锁定）着色，连线表示前置依赖，点节点进技能详情。
/// 布局由 domain/skill_tree_layout.dart 计算，不写死技能与坐标；整棵树缩放到一屏内，可双指放大。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_nav.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/repositories/repositories.dart' show parseDateOnly;
import '../../domain/models.dart';
import '../../domain/skill_tree_layout.dart';
import 'skill_tree_provider.dart';

String skillStatusLabel(SkillStatus s) => switch (s) {
      SkillStatus.mastered => '已掌握',
      SkillStatus.inProgress => '进行中',
      SkillStatus.available => '可解锁',
      SkillStatus.locked => '锁定',
    };

IconData skillStatusIcon(SkillStatus s) => switch (s) {
      SkillStatus.mastered => Icons.check_circle,
      SkillStatus.inProgress => Icons.play_circle,
      SkillStatus.available => Icons.lock_open,
      SkillStatus.locked => Icons.lock,
    };

class _Palette {
  _Palette(ColorScheme cs, SkillStatus s)
      : bg = switch (s) {
          SkillStatus.mastered => cs.primary,
          SkillStatus.inProgress => cs.tertiaryContainer,
          SkillStatus.available => cs.surface,
          SkillStatus.locked => cs.surfaceContainerHighest,
        },
        fg = switch (s) {
          SkillStatus.mastered => cs.onPrimary,
          SkillStatus.inProgress => cs.onTertiaryContainer,
          SkillStatus.available => cs.primary,
          SkillStatus.locked => cs.outline,
        },
        border = switch (s) {
          SkillStatus.mastered => cs.primary,
          SkillStatus.inProgress => cs.tertiary,
          SkillStatus.available => cs.primary,
          SkillStatus.locked => cs.outlineVariant,
        };
  final Color bg;
  final Color fg;
  final Color border;
}

/// 视图：成长路径（默认）/ 全图。只在本页内记住。
final skillTreeGraphViewProvider = StateProvider<bool>((ref) => false);

class SkillTreePage extends ConsumerWidget {
  const SkillTreePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(skillTreeProvider);
    final graph = ref.watch(skillTreeGraphViewProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能树'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.md),
            child: SegmentedButton<bool>(
              key: const Key('skill_tree_view_toggle'),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: Theme.of(context).textTheme.labelMedium,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('路径', key: Key('skill_tree_view_path'))),
                ButtonSegment(value: true, label: Text('全图', key: Key('skill_tree_view_graph'))),
              ],
              selected: {graph},
              onSelectionChanged: (v) => ref.read(skillTreeGraphViewProvider.notifier).state = v.first,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.skillTree),
      body: nodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取失败：$e')),
        data: (list) {
          final counts = {for (final s in SkillStatus.values) s: list.where((n) => n.status == s).length};
          final legend = Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Wrap(
              key: const Key('skill_tree_legend'),
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final s in [SkillStatus.mastered, SkillStatus.inProgress, SkillStatus.available, SkillStatus.locked])
                  _LegendChip(status: s, count: counts[s]!),
              ],
            ),
          );
          if (!graph) return _PathView(nodes: list, legend: legend);
          return Column(
            children: [
              legend,
              Expanded(
                child: InteractiveViewer(
                  key: const Key('skill_tree_viewer'),
                  minScale: 1,
                  maxScale: 3,
                  child: _TreeCanvas(nodes: list),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 成长路径
// ---------------------------------------------------------------------------

class _PathView extends ConsumerWidget {
  const _PathView({required this.nodes, required this.legend});
  final List<SkillTreeNode> nodes;
  final Widget legend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dog = ref.watch(currentDogProvider).valueOrNull;
    final now = ref.watch(clockProvider)();
    final ageWeeks = dog == null ? null : ageWeeksOn(parseDateOnly(dog.birthDate), now);
    final status = {for (final n in nodes) n.skill.id: n.status};
    final names = {for (final n in nodes) n.skill.id: skillShortName(n.skill.name)};

    final doing = nodes.where((n) => n.status == SkillStatus.inProgress).toList();
    final ready = nodes.where((n) => n.status == SkillStatus.available).toList();
    final locked = nodes.where((n) => n.status == SkillStatus.locked).toList();
    final mastered = nodes.where((n) => n.status == SkillStatus.mastered).toList();

    // 锁定的：还差哪些前置；前置都满足的（只差周龄）排前面，即"下一个解锁"
    String need(Skill s) {
      final missing = [
        for (final pId in s.prerequisites)
          if (status[pId] != SkillStatus.mastered) names[pId] ?? pId,
      ];
      if (missing.isNotEmpty) return '先掌握：${missing.join('、')}';
      if (ageWeeks != null && ageWeeks < s.minAgeWeeks) return '满 ${s.minAgeWeeks} 周后可练（还差 ${s.minAgeWeeks - ageWeeks} 周）';
      return '前置已满足，下周计划会安排';
    }

    int missingCount(Skill s) => s.prerequisites.where((pId) => status[pId] != SkillStatus.mastered).length;
    locked.sort((a, b) {
      final c = missingCount(a.skill).compareTo(missingCount(b.skill));
      return c != 0 ? c : a.skill.minAgeWeeks.compareTo(b.skill.minAgeWeeks);
    });

    final total = nodes.length;
    return ListView(
      key: const Key('skill_tree_path'),
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.xl),
      children: [
        legend,
        const SizedBox(height: AppSpace.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('成长进度', style: t.titleMedium),
                    const Spacer(),
                    Text('${mastered.length} / $total 已掌握',
                        style: t.titleSmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : mastered.length / total,
                    minHeight: 10,
                    color: AppColors.success,
                    backgroundColor: AppColors.successSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (doing.isNotEmpty || ready.isNotEmpty) ...[
          _PathSection(icon: Icons.play_circle_fill_rounded, color: AppColors.primary, title: '现在可以练', count: doing.length + ready.length),
          for (final (i, n) in [...doing, ...ready].indexed)
            _PathItem(node: n, subtitle: n.status == SkillStatus.inProgress ? '进行中 · 继续练' : '可以开始', last: i == doing.length + ready.length - 1),
        ],
        if (locked.isNotEmpty) ...[
          _PathSection(icon: Icons.lock_clock_outlined, color: AppColors.streak, title: '接下来解锁', count: locked.length),
          for (final (i, n) in locked.indexed) _PathItem(node: n, subtitle: need(n.skill), last: i == locked.length - 1),
        ],
        if (mastered.isNotEmpty) ...[
          _PathSection(icon: Icons.verified_rounded, color: AppColors.success, title: '已掌握', count: mastered.length),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [for (final n in mastered) _MasteredChip(node: n)],
          ),
        ],
      ],
    );
  }
}

class _PathSection extends StatelessWidget {
  const _PathSection({required this.icon, required this.color, required this.title, required this.count});
  final IconData icon;
  final Color color;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpace.sm),
          Text(title, style: t.titleMedium),
          const SizedBox(width: AppSpace.sm),
          Text('$count', style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 路径上的一站：左侧圆点 + 竖线，右侧卡片。
class _PathItem extends StatelessWidget {
  const _PathItem({required this.node, required this.subtitle, required this.last});
  final SkillTreeNode node;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = node.status;
    final locked = s == SkillStatus.locked;
    final dot = switch (s) {
      SkillStatus.inProgress => AppColors.primary,
      SkillStatus.available => AppColors.primary,
      SkillStatus.mastered => AppColors.success,
      SkillStatus.locked => const Color(0xFFD9C6B6),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 22),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: s == SkillStatus.available ? Colors.white : dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: dot, width: 3),
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: AppColors.outline)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Semantics(
              label: '${node.skill.name}，${skillStatusLabel(s)}',
              button: true,
              child: Card(
                key: Key('skill_tree_${node.skill.id}'),
                color: locked ? const Color(0xFFFBF6F1) : Colors.white,
                child: InkWell(
                  onTap: () => context.push('/skill/${node.skill.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(node.skill.name,
                                  key: Key('skill_tree_label_${node.skill.id}'),
                                  style: t.titleMedium?.copyWith(color: locked ? AppColors.textSecondary : null)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  style: t.bodySmall?.copyWith(
                                      color: locked ? AppColors.textSecondary : AppColors.primary)),
                            ],
                          ),
                        ),
                        Icon(
                          switch (s) {
                            SkillStatus.inProgress => Icons.play_circle_fill_rounded,
                            SkillStatus.available => Icons.play_circle_outline_rounded,
                            _ => skillStatusIcon(s),
                          },
                          key: Key('skill_status_${node.skill.id}'),
                          size: 26,
                          color: dot,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteredChip extends StatelessWidget {
  const _MasteredChip({required this.node});
  final SkillTreeNode node;

  @override
  Widget build(BuildContext context) => Material(
        key: Key('skill_tree_${node.skill.id}'),
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/skill/${node.skill.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, key: Key('skill_status_${node.skill.id}'), size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text(skillShortName(node.skill.name),
                    key: Key('skill_tree_label_${node.skill.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF1F5233))),
              ],
            ),
          ),
        ),
      );
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.status, required this.count});
  final SkillStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = _Palette(Theme.of(context).colorScheme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.border), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(skillStatusIcon(status), size: 14, color: p.fg),
        const SizedBox(width: 4),
        Text('${skillStatusLabel(status)} $count', style: TextStyle(fontSize: 12, color: p.fg)),
      ]),
    );
  }
}

class _TreeCanvas extends StatelessWidget {
  const _TreeCanvas({required this.nodes});
  final List<SkillTreeNode> nodes;

  @override
  Widget build(BuildContext context) {
    final layout = layoutSkillTree([for (final n in nodes) n.skill]);
    final status = {for (final n in nodes) n.skill.id: n.status};
    final byId = {for (final n in nodes) n.skill.id: n.skill};
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      if (layout.columns == 0) return const SizedBox.shrink();
      const pad = 8.0;
      final w = c.maxWidth - pad * 2;
      final h = c.maxHeight - pad * 2;
      // 列间留约 30% 给连线，曲线才看得出走向。
      final nodeW = (w / layout.columns * 0.7).clamp(56.0, 120.0);
      final nodeH = (h / layout.maxRows - 10).clamp(36.0, 64.0);
      Offset center(TreeNodePos p) => Offset(pad + p.x * w, pad + p.y * h);
      return Stack(
        key: const Key('skill_tree_canvas'),
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _EdgePainter(
                edges: [
                  for (final e in layout.edges)
                    (
                      center(layout.nodes[e.from]!) + Offset(nodeW / 2, 0),
                      center(layout.nodes[e.to]!) - Offset(nodeW / 2, 0),
                      status[e.from] == SkillStatus.mastered,
                    ),
                ],
                active: cs.primary,
                inactive: cs.outlineVariant,
              ),
            ),
          ),
          for (final p in layout.nodes.values)
            Positioned(
              left: center(p).dx - nodeW / 2,
              top: center(p).dy - nodeH / 2,
              width: nodeW,
              height: nodeH,
              child: _Node(skill: byId[p.skillId]!, status: status[p.skillId]!),
            ),
        ],
      );
    });
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.skill, required this.status});
  final Skill skill;
  final SkillStatus status;

  @override
  Widget build(BuildContext context) {
    final p = _Palette(Theme.of(context).colorScheme, status);
    return Semantics(
      label: '${skill.name}，${skillStatusLabel(status)}',
      button: true,
      child: Material(
        key: Key('skill_tree_${skill.id}'),
        color: p.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: p.border, width: status == SkillStatus.available ? 1.5 : 1),
        ),
        elevation: status == SkillStatus.locked ? 0 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/skill/${skill.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(skillStatusIcon(status), key: Key('skill_status_${skill.id}'), size: 13, color: p.fg),
                Text(
                  skillShortName(skill.name),
                  key: Key('skill_tree_label_${skill.id}'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, height: 1.15, color: p.fg, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.edges, required this.active, required this.inactive});
  final List<(Offset, Offset, bool)> edges;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, b, on) in edges) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 2.2 : 1.4
        ..color = on ? active : inactive;
      final dx = (b.dx - a.dx) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
      canvas.drawPath(path, paint);
      // 箭头
      final head = Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx - 6, b.dy - 3.5)
        ..lineTo(b.dx - 6, b.dy + 3.5)
        ..close();
      canvas.drawPath(head, Paint()..color = paint.color);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => old.edges != edges || old.active != active;
}
