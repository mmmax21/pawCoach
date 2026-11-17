/// 技能树 Tab（ST-3，M4 批次 B）：按内容库 prerequisites 画成从左到右的依赖树，
/// 四态（已掌握 / 进行中 / 可解锁 / 锁定）着色，连线表示前置依赖，点节点进技能详情。
/// 布局由 domain/skill_tree_layout.dart 计算，不写死技能与坐标；整棵树缩放到一屏内，可双指放大。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_nav.dart';
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

class SkillTreePage extends ConsumerWidget {
  const SkillTreePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(skillTreeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('技能树')),
      bottomNavigationBar: const AppBottomNav(current: AppTab.skillTree),
      body: nodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取失败：$e')),
        data: (list) {
          final counts = {for (final s in SkillStatus.values) s: list.where((n) => n.status == s).length};
          return Column(
            children: [
              Padding(
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
              ),
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
