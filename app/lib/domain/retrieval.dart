/// AI 回答边界第二层：内容库检索（M3 简报第 5 节）。
///
/// 纯函数，无 IO，不依赖 Flutter。不做向量库：
/// 1. 上下文直取：课程内提问带 skill_id → 该技能必入；诊断对话带 issue_id → 该 issue 必入；
/// 2. 关键词打分：用 ai_terms.yaml 词表做子串匹配，按词长降序逐个检查
///    `message.contains(word)`，命中则该词映射的每个 ID 计 1 分（一个词命中多次只计一次），
///    取得分 > 0 的前 3 个追加。
/// 无命中：上下文直取为空，且关键词最高分为 0。
library;

import 'models.dart';

/// 关键词打分最多追加的条目数。
const retrievalTopK = 3;

class ScoredContent {
  const ScoredContent(this.id, this.score);
  final String id;
  final int score;

  @override
  String toString() => '$id:$score';
}

class RetrievalResult {
  const RetrievalResult({
    required this.contextIds,
    required this.scored,
    required this.matchedWords,
    this.keywordMaxScore = 0,
  });

  /// 上下文直取的 ID（skill_id / issue_id），按顺序。
  final List<String> contextIds;

  /// 关键词打分的前 K 个（score > 0，已排除 [contextIds]），按分数降序。
  final List<ScoredContent> scored;

  /// 命中的词（调试、日志用）。
  final List<String> matchedWords;

  /// 关键词打分在全部条目上的最高分（**含**上下文条目自身的得分）。
  /// 16.3"有上下文时关键词最高分是否为 0"按这个判断。
  final int keywordMaxScore;

  /// 关键词打分最高分（不含上下文直取）。
  int get topScore => scored.isEmpty ? 0 : scored.first.score;

  /// 全部检索结果 ID：上下文在前，打分在后，去重。
  List<String> get ids => [...contextIds, ...scored.map((s) => s.id)];

  /// 简报第 5 节无命中判定。
  bool get noHit => contextIds.isEmpty && topScore == 0;

  @override
  String toString() => 'Retrieval(context: $contextIds, scored: $scored)';
}

/// 对 [message] 做关键词打分，返回所有得分 > 0 的 ID 及分数（未截断、未排序）。
/// 同时返回命中的词。
({Map<String, int> scores, List<String> words}) scoreKeywords(
  String message,
  List<AiTerm> terms,
) {
  // 按词长降序；同长度保持词表顺序（List.sort 不稳定，所以带下标排）。
  final indexed = [for (var i = 0; i < terms.length; i++) (i, terms[i])];
  indexed.sort((a, b) {
    final d = b.$2.word.length - a.$2.word.length;
    return d != 0 ? d : a.$1 - b.$1;
  });
  final scores = <String, int>{};
  final words = <String>[];
  for (final (_, t) in indexed) {
    if (!message.contains(t.word)) continue;
    words.add(t.word);
    for (final id in t.ids.toSet()) {
      scores[id] = (scores[id] ?? 0) + 1;
    }
  }
  return (scores: scores, words: words);
}

/// 检索。[skillId] / [issueId] 为上下文直取（不在内容库中的 ID 忽略）。
///
/// 排序：分数降序；同分按首次命中顺序（长词先查），保证确定性。
RetrievalResult retrieve({
  required String message,
  required ContentLibrary library,
  String? skillId,
  String? issueId,
  int topK = retrievalTopK,
}) {
  final context = <String>[
    if (skillId != null && library.skillById.containsKey(skillId)) skillId,
    if (issueId != null && library.issueById.containsKey(issueId)) issueId,
  ];

  final kw = scoreKeywords(message, library.aiTerms);
  // 同分按"首次命中顺序"：词按长度降序检查，先命中的（更长、更具体的词）映射的 ID 排前。
  // Map 保持插入顺序；List.sort 不稳定，所以带下标排。
  final entries = [
    for (final e in kw.scores.entries)
      if (e.value > 0 && !context.contains(e.key)) e,
  ];
  final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])];
  indexed.sort((a, b) {
    final d = b.$2.value - a.$2.value;
    return d != 0 ? d : a.$1 - b.$1;
  });
  final ranked = [for (final (_, e) in indexed) ScoredContent(e.key, e.value)];

  return RetrievalResult(
    contextIds: context,
    scored: ranked.take(topK).toList(),
    matchedWords: kw.words,
    keywordMaxScore: kw.scores.values.fold(0, (a, b) => b > a ? b : a),
  );
}

/// 诊断入口"输入描述"：只在问题行为里取最高分的一个；没有命中返回 null（→ guard_no_hit）。
String? bestIssueFor(String message, ContentLibrary library) {
  final kw = scoreKeywords(message, library.aiTerms);
  String? best;
  var bestScore = 0;
  // 同分取首次命中的（与 retrieve() 一致）。
  for (final e in kw.scores.entries) {
    if (!library.issueById.containsKey(e.key)) continue;
    if (e.value > bestScore) {
      best = e.key;
      bestScore = e.value;
    }
  }
  return best;
}
