/// AI 教练第三层：内容库直出（M3 简报第 16 节，首版默认）。
///
/// 纯函数，无 IO、无 Flutter、不调模型。检索命中后按固定模板展示内容库原文：
/// 每个文本块要么逐字等于内容库某个字段的值（或该狗 DogCue 里的口令 / 手势），
/// 要么属于 [answerTemplates] 这个封闭集合。不截断、不改写、不拼句。
library;

import 'ai_guard.dart';
import 'models.dart';
import 'retrieval.dart';

// ---------------------------------------------------------------------------
// 模板文案（16.4）：只有字段标签、引导语、固定话术、16.3 追加句、降级引导语。
// 不代入任何内容；不含任何步骤、口令、方法描述。
// ---------------------------------------------------------------------------

const tplIntro = '以下内容来自内容库：';
const tplLabelCurrentStep = '【当前这一步】';
const tplLabelSummary = '【简介】';
const tplLabelSuccess = '【成功标准】';
const tplLabelMistakes = '【常见错误】';
const tplLabelScoring = '【评分参考】';
const tplLabelCue = '【你的口令】';
const tplLabelGesture = '【手势】';
const tplIssueGuide = '这个问题需要先做一次问题诊断，回答几个问题后会给出方案：';
const tplDowngradeGuide = '最近两次都没做到，可以先练更基础的技能：';

/// 16.3：有上下文、关键词最高分为 0 时追加。
const tplCourseOutOfScope = '如果问的不是这个技能，内容库暂时没有覆盖，建议咨询专业训犬师。';

/// 回答块里可能出现的全部模板文本（原文性测试与模板审查用）。
const answerTemplates = <String>{
  tplIntro,
  tplLabelCurrentStep,
  tplLabelSummary,
  tplLabelSuccess,
  tplLabelMistakes,
  tplLabelScoring,
  tplLabelCue,
  tplLabelGesture,
  tplIssueGuide,
  tplDowngradeGuide,
  tplCourseOutOfScope,
  healthGuardReply,
  noHitGuardReply,
};

// 纯文本快照里的行首标记（只是排版符号，不承载内容）。
const snapTitle = '■ ';
const snapBullet = '• ';
const snapLink = '→ ';

/// 直出最多展示的条目数，以及其中关键词条目的上限（16.2）。
const composeMaxItems = 3;
const composeMaxKeywordItems = 2;

enum AnswerBlockType {
  /// 条目名称（内容库 name 原文）。
  title,

  /// 字段标签（模板）。
  label,

  /// 内容库字段原文 / DogCue 原文。
  text,

  /// 列表项原文（common_mistakes 的一条）。
  bullet,

  /// 模板句（引导语、追加句）。
  note,

  /// 跳转：降级技能（文本为其 name 原文）。
  downgradeLink,
}

class AnswerBlock {
  const AnswerBlock(this.type, this.text, {this.targetId, this.source});
  final AnswerBlockType type;
  final String text;

  /// title / downgradeLink 指向的内容 ID。
  final String? targetId;

  /// 原文出处（如 `sit.tutorial.summary`、`dog_cue.sit.cue_word`），模板块为 null。
  final String? source;

  bool get isTemplate =>
      type == AnswerBlockType.label || type == AnswerBlockType.note;

  @override
  String toString() => '$type($text)';
}

/// 狗的口令表一项（来自 DogCue，不是 default_cue）。
class CueView {
  const CueView({required this.cueWord, required this.gesture});
  final String cueWord;
  final String gesture;
}

class ComposedAnswer {
  const ComposedAnswer({required this.blocks, required this.cited});
  final List<AnswerBlock> blocks;

  /// 实际展示的条目 ID，顺序同展示顺序。
  final List<String> cited;

  /// 存入 AiMessage.content 的纯文本快照（每块一行，带行首标记）。
  String get snapshot => blocks.map(snapshotLine).join('\n');
}

String snapshotLine(AnswerBlock b) => switch (b.type) {
      AnswerBlockType.title => '$snapTitle${b.text}',
      AnswerBlockType.bullet => '$snapBullet${b.text}',
      AnswerBlockType.downgradeLink => '$snapLink${b.text}',
      _ => b.text,
    };

/// 16.2：选条目。上下文条目在前，然后关键词得分 > 0 的前 2 个，去重，合计最多 3 个。
List<String> selectAnswerItems(RetrievalResult r) {
  final out = <String>[];
  for (final id in r.contextIds) {
    if (!out.contains(id)) out.add(id);
  }
  var kw = 0;
  for (final s in r.scored) {
    if (kw >= composeMaxKeywordItems) break;
    if (s.score <= 0 || out.contains(s.id)) continue;
    out.add(s.id);
    kw++;
  }
  return out.take(composeMaxItems).toList();
}

/// 组装回答。调用方已排除健康拦截与"无上下文且无命中"（那两种是固定话术）。
///
/// [contextSkillId]：课程内提问的技能；[currentStep]（从 1 开始）与 [scriptPart]
/// 指跟练页进入时正在跟练的那份脚本（0 为 mini_script）。
/// [recentScores]：该技能最近的评分，新的在前。
/// [cues]：skillId → 该狗的口令与手势（DogCue）。
ComposedAnswer composeAnswer({
  required ContentLibrary library,
  required RetrievalResult retrieval,
  String? contextSkillId,
  int? currentStep,
  int? scriptPart,
  List<Score> recentScores = const [],
  Map<String, CueView> cues = const {},
}) {
  final ids = selectAnswerItems(retrieval);
  final blocks = <AnswerBlock>[
    const AnswerBlock(AnswerBlockType.note, tplIntro)
  ];
  final cited = <String>[];

  for (final id in ids) {
    final skill = library.skillById[id];
    if (skill != null) {
      cited.add(id);
      blocks.addAll(_skillBlocks(
        skill,
        step: id == contextSkillId ? currentStep : null,
        part: scriptPart,
        cue: cues[id],
      ));
      continue;
    }
    final issue = library.issueById[id];
    if (issue != null) {
      cited.add(id);
      // 问题行为只出名称与诊断入口，不出任何 solution（保证 escalate_if 必随方案出现）。
      blocks
        ..add(AnswerBlock(AnswerBlockType.title, issue.name,
            targetId: id, source: '$id.name'))
        ..add(const AnswerBlock(AnswerBlockType.note, tplIssueGuide));
    }
  }

  // 评分联动：上下文技能最近 2 次都"没做到"且 downgrade_to 非空 → 指向降级技能（与 WP-6 同源）。
  final ctx = contextSkillId == null ? null : library.skillById[contextSkillId];
  if (ctx != null &&
      recentScores.length >= 2 &&
      recentScores[0] == Score.none &&
      recentScores[1] == Score.none) {
    final down =
        ctx.downgradeTo == null ? null : library.skillById[ctx.downgradeTo];
    if (down != null) {
      blocks
        ..add(const AnswerBlock(AnswerBlockType.note, tplDowngradeGuide))
        ..add(AnswerBlock(AnswerBlockType.downgradeLink, down.name,
            targetId: down.id, source: '${down.id}.name'));
    }
  }

  // 16.3：有上下文、关键词最高分为 0 → 只出上下文条目，末尾追加固定一句。
  if (retrieval.contextIds.isNotEmpty && retrieval.keywordMaxScore == 0) {
    blocks.add(const AnswerBlock(AnswerBlockType.note, tplCourseOutOfScope));
  }
  return ComposedAnswer(blocks: blocks, cited: cited);
}

List<AnswerBlock> _skillBlocks(Skill s, {int? step, int? part, CueView? cue}) {
  final out = <AnswerBlock>[
    AnswerBlock(AnswerBlockType.title, s.name,
        targetId: s.id, source: '${s.id}.name'),
  ];
  if (step != null) {
    final steps = s.stepsForPart(part ?? 1);
    if (step >= 1 && step <= steps.length) {
      out
        ..add(const AnswerBlock(AnswerBlockType.label, tplLabelCurrentStep))
        ..add(AnswerBlock(AnswerBlockType.text, steps[step - 1].instruction,
            source:
                '${s.id}.${part == miniScriptPart ? 'mini_script' : 'script'}[${step - 1}].instruction'));
    }
  }
  if (cue != null) {
    out
      ..add(const AnswerBlock(AnswerBlockType.label, tplLabelCue))
      ..add(AnswerBlock(AnswerBlockType.text, cue.cueWord,
          source: 'dog_cue.${s.id}.cue_word'))
      ..add(const AnswerBlock(AnswerBlockType.label, tplLabelGesture))
      ..add(AnswerBlock(AnswerBlockType.text, cue.gesture,
          source: 'dog_cue.${s.id}.gesture_text'));
  }
  out
    ..add(const AnswerBlock(AnswerBlockType.label, tplLabelSummary))
    ..add(AnswerBlock(AnswerBlockType.text, s.tutorial.summary,
        source: '${s.id}.tutorial.summary'))
    ..add(const AnswerBlock(AnswerBlockType.label, tplLabelSuccess))
    ..add(AnswerBlock(AnswerBlockType.text, s.tutorial.successCriteria,
        source: '${s.id}.tutorial.success_criteria'));
  if (s.tutorial.commonMistakes.isNotEmpty) {
    out.add(const AnswerBlock(AnswerBlockType.label, tplLabelMistakes));
    for (var i = 0; i < s.tutorial.commonMistakes.length; i++) {
      out.add(AnswerBlock(AnswerBlockType.bullet, s.tutorial.commonMistakes[i],
          source: '${s.id}.tutorial.common_mistakes[$i]'));
    }
  }
  out
    ..add(const AnswerBlock(AnswerBlockType.label, tplLabelScoring))
    ..add(AnswerBlock(AnswerBlockType.text, s.scoringHint,
        source: '${s.id}.scoring_hint'));
  return out;
}

/// 解析纯文本快照为可渲染的行（对话页用）。不认识的行按正文处理。
enum SnapshotLineType { title, label, bullet, link, body }

({SnapshotLineType type, String text}) parseSnapshotLine(String line) {
  if (line.startsWith(snapTitle)) {
    return (
      type: SnapshotLineType.title,
      text: line.substring(snapTitle.length)
    );
  }
  if (line.startsWith(snapBullet)) {
    return (
      type: SnapshotLineType.bullet,
      text: line.substring(snapBullet.length)
    );
  }
  if (line.startsWith(snapLink)) {
    return (type: SnapshotLineType.link, text: line.substring(snapLink.length));
  }
  if (line.startsWith('【') &&
      line.endsWith('】') &&
      answerTemplates.contains(line)) {
    return (type: SnapshotLineType.label, text: line);
  }
  return (type: SnapshotLineType.body, text: line);
}
