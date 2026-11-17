/// 内容库 YAML 解析。纯 Dart，输入文件名 + 文本，输出领域模型。
///
/// 任何字段缺失或类型错误都抛 [ContentParseException]，带文件名，不吞错。
library;

import 'package:yaml/yaml.dart';

import '../../domain/models.dart';

class ContentParseException implements Exception {
  ContentParseException(this.file, this.message, [this.cause]);
  final String file;
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'ContentParseException($file): $message${cause == null ? '' : ' ($cause)'}';
}

class _Reader {
  _Reader(this.file, this.map, [this.path = '']);
  final String file;
  final Map map;
  final String path;

  String _p(String key) => path.isEmpty ? key : '$path.$key';

  Never _fail(String key, String why) =>
      throw ContentParseException(file, '字段 ${_p(key)} $why');

  Object? opt(String key) => map[key];

  Object req(String key) {
    if (!map.containsKey(key)) _fail(key, '缺失');
    final v = map[key];
    if (v == null) _fail(key, '为 null');
    return v;
  }

  String str(String key) {
    final v = req(key);
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    _fail(key, '应为字符串，实际 ${v.runtimeType}');
  }

  String? strOrNull(String key) {
    final v = opt(key);
    if (v == null) return null;
    if (v is String) return v;
    _fail(key, '应为字符串或 null，实际 ${v.runtimeType}');
  }

  int integer(String key, {int? fallback}) {
    final v = opt(key);
    if (v == null) {
      if (fallback != null) return fallback;
      _fail(key, '缺失');
    }
    if (v is int) return v;
    _fail(key, '应为整数，实际 ${v.runtimeType}');
  }

  bool boolean(String key) {
    final v = req(key);
    if (v is bool) return v;
    _fail(key, '应为布尔，实际 ${v.runtimeType}');
  }

  List<String> strList(String key, {bool allowEmpty = true}) {
    final v = req(key);
    if (v is! List) _fail(key, '应为列表，实际 ${v.runtimeType}');
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is String) {
        out.add(e);
      } else {
        _fail('$key[$i]', '应为字符串，实际 ${e.runtimeType}');
      }
    }
    if (!allowEmpty && out.isEmpty) _fail(key, '不能为空');
    return out;
  }

  List<int> intList(String key) {
    final v = req(key);
    if (v is! List) _fail(key, '应为列表，实际 ${v.runtimeType}');
    return [
      for (var i = 0; i < v.length; i++)
        v[i] is int ? v[i] as int : _fail('$key[$i]', '应为整数'),
    ];
  }

  List<_Reader> mapList(String key, {bool allowEmpty = false}) {
    final v = req(key);
    if (v is! List) _fail(key, '应为列表，实际 ${v.runtimeType}');
    if (!allowEmpty && v.isEmpty) _fail(key, '不能为空');
    return [
      for (var i = 0; i < v.length; i++)
        v[i] is Map
            ? _Reader(file, v[i] as Map, _p('$key[$i]'))
            : _fail('$key[$i]', '应为对象'),
    ];
  }

  _Reader sub(String key) {
    final v = req(key);
    if (v is! Map) _fail(key, '应为对象，实际 ${v.runtimeType}');
    return _Reader(file, v, _p(key));
  }

  _Reader? subOrNull(String key) {
    final v = opt(key);
    if (v == null) return null;
    if (v is! Map) _fail(key, '应为对象或 null，实际 ${v.runtimeType}');
    return _Reader(file, v, _p(key));
  }
}

Map _loadRoot(String file, String text) {
  final Object? doc;
  try {
    doc = loadYaml(text, sourceUrl: Uri.file(file));
  } catch (e) {
    throw ContentParseException(file, 'YAML 解析失败', e);
  }
  if (doc is! Map) {
    throw ContentParseException(file, '顶层应为对象，实际 ${doc.runtimeType}');
  }
  return doc;
}

Skill parseSkill(String file, String text) =>
    skillFromMap(file, _loadRoot(file, text));

/// 从已解析的 Map（YAML 或数据库里的 JSON）构建。
Skill skillFromMap(String file, Map map) {
  final r = _Reader(file, map);
  final t = r.sub('tutorial');
  final tutorial = Tutorial(
    summary: t.str('summary'),
    steps: [
      for (final s in t.mapList('steps'))
        TutorialStep(text: s.str('text'), image: s.strOrNull('image')),
    ],
    commonMistakes: t.strList('common_mistakes'),
    successCriteria: t.str('success_criteria'),
  );
  final scriptParts = r.integer('script_parts', fallback: 1);
  final script = [
    for (final s in r.mapList('script'))
      ScriptStep(
        step: s.integer('step'),
        part: s.integer('part', fallback: 1),
        instruction: s.str('instruction'),
        durationSec: s.integer('duration_sec'),
        voice: s.boolean('voice'),
        clickerHint: s.boolean('clicker_hint'),
      ),
  ];
  final partsSeen = script.map((s) => s.part).toSet();
  if (partsSeen.length != scriptParts) {
    throw ContentParseException(
        file, 'script_parts=$scriptParts 但实际 part 数=${partsSeen.length}');
  }
  if (!r.map.containsKey('downgrade_to')) {
    throw ContentParseException(file, '字段 downgrade_to 缺失');
  }
  // mini_script 自 v1.1 起必填：缺失视为解析错误，不静默回退到 script。
  final miniScript = [
    for (final s in r.mapList('mini_script'))
      ScriptStep(
        step: s.integer('step'),
        part: miniScriptPart,
        instruction: s.str('instruction'),
        durationSec: s.integer('duration_sec'),
        voice: s.boolean('voice'),
        clickerHint: s.boolean('clicker_hint'),
      ),
  ];
  final miniTotal = miniScript.fold(0, (a, s) => a + s.durationSec);
  if (miniTotal > miniScriptMaxSec) {
    throw ContentParseException(
        file, 'mini_script 总时长 $miniTotal 秒，超过上限 $miniScriptMaxSec 秒');
  }
  return Skill(
    id: r.str('id'),
    name: r.str('name'),
    category: r.str('category'),
    minAgeWeeks: r.integer('min_age_weeks'),
    maxAgeWeeks: r.integer('max_age_weeks'),
    prerequisites: r.strList('prerequisites'),
    difficulty: r.integer('difficulty'),
    defaultCue: r.str('default_cue'),
    defaultGesture: r.str('default_gesture'),
    sessionsToMaster: r.integer('sessions_to_master'),
    scriptParts: scriptParts,
    tutorial: tutorial,
    script: script,
    miniScript: miniScript,
    scoringHint: r.str('scoring_hint'),
    downgradeTo: r.strOrNull('downgrade_to'),
    sources: r.strList('sources'),
  );
}

Issue parseIssue(String file, String text) =>
    issueFromMap(file, _loadRoot(file, text));

/// 从已解析的 Map（YAML 或数据库里的 JSON）构建。
Issue issueFromMap(String file, Map map) {
  final r = _Reader(file, map);
  final tree = [
    for (final n in r.mapList('diagnosis_tree'))
      DiagnosisNode(
        question: n.str('q'),
        options: [
          for (final o in n.mapList('options'))
            DiagnosisOption(
              text: o.str('text'),
              next: o.opt('next') == null ? null : o.integer('next'),
              result: o.strOrNull('result'),
            ),
        ],
      ),
  ];
  final sols = r.sub('solutions');
  final solutions = <Solution>[];
  for (final key in sols.map.keys) {
    final s = sols.sub(key.toString());
    solutions.add(Solution(
      key: key.toString(),
      summary: s.str('summary'),
      skills: s.strList('skills', allowEmpty: false),
      management: s.strList('management'),
      escalateIf: s.str('escalate_if'),
    ));
  }
  final typical = r.intList('typical_age_weeks');
  if (typical.length != 2) {
    throw ContentParseException(file, 'typical_age_weeks 应为 [from, to]');
  }
  return Issue(
    id: r.str('id'),
    name: r.str('name'),
    category: r.str('category'),
    typicalAgeWeeks: typical,
    diagnosisTree: tree,
    solutions: solutions,
    sources: r.strList('sources'),
  );
}

List<Badge> parseBadges(String file, String text) =>
    badgesFromMap(file, _loadRoot(file, text));

/// 从已解析的 Map（YAML 或数据库里的 JSON）构建。
List<Badge> badgesFromMap(String file, Map map) {
  final r = _Reader(file, map);
  return [
    for (final b in r.mapList('badges'))
      Badge(
        id: b.str('id'),
        name: b.str('name'),
        icon: b.str('icon'),
        conditionType: b.str('condition_type'),
        conditionValue: b.integer('condition_value'),
        description: b.str('description'),
      ),
  ];
}

CareCalendar parseCareCalendar(String file, String text) =>
    careCalendarFromMap(file, _loadRoot(file, text));

/// 从已解析的 Map（YAML 或数据库里的 JSON）构建。
CareCalendar careCalendarFromMap(String file, Map map) {
  final r = _Reader(file, map);
  return CareCalendar(
    disclaimer: r.str('disclaimer'),
    items: [
      for (final i in r.mapList('items'))
        CareItem(
          id: i.str('id'),
          type: i.str('type'),
          title: i.str('title'),
          weekFrom: i.integer('week_from'),
          weekTo: i.integer('week_to'),
          repeatEveryWeeks: i.subOrNull('repeat')?.integer('every_weeks'),
          note: i.str('note'),
        ),
    ],
    milestones: [
      for (final m in r.mapList('milestones', allowEmpty: true))
        CareMilestone(
          id: m.str('id'),
          title: m.str('title'),
          week: m.integer('week'),
          note: m.str('note'),
        ),
    ],
  );
}

/// 取 VERSION.md 所有 `## vX.Y` 标题中最高的版本，如 `## v1.2（2026-11-16）` → `v1.2`。
///
/// M3 起不再取"第一个"标题：VERSION.md 里 v1.2 段追加在文件末尾，
/// 按出现顺序取会误读成 v1.1。
String parseContentVersion(String file, String text) {
  final re = RegExp(r'^##\s+(v[0-9][^\s（(]*)', multiLine: true);
  final all = re.allMatches(text).map((m) => m.group(1)!).toList();
  if (all.isEmpty) {
    throw ContentParseException(file, '找不到 "## v" 版本标题');
  }
  all.sort((a, b) {
    final va = parseVersionNumber(file, a);
    final vb = parseVersionNumber(file, b);
    return va.major != vb.major ? vb.major - va.major : vb.minor - va.minor;
  });
  return all.first;
}

/// 客户端要求的最低内容库版本：v1.1 起 mini_script 必填，
/// v1.2 起 ai_guard.yaml / ai_terms.yaml 必填（M3 简报第 11 节）。读到更低版本直接报错。
const minContentVersion = (major: 1, minor: 2);

/// 版本号 `v1.1` → (1, 1)。
({int major, int minor}) parseVersionNumber(String file, String version) {
  final m = RegExp(r'^v(\d+)\.(\d+)').firstMatch(version);
  if (m == null) {
    throw ContentParseException(file, '版本号格式不对：$version');
  }
  return (major: int.parse(m.group(1)!), minor: int.parse(m.group(2)!));
}

/// 版本低于 [minContentVersion] 时抛异常。
void requireSupportedContentVersion(String file, String version) {
  final v = parseVersionNumber(file, version);
  final tooOld = v.major < minContentVersion.major ||
      (v.major == minContentVersion.major && v.minor < minContentVersion.minor);
  if (tooOld) {
    throw ContentParseException(file,
        '内容库 $version 版本过低，本客户端要求 v${minContentVersion.major}.${minContentVersion.minor} 及以上（mini_script、ai_guard.yaml、ai_terms.yaml 必填）');
  }
}

/// ai_guard.yaml：hard / soft / training_terms 三组，均不能为空。
AiGuardLexicon parseAiGuard(String file, String text) =>
    aiGuardFromMap(file, _loadRoot(file, text));

AiGuardLexicon aiGuardFromMap(String file, Map map) {
  final r = _Reader(file, map);
  return AiGuardLexicon(
    hard: r.strList('hard', allowEmpty: false),
    soft: r.strList('soft', allowEmpty: false),
    trainingTerms: r.strList('training_terms', allowEmpty: false),
  );
}

/// ai_terms.yaml：`terms: [{word, ids}]`。
List<AiTerm> parseAiTerms(String file, String text) =>
    aiTermsFromMap(file, _loadRoot(file, text));

List<AiTerm> aiTermsFromMap(String file, Map map) {
  final r = _Reader(file, map);
  final out = [
    for (final t in r.mapList('terms'))
      AiTerm(word: t.str('word'), ids: t.strList('ids', allowEmpty: false)),
  ];
  final seen = <String>{};
  for (final t in out) {
    if (t.word.isEmpty) throw ContentParseException(file, '存在空词');
    if (!seen.add(t.word)) {
      throw ContentParseException(file, '词 ${t.word} 重复');
    }
  }
  return out;
}

/// manifest.yaml 由 tool/sync_content.sh 生成。
({List<String> skills, List<String> issues}) parseManifest(
    String file, String text) {
  final r = _Reader(file, _loadRoot(file, text));
  return (
    skills: r.strList('skills', allowEmpty: false),
    issues: r.strList('issues', allowEmpty: false),
  );
}

/// 校验引用关系：prerequisites、downgrade_to、solutions.skills 都能查到。
void validateReferences(ContentLibrary lib) {
  for (final s in lib.skills) {
    for (final p in s.prerequisites) {
      if (!lib.skillById.containsKey(p)) {
        throw ContentParseException(
            'skills/${s.id}.yaml', '前置技能 $p 不存在');
      }
    }
    final d = s.downgradeTo;
    if (d != null && !lib.skillById.containsKey(d)) {
      throw ContentParseException('skills/${s.id}.yaml', 'downgrade_to=$d 不存在');
    }
  }
  for (final t in lib.aiTerms) {
    for (final id in t.ids) {
      if (!lib.skillById.containsKey(id) && !lib.issueById.containsKey(id)) {
        throw ContentParseException('ai_terms.yaml', '词 ${t.word} 引用不存在的内容 $id');
      }
    }
  }
  for (final i in lib.issues) {
    for (final sol in i.solutions) {
      for (final sk in sol.skills) {
        if (!lib.skillById.containsKey(sk)) {
          throw ContentParseException(
              'issues/${i.id}.yaml', 'solution ${sol.key} 引用不存在的技能 $sk');
        }
      }
    }
  }
}
