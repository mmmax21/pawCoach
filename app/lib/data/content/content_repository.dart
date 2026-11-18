/// 内容库仓库：从 assets 读 YAML → 解析 → 写 drift → 提供内存快照。
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../../domain/models.dart';
import '../db/database.dart';
import 'content_parser.dart';

/// 读取内容文件的抽象，便于测试时直接读仓库 content/ 目录。
abstract class ContentSource {
  /// [relativePath] 形如 `skills/sit.yaml`、`badges.yaml`、`VERSION.md`。
  Future<String> read(String relativePath);

  /// 列出 skills/ 和 issues/ 下的文件名。
  Future<({List<String> skills, List<String> issues})> listFiles();
}

/// 把 YamlMap / YamlList 深转成普通 Map / List，方便 jsonEncode。
Object? _plain(Object? v) {
  if (v is YamlMap) {
    return {for (final e in v.entries) e.key.toString(): _plain(e.value)};
  }
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): _plain(e.value)};
  }
  if (v is YamlList || v is List) {
    return [for (final e in v as List) _plain(e)];
  }
  return v;
}

class ContentRepository {
  ContentRepository({required this.db, required this.source});

  final AppDatabase db;
  final ContentSource source;

  ContentLibrary? _cache;

  /// 已加载的内容库。调用前必须 [ensureLoaded]。
  ContentLibrary get library {
    final c = _cache;
    if (c == null) {
      throw StateError('内容库尚未加载，先调用 ensureLoaded()');
    }
    return c;
  }

  /// 启动时调用：版本相同则从数据库读，否则从 assets 解析并写库。
  /// 解析失败抛 [ContentParseException]，不吞错。
  Future<ContentLibrary> ensureLoaded() async {
    if (_cache != null) return _cache!;
    final versionText = await source.read('VERSION.md');
    final version = parseContentVersion('VERSION.md', versionText);
    requireSupportedContentVersion('VERSION.md', version);

    final stored = await (db.select(db.contentVersions)
          ..where((t) => t.version.equals(version)))
        .getSingleOrNull();
    if (stored != null) {
      final fromDb = await _readFromDb(version);
      if (fromDb != null) {
        _cache = fromDb;
        return fromDb;
      }
    }

    final lib = await loadFromSource(version);
    await _writeToDb(lib);
    _cache = lib;
    return lib;
  }

  /// 只解析，不写库。测试与 [ensureLoaded] 共用。
  Future<ContentLibrary> loadFromSource(String version) async {
    final files = await source.listFiles();
    final skills = <Skill>[];
    for (final f in files.skills) {
      final path = 'skills/$f';
      skills.add(parseSkill(path, await source.read(path)));
    }
    final issues = <Issue>[];
    for (final f in files.issues) {
      final path = 'issues/$f';
      issues.add(parseIssue(path, await source.read(path)));
    }
    final badges = parseBadges('badges.yaml', await source.read('badges.yaml'));
    final care = parseCareCalendar(
        'care_calendar.yaml', await source.read('care_calendar.yaml'));
    final ai = await _loadAiLexicons();
    final videoChecks = parseVideoChecks('video_checks.yaml', await _must('video_checks.yaml', 'v1.3'));
    final faqText = await _optional('faq.yaml');
    final faqs = faqText == null ? const <FaqEntry>[] : parseFaqs('faq.yaml', faqText);
    final lib = ContentLibrary(
      version: version,
      skills: skills,
      issues: issues,
      badges: badges,
      careCalendar: care,
      aiGuard: ai.guard,
      aiTerms: ai.terms,
      videoChecks: videoChecks,
      faqs: faqs,
    );
    validateReferences(lib);
    return lib;
  }

  /// v1.4 的 faq.yaml 可缺省（旧内容包没有）；读不到返回 null。
  Future<String?> _optional(String path) async {
    try {
      return await source.read(path);
    } catch (_) {
      return null;
    }
  }

  Future<String> _must(String path, String since) async {
    try {
      return await source.read(path);
    } catch (e) {
      throw ContentParseException(path, '缺失（内容库 $since 起必填）', e);
    }
  }

  /// 从内容源读 ai_guard.yaml / ai_terms.yaml。文件缺失抛 [ContentParseException]，不静默降级。
  Future<({AiGuardLexicon guard, List<AiTerm> terms})> _loadAiLexicons() async {
    Future<String> must(String path) async {
      try {
        return await source.read(path);
      } catch (e) {
        throw ContentParseException(path, '缺失（内容库 v1.2 起必填）', e);
      }
    }

    return (
      guard: parseAiGuard('ai_guard.yaml', await must('ai_guard.yaml')),
      terms: parseAiTerms('ai_terms.yaml', await must('ai_terms.yaml')),
    );
  }

  Future<void> _writeToDb(ContentLibrary lib) async {
    final files = await source.listFiles();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await db.delete(db.contentSkills).go();
      await db.delete(db.contentIssues).go();
      await db.delete(db.contentBadges).go();
      await db.delete(db.contentCareItems).go();
      await db.delete(db.contentVersions).go();
      await db.delete(db.contentAiLexicons).go();

      // 存原始 YAML 转成的 JSON，读回时走同一套解析器。
      for (final f in files.skills) {
        final path = 'skills/$f';
        final map = _plain(loadYaml(await source.read(path))) as Map;
        await db.into(db.contentSkills).insert(ContentSkillsCompanion.insert(
              id: map['id'].toString(),
              version: lib.version,
              json: jsonEncode(map),
            ));
      }
      for (final f in files.issues) {
        final path = 'issues/$f';
        final map = _plain(loadYaml(await source.read(path))) as Map;
        await db.into(db.contentIssues).insert(ContentIssuesCompanion.insert(
              id: map['id'].toString(),
              version: lib.version,
              json: jsonEncode(map),
            ));
      }
      final badgesMap =
          _plain(loadYaml(await source.read('badges.yaml'))) as Map;
      for (final b in badgesMap['badges'] as List) {
        await db.into(db.contentBadges).insert(ContentBadgesCompanion.insert(
              id: (b as Map)['id'].toString(),
              version: lib.version,
              json: jsonEncode(b),
            ));
      }
      final careMap =
          _plain(loadYaml(await source.read('care_calendar.yaml'))) as Map;
      // care_calendar 整份存一行，id 固定。
      await db.into(db.contentCareItems).insert(ContentCareItemsCompanion.insert(
            id: 'care_calendar',
            version: lib.version,
            json: jsonEncode(careMap),
          ));
      // video_checks.yaml（v1.3）与两个 AI 词表同表存放：id → 整份 JSON。
      for (final name in ['ai_guard', 'ai_terms', 'video_checks']) {
        final map = _plain(loadYaml(await source.read('$name.yaml'))) as Map;
        await db.into(db.contentAiLexicons).insert(ContentAiLexiconsCompanion.insert(
              id: name,
              version: lib.version,
              json: jsonEncode(map),
            ));
      }
      // v1.4：faq.yaml（可缺省）同表存放，id 固定为 faq
      final faqText = await _optional('faq.yaml');
      if (faqText != null) {
        await db.into(db.contentAiLexicons).insert(ContentAiLexiconsCompanion.insert(
              id: 'faq',
              version: lib.version,
              json: jsonEncode(_plain(loadYaml(faqText))),
            ));
      }
      await db.into(db.contentVersions).insert(ContentVersionsCompanion.insert(
            version: lib.version,
            loadedAt: now,
          ));
    });
  }

  Future<ContentLibrary?> _readFromDb(String version) async {
    final skillRows = await db.select(db.contentSkills).get();
    final issueRows = await db.select(db.contentIssues).get();
    final badgeRows = await db.select(db.contentBadges).get();
    final careRow = await (db.select(db.contentCareItems)
          ..where((t) => t.id.equals('care_calendar')))
        .getSingleOrNull();
    final aiRows = {
      for (final r in await db.select(db.contentAiLexicons).get()) r.id: r.json,
    };
    // 缺任何一份（例如旧库残留）就当缓存无效，回到从内容源解析，缺文件即报错。
    if (skillRows.isEmpty ||
        careRow == null ||
        aiRows['ai_guard'] == null ||
        aiRows['ai_terms'] == null ||
        aiRows['video_checks'] == null) {
      return null;
    }

    final lib = ContentLibrary(
      aiGuard: aiGuardFromMap(
          'db:content_ai_lexicons/ai_guard', jsonDecode(aiRows['ai_guard']!) as Map),
      aiTerms: aiTermsFromMap(
          'db:content_ai_lexicons/ai_terms', jsonDecode(aiRows['ai_terms']!) as Map),
      videoChecks: videoChecksFromMap('db:content_ai_lexicons/video_checks',
          jsonDecode(aiRows['video_checks']!) as Map),
      faqs: aiRows['faq'] == null
          ? const []
          : faqsFromMap('db:content_ai_lexicons/faq', jsonDecode(aiRows['faq']!) as Map),
      version: version,
      skills: [
        for (final r in skillRows)
          skillFromMap('db:content_skills/${r.id}', jsonDecode(r.json) as Map),
      ],
      issues: [
        for (final r in issueRows)
          issueFromMap('db:content_issues/${r.id}', jsonDecode(r.json) as Map),
      ],
      badges: badgesFromMap('db:content_badges', {
        'badges': [for (final r in badgeRows) jsonDecode(r.json)],
      }),
      careCalendar: careCalendarFromMap(
          'db:content_care_items', jsonDecode(careRow.json) as Map),
    );
    validateReferences(lib);
    return lib;
  }
}
