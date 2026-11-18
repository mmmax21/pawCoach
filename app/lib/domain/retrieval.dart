/// AI 回答边界第二层：内容库检索（M3 简报第 5 节）。
///
/// 纯函数，无 IO，不依赖 Flutter。不做向量库：
/// 1. 上下文直取：课程内提问带 skill_id → 该技能必入；诊断对话带 issue_id → 该 issue 必入；
/// 2. 关键词打分：用 ai_terms.yaml 词表做子串匹配，按词长降序逐个检查
///    `message.contains(word)`，命中则该词映射的每个 ID 计 1 分（一个词命中多次只计一次），
///    取得分 > 0 的前 3 个追加。
/// 无命中：上下文直取为空，且关键词最高分为 0。
///
/// v1.4：词表 = ai_terms.yaml + faq.yaml 的检索词（[ContentLibrary.searchTerms]），FAQ 与技能、问题行为同等参与打分。
///
/// 2026-11-18 补检索（fulltext_search.dart）：
/// 3. 关键词打分前先做同义展开（"蹲下"→"坐下"等，目标都是词表里已有的词）；
/// 4. 关键词仍无命中时，用内容库全文检索兜底：只有强命中（≥3 个片段、得分 ≥0.6、明显领先第二名）
///    才当作命中直出；其余较弱的结果只放进 [RetrievalResult.suggestions]，界面显示为"你可能想问"，不当作回答。
library;

import 'fulltext_search.dart';
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
    this.fulltextHit = false,
    this.suggestions = const [],
  });

  /// 命中来自全文检索兜底（关键词无命中）。
  final bool fulltextHit;

  /// 无命中时的"你可能想问"（技能或问题行为 ID），不当作回答内容。
  final List<String> suggestions;

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

  final kw = scoreKeywords(expandSynonyms(message), library.searchTerms);
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
  final keywordMax = kw.scores.values.fold(0, (a, b) => b > a ? b : a);

  // 关键词与上下文都没有命中：全文检索兜底
  if (context.isEmpty && ranked.isEmpty) {
    final hits = fulltextSearch(message, library);
    final strong = fulltextStrongHit(hits);
    if (strong != null) {
      return RetrievalResult(
        contextIds: context,
        scored: [ScoredContent(strong.id, 1)],
        matchedWords: kw.words,
        keywordMaxScore: keywordMax,
        fulltextHit: true,
      );
    }
    return RetrievalResult(
      contextIds: context,
      scored: const [],
      matchedWords: kw.words,
      keywordMaxScore: keywordMax,
      suggestions: [for (final h in fulltextSuggestions(hits)) h.id],
    );
  }

  return RetrievalResult(
    contextIds: context,
    scored: ranked.take(topK).toList(),
    matchedWords: kw.words,
    keywordMaxScore: keywordMax,
  );
}

/// 诊断入口"输入描述"：只在问题行为里取最高分的一个；没有命中返回 null（→ guard_no_hit）。
String? bestIssueFor(String message, ContentLibrary library) {
  final kw = scoreKeywords(expandSynonyms(message), library.searchTerms);
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
