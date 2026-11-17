/// AI 回答边界第一层：健康拦截；以及两句固定话术（M3 简报第 5 节）。
///
/// 纯函数，无 IO，不依赖 Flutter。词表来自内容库 `ai_guard.yaml`，这里不写任何词。
library;

import 'models.dart';

/// 第一层命中时的固定话术（简报第 5 节原文）。
const healthGuardReply = '涉及狗狗健康的问题，请尽快咨询兽医。训练上的问题我随时在。';

/// 第二层无命中时的固定话术（简报第 5 节原文）。
const noHitGuardReply = '这个问题内容库暂时没有覆盖，建议咨询专业训犬师。';

/// 模型按系统提示拒答时会输出的核心句（不含句末标点），用于把回答改判为 guard_no_hit。
const noHitGuardCore = '这个问题内容库暂时没有覆盖，建议咨询专业训犬师';

/// "同句"的切分符：句号、问号、感叹号、分号、换行。逗号不切
/// （"它没精神，坐下练不进去"按 v1.2 审核说明视为同句，不拦）。
final _sentenceSplit = RegExp(r'[。！？!?；;\n\r]+');

/// 健康拦截的判定结果，带命中词便于日志与测试定位。
class HealthGuardResult {
  const HealthGuardResult._(this.blocked, this.matched, this.group);
  const HealthGuardResult.pass() : this._(false, null, null);
  const HealthGuardResult.hard(String word) : this._(true, word, 'hard');
  const HealthGuardResult.soft(String word) : this._(true, word, 'soft');

  final bool blocked;
  final String? matched;

  /// 'hard' | 'soft' | null
  final String? group;

  @override
  String toString() => blocked ? 'HealthGuard($group: $matched)' : 'HealthGuard(pass)';
}

/// 第一层：子串匹配。
/// - hard 词任一出现在消息中 → 拦；
/// - soft 词出现在某一句中，且该句不含任一 training_terms → 拦。
HealthGuardResult checkHealthGuard(String message, AiGuardLexicon lexicon) {
  for (final w in lexicon.hard) {
    if (message.contains(w)) return HealthGuardResult.hard(w);
  }
  for (final sentence in message.split(_sentenceSplit)) {
    if (sentence.trim().isEmpty) continue;
    for (final w in lexicon.soft) {
      if (!sentence.contains(w)) continue;
      final trainingContext = lexicon.trainingTerms.any(sentence.contains);
      if (!trainingContext) return HealthGuardResult.soft(w);
    }
  }
  return const HealthGuardResult.pass();
}

/// 模型回答里出现了无命中固定话术原文（第三层兜底改判）。
bool containsNoHitReply(String answer) => answer.contains(noHitGuardCore);
