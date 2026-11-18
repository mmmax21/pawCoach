/// 内容库 v1.4 常见问题（FAQ）：加载、缓存往返、检索命中、原文直出、模型模式资料。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/ai/fake_ai_client.dart';
import 'package:puppy_trainer/data/ai/prompt_builder.dart';
import 'package:puppy_trainer/data/content/content_repository.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/domain/answer_composer.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/retrieval.dart';

import 'helpers.dart';

const _dog = DogBrief(name: '豆豆', ageWeeks: 12, concernNames: [], masteredSkillNames: []);

/// 换种说法问常见问题（不是 FAQ 原文问法）→ 期望命中的 FAQ。
const faqParaphrases = <String, String>{
  '小狗几个月开始训练比较好': 'faq_start_age',
  '一天练几次合适': 'faq_session_length',
  '训练零食怎么选': 'faq_treats',
  '它对零食没兴趣怎么练': 'faq_not_food_motivated',
  '没有响片可以训练吗': 'faq_clicker_vs_word',
  '奖励晚了会怎么样': 'faq_reward_timing',
  '它咬坏东西我能不能打它': 'faq_punishment',
  '家里每个人说法不同怎么办': 'faq_family_consistency',
  '出门就不会坐了': 'faq_generalize',
  '怎么判断它学会了没有': 'faq_learned',
  '不给零食就不听怎么办': 'faq_fade_treats',
  '口令要重复吗': 'faq_repeat_cue',
  '训练时总走神': 'faq_distracted',
  '以前会的现在又不会了': 'faq_regression',
  '刚搬家要重新训练吗': 'faq_new_home',
  '怎么做社会化': 'faq_socialization',
};

void main() {
  late ContentLibrary lib;
  setUpAll(() async => lib = await loadRepoContent());

  Future<CoachAnswer> ask(String q) async {
    final e = AiCoachEngine(library: lib, client: FakeAiClient(), mode: AiMode.library, log: (_) {});
    CoachAnswer? done;
    await for (final ev in e.ask(question: q, dog: _dog)) {
      if (ev is CoachDone) done = ev.answer;
    }
    return done!;
  }

  test('加载 faq.yaml：24 条，related 都能查到，检索词进入检索词表', () {
    expect(lib.faqs.length, 24);
    for (final f in lib.faqs) {
      expect(f.sources, isNotEmpty, reason: f.id);
      for (final r in f.related) {
        expect(lib.skillById.containsKey(r) || lib.issueById.containsKey(r), isTrue, reason: '${f.id} → $r');
      }
    }
    final faqWords = lib.searchTerms.where((t) => t.ids.any((id) => id.startsWith('faq_'))).length;
    expect(faqWords, lib.faqs.fold<int>(0, (a, f) => a + f.keywords.length));
    expect(lib.searchTerms.length, lib.aiTerms.length + faqWords);
  });

  test('数据库缓存往返：从库读回的 FAQ 与内容源一致', () async {
    final db = memoryDb();
    final repo = ContentRepository(db: db, source: FileContentSource(repoContentDir()));
    final first = await repo.ensureLoaded();
    final again = await ContentRepository(db: db, source: FileContentSource(repoContentDir())).ensureLoaded();
    expect([for (final f in again.faqs) f.id], [for (final f in first.faqs) f.id]);
    expect(again.faqById['faq_treats']!.answer, first.faqById['faq_treats']!.answer);
    await db.close();
  });

  test('每条 FAQ 的标准问法都走到这条 FAQ（不被健康拦截），回答为原文直出', () async {
    for (final f in lib.faqs) {
      final a = await ask(f.question);
      expect(a.kind, AiMessageKind.normal, reason: f.question);
      expect(a.cited, contains(f.id), reason: '${f.question} → ${a.cited}');
      expect(a.modelCalled, isFalse);
      final blocks = a.blocks!;
      final start = blocks.indexWhere((b) => b.targetId == f.id);
      expect(blocks[start].text, f.question);
      expect(blocks[start + 1].text, f.answer);
      for (final b in blocks) {
        if (b.isTemplate) expect(answerTemplates, contains(b.text));
      }
    }
  });

  test('换种说法问常见问题也能命中', () {
    final wrong = <String>[];
    for (final e in faqParaphrases.entries) {
      final r = retrieve(message: e.key, library: lib);
      if (!r.ids.contains(e.value)) wrong.add('${e.key} → ${r.ids}');
    }
    expect(wrong, isEmpty);
  });

  test('FAQ 回答：要点与相关技能（可点进技能页）', () async {
    final a = await ask('训练用什么零食做奖励？');
    final texts = a.blocks!.map((b) => b.text).toList();
    final f = lib.faqById['faq_treats']!;
    expect(texts, containsAll([tplLabelTips, ...f.tips, tplLabelRelated]));
    final links = a.blocks!.where((b) => b.type == AnswerBlockType.downgradeLink).map((b) => b.targetId);
    expect(links, containsAll(f.related));
  });

  test('模型模式：命中 FAQ 时资料里带上 FAQ 原文', () {
    final prompt = buildSystemPrompt(dog: _dog, materials: ['faq_reward_timing'], library: lib);
    expect(prompt, contains('type="faq"'));
    expect(prompt, contains(lib.faqById['faq_reward_timing']!.answer));
  });
}
