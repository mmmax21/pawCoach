/// AI 边界测试题集（验收硬门槛）：tests/ai_boundary/ 下 in_library / out_of_library / health 各 30 题。
/// M3 简报第 16 节起按 library 模式（内容库直出）跑：三组的模型调用次数都断言为 0。
/// FakeAiClient 只用来计数，证明从未被调用。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/ai/ai_coach_engine.dart';
import 'package:puppy_trainer/data/ai/fake_ai_client.dart';
import 'package:puppy_trainer/data/ai/prompt_builder.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

class BoundaryQuestion {
  BoundaryQuestion(this.q, this.expectIds, this.skillId, this.issueId);
  final String q;
  final List<String> expectIds;
  final String? skillId;
  final String? issueId;
}

List<BoundaryQuestion> loadQuestions(String name) {
  final dir = Directory('${repoContentDir().parent.path}/tests/ai_boundary');
  final doc = loadYaml(File('${dir.path}/$name').readAsStringSync()) as Map;
  return [
    for (final e in doc['questions'] as List)
      BoundaryQuestion(
        (e as Map)['q'].toString(),
        [for (final id in (e['expect_ids'] as List?) ?? const []) id.toString()],
        (e['context'] as Map?)?['skill_id']?.toString(),
        (e['context'] as Map?)?['issue_id']?.toString(),
      ),
  ];
}

const _dog = DogBrief(
  name: '测试狗',
  ageWeeks: 12,
  concernNames: [],
  masteredSkillNames: [],
);

Future<CoachAnswer> run(AiCoachEngine engine, BoundaryQuestion q) async {
  CoachAnswer? done;
  await for (final e in engine.ask(
    question: q.q,
    dog: _dog,
    skillId: q.skillId,
    issueId: q.issueId,
  )) {
    if (e is CoachDone) done = e.answer;
  }
  return done!;
}

void main() {
  late ContentLibrary lib;
  setUpAll(() async {
    lib = await loadRepoContent();
  });

  final inLib = loadQuestions('in_library.yaml');
  final outLib = loadQuestions('out_of_library.yaml');
  final health = loadQuestions('health.yaml');

  test('题集各 30 题', () {
    expect(inLib.length, 30);
    expect(outLib.length, 30);
    expect(health.length, 30);
  });

  group('库内 30 题：kind = normal，cited 非空且含 expect_ids 之一，不调模型', () {
    for (final q in inLib) {
      test(q.q, () async {
        final fake = FakeAiClient();
        final engine = AiCoachEngine(library: lib, client: fake, mode: AiMode.library, log: (_) {});
        final a = await run(engine, q);
        expect(a.kind, AiMessageKind.normal, reason: '${a.retrieval}');
        expect(a.cited, isNotEmpty);
        expect(a.cited.any(q.expectIds.contains), isTrue,
            reason: 'cited=${a.cited} expect=${q.expectIds}');
        expect(fake.calls, 0); // 16.6：library 模式库内题也不调模型
        expect(a.modelCalled, isFalse);
        expect(a.blocks, isNotEmpty);
      });
    }
  });

  group('库外 30 题：kind = guard_no_hit，不调模型', () {
    for (final q in outLib) {
      test(q.q, () async {
        final fake = FakeAiClient();
        final engine = AiCoachEngine(library: lib, client: fake, mode: AiMode.library, log: (_) {});
        final a = await run(engine, q);
        expect(a.kind, AiMessageKind.guardNoHit, reason: '${a.retrieval}');
        expect(a.text, '这个问题内容库暂时没有覆盖，建议咨询专业训犬师。');
        expect(a.cited, isEmpty);
        expect(fake.calls, 0);
      });
    }
  });

  group('健康 30 题：kind = guard_health，不调模型', () {
    for (final q in health) {
      test(q.q, () async {
        final fake = FakeAiClient();
        final engine = AiCoachEngine(library: lib, client: fake, mode: AiMode.library, log: (_) {});
        final a = await run(engine, q);
        expect(a.kind, AiMessageKind.guardHealth);
        expect(a.text, '涉及狗狗健康的问题，请尽快咨询兽医。训练上的问题我随时在。');
        expect(fake.calls, 0);
      });
    }
  });

  // 16.6 第 6 条：model 模式（构建开关）既有行为不回退。
  group('model 模式回归：库内 30 题经 FakeAiClient，调用 1 次、[ref] 解析正确', () {
    for (final q in inLib) {
      test(q.q, () async {
        final fake = FakeAiClient();
        final engine = AiCoachEngine(library: lib, client: fake, mode: AiMode.model, log: (_) {});
        final a = await run(engine, q);
        expect(a.kind, AiMessageKind.normal);
        expect(a.cited.any(q.expectIds.contains), isTrue, reason: 'cited=${a.cited}');
        expect(fake.calls, 1);
        expect(a.text, isNot(contains('[ref')));
      });
    }
  });
}
