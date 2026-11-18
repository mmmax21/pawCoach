import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/content/content_parser.dart';
import 'package:puppy_trainer/data/content/content_repository.dart';
import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/db/database.dart';

import 'helpers.dart';

void main() {
  test('加载真实 content/：技能 18、问题 9、徽章 11，引用关系可解析', () async {
    final lib = await loadRepoContent();
    expect(lib.version, 'v1.3'); // M5：内容库 v1.3（原 M3 断言 v1.2）
    expect(lib.skills.length, 18);
    expect(lib.issues.length, 9);
    expect(lib.badges.length, 11);
    expect(lib.careCalendar.items, isNotEmpty);

    for (final s in lib.skills) {
      for (final p in s.prerequisites) {
        expect(lib.skillById, contains(p), reason: '${s.id} 前置 $p');
      }
      if (s.downgradeTo != null) {
        expect(lib.skillById, contains(s.downgradeTo),
            reason: '${s.id} downgrade_to');
      }
    }
    for (final i in lib.issues) {
      for (final sol in i.solutions) {
        for (final sk in sol.skills) {
          expect(lib.skillById, contains(sk), reason: '${i.id}.${sol.key}');
        }
        expect(sol.escalateIf, isNotEmpty);
      }
    }
  });

  test('script_parts 默认 1，多段脚本 part 正确，手势"无"不展示图', () async {
    final lib = await loadRepoContent();
    expect(lib.skillById['sit']!.scriptParts, 1);
    expect(lib.skillById['sit']!.script.every((s) => s.part == 1), isTrue);
    final stayLong = lib.skillById['stay_long']!;
    expect(stayLong.scriptParts, 2);
    expect(stayLong.script.map((s) => s.part).toSet(), {1, 2});
    expect(stayLong.partDurationSec(1), greaterThan(0));
    expect(lib.skillById['alone_time']!.showsGestureImage, isFalse);
    expect(lib.skillById['sit']!.showsGestureImage, isTrue);
    expect(lib.skillById['crate_intro']!.downgradeTo, isNull);
  });

  test('版本相同时跳过重载，从数据库读回的内容一致', () async {
    final db = memoryDb();
    final src = FileContentSource(repoContentDir());
    final repo1 = ContentRepository(db: db, source: src);
    final lib1 = await repo1.ensureLoaded();

    final versions = await db.select(db.contentVersions).get();
    expect(versions.single.version, 'v1.3'); // M5：内容库 v1.3
    expect((await db.select(db.contentSkills).get()).length, 18);
    expect((await db.select(db.contentIssues).get()).length, 9);
    expect((await db.select(db.contentBadges).get()).length, 11);

    // 第二个仓库实例：应走数据库路径，不重新解析。
    final repo2 = ContentRepository(db: db, source: _FailingSource(src));
    final lib2 = await repo2.ensureLoaded();
    expect(lib2.skills.length, lib1.skills.length);
    expect(lib2.skillById['sit']!.tutorial.steps.length,
        lib1.skillById['sit']!.tutorial.steps.length);
    expect(lib2.skillById['stay_long']!.scriptParts, 2);
    await db.close();
  });

  test('解析失败抛带文件名的异常', () {
    expect(
      () => parseSkill('skills/broken.yaml', 'id: broken\nname: x\n'),
      throwsA(isA<ContentParseException>()
          .having((e) => e.file, 'file', 'skills/broken.yaml')),
    );
    expect(
      () => parseSkill('skills/bad.yaml', 'id: [unclosed'),
      throwsA(isA<ContentParseException>()
          .having((e) => e.file, 'file', 'skills/bad.yaml')),
    );
    expect(
      () => parseContentVersion('VERSION.md', '# 没有版本'),
      throwsA(isA<ContentParseException>()
          .having((e) => e.file, 'file', 'VERSION.md')),
    );
  });

  test('引用不存在的技能时 validateReferences 抛异常', () async {
    final db = memoryDb();
    final src = FileContentSource(repoContentDir());
    final repo = ContentRepository(db: db, source: src);
    final lib = await repo.ensureLoaded();
    // 污染数据库中一条记录，再读回应报错
    await (db.update(db.contentSkills)..where((t) => t.id.equals('sit')))
        .write(ContentSkillsCompanion(
      json: Value(
          '{"id":"sit","name":"x","category":"basic_obedience","min_age_weeks":8,"max_age_weeks":52,"prerequisites":["ghost"],"difficulty":1,"default_cue":"c","default_gesture":"g","sessions_to_master":2,"tutorial":{"summary":"s","steps":[{"text":"t"}],"common_mistakes":["m"],"success_criteria":"c"},"script":[{"step":1,"instruction":"i","duration_sec":10,"voice":true,"clicker_hint":true}],"mini_script":[{"step":1,"instruction":"i","duration_sec":10,"voice":true,"clicker_hint":true}],"scoring_hint":"h","downgrade_to":null,"sources":["s"]}'),
    ));
    final repo2 = ContentRepository(db: db, source: src);
    expect(lib.skills.length, 18);
    await expectLater(
        repo2.ensureLoaded(),
        throwsA(isA<ContentParseException>()
            .having((e) => e.message, 'message', contains('ghost'))));
    await db.close();
  });
}

/// 用来证明走了数据库路径：任何读文件都失败。
class _FailingSource implements ContentSource {
  _FailingSource(this.inner);
  final ContentSource inner;

  @override
  Future<String> read(String relativePath) {
    if (relativePath == 'VERSION.md') return inner.read(relativePath);
    throw StateError('不应该读文件 $relativePath');
  }

  @override
  Future<({List<String> skills, List<String> issues})> listFiles() =>
      throw StateError('不应该列文件');
}
