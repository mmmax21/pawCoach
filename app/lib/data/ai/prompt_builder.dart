/// 组装系统提示（M3 简报第 5 节第三层）。
///
/// 模板只含角色与规则，不含任何技能步骤或口令；技能、问题行为的原文全部在运行时
/// 从内容库检索结果拼进"资料块"。
library;

import '../../domain/models.dart';
import '../../domain/ai_guard.dart';

/// 狗档案摘要（AI-2）。
class DogBrief {
  const DogBrief({
    required this.name,
    required this.ageWeeks,
    required this.concernNames,
    required this.masteredSkillNames,
    this.skillName,
    this.recentScores = const [],
    this.currentStep,
  });

  final String name;
  final int ageWeeks;
  final List<String> concernNames;
  final List<String> masteredSkillNames;

  /// 课程内提问的技能名。
  final String? skillName;

  /// 该技能最近 3 次评分，新的在前。
  final List<Score> recentScores;

  /// 跟练页进入时的当前步骤序号（从 1 开始）。
  final int? currentStep;
}

String scoreLabel(Score s) => switch (s) {
      Score.full => '完全做到',
      Score.partial => '部分做到',
      Score.none => '没做到',
    };

const _role = '你是一个幼犬训练助手，只能依据下面"资料"中给出的内容回答主人的问题。';

const _rules = '''规则（必须遵守）：
1. 资料里没有的训练方法不说，不补充资料以外的做法。
2. 不给任何医疗、用药、疾病相关的建议。
3. 不编造数据、时间、次数或比例；只引用资料里写明的。
4. 回答末尾单独一行用 [ref: id1, id2] 标出你用到的资料 ID，ID 必须来自资料块。
5. 如果资料不足以回答这个问题，只回复"$noHitGuardCore"，不要加任何其他内容。
6. 用简洁的中文回答，面向普通狗主人。''';

/// 拼系统提示。[materials] 为检索结果 ID（上下文在前），按顺序渲染为资料块。
String buildSystemPrompt({
  required DogBrief dog,
  required List<String> materials,
  required ContentLibrary library,
}) {
  final b = StringBuffer()
    ..writeln(_role)
    ..writeln()
    ..writeln(_rules)
    ..writeln()
    ..writeln('## 狗档案')
    ..writeln('- 名字：${dog.name}')
    ..writeln('- 周龄：${dog.ageWeeks} 周')
    ..writeln('- 困扰：${dog.concernNames.isEmpty ? '无' : dog.concernNames.join('、')}')
    ..writeln('- 已掌握技能：${dog.masteredSkillNames.isEmpty ? '无' : dog.masteredSkillNames.join('、')}');
  if (dog.skillName != null) {
    b.writeln('- 正在练的技能：${dog.skillName}');
    b.writeln('- 该技能最近 3 次评分：${dog.recentScores.isEmpty ? '还没有记录' : dog.recentScores.map(scoreLabel).join('、')}');
  }
  if (dog.currentStep != null) {
    b.writeln('- 主人正在跟练第 ${dog.currentStep} 步');
  }
  b
    ..writeln()
    ..writeln('## 资料');
  for (final id in materials) {
    final skill = library.skillById[id];
    if (skill != null) {
      b.writeln(renderSkillMaterial(skill));
      continue;
    }
    final issue = library.issueById[id];
    if (issue != null) b.writeln(renderIssueMaterial(issue));
  }
  return b.toString();
}

/// 技能资料：tutorial、common_mistakes、success_criteria、scoring_hint（简报第 5 节"必入"）。
String renderSkillMaterial(Skill s) {
  final b = StringBuffer()
    ..writeln('<material id="${s.id}" type="skill" name="${s.name}">')
    ..writeln('简介：${s.tutorial.summary}')
    ..writeln('口令：${s.defaultCue}；手势：${s.defaultGesture}')
    ..writeln('前置技能：${s.prerequisites.isEmpty ? '无' : s.prerequisites.join('、')}')
    ..writeln('掌握所需完全做到次数：${s.sessionsToMaster}')
    ..writeln('步骤：');
  for (var i = 0; i < s.tutorial.steps.length; i++) {
    b.writeln('${i + 1}. ${s.tutorial.steps[i].text}');
  }
  b.writeln('常见错误：');
  for (final m in s.tutorial.commonMistakes) {
    b.writeln('- $m');
  }
  b
    ..writeln('成功标准：${s.tutorial.successCriteria}')
    ..writeln('评分提示：${s.scoringHint}')
    ..writeln('</material>');
  return b.toString();
}

/// 问题行为资料：全文（诊断树 + 全部方案）。
String renderIssueMaterial(Issue i) {
  final b = StringBuffer()
    ..writeln('<material id="${i.id}" type="issue" name="${i.name}">')
    ..writeln('常见周龄：${i.typicalAgeWeeks[0]}-${i.typicalAgeWeeks[1]} 周')
    ..writeln('诊断追问：');
  for (var n = 0; n < i.diagnosisTree.length; n++) {
    final node = i.diagnosisTree[n];
    b.writeln('Q${n + 1}. ${node.question}（${node.options.map((o) => o.text).join(' / ')}）');
  }
  b.writeln('方案：');
  for (final s in i.solutions) {
    b
      ..writeln('[${s.key}] ${s.summary}')
      ..writeln('  技能：${s.skills.join('、')}')
      ..writeln('  环境管理：${s.management.join('；')}')
      ..writeln('  需要升级求助的情况：${s.escalateIf}');
  }
  b.writeln('</material>');
  return b.toString();
}

/// 从系统提示的资料块里取出 ID（测试用 FakeAiClient 据此"引用"）。
List<String> materialIdsInPrompt(String system) => [
      for (final m in RegExp(r'<material id="([^"]+)"').allMatches(system)) m.group(1)!,
    ];

/// 解析回答末尾的 `[ref: ...]`。
class ParsedAnswer {
  const ParsedAnswer({required this.body, required this.refs, required this.hadRef});

  /// 去掉 `[ref: ...]` 后的正文。
  final String body;
  final List<String> refs;
  final bool hadRef;
}

final _refRe = RegExp(r'\[\s*ref\s*[:：]\s*([^\]]*)\]\s*$', caseSensitive: false);

ParsedAnswer parseAnswer(String raw) {
  final trimmed = raw.trimRight();
  final m = _refRe.firstMatch(trimmed);
  if (m == null) return ParsedAnswer(body: trimmed, refs: const [], hadRef: false);
  final refs = m
      .group(1)!
      .split(RegExp(r'[,，、\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return ParsedAnswer(
    body: trimmed.substring(0, m.start).trimRight(),
    refs: refs,
    hadRef: true,
  );
}
