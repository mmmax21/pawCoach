/// AI 对话页（AI-1 / AI-2 / AI-6 / AI-7，M3 简报第 5、6、16 节）。
///
/// 首版默认 library 模式：回答为内容库直出，即时返回、零网络，不显示"正在思考"。
/// model 模式（构建开关）保留原有流式实现。
///
/// - 课程内提问：带 skill_id（跟练页还带当前步骤），按 (dog_id, skill_id) 复用对话；
/// - 诊断后自由提问：带 conversation_id 与 issue_id；
/// - 自由提问：不带上下文，每只狗复用一个对话。
/// 流式显示；每条助手回答下方"参考内容"折叠区；网络失败显示固定提示，消息不入库。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/ai/ai_client.dart';
import '../../data/ai/ai_coach_engine.dart';
import '../../data/ai/coach_agent.dart';
import '../../data/db/database.dart';
import '../../domain/answer_composer.dart';
import '../../domain/models.dart';
import '../../domain/retrieval.dart';
import 'agent_widgets.dart';

class ChatStrings {
  const ChatStrings._();
  static const offline = '教练暂时联系不上，稍后再试';
  static const thinking = '正在思考…';
  static const hint = '问问教练';
  static const refs = '参考内容';
  static const empty = '回答只依据内容库。健康问题请咨询兽医。';
  // 补检索（2026-11-18）：没命中时不再是死胡同
  static const maybe = '你可能想问';
  static const tryDiagnosis = '试试问题诊断';
  static const browseSkills = '浏览技能树';
  static const examplesTitle = '可以这样问';
  /// 示例问题：都是内容库能直接回答的问法（有测试保证命中）。
  static const examples = [
    '坐下练了三天还是不坐怎么办',
    '在家叫得回来，出门就叫不回',
    '一出门就拽着绳子往前冲',
    '换牙期老咬手怎么办',
    '每天练多久合适？一次练几遍？', // v1.4 常见问题
  ];
}

final _messagesProvider =
    StreamProvider.family<List<AiMessage>, String>((ref, convId) {
  return ref.watch(aiRepositoryProvider).watchMessages(convId);
});

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.skillId,
    this.issueId,
    this.conversationId,
    this.step,
    this.part,
  });
  final String? skillId;
  final String? issueId;
  final String? conversationId;

  /// 跟练页进入时的当前步骤（从 1 开始）。
  final int? step;

  /// 跟练页进入时正在跟练的脚本 part（0 为 mini_script）。
  final int? part;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  AiConversation? _conv;
  String? _dogId;
  /// 在线模式进行中：已执行的工具（界面逐条显示）。null 表示不在在线流程中。
  List<String>? _agentSteps;
  String? _error;
  bool _sending = false;
  String? _pendingQuestion;
  String _streaming = '';
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final dog = await ref.read(dogRepositoryProvider).currentDog();
      if (dog == null) throw StateError('还没有建档');
      final repo = ref.read(aiRepositoryProvider);
      AiConversation? conv;
      if (widget.conversationId != null) {
        conv = await repo.conversation(widget.conversationId!);
      }
      conv ??= widget.skillId != null
          ? await repo.courseConversation(dog.id, widget.skillId!)
          : await repo.freeConversation(dog.id);
      if (!mounted) return;
      setState(() {
        _dogId = dog.id;
        _conv = conv;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? get _skillId => widget.skillId ?? _conv?.skillId;
  String? get _issueId => widget.issueId ?? _conv?.issueId;

  /// 第 [i] 条消息之前最近的一条用户提问（给"没命中"的回复算"你可能想问"）。
  String? _questionBefore(List<AiMessage> messages, int i) {
    for (var k = i - 1; k >= 0; k--) {
      if (messages[k].role == 'user') return messages[k].content;
    }
    return null;
  }

  /// 在线模式：AI 助理训犬师。成功返回 true；连不上服务返回 false（调用方改走离线）。
  Future<bool> _sendOnline(String q, AiConversation conv, String dogId) async {
    final repo = ref.read(aiRepositoryProvider);
    setState(() => _agentSteps = []);
    try {
      final lib = await ref.read(contentLibraryProvider.future);
      final agent = CoachAgent(
        library: lib,
        client: ref.read(agentClientProvider),
        toolbox: AgentToolbox(
          db: ref.read(databaseProvider),
          library: lib,
          dogId: dogId,
          clock: ref.read(clockProvider),
        ),
      );
      final history = await repo.recentTurns(conv.id);
      CoachAnswer? done;
      await for (final e in agent.ask(question: q, history: history, contextSkillId: _skillId)) {
        switch (e) {
          case AgentStep(:final label):
            if (mounted) setState(() => _agentSteps = [...?_agentSteps, label]);
            _scrollToEnd();
          case AgentDone(:final answer):
            done = answer;
        }
      }
      if (done != null) await repo.addExchange(conversationId: conv.id, question: q, answer: done);
      if (mounted) {
        setState(() {
          _sending = false;
          _pendingQuestion = null;
          _agentSteps = null;
        });
        _scrollToEnd();
      }
      return true;
    } on AiClientException catch (e) {
      debugPrint('[agent] 在线失败：$e');
      if (mounted) setState(() => _agentSteps = null);
      return false;
    }
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    final conv = _conv;
    final dogId = _dogId;
    if (q.isEmpty || conv == null || dogId == null || _sending) return;
    setState(() {
      _sending = true;
      _pendingQuestion = q;
      _streaming = '';
    });
    _input.clear();
    final repo = ref.read(aiRepositoryProvider);
    final mode = ref.read(aiModeProvider);
    if (ref.read(aiOnlineProvider)) {
      final ok = await _sendOnline(q, conv, dogId);
      if (ok) return;
      // 在线失败：自动改用离线模式回答（内容库直出），并提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(key: Key('chat_fell_back'), content: Text(AgentStrings.fellBack)),
        );
      }
    }
    try {
      final lib = await ref.read(contentLibraryProvider.future);
      // library 模式不读 aiClientProvider：HTTP 客户端根本不会被创建（16.8 零网络）。
      final engine = AiCoachEngine(
        library: lib,
        mode: mode,
        client: mode == AiMode.model ? ref.read(aiClientProvider) : null,
      );
      final dog = await repo.dogBrief(
        dogId: dogId,
        content: lib,
        skillId: _skillId,
        currentStep: widget.step,
      );
      final history = mode == AiMode.model
          ? await repo.recentTurns(conv.id)
          : const <ChatTurn>[];
      final cues = mode == AiMode.library
          ? {
              for (final c
                  in await ref.read(profileRepositoryProvider).cues(dogId))
                c.skillId: CueView(cueWord: c.cueWord, gesture: c.gestureText),
            }
          : const <String, CueView>{};
      CoachAnswer? done;
      await for (final e in engine.ask(
        question: q,
        dog: dog,
        skillId: _skillId,
        issueId: _issueId,
        history: history,
        scriptPart: widget.part,
        cues: cues,
      )) {
        switch (e) {
          case CoachDelta(:final text):
            if (mounted) setState(() => _streaming = text);
            _scrollToEnd();
          case CoachDone(:final answer):
            done = answer;
        }
      }
      if (done != null) {
        await repo.addExchange(
            conversationId: conv.id, question: q, answer: done);
      }
    } on AiClientException catch (e) {
      debugPrint('[ai] 网络失败：$e');
      if (mounted) {
        _input.text = q; // 不入库，把问题还给输入框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('chat_offline'),
            content: Text(ChatStrings.offline),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pendingQuestion = null;
          _streaming = '';
        });
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    // ListView 懒加载，maxScrollExtent 在新条目布局后才准确：跳两次。
    void jump() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (_scroll.offset < max) _scroll.jumpTo(max);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final conv = _conv;
    final title = _skillId != null
        ? '问教练 · ${lib?.skillById[_skillId]?.name ?? _skillId}'
        : _issueId != null
            ? '问教练 · ${lib?.issueById[_issueId]?.name ?? _issueId}'
            : '问教练';
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text(_error!)));
    }
    if (conv == null || lib == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final messages =
        ref.watch(_messagesProvider(conv.id)).valueOrNull ?? const [];
    if (messages.length != _lastCount) {
      // 新消息入库（含固定话术，它没有流式过程）后滚到底，避免回答落在屏幕外。
      _lastCount = messages.length;
      _scrollToEnd();
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [AiModeToggle()]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('chat_list'),
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  if (messages.isEmpty && _pendingQuestion == null) ...[
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child:
                          Text(ChatStrings.empty, textAlign: TextAlign.center),
                    ),
                    // 课程内提问已带技能上下文，不需要示例
                    if (_skillId == null)
                      _ExampleQuestions(onPick: (q) {
                        _input.text = q;
                        _send();
                      }),
                  ],
                  for (final (i, m) in messages.indexed)
                    _MessageBubble(
                      message: m,
                      library: lib,
                      question: _questionBefore(messages, i),
                      dogId: _dogId,
                    ),
                  if (_pendingQuestion != null && _agentSteps != null) ...[
                    _Bubble(text: _pendingQuestion!, fromUser: true),
                    AgentWorking(steps: _agentSteps!),
                  ],
                  if (_pendingQuestion != null &&
                      _agentSteps == null &&
                      ref.read(aiModeProvider) == AiMode.model) ...[
                    _Bubble(text: _pendingQuestion!, fromUser: true),
                    _Bubble(
                      key: const Key('chat_streaming'),
                      text: _streaming.isEmpty
                          ? ChatStrings.thinking
                          : _streaming,
                      fromUser: false,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat_input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: ChatStrings.hint,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('chat_send'),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {super.key,
      required this.text,
      required this.fromUser,
      this.tone,
      this.body,
      this.footer});
  final String text;
  final bool fromUser;
  final Color? tone;

  /// 自定义正文（回答块）；为 null 时显示 [text]。
  final Widget? body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4),
        // 用 Material 承载底色：折叠区里的 ListTile 需要 Material 祖先绘制点击效果。
        child: Material(
          color: tone ??
              (fromUser ? cs.primaryContainer : cs.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                body ?? SelectableText(text),
                if (footer != null) footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.library, this.question, this.dogId});
  final AiMessage message;
  final ContentLibrary library;
  final String? dogId;

  /// 这条回复对应的用户提问；没命中时据此给出"你可能想问"。
  final String? question;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kind = kindFromDb(message.kind);
    if (message.role == 'user') {
      return _Bubble(text: message.content, fromUser: true);
    }
    final cited = [
      for (final e in jsonDecode(message.citedContentIds) as List) e.toString()
    ];
    final guard =
        kind == AiMessageKind.guardHealth || kind == AiMessageKind.guardNoHit;
    // 在线模式（AI 助理训犬师）的回答：正文 + 查看过的信息 + 操作卡片
    final agent = AgentMessageParts.parse(message.content);
    if (agent.isAgent) {
      return _Bubble(
        key: Key('msg_${message.id}'),
        text: agent.text,
        fromUser: false,
        tone: guard ? cs.tertiaryContainer : null,
        body: SelectableText(agent.text),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AgentAnswerExtras(parts: agent, library: library, dogId: dogId),
            if (cited.isNotEmpty) _RefsFold(ids: cited, library: library),
          ],
        ),
      );
    }
    return _Bubble(
      key: Key('msg_${message.id}'),
      text: message.content,
      fromUser: false,
      tone: guard ? cs.tertiaryContainer : null,
      body: guard
          ? null
          : _AnswerBody(snapshot: message.content, library: library),
      footer: kind == AiMessageKind.guardNoHit
          ? _NoHitHelp(
              suggestions: question == null
                  ? const []
                  : retrieve(message: question!, library: library).suggestions,
              library: library,
            )
          : cited.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnswerActions(ids: cited, library: library),
                _RefsFold(ids: cited, library: library),
              ],
            ),
    );
  }
}

/// 按块渲染回答（16.5）。数据来自入库的纯文本快照，历史与新回答渲染一致；
/// 内容库升级后历史对话的文字不变。
class _AnswerBody extends StatelessWidget {
  const _AnswerBody({required this.snapshot, required this.library});
  final String snapshot;
  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    final lines = [for (final raw in snapshot.split('\n')) parseSnapshotLine(raw)];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // M4 批次 B：【常见错误】默认折叠，标题显示条数，展开为内容库原文（快照不变，只改展示）。
      if (line.type == SnapshotLineType.label && line.text == tplLabelMistakes) {
        final items = <String>[];
        while (i + 1 < lines.length && lines[i + 1].type == SnapshotLineType.bullet) {
          items.add(lines[++i].text);
        }
        children.add(_MistakesFold(items: items));
        continue;
      }
      switch (line.type) {
        case SnapshotLineType.title:
          children.add(Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Text(line.text, style: t.titleMedium),
          ));
        case SnapshotLineType.label:
          children.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(line.text,
                style: t.labelLarge?.copyWith(color: cs.primary)),
          ));
        case SnapshotLineType.bullet:
          children.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(child: SelectableText(line.text))
            ],
          ));
        case SnapshotLineType.link:
          final target =
              library.skills.where((s) => s.name == line.text).firstOrNull;
          children.add(target == null
              ? Text(line.text)
              : TextButton.icon(
                  key: Key('answer_downgrade_${target.id}'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(line.text),
                  onPressed: () => context.push('/skill/${target.id}'),
                ));
        case SnapshotLineType.body:
          if (line.text.isEmpty) continue;
          children.add(SelectableText(line.text));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// 【常见错误】折叠区：默认收起，标题"【常见错误】（N 条）"，展开后逐条显示原文。
class _MistakesFold extends StatelessWidget {
  const _MistakesFold({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('answer_mistakes_fold'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        initiallyExpanded: false,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text('$tplLabelMistakes（${items.length} 条）',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
        children: [
          for (final m in items)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('• '), Expanded(child: SelectableText(m))],
            ),
        ],
      ),
    );
  }
}

/// 16.2："看教程"入口（技能）与"开始诊断"按钮（问题行为），按 cited_content_ids 生成。
class _AnswerActions extends StatelessWidget {
  const _AnswerActions({required this.ids, required this.library});
  final List<String> ids;
  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final id in ids) {
      if (library.skillById[id] case final s?) {
        chips.add(ActionChip(
          key: Key('answer_tutorial_$id'),
          avatar: const Icon(Icons.school_outlined, size: 18),
          label: Text('看教程 · ${s.name}'),
          onPressed: () => context.push('/skill/$id'),
        ));
      } else if (library.issueById[id] case final i?) {
        chips.add(ActionChip(
          key: Key('answer_diagnose_$id'),
          avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
          label: Text('开始诊断 · ${i.name}'),
          onPressed: () => context.push('/coach/diagnosis?issue=$id'),
        ));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }
}

/// AI-6：参考内容折叠区。技能可点进技能详情页。
class _RefsFold extends StatelessWidget {
  const _RefsFold({required this.ids, required this.library});
  final List<String> ids;
  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('chat_refs'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        title: Text('${ChatStrings.refs}（${ids.length}）',
            style: Theme.of(context).textTheme.labelMedium),
        children: [
          for (final id in ids)
            if (library.skillById[id] case final s?)
              ListTile(
                key: Key('ref_$id'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined, size: 18),
                title: Text('技能 · ${s.name}'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/skill/${s.id}'),
              )
            else if (library.faqById[id] case final f?)
              ListTile(
                key: Key('ref_$id'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline, size: 18),
                title: Text('常见问题 · ${f.question}'),
              )
            else if (library.issueById[id] case final i?)
              ListTile(
                key: Key('ref_$id'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.report_outlined, size: 18),
                title: Text('问题行为 · ${i.name}'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/coach/diagnosis?issue=${i.id}'),
              ),
        ],
      ),
    );
  }
}

/// 没命中时的出路：内容库里相近的条目 + 问题诊断 / 技能树入口。回复文字本身不变。
class _NoHitHelp extends StatelessWidget {
  const _NoHitHelp({required this.suggestions, required this.library});
  final List<String> suggestions;
  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const Key('nohit_help'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suggestions.isNotEmpty) ...[
            Text(ChatStrings.maybe, style: t.labelLarge),
            _AnswerActions(ids: suggestions, library: library),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                key: const Key('nohit_diagnosis'),
                avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
                label: const Text(ChatStrings.tryDiagnosis),
                onPressed: () => context.push('/coach/diagnosis'),
              ),
              ActionChip(
                key: const Key('nohit_skills'),
                avatar: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text(ChatStrings.browseSkills),
                onPressed: () => context.go('/skills'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 空对话时的示例问题，点一下直接提问。
class _ExampleQuestions extends StatelessWidget {
  const _ExampleQuestions({required this.onPick});
  final void Function(String q) onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const Key('chat_examples'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ChatStrings.examplesTitle, style: t.titleSmall),
          const SizedBox(height: 8),
          for (final (i, q) in ChatStrings.examples.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('chat_example_$i'),
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: () => onPick(q),
                child: Text(q),
              ),
            ),
        ],
      ),
    );
  }
}
