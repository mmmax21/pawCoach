import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../video/video_check_page.dart';
import '../video/live_timer_page.dart';

/// 技能详情 / 教程页（TR-1）：summary、steps、common_mistakes、success_criteria，
/// 底部"开始跟练"进入全屏跟练。
///
/// [part]：从首页保底任务进入时为 0（跟练 mini_script），从目标进入时为 1；
/// 多段脚本的技能（script_parts ≥ 2）在页面里让用户选 part。
class SkillDetailPage extends ConsumerWidget {
  const SkillDetailPage({super.key, required this.skillId, this.part});
  final String skillId;
  final int? part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentLibraryProvider);
    final t = Theme.of(context).textTheme;

    return content.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('内容库加载失败：$e'))),
      data: (lib) {
        final skill = lib.skillById[skillId];
        if (skill == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('技能 $skillId 不存在')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(skill.name),
            actions: [
              TextButton.icon(
                key: const Key('skill_ask_coach'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('问教练'),
                onPressed: () => context.push('/coach/chat?skill=${skill.id}'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, AppSpace.xs, AppSpace.page, AppSpace.xl),
            children: [
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  _MetaChip(icon: Icons.star_rounded, text: '难度 ${difficultyStars(skill.difficulty)}'),
                  _MetaChip(icon: Icons.cake_outlined, text: '${skill.minAgeWeeks} 周起'),
                  _MetaChip(icon: Icons.emoji_events_outlined, text: '掌握需 ${skill.sessionsToMaster} 次完全做到'),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Text(skill.tutorial.summary, style: t.bodyLarge),
              const SizedBox(height: AppSpace.lg),
              _CueCard(cue: skill.defaultCue, gesture: skill.defaultGesture),
              const SizedBox(height: AppSpace.xl),
              _SectionTitle(icon: Icons.format_list_numbered_rounded, text: '步骤', trailing: '${skill.tutorial.steps.length} 步'),
              const SizedBox(height: AppSpace.sm),
              for (var i = 0; i < skill.tutorial.steps.length; i++)
                _StepCard(index: i + 1, text: skill.tutorial.steps[i].text, last: i == skill.tutorial.steps.length - 1),
              const SizedBox(height: AppSpace.lg),
              Card(
                key: const Key('skill_mistakes'),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: AppColors.streak),
                    title: Text('常见错误（${skill.tutorial.commonMistakes.length} 条）', style: t.titleMedium),
                    childrenPadding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final m in skill.tutorial.commonMistakes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 7, right: 8),
                                child: Icon(Icons.circle, size: 6, color: AppColors.streak),
                              ),
                              Expanded(child: Text(m, style: t.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(AppSpace.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: AppSpace.sm),
                        Text('成功标准', style: t.titleMedium?.copyWith(color: const Color(0xFF1F5233))),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(skill.tutorial.successCriteria, style: t.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              // M5（AI-4）：视频纠错入口（默认显示"敬请期待"）
              LiveTimerEntry(skill: skill),
              const SizedBox(height: AppSpace.sm),
              VideoCheckSection(skill: skill),
              const SizedBox(height: AppSpace.lg),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _StartButtons(skill: skill, fixedPart: part),
            ),
          ),
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(text, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text, this.trailing});
  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpace.sm),
        Text(text, style: t.titleMedium),
        if (trailing != null) ...[
          const SizedBox(width: AppSpace.sm),
          Text(trailing!, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// 口令与手势：现场最常回看的两样，放大显示。
class _CueCard extends StatelessWidget {
  const _CueCard({required this.cue, required this.gesture});
  final String cue;
  final String gesture;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSpace.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_outlined, size: 20, color: AppColors.primaryDeep),
              const SizedBox(width: AppSpace.sm),
              Text('口令：', style: t.titleSmall?.copyWith(color: AppColors.primaryDeep)),
              Text(cue, style: t.titleLarge?.copyWith(color: AppColors.primaryDeep)),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.back_hand_outlined, size: 20, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text('手势：$gesture', style: t.bodyMedium)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一步一张卡，左侧编号与竖线串起来。
class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.text, required this.last});
  final int index;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text('$index', style: t.labelLarge?.copyWith(color: Colors.white)),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: AppColors.primarySoft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md + 2),
                child: Text(text, style: t.bodyLarge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 开始跟练按钮。保底入口（part == 0）只出一个按钮；
/// 正式入口按 script_parts 出 1 个或多个按钮。
class _StartButtons extends StatelessWidget {
  const _StartButtons({required this.skill, required this.fixedPart});
  final Skill skill;
  final int? fixedPart;

  @override
  Widget build(BuildContext context) {
    void go(int part) => context.push('/training/${skill.id}/$part');
    if (fixedPart == miniScriptPart) {
      return FilledButton(
        key: const Key('start_training_mini'),
        onPressed: () => go(miniScriptPart),
        child: Text('开始保底跟练（约 ${skill.miniDurationMinutes} 分钟）'),
      );
    }
    if (skill.scriptParts <= 1) {
      return FilledButton(
        key: const Key('start_training'),
        onPressed: () => go(1),
        child: Text('开始跟练（约 ${skill.partDurationMinutes(1)} 分钟）'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var p = 1; p <= skill.scriptParts; p++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: Key('start_training_part_$p'),
                onPressed: () => go(p),
                child: Text(
                    '开始跟练 第 $p 部分（约 ${skill.partDurationMinutes(p)} 分钟）'),
              ),
            ),
          ),
      ],
    );
  }
}
