/// 问题行为诊断（AI-3 / WP-8，M3 简报第 7 节）。
///
/// 选问题（或输入描述 → 本地检索取最高分 issue）→ 按 diagnosis_tree 逐题追问（选项即按钮）
/// → 结果页渲染 solutions[result] 原文 → 加入本周 / 下周计划 → 可继续自由提问。
/// 追问与结果全部来自内容库，不调模型。escalate_if 放在方案最前面醒目展示。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import 'diagnosis_add_text.dart';
import '../../data/repositories/household_repository.dart' show displayNickname;
import '../../data/ai/ai_coach_engine.dart';
import '../../domain/ai_guard.dart';
import '../../domain/diagnosis.dart';
import '../../domain/models.dart';
import '../../domain/plan_generator.dart';
import '../../domain/retrieval.dart';

class DiagnosisStrings {
  const DiagnosisStrings._();
  static const title = '问题诊断';
  static const pick = '狗狗现在最让你头疼的是？';
  static const describeHint = '或者描述一下情况';
  static const describeGo = '开始诊断';
  static const escalate = '出现以下情况请停止自行训练，尽快求助专业训犬师';
  static const summary = '判断';
  static const skills = '建议练习的技能';
  static const management = '环境管理';
  static const addThisWeek = '加入本周计划';
  static const addNextWeek = '加入下周计划';
  static const askMore = '继续提问';
  static const restart = '重新诊断';
}

String skillStatusLabel(String? status) => switch (status) {
      'mastered' => '已掌握',
      'in_progress' => '练习中',
      'available' => '可以开始',
      'locked' => '前置未完成',
      _ => '—',
    };

class DiagnosisPage extends ConsumerStatefulWidget {
  const DiagnosisPage({super.key, this.initialIssueId});
  final String? initialIssueId;

  @override
  ConsumerState<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends ConsumerState<DiagnosisPage> {
  final _describe = TextEditingController();
  Issue? _issue;
  final List<int> _path = [];
  String? _conversationId;
  String? _resultId;
  String? _notice; // 描述输入命中固定话术时展示
  Map<String, String> _statuses = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final id = widget.initialIssueId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lib = await ref.read(contentLibraryProvider.future);
        final issue = lib.issueById[id];
        if (issue != null && mounted) await _start(issue);
      });
    }
  }

  @override
  void dispose() {
    _describe.dispose();
    super.dispose();
  }

  Future<String> _dogId() async {
    final dog = await ref.read(dogRepositoryProvider).currentDog();
    if (dog == null) throw StateError('还没有建档');
    return dog.id;
  }

  Future<void> _start(Issue issue) async {
    final dogId = await _dogId();
    final repo = ref.read(aiRepositoryProvider);
    final conv = await repo.newDiagnosisConversation(dogId, issue.id);
    final statuses = await repo.skillStatusMap(dogId);
    if (!mounted) return;
    setState(() {
      _issue = issue;
      _path.clear();
      _conversationId = conv.id;
      _resultId = null;
      _notice = null;
      _statuses = statuses;
    });
  }

  /// 输入描述：第一层健康拦截 → 第二层在问题行为里取最高分。都不调模型。
  Future<void> _startFromDescription(ContentLibrary lib) async {
    final text = _describe.text.trim();
    if (text.isEmpty) return;
    if (checkHealthGuard(text, lib.aiGuard).blocked) {
      setState(() => _notice = healthGuardReply);
      return;
    }
    final id = bestIssueFor(text, lib);
    if (id == null) {
      setState(() => _notice = noHitGuardReply);
      return;
    }
    await _start(lib.issueById[id]!);
  }

  Future<void> _answer(DiagnosisQuestion q, int option) async {
    final issue = _issue!;
    final conv = _conversationId!;
    final repo = ref.read(aiRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.addMessage(
        conversationId: conv,
        role: 'assistant',
        content: q.node.question,
        kind: AiMessageKind.diagnosisQ,
      );
      await repo.addMessage(
        conversationId: conv,
        role: 'user',
        content: q.node.options[option].text,
        kind: AiMessageKind.normal,
      );
      final next = diagnosisNext(issue, [..._path, option]);
      String? resultId;
      if (next is DiagnosisOutcome) {
        await repo.addMessage(
          conversationId: conv,
          role: 'assistant',
          content: next.solution.summary,
          kind: AiMessageKind.diagnosisResult,
          cited: [issue.id, ...next.solution.skills],
        );
        resultId = await repo.saveDiagnosisResult(
          conversationId: conv,
          dogId: await _dogId(),
          issueId: issue.id,
          resultKey: next.resultKey,
          solutionSkills: next.solution.skills,
        );
      }
      if (!mounted) return;
      setState(() {
        _path.add(option);
        _resultId = resultId;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addThisWeek(ContentLibrary lib) async {
    final id = _resultId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(aiRepositoryProvider).addToThisWeek(
            diagnosisResultId: id,
            content: lib,
          );
      if (!mounted) return;
      await _showAddResult(lib, r);
    } catch (e) {
      if (mounted) _snack('加入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNextWeek(ContentLibrary lib) async {
    final id = _resultId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(aiRepositoryProvider);
      await repo.addToNextWeek(diagnosisResultId: id);
      final preview = await repo.previewNextWeek(diagnosisResultId: id, content: lib);
      if (!mounted) return;
      _snack('已标记，下周计划生成时优先安排这些技能');
      await _showAddResult(lib, preview, nextWeek: true);
    } catch (e) {
      if (mounted) _snack('加入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(key: const Key('diagnosis_snack'), content: Text(text)));

  Future<void> _showAddResult(ContentLibrary lib, DiagnosisWeekAddition r,
      {bool nextWeek = false}) {
    String name(String id) => lib.skillById[id]?.name ?? id;
    final week = nextWeek ? '下周' : '本周';
    String reason(DiagnosisSkip s) => switch (s.reason) {
          DiagnosisSkipReason.mastered => '已掌握',
          DiagnosisSkipReason.alreadyInPlan => '已在计划中',
          DiagnosisSkipReason.ageTooYoung => '${s.untilWeeks} 周龄后再练',
          DiagnosisSkipReason.prerequisitesUnmet =>
            '前置未满足（需先掌握：${s.missing.map(name).join('、')}）',
          DiagnosisSkipReason.capReached => s.forSkill == null
              ? '$week目标已满 $diagnosisWeekGoalCap 个，超出部分未加入'
              : '$week目标已满 $diagnosisWeekGoalCap 个，未加入（原为${name(s.forSkill!)}打基础）',
          DiagnosisSkipReason.unknownSkill => '内容库中没有这个技能',
        };
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('diagnosis_add_result'),
        title: Text(r.added.isEmpty
            ? (r.foundations.isNotEmpty
                ? (nextWeek ? '下周计划已在为它打基础' : '本周计划已在为它打基础')
                : (nextWeek ? '下周没有新增目标' : '没有新增目标'))
            : (nextWeek ? '下周将加入' : '已加入本周计划')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in r.added) Text('＋ ${name(g.skillId)}（目标 ${g.targetSessions} 次）'),
              if (r.foundations.isNotEmpty) const SizedBox(height: 8),
              for (final l in foundationLines(r, name, nextWeek: nextWeek))
                Text(l.text, key: Key(l.key)),
              if (r.skipped.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('跳过：'),
                for (final s in r.skipped) Text('· ${name(s.skillId)}：${reason(s)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('diagnosis_add_ok'),
            onPressed: () => Navigator.pop(c),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libAsync = ref.watch(contentLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(DiagnosisStrings.title)),
      body: libAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('内容库加载失败：$e')),
        data: (lib) {
          final issue = _issue;
          if (issue == null) return _pickView(lib);
          final step = diagnosisNext(issue, _path);
          return switch (step) {
            DiagnosisQuestion() => _questionView(issue, step),
            DiagnosisOutcome() => _resultView(lib, issue, step),
          };
        },
      ),
    );
  }

  Widget _pickView(ContentLibrary lib) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(DiagnosisStrings.pick, style: t.titleMedium),
        const SizedBox(height: 8),
        for (final i in lib.issues)
          Card(
            child: ListTile(
              key: Key('issue_${i.id}'),
              title: Text(i.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _start(i),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('diagnosis_describe'),
          controller: _describe,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: DiagnosisStrings.describeHint,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const Key('diagnosis_describe_go'),
          onPressed: () => _startFromDescription(lib),
          child: const Text(DiagnosisStrings.describeGo),
        ),
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Card(
            key: const Key('diagnosis_notice'),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_notice!)),
          ),
        ],
      ],
    );
  }

  Widget _questionView(Issue issue, DiagnosisQuestion q) {
    final t = Theme.of(context).textTheme;
    final answers = diagnosisAnswers(issue, _path);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(issue.name, style: t.labelLarge),
        const SizedBox(height: 4),
        for (final a in answers)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${a.question}  →  ${a.option}', style: t.bodySmall),
          ),
        const SizedBox(height: 12),
        Text('第 ${q.depth} 问', style: t.labelMedium),
        const SizedBox(height: 4),
        Text(q.node.question, key: const Key('diagnosis_question'), style: t.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < q.node.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: Key('diagnosis_option_$i'),
              onPressed: _busy ? null : () => _answer(q, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(q.node.options[i].text),
              ),
            ),
          ),
        TextButton(
          key: const Key('diagnosis_restart'),
          onPressed: () => setState(() => _issue = null),
          child: const Text(DiagnosisStrings.restart),
        ),
      ],
    );
  }

  Widget _resultView(ContentLibrary lib, Issue issue, DiagnosisOutcome o) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sol = o.solution;
    return ListView(
      key: const Key('diagnosis_result'),
      padding: const EdgeInsets.all(16),
      children: [
        // M3 决策第 6 条：同分时维持首次命中，结果页顶部给一个返回问题列表的出口。
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('diagnosis_not_this'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: () => setState(() => _issue = null),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('不是这个问题？'),
          ),
        ),
        Text(issue.name, style: t.titleMedium),
        if (_resultId != null) _DiagnosedBy(resultId: _resultId!),
        const SizedBox(height: 12),
        // escalate_if 放在方案前面，醒目样式，原文完整展示（简报第 7 节、打回条件）。
        Card(
          key: const Key('diagnosis_escalate'),
          color: cs.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DiagnosisStrings.escalate,
                          style: t.titleSmall?.copyWith(color: cs.onErrorContainer)),
                      const SizedBox(height: 4),
                      Text(sol.escalateIf,
                          key: const Key('diagnosis_escalate_text'),
                          style: t.bodyLarge?.copyWith(color: cs.onErrorContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(DiagnosisStrings.summary, style: t.titleMedium),
        const SizedBox(height: 4),
        Text(sol.summary, key: const Key('diagnosis_summary')),
        const SizedBox(height: 16),
        Text(DiagnosisStrings.skills, style: t.titleMedium),
        for (final id in sol.skills)
          ListTile(
            key: Key('diagnosis_skill_$id'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined),
            title: Text(lib.skillById[id]?.name ?? id),
            subtitle: Text(skillStatusLabel(_statuses[id])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/skill/$id'),
          ),
        const SizedBox(height: 8),
        Text(DiagnosisStrings.management, style: t.titleMedium),
        const SizedBox(height: 4),
        for (final m in sol.management)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('• '), Expanded(child: Text(m))],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('diagnosis_add_this_week'),
                onPressed: _busy || _resultId == null ? null : () => _addThisWeek(lib),
                child: const Text(DiagnosisStrings.addThisWeek),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                key: const Key('diagnosis_add_next_week'),
                onPressed: _busy || _resultId == null ? null : () => _addNextWeek(lib),
                child: const Text(DiagnosisStrings.addNextWeek),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('diagnosis_ask_more'),
          icon: const Icon(Icons.chat_outlined),
          onPressed: () => context.push('/coach/chat?conv=$_conversationId&issue=${issue.id}'),
          label: const Text(DiagnosisStrings.askMore),
        ),
        TextButton(
          key: const Key('diagnosis_restart'),
          onPressed: () => setState(() => _issue = null),
          child: const Text(DiagnosisStrings.restart),
        ),
      ],
    );
  }
}


/// FM-5：诊断结果显示做诊断的成员昵称。
class _DiagnosedBy extends ConsumerWidget {
  const _DiagnosedBy({required this.resultId});
  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(nicknamesProvider).valueOrNull ?? const {};
    final me = ref.watch(currentUserIdProvider).valueOrNull;
    return FutureBuilder(
      future: ref.read(aiRepositoryProvider).diagnosisResult(resultId),
      builder: (_, snap) {
        final uid = snap.data?.userId;
        if (uid == null) return const SizedBox.shrink();
        return Text('诊断人：${displayNickname(names, uid, meId: me)}',
            key: const Key('diagnosis_by'), style: Theme.of(context).textTheme.bodySmall);
      },
    );
  }
}
