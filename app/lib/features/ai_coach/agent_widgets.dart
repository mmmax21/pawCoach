/// 在线模式（AI 助理训犬师）的界面部件：离线 / 在线开关、工作过程、操作卡片。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/ai/coach_agent.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models.dart';
import '../../domain/plan_generator.dart';

class AgentStrings {
  const AgentStrings._();
  static const offline = '离线';
  static const online = '在线';
  static const onlineBadge = 'AI 助理训犬师';
  static const offlineHint = '离线：回答直接来自内容库，不联网';
  static const onlineHint = '在线：AI 助理训犬师会查看狗狗档案和训练记录，按规则给建议';
  static const working = 'AI 助理训犬师正在处理…';
  static const fellBack = '连不上在线服务，已改用离线模式回答';
  static const looked = '已查看：';
  static const confirmAdd = '确认加入';
  static const added = '已加入本周计划';
  static const inPlan = '已在本周计划中';
  static String addTitle(String names) => '加入本周计划：$names';
  static String startTraining(String name) => '开始跟练 · $name';
  static const referVet = '建议尽快咨询兽医';
  static const referTrainer = '建议咨询专业训犬师';
}

/// 离线 / 在线切换（AI 教练首页与对话页右上角）。
class AiModeToggle extends ConsumerWidget {
  const AiModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(aiOnlineProvider);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.md),
      child: SegmentedButton<bool>(
        key: const Key('ai_mode_toggle'),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
        segments: const [
          ButtonSegment(value: false, label: Text(AgentStrings.offline, key: Key('ai_mode_offline'))),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.auto_awesome, size: 16),
            label: Text(AgentStrings.online, key: Key('ai_mode_online')),
          ),
        ],
        selected: {online},
        onSelectionChanged: (v) => ref.read(aiOnlineProvider.notifier).set(v.first),
      ),
    );
  }
}

/// 在线模式进行中：逐条显示正在执行的工具。
class AgentWorking extends StatelessWidget {
  const AgentWorking({super.key, required this.steps});
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('agent_working'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(AgentStrings.working, style: t.labelLarge),
          ]),
          for (final (i, s) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Row(children: [
                Icon(i == steps.length - 1 ? Icons.more_horiz : Icons.check_circle,
                    size: 16, color: i == steps.length - 1 ? AppColors.textSecondary : AppColors.success),
                const SizedBox(width: 6),
                Text(s, style: t.bodySmall),
              ]),
            ),
        ],
      ),
    );
  }
}

/// 在线回答下方：查看过哪些信息 + 待确认的操作卡片。
class AgentAnswerExtras extends StatelessWidget {
  const AgentAnswerExtras({super.key, required this.parts, required this.library, required this.dogId});
  final AgentMessageParts parts;
  final ContentLibrary library;
  final String? dogId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (parts.trace.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              key: const Key('agent_trace'),
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(AgentStrings.looked, style: t.labelSmall?.copyWith(color: AppColors.textSecondary)),
                for (final s in parts.trace)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(s, style: t.labelSmall?.copyWith(color: const Color(0xFF1F5233))),
                  ),
              ],
            ),
          ),
        for (final (i, a) in parts.actions.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ActionCard(key: Key('agent_action_$i'), action: a, library: library, dogId: dogId),
          ),
      ],
    );
  }
}

class _ActionCard extends ConsumerStatefulWidget {
  const _ActionCard({super.key, required this.action, required this.library, required this.dogId});
  final AgentAction action;
  final ContentLibrary library;
  final String? dogId;

  @override
  ConsumerState<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<_ActionCard> {
  bool? _alreadyInPlan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.action.type == AgentActionType.addToPlan) _checkPlan();
  }

  Future<void> _checkPlan() async {
    final dogId = widget.dogId;
    if (dogId == null) return;
    final db = ref.read(databaseProvider);
    final plan = await PlanRepository(db).activePlan(dogId);
    final goals = plan == null ? const <String>[] : [for (final g in await PlanRepository(db).goals(plan.id)) g.skillId];
    if (mounted) setState(() => _alreadyInPlan = widget.action.skillIds.every(goals.contains));
  }

  Future<void> _confirm() async {
    final dogId = widget.dogId;
    if (dogId == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(aiRepositoryProvider)
          .addSkillsToThisWeek(dogId: dogId, skillIds: widget.action.skillIds, content: widget.library);
      if (!mounted) return;
      setState(() => _alreadyInPlan = true);
      if (r.added.isEmpty) {
        final why = r.skipped.map((k) => switch (k.reason) {
              DiagnosisSkipReason.capReached => '本周目标已满',
              DiagnosisSkipReason.alreadyInPlan => '已在计划中',
              _ => '规则不允许',
            });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('没有加入：${why.toSet().join('、')}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _name(String id) => widget.library.skillById[id]?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = widget.action;
    switch (a.type) {
      case AgentActionType.addToPlan:
        final done = _alreadyInPlan == true;
        return _card(
          icon: Icons.event_available,
          color: AppColors.primary,
          title: AgentStrings.addTitle(a.skillIds.map(_name).join('、')),
          note: a.note,
          trailing: done
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  const SizedBox(width: 4),
                  Text(AgentStrings.added, key: const Key('agent_action_done'), style: t.labelMedium),
                ])
              : FilledButton(
                  key: const Key('agent_action_confirm'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: _busy || _alreadyInPlan == null ? null : _confirm,
                  child: const Text(AgentStrings.confirmAdd),
                ),
        );
      case AgentActionType.startTraining:
        final id = a.skillIds.firstOrNull ?? '';
        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('agent_action_train'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(AgentStrings.startTraining(_name(id))),
            onPressed: () => context.push('/skill/$id'),
          ),
        );
      case AgentActionType.referVet:
      case AgentActionType.referTrainer:
        final vet = a.type == AgentActionType.referVet;
        return _card(
          icon: vet ? Icons.local_hospital_outlined : Icons.support_agent,
          color: vet ? const Color(0xFFC84B4B) : AppColors.streak,
          title: vet ? AgentStrings.referVet : AgentStrings.referTrainer,
          note: a.note,
        );
    }
  }

  Widget _card({required IconData icon, required Color color, required String title, String note = '', Widget? trailing}) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleSmall),
              if (note.isNotEmpty) Text(note, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}
