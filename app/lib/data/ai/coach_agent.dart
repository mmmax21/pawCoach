/// 在线模式：AI 助理训犬师（2026-11-18，比赛命题"给一个行业，造一位 AI 同事"）。
///
/// 行业：宠物训练服务；岗位：助理训犬师。Agent 在 App 里循环：模型决定调用哪些工具，
/// 工具在本机执行（读狗档案、训练记录、本周计划、内容库；按业务规则判断能不能练、能不能加进计划），
/// 写操作（改计划、开始跟练、转介）只生成"待主人确认"的操作卡片，主人点了才执行。
///
/// 边界（与离线模式一致）：
/// - 健康问题先由 [checkHealthGuard] 拦截，固定话术，不交给模型；
/// - 训练方法只依据内容库（search_library 返回的资料），回答里用 [ref: id] 标注出处；
/// - 计划改动必须经过 [addDiagnosisToWeek] 同一套规则（周龄、前置、已掌握、每周上限），模型无法绕过。
library;

import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;

import '../../domain/ai_guard.dart';
import '../../domain/models.dart';
import '../../domain/plan_generator.dart';
import '../../domain/retrieval.dart';
import '../db/database.dart';
import '../repositories/repositories.dart';
import '../repositories/session_repository.dart' show scoreFromDb;
import 'agent_client.dart';
import 'ai_client.dart' show ChatTurn;
import 'ai_coach_engine.dart';
import 'prompt_builder.dart' show renderFaqMaterial, renderIssueMaterial, renderSkillMaterial, scoreLabel;

/// 一次提问最多几轮工具调用（防止模型反复调用不收敛）。
const agentMaxRounds = 6;

// ---------------------------------------------------------------------------
// 操作卡片（待主人确认）与过程记录：编码在消息正文末尾，历史消息重新打开也能显示
// ---------------------------------------------------------------------------

enum AgentActionType { addToPlan, startTraining, referVet, referTrainer }

class AgentAction {
  const AgentAction(this.type, {this.skillIds = const [], this.note = ''});
  final AgentActionType type;
  final List<String> skillIds;
  final String note;

  String encode() => '$agentActionPrefix${type.name} ${skillIds.join(',')}|${note.replaceAll('\n', ' ')}';

  static AgentAction? decode(String line) {
    if (!line.startsWith(agentActionPrefix)) return null;
    final body = line.substring(agentActionPrefix.length);
    final sp = body.indexOf(' ');
    if (sp < 0) return null;
    final type = AgentActionType.values.where((t) => t.name == body.substring(0, sp)).firstOrNull;
    if (type == null) return null;
    final rest = body.substring(sp + 1);
    final bar = rest.indexOf('|');
    final ids = (bar < 0 ? rest : rest.substring(0, bar)).split(',').where((s) => s.isNotEmpty).toList();
    return AgentAction(type, skillIds: ids, note: bar < 0 ? '' : rest.substring(bar + 1));
  }
}

const agentTracePrefix = '§trace ';
const agentActionPrefix = '§action ';

/// 在线模式消息正文 = 回答文字 + 过程记录行 + 操作卡片行。
class AgentMessageParts {
  const AgentMessageParts(this.text, this.trace, this.actions);
  final String text;
  final List<String> trace;
  final List<AgentAction> actions;

  bool get isAgent => trace.isNotEmpty || actions.isNotEmpty;

  static AgentMessageParts parse(String content) {
    final text = <String>[];
    final trace = <String>[];
    final actions = <AgentAction>[];
    for (final line in content.split('\n')) {
      if (line.startsWith(agentTracePrefix)) {
        trace.addAll(line.substring(agentTracePrefix.length).split('|').where((s) => s.isNotEmpty));
      } else if (AgentAction.decode(line) case final a?) {
        actions.add(a);
      } else {
        text.add(line);
      }
    }
    return AgentMessageParts(text.join('\n').trim(), trace, actions);
  }

  String encode() => [
        text,
        if (trace.isNotEmpty) '$agentTracePrefix${trace.join('|')}',
        for (final a in actions) a.encode(),
      ].join('\n');
}

// ---------------------------------------------------------------------------
// 事件
// ---------------------------------------------------------------------------

sealed class AgentEvent {
  const AgentEvent();
}

/// 正在执行某个工具（界面显示"正在查看训练记录…"）。
class AgentStep extends AgentEvent {
  const AgentStep(this.label);
  final String label;
}

class AgentDone extends AgentEvent {
  const AgentDone(this.answer);
  final CoachAnswer answer;
}

// ---------------------------------------------------------------------------
// 工具
// ---------------------------------------------------------------------------

Map<String, dynamic> _tool(String name, String description, Map<String, dynamic> props, [List<String> required = const []]) => {
      'name': name,
      'description': description,
      'input_schema': {
        'type': 'object',
        'properties': props,
        'required': required,
        'additionalProperties': false,
      },
    };

/// 发给模型的工具清单。
final List<Map<String, dynamic>> agentTools = [
  _tool('get_dog_profile', '读取狗的档案：名字、周龄、性别、居住环境、每天可练时长、主人的困扰、已掌握与进行中的技能、全家统一的口令。回答前先了解这只狗。', {}),
  _tool('get_training_history', '读取最近的训练记录（日期、技能、评分、时长）和连续打卡天数。可以只看某个技能。', {
    'skill_id': {'type': 'string', 'description': '只看这个技能（可选）'},
    'limit': {'type': 'integer', 'description': '最多几条，默认 5，最多 10'},
  }),
  _tool('get_week_plan', '读取本周训练计划：目标技能、每项完成次数 / 目标次数、今日保底任务。', {}),
  _tool('search_library', '在训练内容库（技能教程、问题行为、常见问题）里检索。给出任何训练方法前必须先检索，只能依据返回的资料回答。', {
    'query': {'type': 'string', 'description': '检索内容，用主人的说法即可'},
  }, ['query']),
  _tool('check_skill_eligibility', '按业务规则判断这只狗现在能不能练某个技能：周龄窗口、前置技能是否掌握、是否已掌握、是否已在本周计划。建议练某个技能前先查。', {
    'skill_id': {'type': 'string'},
  }, ['skill_id']),
  _tool('propose_plan_change', '提议把某个技能加入本周计划。会按业务规则校验（周龄、前置、已掌握、每周目标上限），前置没掌握时会自动改为先练可练的前置技能。只生成确认卡片，主人点确认后才写入计划。', {
    'skill_id': {'type': 'string'},
    'reason': {'type': 'string', 'description': '给主人看的一句理由'},
  }, ['skill_id', 'reason']),
  _tool('suggest_start_training', '给主人一个"开始跟练"按钮，进入该技能的全屏跟练。', {
    'skill_id': {'type': 'string'},
  }, ['skill_id']),
  _tool('refer_to_professional', '转介：健康、受伤、疑似疼痛 → 兽医（vet）；攻击性强、持续恶化、超出内容库范围的问题行为 → 专业训犬师（trainer）。会给主人显示转介卡片。', {
    'kind': {'type': 'string', 'enum': ['vet', 'trainer']},
    'reason': {'type': 'string'},
  }, ['kind', 'reason']),
];

/// 工具名 → 界面上的过程描述。
const agentToolLabels = {
  'get_dog_profile': '查看狗狗档案',
  'get_training_history': '查看训练记录',
  'get_week_plan': '查看本周计划',
  'search_library': '检索训练内容库',
  'check_skill_eligibility': '按规则检查能不能练',
  'propose_plan_change': '准备调整计划',
  'suggest_start_training': '准备跟练入口',
  'refer_to_professional': '准备转介建议',
};

String agentSystemPrompt({String? contextSkillName}) => '''
你是"豆豆训练营"App 里的 AI 助理训犬师，在宠物训练行业工作，帮主人每天跟进幼犬训练。你的同事是专业训犬师和兽医：超出你职责的事要转介给他们。

# 工作规则（必须遵守）
1. 先了解情况：回答前用工具查看狗的档案、最近的训练记录或本周计划，结合这只狗的实际情况回答，不要泛泛而谈。
2. 方法只依据内容库：给出任何训练方法前先调用 search_library，只能依据返回的资料；用到哪条资料，就在句末标注 [ref: 资料id]。资料里没有的，直接说"内容库暂时没有覆盖，建议咨询专业训犬师"，不要自己编。
3. 只用正向训练：拒绝打骂、惩罚、恐吓等方法，并简单说明原因、给出替代做法。
4. 计划由规则说了算：建议练某个技能前先 check_skill_eligibility；要改计划只能调用 propose_plan_change，它只会生成确认卡片——不要说"已经帮你加好了"，要说"点下面的卡片确认后就会加入"。
5. 业务判断：同一技能最近连续两次"没做到"，按规则建议先退回更基础的技能；出现健康、受伤、疑似疼痛的迹象 → refer_to_professional(kind=vet)，不给任何医疗建议；攻击性强或持续恶化 → refer_to_professional(kind=trainer)。
6. 表达：中文，简洁、具体、像同事一样说话，200 字以内；先给结论，再给 1-3 个可以马上做的步骤。
${contextSkillName == null ? '' : '\n主人当前正在看的技能：$contextSkillName。\n'}''';

/// 执行工具。读本机数据库；写操作只产生待确认的 [AgentAction]。
class AgentToolbox {
  AgentToolbox({required this.db, required this.library, required this.dogId, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final ContentLibrary library;
  final String dogId;
  final DateTime Function() _clock;

  /// 本次提问里 search_library 实际返回过的资料 ID（回答的出处）。
  final Set<String> materialIds = {};
  final List<AgentAction> actions = [];

  Future<Map<String, String>> _statuses() async => {
        for (final r in await (db.select(db.dogSkillStatuses)..where((t) => t.dogId.equals(dogId))).get())
          r.skillId: r.status,
      };

  Future<int> _ageWeeks() async {
    final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingle();
    return ageWeeksOn(parseDateOnly(dog.birthDate), _clock().toLocal());
  }

  Future<List<String>> _goalIds() async {
    final plan = await PlanRepository(db).activePlan(dogId);
    if (plan == null) return const [];
    return [for (final g in await PlanRepository(db).goals(plan.id)) g.skillId];
  }

  String _name(String id) => library.skillById[id]?.name ?? library.issueById[id]?.name ?? id;

  /// 执行一个工具，返回给模型的文本（JSON）。未知工具 / 参数错误抛 [ArgumentError]。
  Future<String> run(String name, Map<String, dynamic> input) async {
    switch (name) {
      case 'get_dog_profile':
        return jsonEncode(await _profile());
      case 'get_training_history':
        return jsonEncode(await _history(input['skill_id'] as String?, (input['limit'] as num?)?.toInt() ?? 5));
      case 'get_week_plan':
        return jsonEncode(await _plan());
      case 'search_library':
        return _search((input['query'] ?? '').toString());
      case 'check_skill_eligibility':
        return jsonEncode(await _eligibility(_skillArg(input)));
      case 'propose_plan_change':
        return jsonEncode(await _proposePlan(_skillArg(input), (input['reason'] ?? '').toString()));
      case 'suggest_start_training':
        final id = _skillArg(input);
        actions.add(AgentAction(AgentActionType.startTraining, skillIds: [id]));
        return jsonEncode({'ok': true, 'shown': '已给主人显示"开始跟练 · ${_name(id)}"按钮'});
      case 'refer_to_professional':
        final kind = input['kind'] == 'vet' ? AgentActionType.referVet : AgentActionType.referTrainer;
        actions.add(AgentAction(kind, note: (input['reason'] ?? '').toString()));
        return jsonEncode({'ok': true, 'shown': '已给主人显示转介卡片'});
    }
    throw ArgumentError('未知工具 $name');
  }

  String _skillArg(Map<String, dynamic> input) {
    final id = (input['skill_id'] ?? '').toString();
    if (!library.skillById.containsKey(id)) {
      throw ArgumentError('技能 $id 不存在。可用技能 ID：${library.skills.map((s) => s.id).join(', ')}');
    }
    return id;
  }

  Future<Map<String, dynamic>> _profile() async {
    final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingle();
    final concerns = await (db.select(db.dogConcerns)..where((t) => t.dogId.equals(dogId))).get();
    final st = await _statuses();
    final cues = await (db.select(db.dogCues)..where((t) => t.dogId.equals(dogId))).get();
    final goalIds = await _goalIds();
    final relevant = {...goalIds, for (final e in st.entries) if (e.value == 'mastered' || e.value == 'in_progress') e.key};
    return {
      'name': dog.name,
      'age_weeks': await _ageWeeks(),
      'sex': dog.sex == 'male' ? '公' : '母',
      'living_env': dog.livingEnv == 'apartment' ? '公寓' : '带院子',
      'daily_minutes': dog.dailyMinutes,
      'concerns': [for (final c in concerns) _name(c.issueId)],
      'mastered_skills': [for (final e in st.entries) if (e.value == 'mastered') {'id': e.key, 'name': _name(e.key)}],
      'in_progress_skills': [for (final e in st.entries) if (e.value == 'in_progress') {'id': e.key, 'name': _name(e.key)}],
      'cues': [
        for (final c in cues)
          if (relevant.contains(c.skillId)) {'skill': _name(c.skillId), 'cue': c.cueWord, 'gesture': c.gestureText},
      ],
    };
  }

  Future<Map<String, dynamic>> _history(String? skillId, int limit) async {
    final q = db.select(db.trainingSessions)
      ..where((t) => t.dogId.equals(dogId))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(limit.clamp(1, 10));
    if (skillId != null && skillId.isNotEmpty) q.where((t) => t.skillId.equals(skillId));
    final rows = await q.get();
    final streak = await (db.select(db.streaks)..where((t) => t.dogId.equals(dogId))).getSingleOrNull();
    return {
      'streak_days': streak?.currentDays ?? 0,
      'sessions': [
        for (final r in rows)
          {
            'date': DateTime.parse(r.startedAt).toLocal().toIso8601String().substring(0, 10),
            'skill_id': r.skillId,
            'skill': _name(r.skillId),
            'score': switch (scoreFromDb(r.score)) { final sc? => scoreLabel(sc), null => r.score },
            'minutes': (r.durationSec / 60).toStringAsFixed(1),
          },
      ],
      if (rows.isEmpty) 'note': '还没有训练记录',
    };
  }

  Future<Map<String, dynamic>> _plan() async {
    final repo = PlanRepository(db);
    final plan = await repo.activePlan(dogId);
    if (plan == null) return {'note': '还没有本周计划'};
    final goals = await repo.goals(plan.id);
    final mini = await repo.miniTask(plan.id);
    return {
      'week_start': plan.weekStart,
      'goals': [
        for (final g in goals)
          {'skill_id': g.skillId, 'skill': _name(g.skillId), 'completed': g.completedSessions, 'target': g.targetSessions},
      ],
      if (mini != null) 'daily_mini_task': _name(mini.skillId),
    };
  }

  String _search(String query) {
    final r = retrieve(message: query, library: library);
    final ids = r.ids.take(3).toList();
    if (ids.isEmpty) {
      return jsonEncode({
        'found': false,
        'note': '内容库没有找到相关资料',
        if (r.suggestions.isNotEmpty) 'maybe_related': [for (final s in r.suggestions) {'id': s, 'name': _name(s)}],
      });
    }
    materialIds.addAll(ids);
    final b = StringBuffer();
    for (final id in ids) {
      if (library.skillById[id] case final s?) b.writeln(renderSkillMaterial(s));
      if (library.issueById[id] case final i?) b.writeln(renderIssueMaterial(i));
      if (library.faqById[id] case final f?) b.writeln(renderFaqMaterial(f));
    }
    return b.toString();
  }

  Future<Map<String, dynamic>> _eligibility(String id) async {
    final s = library.skillById[id]!;
    final st = await _statuses();
    final age = await _ageWeeks();
    final goals = await _goalIds();
    final prereq = [for (final p in s.prerequisites) {'id': p, 'name': _name(p), 'mastered': st[p] == 'mastered'}];
    final reasons = <String>[];
    if (st[id] == 'mastered') reasons.add('已经掌握');
    if (goals.contains(id)) reasons.add('已在本周计划');
    if (age < s.minAgeWeeks) reasons.add('周龄未到：${s.minAgeWeeks} 周起，还差 ${s.minAgeWeeks - age} 周');
    final missing = [for (final p in s.prerequisites) if (st[p] != 'mastered') _name(p)];
    if (missing.isNotEmpty) reasons.add('前置技能未掌握：${missing.join('、')}');
    return {
      'skill': s.name,
      'age_weeks': age,
      'min_age_weeks': s.minAgeWeeks,
      'prerequisites': prereq,
      'can_train_now': reasons.isEmpty,
      'reasons': reasons,
      if (s.downgradeTo != null) 'easier_skill': {'id': s.downgradeTo, 'name': _name(s.downgradeTo!)},
    };
  }

  Future<Map<String, dynamic>> _proposePlan(String id, String reason) async {
    final st = await _statuses();
    final r = addDiagnosisToWeek(
      solutionSkills: [id],
      currentGoalIds: await _goalIds(),
      mastered: {for (final e in st.entries) if (e.value == 'mastered') e.key},
      ageWeeks: await _ageWeeks(),
      skills: library.skills,
    );
    if (r.added.isEmpty) {
      return {
        'ok': false,
        'reasons': [for (final k in r.skipped) _skipText(k)],
        'note': '没有生成确认卡片，请把原因告诉主人',
      };
    }
    final added = [for (final g in r.added) g.skillId];
    final viaFoundation = !added.contains(id);
    actions.add(AgentAction(AgentActionType.addToPlan, skillIds: added, note: reason));
    return {
      'ok': true,
      'will_add': [for (final a in added) _name(a)],
      if (viaFoundation) 'note': '${_name(id)} 现在还不能练，规则改为先练前置：${added.map(_name).join('、')}',
      'shown': '已给主人显示确认卡片，主人点确认后才会写入本周计划',
    };
  }

  String _skipText(DiagnosisSkip k) => switch (k.reason) {
        DiagnosisSkipReason.mastered => '${_name(k.skillId)} 已经掌握',
        DiagnosisSkipReason.alreadyInPlan => '${_name(k.skillId)} 已在本周计划',
        DiagnosisSkipReason.ageTooYoung => '${_name(k.skillId)} 周龄未到（${k.untilWeeks} 周起）',
        DiagnosisSkipReason.prerequisitesUnmet => '${_name(k.skillId)} 前置未掌握：${k.missing.map(_name).join('、')}',
        DiagnosisSkipReason.capReached => '本周目标已达上限',
        DiagnosisSkipReason.unknownSkill => '技能 ${k.skillId} 不存在',
      };
}

// ---------------------------------------------------------------------------
// Agent 循环
// ---------------------------------------------------------------------------

final _refRe = RegExp(r'\[ref:\s*([^\]]+)\]');

class CoachAgent {
  CoachAgent({
    required this.library,
    required this.client,
    required this.toolbox,
    this.maxRounds = agentMaxRounds,
  });
  final ContentLibrary library;
  final AgentClient client;
  final AgentToolbox toolbox;
  final int maxRounds;

  Stream<AgentEvent> ask({
    required String question,
    List<ChatTurn> history = const [],
    String? contextSkillId,
  }) async* {
    // 第一层：健康拦截（与离线模式完全相同，不调模型）
    if (checkHealthGuard(question, library.aiGuard).blocked) {
      yield const AgentDone(CoachAnswer(
        text: healthGuardReply,
        cited: [],
        kind: AiMessageKind.guardHealth,
        modelCalled: false,
      ));
      return;
    }
    final system = agentSystemPrompt(contextSkillName: library.skillById[contextSkillId]?.name);
    final messages = <Map<String, dynamic>>[
      for (final t in history)
        {'role': t.role, 'content': t.role == 'assistant' ? AgentMessageParts.parse(t.content).text : t.content},
      {'role': 'user', 'content': question},
    ];
    final trace = <String>[];
    String answer = '';
    for (var round = 0; round < maxRounds; round++) {
      final turn = await client.turn(system: system, messages: messages, tools: agentTools);
      messages.add({'role': 'assistant', 'content': turn.content});
      if (turn.stopReason == 'refusal') {
        answer = '这个问题我没办法回答，训练上的问题我随时在。';
        break;
      }
      final uses = turn.toolUses;
      if (uses.isEmpty) {
        answer = turn.text;
        break;
      }
      final results = <Map<String, dynamic>>[];
      for (final u in uses) {
        final name = (u['name'] ?? '').toString();
        final label = agentToolLabels[name] ?? name;
        yield AgentStep(label);
        if (!trace.contains(label)) trace.add(label);
        try {
          final out = await toolbox.run(name, Map<String, dynamic>.from((u['input'] as Map?) ?? const {}));
          results.add({'type': 'tool_result', 'tool_use_id': u['id'], 'content': out});
        } catch (e) {
          results.add({'type': 'tool_result', 'tool_use_id': u['id'], 'content': '错误：$e', 'is_error': true});
        }
      }
      messages.add({'role': 'user', 'content': results});
      if (round == maxRounds - 1) answer = turn.text;
    }
    if (answer.isEmpty) answer = '我查了一些资料，但还没整理出结论，请换个说法再问一次。';

    // 出处：回答里的 [ref: id]（只认内容库里存在的 ID）+ 检索到的资料
    final refs = <String>{};
    for (final m in _refRe.allMatches(answer)) {
      for (final id in m.group(1)!.split(RegExp(r'[,，\s]+'))) {
        if (library.skillById.containsKey(id) || library.issueById.containsKey(id) || library.faqById.containsKey(id)) {
          refs.add(id);
        }
      }
    }
    final clean = answer.replaceAll(RegExp(r'[ \t]*\[ref:\s*[^\]]+\]'), '').replaceAll(RegExp(r'[ \t]+\n'), '\n').trim();
    final cited = refs.isNotEmpty ? refs.toList() : toolbox.materialIds.toList();
    final parts = AgentMessageParts(clean, trace, toolbox.actions);
    yield AgentDone(CoachAnswer(
      text: parts.encode(),
      cited: cited,
      kind: containsNoHitReply(clean) ? AiMessageKind.guardNoHit : AiMessageKind.normal,
      modelCalled: true,
    ));
  }
}
