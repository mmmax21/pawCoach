/// M3 简报第 10 节：retrieval / ai_guard / diagnosis 纯函数单测，
/// 以及 prompt_builder、[ref] 解析、SSE 解析、内容库 v1.2 门槛。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/ai/ai_client.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/ai/fake_ai_client.dart';
import 'package:puppy_trainer/data/ai/prompt_builder.dart';
import 'package:puppy_trainer/data/content/content_parser.dart';
import 'package:puppy_trainer/data/content/content_repository.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/domain/ai_guard.dart';
import 'package:puppy_trainer/domain/diagnosis.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/domain/retrieval.dart';

import 'helpers.dart';

const _dog = DogBrief(name: '豆豆', ageWeeks: 12, concernNames: [], masteredSkillNames: []);

void main() {
  late ContentLibrary lib;
  setUpAll(() async {
    lib = await loadRepoContent();
  });

  group('retrieval（简报第 10 节）', () {
    test('课程内提问必含该技能，且排在最前', () {
      final r = retrieve(message: '今天天气不错', library: lib, skillId: 'down');
      expect(r.ids.first, 'down');
      expect(r.noHit, isFalse);
    });

    test('"狗不坐"命中 sit', () {
      final r = retrieve(message: '狗不坐', library: lib);
      expect(r.ids, contains('sit'));
      expect(r.topScore, greaterThan(0));
    });

    test('"咬手"同时命中 biting_hands 和 bite_inhibition', () {
      final r = retrieve(message: '咬手', library: lib);
      expect(r.ids, containsAll(['biting_hands', 'bite_inhibition']));
    });

    test('"今天天气不错"得分 0，无命中', () {
      final r = retrieve(message: '今天天气不错', library: lib);
      expect(r.topScore, 0);
      expect(r.ids, isEmpty);
      expect(r.noHit, isTrue);
    });

    test('诊断对话带 issue_id：该 issue 必入', () {
      final r = retrieve(message: '还有别的办法吗', library: lib, issueId: 'biting_hands');
      expect(r.contextIds, ['biting_hands']);
      expect(r.noHit, isFalse);
    });

    test('一个词出现多次只计一次', () {
      final once = scoreKeywords('咬手', lib.aiTerms).scores;
      final twice = scoreKeywords('咬手咬手咬手', lib.aiTerms).scores;
      expect(twice, once);
    });

    test('最多追加 3 个，上下文不重复计入', () {
      final r = retrieve(message: '坐下趴下等待召回牵绳', library: lib, skillId: 'sit');
      expect(r.scored.length, lessThanOrEqualTo(retrievalTopK));
      expect(r.scored.map((s) => s.id), isNot(contains('sit')));
    });

    test('同分按首次命中顺序（长词先查）', () {
      // 叫不回(3 字) 先于 出门(2 字)：not_coming / recall_* 排在 alone_time 之前。
      final r = retrieve(message: '在家叫得回来出门就叫不回', library: lib);
      expect(r.scored.first.id, 'not_coming');
    });

    test('bestIssueFor：只在问题行为里取最高分；无命中为 null', () {
      expect(bestIssueFor('总是在家里乱尿', lib), 'potty_accidents');
      expect(bestIssueFor('今天天气不错', lib), isNull);
      // "坐下"只映射技能，不映射问题行为
      expect(bestIssueFor('坐下', lib), isNull);
    });
  });

  group('ai_guard（简报第 10 节，以 v1.2 词表为准）', () {
    test('hard 词命中', () {
      final r = checkHealthGuard('狗拉肚子能不能继续训练', lib.aiGuard);
      expect(r.blocked, isTrue);
      expect(r.group, 'hard');
    });

    test('hard 词即使与训练词同句也拦', () {
      expect(checkHealthGuard('练坐下的时候突然抽搐了', lib.aiGuard).blocked, isTrue);
    });

    test('soft 词单独命中', () {
      final r = checkHealthGuard('没精神一直睡', lib.aiGuard);
      expect(r.blocked, isTrue);
      expect(r.group, 'soft');
    });

    test('soft 词与训练词同句（逗号不切句）不拦："它没精神，坐下练不进去"', () {
      expect(checkHealthGuard('它没精神，坐下练不进去', lib.aiGuard).blocked, isFalse);
    });

    test('soft 词与训练词在不同句（句号切开）仍拦', () {
      expect(checkHealthGuard('坐下练得还行。今天它一直发抖', lib.aiGuard).blocked, isTrue);
    });

    test('普通训练问题不拦', () {
      expect(checkHealthGuard('坐下练了三天狗还是不坐怎么办', lib.aiGuard).blocked, isFalse);
    });
  });

  group('diagnosis（简报第 10 节）', () {
    test('9 个 issue 每条路径都能走到 result，且不超过 4 问', () {
      expect(lib.issues.length, 9);
      for (final issue in lib.issues) {
        final paths = allDiagnosisPaths(issue);
        expect(paths, isNotEmpty, reason: issue.id);
        for (final p in paths) {
          expect(p.length, lessThanOrEqualTo(maxDiagnosisDepth), reason: '${issue.id} $p');
          final step = diagnosisNext(issue, p);
          expect(step, isA<DiagnosisOutcome>(), reason: '${issue.id} $p');
          final o = step as DiagnosisOutcome;
          expect(o.solution.skills, isNotEmpty);
          expect(o.solution.escalateIf, isNotEmpty);
        }
        // 每个 solution 至少有一条路径能到达
        final reached = {
          for (final p in paths) (diagnosisNext(issue, p) as DiagnosisOutcome).resultKey,
        };
        expect(reached, {for (final s in issue.solutions) s.key}, reason: issue.id);
      }
    });

    test('空路径返回第一问', () {
      final issue = lib.issueById['biting_hands']!;
      final s = diagnosisNext(issue, const []);
      expect(s, isA<DiagnosisQuestion>());
      expect((s as DiagnosisQuestion).depth, 1);
      expect(s.node.question, issue.diagnosisTree.first.question);
    });

    test('选项越界抛异常', () {
      final issue = lib.issueById['biting_hands']!;
      expect(() => diagnosisNext(issue, const [99]), throwsA(isA<DiagnosisException>()));
      expect(() => diagnosisNext(issue, const [-1]), throwsA(isA<DiagnosisException>()));
    });

    test('到达结果后路径还有多余项抛异常', () {
      final issue = lib.issueById['biting_hands']!;
      final p = allDiagnosisPaths(issue).first;
      expect(() => diagnosisNext(issue, [...p, 0]), throwsA(isA<DiagnosisException>()));
    });

    test('diagnosisAnswers 还原问题与选项原文', () {
      final issue = lib.issueById['biting_hands']!;
      final p = allDiagnosisPaths(issue).first;
      final answers = diagnosisAnswers(issue, p);
      expect(answers.length, p.length);
      expect(answers.first.question, issue.diagnosisTree.first.question);
    });
  });

  group('prompt_builder', () {
    test('系统提示模板（无资料时）不含任何技能步骤、口令或脚本文案', () {
      final system = buildSystemPrompt(dog: _dog, materials: const [], library: lib);
      for (final s in lib.skills) {
        if (s.defaultCue.length >= 2) {
          expect(system, isNot(contains(s.defaultCue)), reason: '${s.id} 口令');
        }
        for (final st in s.tutorial.steps) {
          expect(system, isNot(contains(st.text)), reason: '${s.id} 步骤');
        }
        for (final sc in [...s.script, ...s.miniScript]) {
          expect(system, isNot(contains(sc.instruction)), reason: '${s.id} 脚本');
        }
        for (final m in s.tutorial.commonMistakes) {
          expect(system, isNot(contains(m)), reason: '${s.id} 常见错误');
        }
      }
      expect(system, contains('[ref: id1, id2]'));
      expect(system, contains(noHitGuardCore));
    });

    test('资料块含检索到的技能原文与 ID；带最近 3 次评分与当前步骤', () {
      final sit = lib.skillById['sit']!;
      final system = buildSystemPrompt(
        dog: const DogBrief(
          name: '豆豆',
          ageWeeks: 12,
          concernNames: ['咬手 / 啃人'],
          masteredSkillNames: ['标记词'],
          skillName: '坐下',
          recentScores: [Score.none, Score.partial, Score.full],
          currentStep: 2,
        ),
        materials: const ['sit', 'biting_hands'],
        library: lib,
      );
      expect(materialIdsInPrompt(system), ['sit', 'biting_hands']);
      expect(system, contains(sit.tutorial.successCriteria));
      expect(system, contains(sit.scoringHint));
      expect(system, contains(sit.tutorial.commonMistakes.first));
      expect(system, contains('没做到、部分做到、完全做到'));
      expect(system, contains('第 2 步'));
      expect(system, contains(lib.issueById['biting_hands']!.solutions.first.escalateIf));
    });

    test('parseAnswer：去掉末尾 [ref]，拆出 ID', () {
      final p = parseAnswer('先降低难度。\n[ref: sit, stay_short]');
      expect(p.body, '先降低难度。');
      expect(p.refs, ['sit', 'stay_short']);
      expect(p.hadRef, isTrue);
      expect(parseAnswer('[REF：sit、down]').refs, ['sit', 'down']);
      expect(parseAnswer('没有引用').hadRef, isFalse);
    });

    test('visibleWhileStreaming 隐藏尾部 [ref 片段', () {
      expect(visibleWhileStreaming('回答\n[ref: si'), '回答');
      expect(visibleWhileStreaming('回答['), '回答');
      expect(visibleWhileStreaming('回答[re'), '回答');
      expect(visibleWhileStreaming('回答'), '回答');
    });
  });

  group('第三层回答后处理（简报第 5 节）', () {
    late AiCoachEngine engine;
    final logs = <String>[];
    setUp(() {
      logs.clear();
      engine = AiCoachEngine(library: lib, client: FakeAiClient(), mode: AiMode.model, log: logs.add);
    });
    RetrievalResult r() => retrieve(message: '坐下', library: lib);

    test('[ref] 缺失：仍展示，cited 为空并打日志', () {
      final a = engine.finalizeAnswer('先降低难度。', r());
      expect(a.kind, AiMessageKind.normal);
      expect(a.text, '先降低难度。');
      expect(a.cited, isEmpty);
      expect(logs.single, startsWith('ref_missing'));
    });

    test('[ref] ID 不在检索集合：cited 为空并打日志', () {
      final a = engine.finalizeAnswer('答案\n[ref: sit, crate_intro]', r());
      expect(a.cited, isEmpty);
      expect(logs.single, startsWith('ref_invalid'));
    });

    test('合法 [ref]：cited 写入', () {
      final a = engine.finalizeAnswer('答案\n[ref: sit]', r());
      expect(a.cited, ['sit']);
      expect(logs, isEmpty);
    });

    test('回答出现固定话术原文：kind 改为 guard_no_hit', () {
      final a = engine.finalizeAnswer('这个问题内容库暂时没有覆盖，建议咨询专业训犬师', r());
      expect(a.kind, AiMessageKind.guardNoHit);
      expect(a.cited, isEmpty);
    });

    test('历史只带最近 10 条', () async {
      final fake = FakeAiClient();
      final e = AiCoachEngine(library: lib, client: fake, mode: AiMode.model, log: (_) {});
      final history = [
        for (var i = 0; i < 14; i++) ChatTurn(role: i.isEven ? 'user' : 'assistant', content: '$i'),
      ];
      await e.ask(question: '坐下怎么练', dog: _dog, history: history).drain<void>();
      expect(fake.lastMessages!.length, aiHistoryLimit + 1);
      expect(fake.lastMessages!.first.content, '4');
      expect(fake.lastMessages!.last.content, '坐下怎么练');
    });

    test('网络失败抛 AiClientException', () async {
      final e = AiCoachEngine(
          library: lib, client: FakeAiClient(fail: true), mode: AiMode.model, log: (_) {});
      expect(e.ask(question: '坐下怎么练', dog: _dog).drain<void>(),
          throwsA(isA<AiClientException>()));
    });
  });

  group('SSE 解析', () {
    test('多行 data 用换行拼接，[DONE] 与 error 事件', () async {
      final events = await parseSse(Stream.fromIterable([
        'data: 第一行',
        'data: 第二行',
        '',
        ': 注释',
        'data: [DONE]',
        '',
        'event: error',
        'data: Boom',
        '',
      ])).toList();
      expect(events.map((e) => e.data), ['第一行\n第二行', '[DONE]', 'Boom']);
      expect(events.last.event, 'error');
    });
  });

  group('内容库 v1.2 门槛', () {
    test('真实内容库读到 v1.2，两个词表已解析', () {
      expect(lib.version, 'v1.6'); // v1.4（M5 为 v1.3），两个词表仍在
      expect(lib.aiGuard.hard, isNotEmpty);
      expect(lib.aiGuard.soft, isNotEmpty);
      expect(lib.aiGuard.trainingTerms, isNotEmpty);
      expect(lib.aiTerms.length, greaterThanOrEqualTo(100));
    });

    test('VERSION.md 取最高版本，不取第一个标题', () {
      expect(parseContentVersion('VERSION.md', '## v1.1\n## v1.0\n## v1.2\n'), 'v1.2');
    });

    test('读到 v1.1 报错', () async {
      final repo = ContentRepository(
        db: memoryDb(),
        source: _PatchedSource(FileContentSource(repoContentDir()),
            overrides: {'VERSION.md': '## v1.1（2026-11-16）\n'}),
      );
      await expectLater(repo.ensureLoaded(), throwsA(isA<ContentParseException>()));
    });

    test('缺 ai_guard.yaml 报错', () async {
      final repo = ContentRepository(
        db: memoryDb(),
        source: _PatchedSource(FileContentSource(repoContentDir()), missing: {'ai_guard.yaml'}),
      );
      await expectLater(
          repo.ensureLoaded(),
          throwsA(isA<ContentParseException>()
              .having((e) => e.file, 'file', 'ai_guard.yaml')));
    });

    test('库里缓存的词表缺失时回到内容源解析，缺 ai_terms.yaml 报错', () async {
      final db = memoryDb();
      await ContentRepository(db: db, source: FileContentSource(repoContentDir())).ensureLoaded();
      expect((await db.select(db.contentAiLexicons).get()).length, 5); // M5：同表另存 video_checks；v1.4：faq；v1.6：body_signals
      await db.delete(db.contentAiLexicons).go();
      final repo = ContentRepository(
        db: db,
        source: _PatchedSource(FileContentSource(repoContentDir()), missing: {'ai_terms.yaml'}),
      );
      await expectLater(
          repo.ensureLoaded(),
          throwsA(isA<ContentParseException>()
              .having((e) => e.file, 'file', 'ai_terms.yaml')));
    });

    test('ai_terms 引用不存在的 ID 报错', () async {
      final repo = ContentRepository(
        db: memoryDb(),
        source: _PatchedSource(FileContentSource(repoContentDir()), overrides: {
          'ai_terms.yaml': 'terms:\n  - { word: 装死, ids: [play_dead] }\n',
        }),
      );
      await expectLater(repo.ensureLoaded(), throwsA(isA<ContentParseException>()));
    });
  });
}

class _PatchedSource implements ContentSource {
  _PatchedSource(this.inner, {this.overrides = const {}, this.missing = const {}});
  final ContentSource inner;
  final Map<String, String> overrides;
  final Set<String> missing;

  @override
  Future<String> read(String relativePath) async {
    if (missing.contains(relativePath)) throw StateError('no such file $relativePath');
    return overrides[relativePath] ?? inner.read(relativePath);
  }

  @override
  Future<({List<String> skills, List<String> issues})> listFiles() => inner.listFiles();
}
