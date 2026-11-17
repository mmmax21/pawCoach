/// 周计划生成器（WP-2，规则以 handoffs/2026-11-16-M1-brief.md 第 4 节为准）。
///
/// 纯函数，无 IO，不依赖 Flutter。
library;

import 'models.dart';

class PlanInput {
  const PlanInput({
    required this.ageWeeks,
    required this.mastered,
    required this.concerns,
    required this.dailyMinutes,
  });

  final int ageWeeks;
  final Set<String> mastered;

  /// 困扰的 issue id 列表。
  final List<String> concerns;

  /// 5 / 10 / 15 / 30
  final int dailyMinutes;
}

class GeneratedGoal {
  const GeneratedGoal({
    required this.skillId,
    required this.targetSessions,
    required this.source,
  });
  final String skillId;
  final int targetSessions;
  final GoalSource source;

  @override
  String toString() => 'GeneratedGoal($skillId, $targetSessions, $source)';
}

class GeneratedMiniTask {
  const GeneratedMiniTask({required this.skillId, required this.scriptPart});
  final String skillId;
  final int scriptPart;

  @override
  String toString() => 'GeneratedMiniTask($skillId, part $scriptPart)';
}

class GeneratedPlan {
  const GeneratedPlan({required this.goals, required this.miniTask});
  final List<GeneratedGoal> goals;

  /// 为 null 表示目标与已掌握都为空，首页应提示"去狗档案调整信息"。
  final GeneratedMiniTask? miniTask;

  bool get isEmpty => goals.isEmpty && miniTask == null;
}

/// 基础保障技能，按顺序强制放入目标前两位。
const _foundationSkills = ['marker_intro', 'name_response'];

int goalCountFor(int dailyMinutes) {
  switch (dailyMinutes) {
    case 5:
      return 2;
    case 10:
      return 3;
    case 15:
      return 3;
    case 30:
      return 4;
    default:
      throw ArgumentError.value(dailyMinutes, 'dailyMinutes', '只允许 5/10/15/30');
  }
}

/// [pinned]：下周计划用，已定的目标（carryover / downgrade），排在最前面，
/// 其余名额由本函数按 M1 规则补足；pinned 已 ≥ N 时不补也不裁。
/// [excluded]：补足时不考虑的技能（例如刚被降级的技能）。
/// 两个参数默认为空，行为与 M1 完全一致。
GeneratedPlan generateWeeklyPlan({
  required PlanInput input,
  required List<Skill> skills,
  required List<Issue> issues,
  List<GeneratedGoal> pinned = const [],
  Set<String> excluded = const {},
}) {
  final byId = {for (final s in skills) s.id: s};
  final mastered = input.mastered;
  final pinnedIds = {for (final g in pinned) g.skillId};

  // 1. 候选
  final candidates = skills.where((s) {
    if (s.minAgeWeeks > input.ageWeeks) return false;
    if (mastered.contains(s.id)) return false;
    if (pinnedIds.contains(s.id) || excluded.contains(s.id)) return false;
    return s.prerequisites.every(mastered.contains);
  }).toList();

  // 2. 困扰技能集
  final issueById = {for (final i in issues) i.id: i};
  final concernSkills = <String>{};
  for (final c in input.concerns) {
    final issue = issueById[c];
    if (issue != null) concernSkills.addAll(issue.allSolutionSkills);
  }

  // 3. 排序
  int cmp(Skill a, Skill b) {
    final ca = concernSkills.contains(a.id) ? 0 : 1;
    final cb = concernSkills.contains(b.id) ? 0 : 1;
    if (ca != cb) return ca - cb;
    if (a.difficulty != b.difficulty) return a.difficulty - b.difficulty;
    if (a.minAgeWeeks != b.minAgeWeeks) return a.minAgeWeeks - b.minAgeWeeks;
    return a.id.compareTo(b.id);
  }

  candidates.sort(cmp);

  // 4. 目标数
  final n = goalCountFor(input.dailyMinutes);

  // 5. 基础保障
  final ordered = <Skill>[];
  final foundationIds = <String>{};
  for (final fid in _foundationSkills) {
    if (mastered.contains(fid)) continue;
    final s = candidates.where((c) => c.id == fid).firstOrNull;
    if (s != null) {
      ordered.add(s);
      foundationIds.add(fid);
    }
  }
  for (final s in candidates) {
    if (!foundationIds.contains(s.id)) ordered.add(s);
  }

  // 6. 取前 N（pinned 先占位，剩余名额再补）
  final room = n - pinned.length;
  final goals = ordered.take(room > 0 ? room : 0).map((s) {
    final source = foundationIds.contains(s.id)
        ? GoalSource.age
        : concernSkills.contains(s.id)
            ? GoalSource.concern
            : GoalSource.age;
    return GeneratedGoal(
      skillId: s.id,
      targetSessions: s.sessionsToMaster + 1,
      source: source,
    );
  }).toList();
  goals.insertAll(0, pinned);

  // 7 / 8. 保底任务
  Skill? lowest(Iterable<Skill> list) {
    Skill? best;
    for (final s in list) {
      if (best == null ||
          s.difficulty < best.difficulty ||
          (s.difficulty == best.difficulty && s.id.compareTo(best.id) < 0)) {
        best = s;
      }
    }
    return best;
  }

  final masteredSkills = mastered.map((id) => byId[id]).nonNulls;
  Skill? mini = lowest(masteredSkills);
  mini ??= lowest(goals.map((g) => byId[g.skillId]).nonNulls);

  return GeneratedPlan(
    goals: goals,
    miniTask:
        mini == null ? null : GeneratedMiniTask(skillId: mini.id, scriptPart: miniScriptPart),
  );
}

/// 建档时推导每个技能的状态：勾选的 mastered，前置满足的 available，其余 locked。
Map<String, SkillStatus> deriveSkillStatuses({
  required List<Skill> skills,
  required Set<String> mastered,
}) {
  return {
    for (final s in skills)
      s.id: mastered.contains(s.id)
          ? SkillStatus.mastered
          : s.prerequisites.every(mastered.contains)
              ? SkillStatus.available
              : SkillStatus.locked,
  };
}


// ---------------------------------------------------------------------------
// WP-6 下周计划（M2 简报第 9 节）
// ---------------------------------------------------------------------------

/// 本周一个目标的评分统计。只统计正式脚本（script_part ≥ 1）的已评分记录。
class GoalWeekStat {
  const GoalWeekStat({
    required this.skillId,
    required this.full,
    required this.partial,
    required this.none,
  });
  final String skillId;
  final int full;
  final int partial;
  final int none;
}

/// WP-6 判定：full ≥ 2 → mastered；否则 none ≥ 2 → downgrade；否则 carryover。
GoalOutcome judgeGoalOutcome({required int full, required int none}) {
  if (full >= 2) return GoalOutcome.mastered;
  if (none >= 2) return GoalOutcome.downgrade;
  return GoalOutcome.carryover;
}

class NextWeekResult {
  const NextWeekResult({
    required this.outcomes,
    required this.newlyMastered,
    required this.plan,
  });

  /// skillId → 本周判定。regenerateNext 为 true 时为空。
  final Map<String, GoalOutcome> outcomes;

  /// 本周新掌握的技能，调用方负责把 DogSkillStatus 置为 mastered。
  final Set<String> newlyMastered;

  /// 下周计划（目标 + 保底任务）。
  final GeneratedPlan plan;
}

/// 下周计划。纯函数，无 IO，不依赖 Flutter。
///
/// [thisWeek]：本周每个目标的评分统计，顺序即本周目标顺序。
/// [input]：下周的输入（ageWeeks 为下周周龄，mastered 为本周开始时的已掌握集合）。
/// [regenerateNext]：为 true 时跳过 WP-6，直接全新生成。
/// [pendingDiagnosisSkills]：M3 诊断"加入下周计划"标记在本周计划上的技能，
/// 下周优先放入（排在最前，source = ai_diagnosis）；已掌握或前置未满足的跳过。
NextWeekResult nextWeekPlan({
  required List<GoalWeekStat> thisWeek,
  required PlanInput input,
  required List<Skill> skills,
  required List<Issue> issues,
  bool regenerateNext = false,
  List<String> pendingDiagnosisSkills = const [],
}) {
  if (regenerateNext) {
    return NextWeekResult(
      outcomes: const {},
      newlyMastered: const {},
      plan: generateWeeklyPlan(
        input: input,
        skills: skills,
        issues: issues,
        pinned: diagnosisPins(
          pending: pendingDiagnosisSkills,
          mastered: input.mastered,
          ageWeeks: input.ageWeeks,
          skills: skills,
        ),
      ),
    );
  }

  final byId = {for (final s in skills) s.id: s};
  final outcomes = <String, GoalOutcome>{};
  final newlyMastered = <String>{};
  final pinned = <GeneratedGoal>[];
  final pinnedIds = <String>{};
  final downgradedFrom = <String>{};

  void pin(String skillId, GoalSource source) {
    if (!pinnedIds.add(skillId)) return;
    final target = byId[skillId]?.sessionsToMaster ?? 0;
    pinned.add(GeneratedGoal(
      skillId: skillId,
      targetSessions: target + 1,
      source: source,
    ));
  }

  // 先算本周新掌握，诊断技能的"已掌握 / 前置"按下周开始时的掌握集合判断。
  final masteredNext = {
    ...input.mastered,
    for (final g in thisWeek)
      if (judgeGoalOutcome(full: g.full, none: g.none) == GoalOutcome.mastered)
        g.skillId,
  };
  for (final g in diagnosisPins(
    pending: pendingDiagnosisSkills,
    mastered: masteredNext,
    ageWeeks: input.ageWeeks,
    skills: skills,
  )) {
    if (pinnedIds.add(g.skillId)) pinned.add(g);
  }

  for (final g in thisWeek) {
    final outcome = judgeGoalOutcome(full: g.full, none: g.none);
    outcomes[g.skillId] = outcome;
    switch (outcome) {
      case GoalOutcome.mastered:
        newlyMastered.add(g.skillId);
      case GoalOutcome.downgrade:
        final to = byId[g.skillId]?.downgradeTo;
        if (to == null) {
          pin(g.skillId, GoalSource.carryover);
        } else {
          downgradedFrom.add(g.skillId);
          pin(to, GoalSource.downgrade);
        }
      case GoalOutcome.carryover:
        pin(g.skillId, GoalSource.carryover);
    }
  }

  // 降级后目标可能与"被降级的技能"同名（例如 A 降到 B，B 又降到 A），保留 pin 的结果。
  downgradedFrom.removeAll(pinnedIds);

  // M3 决策第 5 条：下周目标总数上限 6，优先级 诊断 > downgrade > carryover。
  // 超出时先从末尾去掉 carryover，再去掉 downgrade；保留的目标维持原顺序。
  for (final drop in [GoalSource.carryover, GoalSource.downgrade]) {
    for (var i = pinned.length - 1; i >= 0 && pinned.length > nextWeekGoalCap; i--) {
      if (pinned[i].source == drop) pinned.removeAt(i);
    }
  }
  if (pinned.length > nextWeekGoalCap) pinned.removeRange(nextWeekGoalCap, pinned.length);

  final mastered = {...input.mastered, ...newlyMastered};
  final plan = generateWeeklyPlan(
    input: PlanInput(
      ageWeeks: input.ageWeeks,
      mastered: mastered,
      concerns: input.concerns,
      dailyMinutes: input.dailyMinutes,
    ),
    skills: skills,
    issues: issues,
    pinned: pinned,
    excluded: downgradedFrom,
  );
  return NextWeekResult(
    outcomes: outcomes,
    newlyMastered: newlyMastered,
    plan: plan,
  );
}


// ---------------------------------------------------------------------------
// M3：诊断方案加入计划（WP-8，M3 简报第 7 节）
// ---------------------------------------------------------------------------

/// 诊断加入本周计划后，本周目标的上限（简报第 7 节"本周目标上限放宽到 6"）。
const diagnosisWeekGoalCap = 6;

/// 下周计划目标总数上限（M3 决策第 5 条）。
const nextWeekGoalCap = 6;

/// 诊断技能被跳过的原因（M4 简报第 9 节）。
enum DiagnosisSkipReason {
  /// 第 1 步：已掌握（M3 决策第 2 条，本周、下周一致）。
  mastered,

  /// 第 2 步：已在本周目标中。
  alreadyInPlan,

  /// 第 5 步：S 周龄未到且前置链上没有当前可练的技能，[DiagnosisSkip.untilWeeks] 周龄后再练。
  ageTooYoung,

  /// S 周龄已到、前置未掌握，且前置链上没有当前可练的技能（前置也都周龄未到）。
  prerequisitesUnmet,

  /// 超出目标上限，按方案顺序截断。
  capReached,

  unknownSkill,
}

class DiagnosisSkip {
  const DiagnosisSkip(
    this.skillId,
    this.reason, {
    this.missing = const [],
    this.untilWeeks,
    this.forSkill,
  });
  final String skillId;
  final DiagnosisSkipReason reason;

  /// 前置未满足时，缺的前置技能 ID。
  final List<String> missing;

  /// [DiagnosisSkipReason.ageTooYoung] 时：该技能的最低周龄。
  final int? untilWeeks;

  /// 被截断的是某个方案技能的前置时，记下它是为哪个方案技能加的。
  final String? forSkill;

  @override
  String toString() => 'DiagnosisSkip($skillId, $reason, $missing, $untilWeeks, $forSkill)';
}

/// "先练 [via]，为 [target] 打基础"（第 9 节第 4 步）。
/// [via] 为前置链上当前可练、且最终在目标里的技能（本次新加的或原本就在目标里的）。
class DiagnosisFoundation {
  const DiagnosisFoundation({
    required this.target,
    required this.via,
    this.newlyAdded = const [],
    this.unlockPrerequisites = const [],
    this.unlockAgeWeeks,
  });
  final String target;
  final List<String> via;

  /// [via] 中本次新加入的；其余原本就在计划里（"本周计划里的 P 正是在为 S 打基础"）。
  final List<String> newlyAdded;

  /// 解锁条件：S 尚未掌握的直接前置（"S：掌握 P1、P2 后解锁"）。
  final List<String> unlockPrerequisites;

  /// 解锁条件：S 周龄未到时为其最低周龄，否则为 null。
  final int? unlockAgeWeeks;

  List<String> get alreadyInPlan => [for (final v in via) if (!newlyAdded.contains(v)) v];

  @override
  String toString() => 'DiagnosisFoundation($target <- $via, new $newlyAdded, unlock $unlockPrerequisites $unlockAgeWeeks)';
}

class DiagnosisWeekAddition {
  const DiagnosisWeekAddition({
    required this.added,
    required this.skipped,
    this.foundations = const [],
  });

  /// 追加的目标，按处理顺序（方案顺序，前置紧跟在它所服务的方案技能位置），
  /// source = ai_diagnosis。
  final List<GeneratedGoal> added;
  final List<DiagnosisSkip> skipped;
  final List<DiagnosisFoundation> foundations;
}

/// 诊断方案加入计划（M4 简报第 9 节，M3 决策第 2、8 条）。纯函数。
///
/// 对 [solutionSkills] 中每个技能 S：
/// 1. 已掌握 → 跳过（已掌握）；
/// 2. 已在 [currentGoalIds] 或已被本次加入 → 跳过（已在计划中）；
/// 3. 前置全部掌握且 [ageWeeks] ≥ 最低周龄 → 加入 S；
/// 4. 否则沿前置链向上找出当前可练的技能 P（周龄满足、未掌握、自身前置已全部掌握）
///    加入，可能不止一个；P 已在目标中或已被本次加入的不重复；
/// 5. S 周龄未到且前置链上没有可练的 → 跳过（X 周龄后再练）。
///
/// 目标总数不超过 [cap]，超出部分按方案顺序截断。"加入下周"用同一函数，
/// [ageWeeks] 传下周一的周龄，[currentGoalIds] 传空。
DiagnosisWeekAddition addDiagnosisToWeek({
  required List<String> solutionSkills,
  required List<String> currentGoalIds,
  required Set<String> mastered,
  required int ageWeeks,
  required List<Skill> skills,
  int cap = diagnosisWeekGoalCap,
}) {
  final byId = {for (final s in skills) s.id: s};
  final inPlan = <String>{...currentGoalIds};
  final added = <GeneratedGoal>[];
  final skipped = <DiagnosisSkip>[];
  final foundations = <DiagnosisFoundation>[];
  final seen = <String>{};

  bool trainable(Skill s) =>
      s.minAgeWeeks <= ageWeeks &&
      !mastered.contains(s.id) &&
      s.prerequisites.every(mastered.contains);

  /// 前置链上当前可练的技能，按前置列表顺序深度优先，去重。
  List<String> chainTrainable(Skill s) {
    final out = <String>[];
    final visited = <String>{s.id};
    void walk(Skill node) {
      for (final pid in node.prerequisites) {
        if (mastered.contains(pid) || !visited.add(pid)) continue;
        final p = byId[pid];
        if (p == null) continue;
        if (trainable(p)) {
          out.add(pid);
        } else {
          walk(p);
        }
      }
    }

    walk(s);
    return out;
  }

  /// 返回 true 表示技能最终在目标里（新加或原本就在）。
  bool place(Skill s) {
    if (inPlan.contains(s.id)) return true;
    if (inPlan.length >= cap) return false;
    inPlan.add(s.id);
    added.add(GeneratedGoal(
      skillId: s.id,
      targetSessions: s.sessionsToMaster + 1,
      source: GoalSource.aiDiagnosis,
    ));
    return true;
  }

  for (final id in solutionSkills) {
    if (!seen.add(id)) continue;
    final s = byId[id];
    if (s == null) {
      skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.unknownSkill));
      continue;
    }
    if (mastered.contains(id)) {
      skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.mastered));
      continue;
    }
    if (inPlan.contains(id)) {
      skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.alreadyInPlan));
      continue;
    }
    if (trainable(s)) {
      if (!place(s)) skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.capReached));
      continue;
    }
    final chain = chainTrainable(s);
    if (chain.isEmpty) {
      if (s.minAgeWeeks > ageWeeks) {
        skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.ageTooYoung,
            untilWeeks: s.minAgeWeeks));
      } else {
        skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.prerequisitesUnmet,
            missing: s.prerequisites.where((p) => !mastered.contains(p)).toList()));
      }
      continue;
    }
    final via = <String>[];
    final fresh = <String>[];
    for (final pid in chain) {
      if (place(byId[pid]!)) {
        via.add(pid);
        if (added.any((g) => g.skillId == pid)) fresh.add(pid);
      } else {
        skipped.add(DiagnosisSkip(pid, DiagnosisSkipReason.capReached, forSkill: id));
      }
    }
    if (via.isEmpty) {
      skipped.add(DiagnosisSkip(id, DiagnosisSkipReason.capReached));
    } else {
      foundations.add(DiagnosisFoundation(
        target: id,
        via: via,
        newlyAdded: fresh,
        unlockPrerequisites: s.prerequisites.where((p) => !mastered.contains(p)).toList(),
        unlockAgeWeeks: s.minAgeWeeks > ageWeeks ? s.minAgeWeeks : null,
      ));
    }
  }
  return DiagnosisWeekAddition(added: added, skipped: skipped, foundations: foundations);
}

/// 下周计划里由诊断带入的目标（排最前，source = ai_diagnosis）。
/// 与"加入本周"同一规则（[addDiagnosisToWeek]），[ageWeeks] 为下周周龄。纯函数。
List<GeneratedGoal> diagnosisPins({
  required List<String> pending,
  required Set<String> mastered,
  required int ageWeeks,
  required List<Skill> skills,
}) =>
    addDiagnosisToWeek(
      solutionSkills: pending,
      currentGoalIds: const [],
      mastered: mastered,
      ageWeeks: ageWeeks,
      skills: skills,
    ).added;
