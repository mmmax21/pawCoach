import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

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
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                  '${difficultyStars(skill.difficulty)} · ${skill.minAgeWeeks} 周起 · 掌握需 ${skill.sessionsToMaster} 次完全做到',
                  style: t.labelMedium),
              const SizedBox(height: 12),
              Text(skill.tutorial.summary, style: t.bodyLarge),
              const SizedBox(height: 16),
              Text('口令：${skill.defaultCue}', style: t.titleSmall),
              Text('手势：${skill.defaultGesture}', style: t.bodyMedium),
              const SizedBox(height: 16),
              Text('步骤', style: t.titleMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < skill.tutorial.steps.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                  title: Text(skill.tutorial.steps[i].text),
                ),
              const SizedBox(height: 16),
              Text('常见错误', style: t.titleMedium),
              const SizedBox(height: 8),
              for (final m in skill.tutorial.commonMistakes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(m)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text('成功标准', style: t.titleMedium),
              const SizedBox(height: 8),
              Text(skill.tutorial.successCriteria),
              const SizedBox(height: 32),
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
