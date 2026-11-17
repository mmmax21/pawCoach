import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/content/content_parser.dart';
import 'package:puppy_trainer/data/content/content_repository.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/domain/models.dart';

import 'helpers.dart';

/// M2 简报第 7、11、12 节：mini_script 解析、时长校验、v1.0 报错。
void main() {
  late String sitYaml;
  late ContentLibrary lib;

  setUpAll(() async {
    sitYaml = File('${repoContentDir().path}/skills/sit.yaml').readAsStringSync();
    lib = await loadRepoContent();
  });

  /// 删掉 sit.yaml 里整个 mini_script 段。
  String withoutMini(String yaml) {
    final start = yaml.indexOf('mini_script:');
    final end = yaml.indexOf('scoring_hint:');
    return yaml.substring(0, start) + yaml.substring(end);
  }

  group('解析', () {
    test('缺失 mini_script 抛 ContentParseException，带文件名与字段名', () {
      expect(
        () => parseSkill('skills/sit.yaml', withoutMini(sitYaml)),
        throwsA(isA<ContentParseException>()
            .having((e) => e.file, 'file', 'skills/sit.yaml')
            .having((e) => e.message, 'message', contains('mini_script'))),
      );
    });

    test('mini_script 为空列表也抛异常', () {
      final yaml = withoutMini(sitYaml).replaceFirst(
          'scoring_hint:', 'mini_script: []\nscoring_hint:');
      expect(
        () => parseSkill('skills/sit.yaml', yaml),
        throwsA(isA<ContentParseException>()
            .having((e) => e.message, 'message', contains('mini_script'))),
      );
    });

    /// 把 mini_script 第一步的 duration_sec 改成 [sec]。
    String miniFirstStep(String yaml, int sec) => yaml.replaceFirstMapped(
        RegExp(r'(mini_script:\n  - step: 1\n    instruction: [^\n]*\n    duration_sec: )60'),
        (m) => '${m[1]}$sec');

    test('总时长超过 300 秒抛异常', () {
      // sit 的 mini_script 是 60+45+45+10=160；第一步改成 201 → 301。
      final yaml = miniFirstStep(sitYaml, 201);
      expect(yaml, isNot(sitYaml));
      expect(
        () => parseSkill('skills/sit.yaml', yaml),
        throwsA(isA<ContentParseException>()
            .having((e) => e.file, 'file', 'skills/sit.yaml')
            .having((e) => e.message, 'message', contains('300'))),
      );
    });

    test('恰好 300 秒通过', () {
      final skill = parseSkill('skills/sit.yaml', miniFirstStep(sitYaml, 200));
      expect(skill.miniDurationSec, 300);
    });

    test('mini_script 的 part 恒为 0', () {
      final sit = lib.skillById['sit']!;
      expect(sit.miniScript, isNotEmpty);
      expect(sit.miniScript.every((s) => s.part == miniScriptPart), isTrue);
      expect(sit.stepsForPart(0), same(sit.miniScript));
    });
  });

  group('v1.1 内容库', () {
    test('18 个技能全部有 mini_script，总时长 ≤300 秒，至少一步 clicker_hint', () {
      expect(lib.skills.length, 18);
      for (final s in lib.skills) {
        expect(s.miniScript, isNotEmpty, reason: s.id);
        expect(s.miniDurationSec, lessThanOrEqualTo(miniScriptMaxSec),
            reason: s.id);
        expect(s.miniScript.any((m) => m.clickerHint), isTrue, reason: s.id);
        expect(s.miniDurationMinutes, lessThanOrEqualTo(5), reason: s.id);
      }
    });

    test('mini_script 时长与 VERSION.md v1.1 一览表一致', () {
      const expected = {
        'lure_follow': 145,
        'marker_intro': 150,
        'name_response': 160,
        'sit': 160,
        'stay_short': 170,
        'handling_body': 175,
        'recall_indoor': 180,
        'redirect_to_toy': 190,
        'down': 205,
        'alone_time': 210,
        'stay_long': 220,
        'leash_intro': 225,
        'bite_inhibition': 230,
        'loose_leash': 240,
        'potty_training': 240,
        'recall_outdoor': 240,
        'crate_intro': 245,
        'calm_settle': 270,
      };
      for (final e in expected.entries) {
        expect(lib.skillById[e.key]!.miniDurationSec, e.value, reason: e.key);
      }
    });

    test('多段脚本技能（stay_long 等）保底也只有一个 mini_script，不分 part', () {
      for (final id in ['stay_long', 'alone_time', 'loose_leash', 'handling_body']) {
        final s = lib.skillById[id]!;
        expect(s.scriptParts, 2);
        expect(s.miniDurationSec, lessThanOrEqualTo(300), reason: id);
      }
    });

    test('partDurationSec(0) 等于 mini_script 总时长', () {
      final sit = lib.skillById['sit']!;
      expect(sit.partDurationSec(0), sit.miniDurationSec);
      expect(sit.partDurationMinutes(0), 3);
    });
  });

  // M3 起最低版本升到 v1.2（ai_guard.yaml / ai_terms.yaml 必填），v1.0 / v1.1 都报错。
  group('版本门槛：读到 v1.0 / v1.1 报错，不静默兼容', () {
    test('v1.0 / v1.1 抛异常', () {
      for (final v in ['v1.0', 'v1.1']) {
        expect(
          () => requireSupportedContentVersion('VERSION.md', v),
          throwsA(isA<ContentParseException>()
              .having((e) => e.message, 'message', contains('v1.2'))),
        );
      }
    });

    test('v1.2 / v2.0 通过', () {
      for (final v in ['v1.2', 'v1.3', 'v2.0', 'v10.0']) {
        requireSupportedContentVersion('VERSION.md', v);
      }
    });

    test('ensureLoaded 读到 v1.0 的 VERSION.md 抛异常', () async {
      final repo = ContentRepository(
        db: memoryDb(),
        source: _OldVersionSource(FileContentSource(repoContentDir())),
      );
      await expectLater(
          repo.ensureLoaded(),
          throwsA(isA<ContentParseException>()
              .having((e) => e.file, 'file', 'VERSION.md')));
    });

    test('版本号格式错误抛异常', () {
      expect(() => parseVersionNumber('VERSION.md', 'abc'),
          throwsA(isA<ContentParseException>()));
    });
  });
}

class _OldVersionSource implements ContentSource {
  _OldVersionSource(this.inner);
  final ContentSource inner;

  @override
  Future<String> read(String relativePath) async {
    if (relativePath == 'VERSION.md') return '# 内容库版本\n\n## v1.0（2026-11-16）\n';
    return inner.read(relativePath);
  }

  @override
  Future<({List<String> skills, List<String> issues})> listFiles() =>
      inner.listFiles();
}
