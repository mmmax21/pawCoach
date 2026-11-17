/// M3 简报第 16 节：内容库直出。
/// - 组装器单测（16.6 第 4 条）；
/// - 原文性测试（16.6 第 2 条，硬门槛）：90 题 + model_should_refuse 10 题 + 18 个技能 × 空关键词问题，
///   回答的每个文本块要么逐字等于内容库某个字段的值（或该狗 DogCue 原文），要么属于模板集合；
/// - 模板审查（16.4）：模板字符串不含任何技能步骤、口令、方法描述。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/ai/fake_ai_client.dart';
import 'package:puppy_trainer/data/ai/prompt_builder.dart';
import 'package:puppy_trainer/domain/ai_guard.dart';
import 'package:puppy_trainer/domain/answer_composer.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/retrieval.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

/// 18 例空关键词问题：问的就是当前技能，但不含任何词表词（16.3 第三种情形）。
const emptyKeywordQuestion = '它老是做不好怎么办';

List<({String q, String? skill})> _load(String name) {
  final dir = Directory('${repoContentDir().parent.path}/tests/ai_boundary');
  final doc = loadYaml(File('${dir.path}/$name').readAsStringSync()) as Map;
  return [
    for (final e in doc['questions'] as List)
      (q: (e as Map)['q'].toString(), skill: (e['context'] as Map?)?['skill_id']?.toString()),
  ];
}

/// 内容库里可被直出的全部原文值（以及 DogCue 原文）。
Set<String> rawValues(ContentLibrary lib, Map<String, CueView> cues) => {
      for (final s in lib.skills) ...[
        s.name,
        s.tutorial.summary,
        s.tutorial.successCriteria,
        ...s.tutorial.commonMistakes,
        s.scoringHint,
        for (final st in [...s.script, ...s.miniScript]) st.instruction,
      ],
      for (final i in lib.issues) i.name,
      for (final c in cues.values) ...[c.cueWord, c.gesture],
    };

/// 原文性断言：每块要么是原文（title / text / bullet / downgradeLink），要么是模板（label / note）。
void expectVerbatim(List<AnswerBlock> blocks, Set<String> raw, {String reason = ''}) {
  for (final b in blocks) {
    if (b.isTemplate) {
      expect(answerTemplates, contains(b.text), reason: '$reason 模板块不在集合内：${b.text}');
    } else {
      expect(raw, contains(b.text), reason: '$reason 原文块对不上内容库：${b.text}');
      expect(b.source, isNotNull, reason: '$reason 原文块缺出处');
    }
  }
}

void main() {
  late ContentLibrary lib;
  late Map<String, CueView> cues;
  late Set<String> raw;
  // 用一份"改过的"口令表模拟 DogCue：证明展示的是 DogCue 而不是 default_cue。
  setUpAll(() async {
    lib = await loadRepoContent();
    cues = {
      for (final s in lib.skills) s.id: CueView(cueWord: '自定义口令${s.id}', gesture: '自定义手势${s.id}'),
    };
    raw = rawValues(lib, cues);
  });

  const dog = DogBrief(name: '豆豆', ageWeeks: 12, concernNames: [], masteredSkillNames: []);

  Future<CoachAnswer> ask(String q,
      {String? skill, String? issue, DogBrief d = dog, int? part}) async {
    final fake = FakeAiClient();
    final e = AiCoachEngine(library: lib, client: fake, mode: AiMode.library, log: (_) {});
    CoachAnswer? done;
    await for (final ev in e.ask(
        question: q, dog: d, skillId: skill, issueId: issue, scriptPart: part, cues: cues)) {
      if (ev is CoachDone) done = ev.answer;
    }
    expect(fake.calls, 0);
    return done!;
  }

  group('组装器（16.6 第 4 条）', () {
    test('条目上限 3、关键词条目最多 2 个、去重', () {
      final r = retrieve(message: '坐下趴下等待召回牵绳', library: lib, skillId: 'sit');
      final ids = selectAnswerItems(r);
      expect(ids.length, lessThanOrEqualTo(composeMaxItems));
      expect(ids.first, 'sit');
      expect(ids.toSet().length, ids.length);
      expect(ids.skip(1).length, lessThanOrEqualTo(composeMaxKeywordItems));
      // 无上下文时最多 2 个
      final r2 = retrieve(message: '坐下趴下等待召回牵绳', library: lib);
      expect(selectAnswerItems(r2).length, lessThanOrEqualTo(composeMaxKeywordItems));
    });

    test('技能字段齐全且顺序固定：名称、口令、手势、简介、成功标准、常见错误全部条目、评分参考', () {
      final sit = lib.skillById['sit']!;
      final c = composeAnswer(
        library: lib,
        retrieval: retrieve(message: '坐下', library: lib, skillId: 'sit'),
        contextSkillId: 'sit',
        cues: cues,
      );
      final texts = c.blocks.map((b) => b.text).toList();
      final i = texts.indexOf(sit.name);
      expect(texts.sublist(i, i + 10), [
        sit.name,
        tplLabelCue,
        cues['sit']!.cueWord,
        tplLabelGesture,
        cues['sit']!.gesture,
        tplLabelSummary,
        sit.tutorial.summary,
        tplLabelSuccess,
        sit.tutorial.successCriteria,
        tplLabelMistakes,
      ]);
      for (final m in sit.tutorial.commonMistakes) {
        expect(texts, contains(m));
      }
      expect(texts, contains(sit.scoringHint));
      expect(c.cited.first, 'sit');
    });

    test('口令取自 DogCue，不是 default_cue', () {
      final sit = lib.skillById['sit']!;
      final c = composeAnswer(
        library: lib,
        retrieval: retrieve(message: '坐下', library: lib, skillId: 'sit'),
        contextSkillId: 'sit',
        cues: {'sit': const CueView(cueWord: '坐好', gesture: '手心向上抬')},
      );
      final texts = c.blocks.map((b) => b.text).toList();
      expect(texts, contains('坐好'));
      expect(texts, contains('手心向上抬'));
      expect(texts, isNot(contains(sit.defaultCue)));
      // 没有口令表时不出口令块
      final c2 = composeAnswer(
          library: lib, retrieval: retrieve(message: '坐下', library: lib, skillId: 'sit'), contextSkillId: 'sit');
      expect(c2.blocks.map((b) => b.text), isNot(contains(tplLabelCue)));
    });

    test('带当前步骤：该步 instruction 原文在技能内容最前（正式脚本与保底脚本）', () {
      final sit = lib.skillById['sit']!;
      for (final part in [1, miniScriptPart]) {
        final c = composeAnswer(
          library: lib,
          retrieval: retrieve(message: '坐下', library: lib, skillId: 'sit'),
          contextSkillId: 'sit',
          currentStep: 2,
          scriptPart: part,
        );
        final texts = c.blocks.map((b) => b.text).toList();
        final i = texts.indexOf(sit.name);
        expect(texts[i + 1], tplLabelCurrentStep);
        expect(texts[i + 2], sit.stepsForPart(part)[1].instruction);
      }
    });

    test('步骤只加在上下文技能上；越界步骤不出', () {
      final c = composeAnswer(
        library: lib,
        retrieval: retrieve(message: '趴下', library: lib, skillId: 'sit'),
        contextSkillId: 'sit',
        currentStep: 99,
        scriptPart: 1,
      );
      expect(c.blocks.map((b) => b.text), isNot(contains(tplLabelCurrentStep)));
      final c2 = composeAnswer(
        library: lib,
        retrieval: retrieve(message: '趴下', library: lib, skillId: 'sit'),
        contextSkillId: 'sit',
        currentStep: 1,
        scriptPart: 1,
      );
      expect(c2.blocks.where((b) => b.text == tplLabelCurrentStep).length, 1);
    });

    test('问题行为只出名称与诊断引导，不出任何 solution 字段', () {
      final c = composeAnswer(library: lib, retrieval: retrieve(message: '咬手', library: lib));
      final issue = lib.issueById['biting_hands']!;
      expect(c.cited, contains('biting_hands'));
      final texts = c.blocks.map((b) => b.text).toSet();
      expect(texts, contains(issue.name));
      expect(texts, contains(tplIssueGuide));
      for (final i in lib.issues) {
        for (final s in i.solutions) {
          expect(texts, isNot(contains(s.summary)));
          expect(texts, isNot(contains(s.escalateIf)));
          for (final m in s.management) {
            expect(texts, isNot(contains(m)));
          }
        }
        for (final n in i.diagnosisTree) {
          expect(texts, isNot(contains(n.question)));
        }
      }
    });

    test('评分联动：最近 2 次都没做到且有 downgrade_to → 指向降级技能；否则不出', () {
      final withDown = lib.skills.firstWhere((s) => s.downgradeTo != null);
      final down = lib.skillById[withDown.downgradeTo]!;
      ComposedAnswer run(List<Score> scores, Skill s) => composeAnswer(
            library: lib,
            retrieval: retrieve(message: emptyKeywordQuestion, library: lib, skillId: s.id),
            contextSkillId: s.id,
            recentScores: scores,
          );
      final hit = run([Score.none, Score.none, Score.full], withDown);
      final link = hit.blocks.where((b) => b.type == AnswerBlockType.downgradeLink).single;
      expect(link.text, down.name);
      expect(link.targetId, down.id);
      expect(hit.blocks.map((b) => b.text), contains(tplDowngradeGuide));
      for (final scores in [
        [Score.none],
        [Score.none, Score.partial],
        [Score.full, Score.none],
        <Score>[],
      ]) {
        expect(run(scores, withDown).blocks.where((b) => b.type == AnswerBlockType.downgradeLink), isEmpty,
            reason: '$scores');
      }
      final noDown = lib.skills.where((s) => s.downgradeTo == null).firstOrNull;
      if (noDown != null) {
        expect(run([Score.none, Score.none], noDown).blocks.where((b) => b.type == AnswerBlockType.downgradeLink),
            isEmpty);
      }
    });

    test('16.3 三种情形', () async {
      // 1. 无上下文、关键词 0 → guard_no_hit
      final a1 = await ask('今天天气不错');
      expect(a1.kind, AiMessageKind.guardNoHit);
      expect(a1.text, noHitGuardReply);
      // 2. 有上下文、关键词 > 0 → 正常直出，不追加
      final a2 = await ask('坐下练了三天狗还是不坐怎么办', skill: 'sit');
      expect(a2.kind, AiMessageKind.normal);
      expect(a2.blocks!.map((b) => b.text), isNot(contains(tplCourseOutOfScope)));
      // 3. 有上下文、关键词 0 → 只出上下文条目，末尾追加固定一句
      final a3 = await ask('怎么教狗握手', skill: 'sit');
      expect(a3.kind, AiMessageKind.normal);
      expect(a3.cited, ['sit']);
      expect(a3.blocks!.last.text, tplCourseOutOfScope);
    });

    test('历史不影响回答：同一问题同一上下文输出恒定', () async {
      final a = await ask('它坐下马上又站起来', skill: 'sit');
      final b = await ask('它坐下马上又站起来', skill: 'sit');
      expect(a.text, b.text);
      expect(a.cited, b.cited);
    });

    test('纯文本快照：逐块一行，能解析回块类型', () async {
      final a = await ask('咬手怎么办', skill: 'bite_inhibition');
      final lines = a.text.split('\n');
      expect(a.text, a.blocks!.map(snapshotLine).join('\n'));
      expect(parseSnapshotLine(lines.first).type, SnapshotLineType.body); // 引导语
      expect(lines.where((l) => parseSnapshotLine(l).type == SnapshotLineType.title), isNotEmpty);
      expect(lines.where((l) => parseSnapshotLine(l).type == SnapshotLineType.label), isNotEmpty);
    });
  });

  group('模板审查（16.4）', () {
    test('模板字符串不含任何技能口令、步骤、脚本、常见错误、方案文案', () {
      for (final tpl in answerTemplates) {
        for (final s in lib.skills) {
          if (s.defaultCue.length >= 2) expect(tpl, isNot(contains(s.defaultCue)), reason: tpl);
          for (final st in s.tutorial.steps) {
            expect(tpl, isNot(contains(st.text)));
          }
          for (final sc in [...s.script, ...s.miniScript]) {
            expect(tpl, isNot(contains(sc.instruction)));
          }
          for (final m in s.tutorial.commonMistakes) {
            expect(tpl, isNot(contains(m)));
          }
        }
        for (final i in lib.issues) {
          for (final sol in i.solutions) {
            expect(tpl, isNot(contains(sol.summary)));
            for (final m in sol.management) {
              expect(tpl, isNot(contains(m)));
            }
          }
        }
      }
    });

    test('模板集合是封闭的常量：不代入任何内容', () {
      expect(answerTemplates.length, 13);
    });
  });

  group('原文性测试（16.6 第 2 条，硬门槛）', () {
    final questions = [
      for (final f in ['in_library.yaml', 'out_of_library.yaml', 'health.yaml', 'model_should_refuse.yaml'])
        for (final q in _load(f)) (file: f, q: q.q, skill: q.skill),
    ];

    test('题目总数 100', () => expect(questions.length, 100));

    for (final item in questions) {
      test('${item.file} · ${item.q}', () async {
        final a = await ask(item.q, skill: item.skill);
        if (a.blocks == null) {
          // 固定话术
          expect({healthGuardReply, noHitGuardReply}, contains(a.text));
          return;
        }
        expectVerbatim(a.blocks!, raw, reason: item.q);
        // 快照也只由原文 / 模板 / 行首排版符号构成
        expect(a.text, a.blocks!.map(snapshotLine).join('\n'));
      });
    }

    // 18 个技能各作为上下文 × 空关键词问题；带当前步骤与"最近两次没做到"，覆盖步骤块与降级块。
    for (final id in [
      'alone_time', 'bite_inhibition', 'calm_settle', 'crate_intro', 'down', 'handling_body',
      'leash_intro', 'loose_leash', 'lure_follow', 'marker_intro', 'name_response', 'potty_training',
      'recall_indoor', 'recall_outdoor', 'redirect_to_toy', 'sit', 'stay_long', 'stay_short',
    ]) {
      test('上下文 $id × 空关键词问题', () async {
        expect(lib.skillById, contains(id));
        final a = await ask(
          emptyKeywordQuestion,
          skill: id,
          part: 1,
          d: const DogBrief(
            name: '豆豆',
            ageWeeks: 12,
            concernNames: [],
            masteredSkillNames: [],
            recentScores: [Score.none, Score.none],
            currentStep: 1,
          ),
        );
        expect(a.kind, AiMessageKind.normal);
        expect(a.cited, [id]);
        expect(a.blocks!.last.text, tplCourseOutOfScope);
        expect(a.blocks!.map((b) => b.text), contains(lib.skillById[id]!.stepsForPart(1).first.instruction));
        expectVerbatim(a.blocks!, raw, reason: id);
      });
    }

    test('18 个技能清单与内容库一致', () => expect(lib.skills.length, 18));
  });
}
