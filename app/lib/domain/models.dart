/// 纯 Dart 领域模型。不依赖 Flutter、drift。
///
/// 内容库对象（Skill / Issue / Badge / CareItem）的字段与
/// docs/content-library.md 一一对应，只做解析，不含任何训练内容。
library;

import 'video_checks.dart' show VideoCheckMapping, VideoChecksConfig;

export 'video_checks.dart' show VideoCheckMapping, VideoChecksConfig, VideoDetectorRule;

class TutorialStep {
  const TutorialStep({required this.text, this.image});
  final String text;
  final String? image;
}

class Tutorial {
  const Tutorial({
    required this.summary,
    required this.steps,
    required this.commonMistakes,
    required this.successCriteria,
  });
  final String summary;
  final List<TutorialStep> steps;
  final List<String> commonMistakes;
  final String successCriteria;
}

class ScriptStep {
  const ScriptStep({
    required this.step,
    required this.part,
    required this.instruction,
    required this.durationSec,
    required this.voice,
    required this.clickerHint,
  });
  final int step;
  final int part;
  final String instruction;
  final int durationSec;
  final bool voice;
  final bool clickerHint;
}

class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.category,
    required this.minAgeWeeks,
    required this.maxAgeWeeks,
    required this.prerequisites,
    required this.difficulty,
    required this.defaultCue,
    required this.defaultGesture,
    required this.sessionsToMaster,
    required this.scriptParts,
    required this.tutorial,
    required this.script,
    required this.miniScript,
    required this.scoringHint,
    required this.downgradeTo,
    required this.sources,
    this.videoChecks = const [],
  });

  final String id;
  final String name;
  final String category;
  final int minAgeWeeks;
  final int maxAgeWeeks;
  final List<String> prerequisites;
  final int difficulty;
  final String defaultCue;
  final String defaultGesture;
  final int sessionsToMaster;
  final int scriptParts;
  final Tutorial tutorial;
  final List<ScriptStep> script;

  /// 每日保底版脚本（内容库 v1.1 起必填，总时长 ≤300 秒，step 的 part 恒为 0）。
  final List<ScriptStep> miniScript;
  final String scoringHint;
  final String? downgradeTo;
  final List<String> sources;

  /// v1.3 可选字段：视频纠错检测器 → common_mistakes 下标。为空表示本技能不支持视频纠错。
  final List<VideoCheckMapping> videoChecks;

  /// 手势文案以"无"开头时不展示手势图（content/VERSION.md 审核说明）。
  bool get showsGestureImage => !defaultGesture.startsWith('无');

  /// 某个 script part 的总时长（秒）。part 为 0 时是 mini_script。
  int partDurationSec(int part) => part == miniScriptPart
      ? miniDurationSec
      : script.where((s) => s.part == part).fold(0, (a, s) => a + s.durationSec);

  /// 某个 script part 的时长，向上取整到分钟。
  int partDurationMinutes(int part) => (partDurationSec(part) + 59) ~/ 60;

  /// 保底脚本总时长（秒）。
  int get miniDurationSec => miniScript.fold(0, (a, s) => a + s.durationSec);

  /// 保底脚本时长，向上取整到分钟。
  int get miniDurationMinutes => (miniDurationSec + 59) ~/ 60;

  /// 跟练用的步骤：[part] 为 [miniScriptPart]（0）时取 mini_script，
  /// 否则取正式脚本中该 part 的步骤。
  List<ScriptStep> stepsForPart(int part) => part == miniScriptPart
      ? miniScript
      : script.where((s) => s.part == part).toList();
}

/// `DailyMiniTask.script_part` / `TrainingSession.script_part` 为 0 表示 mini_script。
const miniScriptPart = 0;

/// mini_script 总时长上限（秒）。
const miniScriptMaxSec = 300;

class DiagnosisOption {
  const DiagnosisOption({required this.text, this.next, this.result});
  final String text;
  final int? next;
  final String? result;
}

class DiagnosisNode {
  const DiagnosisNode({required this.question, required this.options});
  final String question;
  final List<DiagnosisOption> options;
}

class Solution {
  const Solution({
    required this.key,
    required this.summary,
    required this.skills,
    required this.management,
    required this.escalateIf,
  });
  final String key;
  final String summary;
  final List<String> skills;
  final List<String> management;
  final String escalateIf;
}

class Issue {
  const Issue({
    required this.id,
    required this.name,
    required this.category,
    required this.typicalAgeWeeks,
    required this.diagnosisTree,
    required this.solutions,
    required this.sources,
  });
  final String id;
  final String name;
  final String category;

  /// [from, to]
  final List<int> typicalAgeWeeks;
  final List<DiagnosisNode> diagnosisTree;
  final List<Solution> solutions;
  final List<String> sources;

  /// 所有 solutions[*].skills 的并集。
  Set<String> get allSolutionSkills =>
      {for (final s in solutions) ...s.skills};
}

class Badge {
  const Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.conditionType,
    required this.conditionValue,
    required this.description,
  });
  final String id;
  final String name;
  final String icon;
  final String conditionType;
  final int conditionValue;
  final String description;
}

class CareItem {
  const CareItem({
    required this.id,
    required this.type,
    required this.title,
    required this.weekFrom,
    required this.weekTo,
    required this.repeatEveryWeeks,
    required this.note,
  });
  final String id;
  final String type;
  final String title;
  final int weekFrom;
  final int weekTo;
  final int? repeatEveryWeeks;
  final String note;
}

class CareMilestone {
  const CareMilestone({
    required this.id,
    required this.title,
    required this.week,
    required this.note,
  });
  final String id;
  final String title;
  final int week;
  final String note;
}

class CareCalendar {
  const CareCalendar({
    required this.disclaimer,
    required this.items,
    required this.milestones,
  });
  final String disclaimer;
  final List<CareItem> items;
  final List<CareMilestone> milestones;
}

/// AI 健康拦截词表（content/ai_guard.yaml，内容库 v1.2 起必填）。
class AiGuardLexicon {
  const AiGuardLexicon({
    required this.hard,
    required this.soft,
    required this.trainingTerms,
  });

  /// 命中即拦。
  final List<String> hard;

  /// 命中且同句无 [trainingTerms] 中任一词时拦。
  final List<String> soft;

  /// 训练语境词。
  final List<String> trainingTerms;
}

/// AI 检索词表的一项：词 → 内容 ID（技能或问题行为）。
class AiTerm {
  const AiTerm({required this.word, required this.ids});
  final String word;
  final List<String> ids;
}

/// 常见问题（v1.4 起，content/faq.yaml）：训练通识问答，AI 教练命中后原文直出。
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.question,
    required this.keywords,
    required this.answer,
    this.tips = const [],
    this.related = const [],
    this.sources = const [],
  });
  final String id;
  final String question;
  final List<String> keywords;
  final String answer;
  final List<String> tips;
  final List<String> related;
  final List<String> sources;
}

/// 整个内容库的内存快照。
class ContentLibrary {
  ContentLibrary({
    required this.version,
    required List<Skill> skills,
    required List<Issue> issues,
    required this.badges,
    required this.careCalendar,
    required this.aiGuard,
    required List<AiTerm> aiTerms,
    this.videoChecks,
    List<FaqEntry> faqs = const [],
  })  : aiTerms = List.unmodifiable(aiTerms),
        faqs = List.unmodifiable(faqs),
        faqById = {for (final f in faqs) f.id: f},
        // 检索用词表 = ai_terms + 每条 FAQ 的检索词（映射到该 FAQ）
        searchTerms = List.unmodifiable([
          ...aiTerms,
          for (final f in faqs)
            for (final w in f.keywords) AiTerm(word: w, ids: [f.id]),
        ]),
        skills = List.unmodifiable(skills),
        issues = List.unmodifiable(issues),
        skillById = {for (final s in skills) s.id: s},
        issueById = {for (final i in issues) i.id: i};

  final String version;
  final List<Skill> skills;
  final List<Issue> issues;
  final List<Badge> badges;
  final CareCalendar careCalendar;
  final AiGuardLexicon aiGuard;
  final List<AiTerm> aiTerms;

  /// v1.3 起：video_checks.yaml。客户端加载内容库时必填；手工构造（测试）可省略。
  final VideoChecksConfig? videoChecks;

  /// v1.4 起：faq.yaml（可缺省，缺省为空）。
  final List<FaqEntry> faqs;
  final Map<String, FaqEntry> faqById;

  /// 关键词检索用的完整词表：ai_terms.yaml + FAQ 检索词。
  final List<AiTerm> searchTerms;
  final Map<String, Skill> skillById;
  final Map<String, Issue> issueById;
}

// ---------------------------------------------------------------------------
// 狗档案相关枚举（与 docs/data-model.md 一致）
// ---------------------------------------------------------------------------

enum Sex { male, female }

enum LivingEnv { apartment, houseWithYard }

enum SkillStatus { locked, available, inProgress, mastered }

enum GoalSource { age, concern, carryover, downgrade, aiDiagnosis, manual }

/// 一次跟练的三档评分（RC-1）。
enum Score { full, partial, none }

/// WP-6 下周计划规则对一个目标的判定。
enum GoalOutcome { mastered, downgrade, carryover }

/// 周龄计算：按整周向下取整。
int ageWeeksOn(DateTime birthDate, DateTime on) {
  final b = DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
  final o = DateTime.utc(on.year, on.month, on.day);
  final days = o.difference(b).inDays;
  return days < 0 ? 0 : days ~/ 7;
}

/// 给定日期所在周的周一（UTC 日期，时间 00:00）。
DateTime weekStartOf(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
