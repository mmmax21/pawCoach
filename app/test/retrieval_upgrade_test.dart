/// 补检索（2026-11-18）：同义展开 + 全文检索兜底 + "你可能想问"。
///
/// - 换种说法的提问应命中正确条目（30 题；前 20 题按 ai_terms 词表外的口语写，后 10 题先盲测 6/10，
///   再据此补了通用同义词，所以已不算盲测）；
/// - tests/ai_boundary/out_of_library.yaml 的库外题仍然全部无命中（ai_boundary_test 同样断言）；
/// - 同义词的目标词都在词表里；示例问题全部命中；建议只来自名称相关的条目。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/domain/fulltext_search.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/retrieval.dart';
import 'package:puppy_trainer/features/ai_coach/chat_page.dart' show ChatStrings;
import 'package:yaml/yaml.dart';

import 'helpers.dart';

const paraphrases = <String, List<String>>{
  '让它蹲下它不动': ['sit'],
  '狗狗老扑到客人身上': ['jumping_on_people'],
  '一出门就拽着绳子往前冲': ['leash_pulling', 'loose_leash'],
  '晚上关在笼子里一直哼唧': ['crate_intro', 'separation_crying'],
  '我一出门上班它就在家叫个不停': ['separation_crying', 'alone_time'],
  '吃饭的时候护着碗不让碰': ['resource_guarding'],
  '最近老是啃拖鞋和沙发': ['chewing_furniture'],
  '给它剪指甲就躲': ['handling_body'],
  '戴上牵引绳就趴着不肯走': ['leash_intro'],
  '换牙期老啃我的手': ['biting_hands', 'bite_inhibition'],
  '让它待在原地别动怎么教': ['stay_short', 'stay_long'],
  '在外面喊它不回来': ['not_coming', 'recall_outdoor', 'recall_indoor'],
  '有人敲门就狂叫': ['excessive_barking'],
  '它不愿意进航空箱': ['crate_intro'],
  '怎么让它安静趴在垫子上': ['calm_settle'],
  '玩着玩着就咬人': ['biting_hands', 'bite_inhibition'],
  '叼着玩具不给我': ['resource_guarding', 'redirect_to_toy'],
  '它在家里随地大小便': ['potty_accidents', 'potty_training'],
  '怎么让它躺下': ['down'],
  '怎么教它看着我': ['name_response'],
  '狗狗见到人就往上蹦': ['jumping_on_people'],
  '溜狗的时候它一直往前拉': ['leash_pulling', 'loose_leash'],
  '它不让我摸它的脚': ['handling_body'],
  '我出门它就嚎': ['separation_crying', 'alone_time'],
  '它把家里的电线咬坏了': ['chewing_furniture'],
  '怎么让它乖乖坐好等我放饭': ['sit', 'stay_short'],
  '在户外放开它就跑没影了': ['not_coming', 'recall_outdoor'],
  '它吃东西的时候我靠近它就吼': ['resource_guarding'],
  '尿在尿垫外面怎么办': ['potty_accidents', 'potty_training'],
  '狗晚上在笼子里叫': ['crate_intro', 'separation_crying'],
};

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  test('换种说法的提问命中正确条目（30 题）', () {
    final wrong = <String>[];
    for (final e in paraphrases.entries) {
      final r = retrieve(message: e.key, library: lib);
      if (!r.ids.any(e.value.contains)) wrong.add('${e.key} → ${r.ids}');
    }
    expect(wrong, isEmpty);
  });

  test('库外题仍然全部无命中', () {
    final doc = loadYaml(File('${repoContentDir().parent.path}/tests/ai_boundary/out_of_library.yaml')
        .readAsStringSync()) as Map;
    for (final e in doc['questions'] as List) {
      final q = (e as Map)['q'].toString();
      expect(retrieve(message: q, library: lib).noHit, isTrue, reason: q);
    }
  });

  test('同义词的目标词都在关键词词表里，展开不改变原句', () {
    final words = {for (final t in lib.aiTerms) t.word};
    for (final e in querySynonyms.entries) {
      expect(words, contains(e.value), reason: '${e.key} → ${e.value}');
    }
    expect(expandSynonyms('让它蹲下'), startsWith('让它蹲下'));
    expect(expandSynonyms('让它蹲下'), contains('坐下'));
    expect(expandSynonyms('今天天气不错'), '今天天气不错');
  });

  test('空对话的示例问题全部命中', () {
    for (final q in ChatStrings.examples) {
      expect(retrieve(message: q, library: lib).noHit, isFalse, reason: q);
    }
  });

  test('全文检索：强命中要求片段数、分数和领先幅度', () {
    expect(fulltextStrongHit(const [FulltextHit('a', 0.9, 3), FulltextHit('b', 0.3, 2)])?.id, 'a');
    expect(fulltextStrongHit(const [FulltextHit('a', 0.9, 2)]), isNull); // 片段太少
    expect(fulltextStrongHit(const [FulltextHit('a', 0.5, 4)]), isNull); // 分数不够
    expect(fulltextStrongHit(const [FulltextHit('a', 0.8, 4), FulltextHit('b', 0.75, 4)]), isNull); // 没有区分度
  });

  test('关键词无命中时由全文检索兜底（结果标记为全文命中）', () {
    final r = retrieve(message: '它吃东西的时候我靠近它就吼', library: lib);
    expect(r.ids, ['resource_guarding']);
    expect(r.fulltextHit, isTrue);
  });

  test('建议：只取名称相关的条目，泛用片段不带出无关条目', () {
    expect(retrieve(message: '狗一直盯着我看是什么意思', library: lib).suggestions, isEmpty);
    final hits = const [
      FulltextHit('a', 0.5, 2, nameMatched: true),
      FulltextHit('b', 0.5, 2),
      FulltextHit('c', 0.2, 2, nameMatched: true),
    ];
    expect([for (final h in fulltextSuggestions(hits)) h.id], ['a']);
  });

  test('课程内 / 诊断上下文与原有关键词命中不受影响', () {
    final r = retrieve(message: '它总是不听', library: lib, skillId: 'sit');
    expect(r.ids, ['sit']);
    expect(r.fulltextHit, isFalse);
    expect(retrieve(message: '坐下练了三天狗还是不坐怎么办', library: lib).ids.first, 'sit');
  });
}
