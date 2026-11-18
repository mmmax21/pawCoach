/// 内容库全文检索（2026-11-18 补检索）。
///
/// 关键词词表（ai_terms.yaml）只认字面完全一样的词，换个说法就检索不到。这里补一层：
/// 把每个技能 / 问题行为的全部文字（名称、简介、步骤、常见错误、成功标准、诊断问答、方案）
/// 切成中文二字片段建索引，按问题里的片段命中情况打分。
///
/// - 纯函数、无 IO、无依赖；索引按内容库实例缓存。
/// - 只用于关键词完全没命中时（见 retrieval.dart），不改变原有关键词命中的结果。
/// - 两档阈值：[fulltextHitScore] 以上算命中（直出内容库原文）；
///   [fulltextSuggestScore] 以上只作为"你可能想问"的建议，不当作回答。
/// - 同义说法（"蹲下"→"坐下"等）在 [querySynonyms] 里展开后再切片。
library;

import 'dart:math' as math;

import 'models.dart';

/// 命中阈值：问题里有效片段按信息量加权后，至少这么多比例能在同一条目里找到。
const fulltextHitScore = 0.6;

/// 建议阈值：低于命中阈值、高于此值的条目只作为"你可能想问"。
const fulltextSuggestScore = 0.35;

/// 命中至少需要的不同片段数（防止一两个常见片段撞上就算命中）。
const fulltextMinMatched = 3;

/// 命中还要求第一名比第二名高出这么多（多个条目分数接近时说明没有区分度，不直出）。
const fulltextMinMargin = 0.15;

/// 建议至少需要的不同片段数。
const fulltextSuggestMinMatched = 2;

/// 口语同义说法 → 关键词词表（ai_terms.yaml）里已有的词。只做查询展开，不改内容库。
/// 只放"说法不同、意思相同"的训练用语，不放训练方法；目标词必须是词表里已有的词（有测试保证）。
/// 后续可迁入内容库词表，由 Fable 维护。
const querySynonyms = <String, String>{
  '蹲下': '坐下',
  '蹲着': '坐着',
  '蹲好': '坐好',
  '躺下': '趴下',
  '卧下': '趴下',
  '趴着': '趴下',
  '狂叫': '乱叫',
  '叫个不停': '乱叫',
  '一直叫': '乱叫',
  '吠': '吠叫',
  '扑到': '扑人',
  '扑上来': '扑人',
  '扑过来': '扑人',
  '往人身上跳': '扑人',
  '待着别动': '等待',
  '别动': '等待',
  '待在原地': '等待',
  '原地不动': '等待',
  '看着我': '不看我',
  '护着碗': '护食',
  '护碗': '护食',
  '护着': '护食',
  '啃我': '咬我',
  '啃手': '咬手',
  '哼唧': '哭叫',
  '呜呜叫': '哭叫',
  '拽着': '拉绳',
  '拽绳': '拉绳',
  '狗笼': '笼子',
  '上班': '不在家',
  '往上蹦': '跳起来',
  '往上跳': '跳起来',
  '蹦起来': '跳起来',
  '溜狗': '遛狗',
  '溜它': '遛狗',
  '往前拉': '拉绳',
  '脚': '爪子',
  '爪爪': '爪子',
  '电线': '咬东西',
  '咬坏': '咬东西',
  '嚎': '哭叫',
};

/// 问题里的套话：切片前去掉，避免"怎么办""我家狗"这类片段撞上任何条目。
const _stopPhrases = <String>[
  '怎么办', '怎么样', '怎么回事', '为什么', '是什么', '什么时候', '怎么', '如何', '什么',
  '我家的', '我家', '我的', '狗狗', '小狗', '幼犬', '狗子', '我们',
  '一直', '总是', '老是', '还是', '经常', '有时候', '每次', '已经', '应该', '可以', '能不能',
  '需要', '要不要', '是不是', '有没有', '一下', '这样', '那样', '这个', '那个', '时候',
];

/// 单字虚词：作为切片的分隔符。
const _stopChars = '的了吗呢吧啊呀哦嘛它他她我你狗是在就都也还又很太和与或把被让给对';

class FulltextHit {
  const FulltextHit(this.id, this.score, this.matched, {this.nameMatched = false});

  /// 是否有片段落在条目名称里（建议要求这一条，避免"意思""盯着"这类泛用片段带出无关条目）。
  final bool nameMatched;
  final String id;

  /// 0–1：问题有效片段（按信息量加权）在该条目中出现的比例。
  final double score;

  /// 命中的不同片段数。
  final int matched;

  @override
  String toString() => '$id:${score.toStringAsFixed(2)}($matched)';
}

class _Index {
  _Index(this.docs, this.idf);
  final Map<String, Set<String>> docs; // id → 片段集合
  final Map<String, double> idf;
}

final _cache = Expando<_Index>('fulltext');

bool _isCjk(int c) => c >= 0x4E00 && c <= 0x9FFF;

/// 文本 → 二字片段（只取连续的汉字段内部；字母数字整体作为一个片段）。
Set<String> _grams(String text) {
  final out = <String>{};
  final buf = StringBuffer();
  void flush() {
    final s = buf.toString();
    buf.clear();
    if (s.length >= 2) {
      for (var i = 0; i + 2 <= s.length; i++) {
        out.add(s.substring(i, i + 2));
      }
    }
  }

  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    if (_isCjk(r) && !_stopChars.contains(ch)) {
      buf.write(ch);
    } else {
      flush();
    }
  }
  flush();
  return out;
}

String _docText(Object item) {
  final b = StringBuffer();
  if (item is Skill) {
    b
      ..writeln(item.name)
      ..writeln(item.defaultCue)
      ..writeln(item.tutorial.summary)
      ..writeln(item.tutorial.successCriteria);
    for (final s in item.tutorial.steps) {
      b.writeln(s.text);
    }
    for (final m in item.tutorial.commonMistakes) {
      b.writeln(m);
    }
  } else if (item is FaqEntry) {
    b
      ..writeln(item.question)
      ..writeln(item.answer);
    for (final k in item.keywords) {
      b.writeln(k);
    }
    for (final t in item.tips) {
      b.writeln(t);
    }
  } else if (item is Issue) {
    b.writeln(item.name);
    for (final n in item.diagnosisTree) {
      b.writeln(n.question);
      for (final o in n.options) {
        b.writeln(o.text);
      }
    }
    for (final s in item.solutions) {
      b
        ..writeln(s.summary)
        ..writeln(s.escalateIf);
      for (final m in s.management) {
        b.writeln(m);
      }
    }
  }
  return b.toString();
}

_Index _indexFor(ContentLibrary lib) {
  final hit = _cache[lib];
  if (hit != null) return hit;
  final docs = <String, Set<String>>{
    for (final s in lib.skills) s.id: _grams(_docText(s)),
    for (final i in lib.issues) i.id: _grams(_docText(i)),
    for (final f in lib.faqs) f.id: _grams(_docText(f)),
  };
  // 名称里的片段额外记一遍（名称最能代表条目）：用前缀标记，打分时加权
  for (final s in lib.skills) {
    docs[s.id]!.addAll(_grams(s.name).map((g) => '#$g'));
  }
  for (final i in lib.issues) {
    docs[i.id]!.addAll(_grams(i.name).map((g) => '#$g'));
  }
  for (final f in lib.faqs) {
    docs[f.id]!.addAll(_grams(f.question).map((g) => '#$g'));
  }
  final n = docs.length;
  final df = <String, int>{};
  for (final grams in docs.values) {
    for (final g in grams) {
      if (g.startsWith('#')) continue;
      df[g] = (df[g] ?? 0) + 1;
    }
  }
  final idf = {for (final e in df.entries) e.key: math.log((n + 1) / (e.value + 0.5))};
  return _cache[lib] = _Index(docs, idf);
}

/// 同义展开：原句后面追加展开出的词表词（原句保留，健康词等判断不受影响）。
String expandSynonyms(String message) {
  final add = <String>[
    for (final e in querySynonyms.entries)
      if (message.contains(e.key) && !message.contains(e.value)) e.value,
  ];
  return add.isEmpty ? message : '$message ${add.join(' ')}';
}

/// 同义展开 + 去套话后的查询文本。
String normalizeQuery(String message) {
  var q = message;
  // 长的先替换，避免"蹲"先把"蹲下"拆坏
  final keys = querySynonyms.keys.toList()..sort((a, b) => b.length - a.length);
  for (final k in keys) {
    if (q.contains(k)) q = q.replaceAll(k, ' ${querySynonyms[k]} ');
  }
  for (final p in _stopPhrases) {
    q = q.replaceAll(p, ' ');
  }
  return q;
}

/// 全文打分：返回所有得分 > 0 的条目，按分数降序（同分按 id，保证确定性）。
List<FulltextHit> fulltextSearch(String message, ContentLibrary lib) {
  final idx = _indexFor(lib);
  final q = _grams(normalizeQuery(message));
  // 只保留在内容库里出现过的片段；没出现过的（如"握手""飞盘"）计入分母，拉低得分
  double weight(String g) => idx.idf[g] ?? math.log(idx.docs.length + 1.0);
  final total = q.fold<double>(0, (a, g) => a + weight(g));
  if (total == 0) return const [];
  final hits = <FulltextHit>[];
  for (final e in idx.docs.entries) {
    var got = 0.0;
    var matched = 0;
    var inName = false;
    for (final g in q) {
      if (e.value.contains(g)) {
        matched++;
        if (e.value.contains('#$g')) inName = true;
        // 名称里出现的片段加权 1.5 倍（上限为该片段自身权重的 1.5 倍）
        got += weight(g) * (e.value.contains('#$g') ? 1.5 : 1.0);
      }
    }
    if (matched == 0) continue;
    hits.add(FulltextHit(e.key, math.min(1.0, got / total), matched, nameMatched: inName));
  }
  hits.sort((a, b) {
    final d = b.score.compareTo(a.score);
    return d != 0 ? d : a.id.compareTo(b.id);
  });
  return hits;
}

/// 全文检索的强命中：足够多片段、足够高分、且明显领先第二名。没有返回 null。
FulltextHit? fulltextStrongHit(List<FulltextHit> hits) {
  if (hits.isEmpty) return null;
  final top = hits.first;
  final second = hits.length > 1 ? hits[1].score : 0.0;
  if (top.matched >= fulltextMinMatched && top.score >= fulltextHitScore && top.score - second >= fulltextMinMargin) {
    return top;
  }
  return null;
}

/// "你可能想问"：分数与片段数达到建议阈值的前 [n] 个。
List<FulltextHit> fulltextSuggestions(List<FulltextHit> hits, {int n = 3}) => [
      for (final h in hits)
        if (h.matched >= fulltextSuggestMinMatched && h.score >= fulltextSuggestScore && h.nameMatched) h,
    ].take(n).toList();
