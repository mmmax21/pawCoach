/// AI 教练 Tab：问题诊断入口 + 该狗的对话记录（AI-3 / AI-7）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/mascot.dart';
import '../../core/app_nav.dart';
import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ai_repository.dart';
import '../../domain/models.dart';
import 'agent_widgets.dart';

final dogConversationsProvider = StreamProvider.autoDispose<List<AiConversation>>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield const [];
    return;
  }
  yield* ref.watch(aiRepositoryProvider).watchConversations(dog.id);
});

String conversationTitle(AiConversation c, ContentLibrary? lib) {
  if (c.type == convDiagnosis) {
    final name = lib?.issueById[c.issueId]?.name ?? c.issueId ?? '';
    return '问题诊断 · $name';
  }
  if (c.skillId == null) return '自由提问';
  return '课程提问 · ${lib?.skillById[c.skillId]?.name ?? c.skillId}';
}

class CoachHomePage extends ConsumerWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(dogConversationsProvider);
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 教练'), actions: const [AiModeToggle()]),
      bottomNavigationBar: const AppBottomNav(current: AppTab.coach),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModeHint(online: ref.watch(aiOnlineProvider)),
          const SizedBox(height: 12),
          Card(
            key: const Key('coach_diagnosis_entry'),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.psychology_alt_outlined),
              title: const Text('问题诊断'),
              subtitle: const Text('选一个困扰，按步骤回答几个问题，得到训练方案'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/diagnosis'),
            ),
          ),
          Card(
            key: const Key('coach_free_entry'),
            child: ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('自由提问'),
              subtitle: const Text('回答只依据内容库；练某个技能时可在技能页点"问教练"'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/chat'),
            ),
          ),
          const SizedBox(height: 16),
          Text('对话记录', style: t.titleMedium),
          const SizedBox(height: 8),
          convs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('读取对话失败：$e'),
            data: (list) => list.isEmpty
                ? const EmptyState(title: '还没有对话', hint: '遇到问题时，试试上面的问题诊断', compact: true)
                : Column(
                    children: [
                      for (final c in list)
                        ListTile(
                          key: Key('conv_${c.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(c.type == convDiagnosis
                              ? Icons.psychology_alt_outlined
                              : Icons.chat_bubble_outline),
                          title: Text(conversationTitle(c, lib)),
                          subtitle: Text(_shortTime(c.updatedAt)),
                          onTap: () => context.push(
                              '/coach/chat?conv=${c.id}${c.skillId != null ? '&skill=${c.skillId}' : ''}${c.issueId != null ? '&issue=${c.issueId}' : ''}'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _shortTime(String iso) {
  final t = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.month}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class _ModeHint extends StatelessWidget {
  const _ModeHint({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      key: const Key('ai_mode_hint'),
      children: [
        Icon(online ? Icons.auto_awesome : Icons.menu_book_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(child: Text(online ? AgentStrings.onlineHint : AgentStrings.offlineHint, style: t.bodySmall)),
      ],
    );
  }
}
