/// AI 对话记录（AI-7）、诊断结果与加入计划（AI-3 / WP-8），M3 简报第 4、6、7 节。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/plan_generator.dart';
import '../ai/ai_client.dart';
import '../ai/ai_coach_engine.dart';
import '../ai/prompt_builder.dart';
import '../db/database.dart';
import 'report_repository.dart' show decodeIdList;
import 'repositories.dart';
import 'session_repository.dart' show scoreFromDb;
import '../sync/sync_service.dart' show currentUserId;

int _seq = 0;
String _id(String prefix) {
  _seq = (_seq + 1) % 1000;
  final t = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
  return '${prefix}_$t${_seq.toString().padLeft(3, '0')}';
}

String _iso(DateTime t) => t.toUtc().toIso8601String();

const convCourseQa = 'course_qa';
const convDiagnosis = 'diagnosis';

class AiRepository {
  AiRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _clock;

  // ---- 对话 ----------------------------------------------------------------

  /// 课程内提问：按 (dog_id, skill_id) 复用同一个对话，不存在才新建。
  Future<AiConversation> courseConversation(String dogId, String skillId) async {
    final existing = await (db.select(db.aiConversations)
          ..where((t) =>
              t.dogId.equals(dogId) &
              t.type.equals(convCourseQa) &
              t.skillId.equals(skillId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    final now = _iso(_clock());
    final row = AiConversationsCompanion.insert(
      id: _id('conv'),
      dogId: dogId,
      type: convCourseQa,
      skillId: Value(skillId),
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.aiConversations).insert(row);
    return (db.select(db.aiConversations)..where((t) => t.id.equals(row.id.value)))
        .getSingle();
  }

  /// 自由提问（AI 教练 Tab，不带技能上下文）：每只狗复用一个 course_qa 对话，skill_id 为空。
  Future<AiConversation> freeConversation(String dogId) async {
    final existing = await (db.select(db.aiConversations)
          ..where((t) =>
              t.dogId.equals(dogId) &
              t.type.equals(convCourseQa) &
              t.skillId.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    final now = _iso(_clock());
    final id = _id('conv');
    await db.into(db.aiConversations).insert(AiConversationsCompanion.insert(
          id: id,
          dogId: dogId,
          type: convCourseQa,
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.aiConversations)..where((t) => t.id.equals(id))).getSingle();
  }

  /// 诊断：每次诊断新建一个对话（结果页之后的自由提问也记在这里）。
  Future<AiConversation> newDiagnosisConversation(String dogId, String issueId) async {
    final now = _iso(_clock());
    final id = _id('conv');
    await db.into(db.aiConversations).insert(AiConversationsCompanion.insert(
          id: id,
          dogId: dogId,
          type: convDiagnosis,
          issueId: Value(issueId),
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.aiConversations)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<AiConversation?> conversation(String id) =>
      (db.select(db.aiConversations)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 该狗的全部对话，最近更新的在前（AI-7 对话记录按狗保存）。
  Stream<List<AiConversation>> watchConversations(String dogId) =>
      (db.select(db.aiConversations)
            ..where((t) => t.dogId.equals(dogId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Stream<List<AiMessage>> watchMessages(String conversationId) =>
      (db.select(db.aiMessages)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<List<AiMessage>> messages(String conversationId) =>
      (db.select(db.aiMessages)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]))
          .get();

  /// 发给模型的历史：最近 [limit] 条 user / assistant 普通问答。
  /// 固定话术与诊断追问不带（它们不是模型的回答，带上会干扰模型）。
  Future<List<ChatTurn>> recentTurns(String conversationId, {int limit = aiHistoryLimit}) async {
    final all = await messages(conversationId);
    final usable = <ChatTurn>[];
    for (var i = 0; i < all.length; i++) {
      final m = all[i];
      if (m.role != 'user') continue;
      final reply = i + 1 < all.length ? all[i + 1] : null;
      if (reply == null || reply.role != 'assistant' || reply.kind != 'normal') continue;
      usable
        ..add(ChatTurn(role: 'user', content: m.content))
        ..add(ChatTurn(role: 'assistant', content: reply.content));
    }
    return usable.length > limit ? usable.sublist(usable.length - limit) : usable;
  }

  Future<void> addMessage({
    required String conversationId,
    required String role,
    required String content,
    required AiMessageKind kind,
    List<String> cited = const [],
    DateTime? at,
  }) async {
    final now = at ?? _clock();
    await db.into(db.aiMessages).insert(AiMessagesCompanion.insert(
          id: _id('msg'),
          conversationId: conversationId,
          role: role,
          content: content,
          citedContentIds: Value(jsonEncode(cited)),
          kind: kindToDb(kind),
          createdAt: _iso(now),
        ));
    await (db.update(db.aiConversations)..where((t) => t.id.equals(conversationId)))
        .write(AiConversationsCompanion(updatedAt: Value(_iso(now))));
  }

  /// 一问一答成功后一起入库（网络失败时调用方不调用，消息不入库）。
  Future<void> addExchange({
    required String conversationId,
    required String question,
    required CoachAnswer answer,
  }) async {
    final now = _clock();
    await db.transaction(() async {
      await addMessage(
        conversationId: conversationId,
        role: 'user',
        content: question,
        kind: AiMessageKind.normal,
        at: now,
      );
      await addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: answer.text,
        kind: answer.kind,
        cited: answer.cited,
        // 同一毫秒内保持先问后答的顺序。
        at: now.add(const Duration(milliseconds: 1)),
      );
    });
  }

  // ---- 狗档案摘要（AI-2） -------------------------------------------------

  Future<DogBrief> dogBrief({
    required String dogId,
    required ContentLibrary content,
    String? skillId,
    int? currentStep,
  }) async {
    final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingle();
    final concerns = await (db.select(db.dogConcerns)..where((t) => t.dogId.equals(dogId))).get();
    final statuses =
        await (db.select(db.dogSkillStatuses)..where((t) => t.dogId.equals(dogId))).get();
    var scores = <Score>[];
    if (skillId != null) {
      final rows = await (db.select(db.trainingSessions)
            ..where((t) => t.dogId.equals(dogId) & t.skillId.equals(skillId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(3))
          .get();
      scores = [for (final r in rows) if (scoreFromDb(r.score) case final s?) s];
    }
    return DogBrief(
      name: dog.name,
      ageWeeks: ageWeeksOn(parseDateOnly(dog.birthDate), _clock()),
      concernNames: [
        for (final c in concerns) content.issueById[c.issueId]?.name ?? c.issueId,
      ],
      masteredSkillNames: [
        for (final s in statuses)
          if (s.status == 'mastered') content.skillById[s.skillId]?.name ?? s.skillId,
      ],
      skillName: skillId == null ? null : content.skillById[skillId]?.name,
      recentScores: scores,
      currentStep: currentStep,
    );
  }

  Future<Map<String, String>> skillStatusMap(String dogId) async {
    final rows =
        await (db.select(db.dogSkillStatuses)..where((t) => t.dogId.equals(dogId))).get();
    return {for (final r in rows) r.skillId: r.status};
  }

  // ---- 诊断结果与加入计划（WP-8） ----------------------------------------

  Future<String> saveDiagnosisResult({
    required String conversationId,
    required String dogId,
    required String issueId,
    required String resultKey,
    required List<String> solutionSkills,
  }) async {
    final id = _id('diag');
    await db.into(db.diagnosisResults).insert(DiagnosisResultsCompanion.insert(
          id: id,
          conversationId: conversationId,
          dogId: dogId,
          issueId: issueId,
          resultKey: resultKey,
          solutionSkillIds: jsonEncode(solutionSkills),
          createdAt: _iso(_clock()),
          userId: Value(await currentUserId(db)),
        ));
    return id;
  }

  Future<DiagnosisResult?> diagnosisResult(String id) =>
      (db.select(db.diagnosisResults)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 加入本周计划：按 [addDiagnosisToWeek] 规则追加到当前活动计划，
  /// 并把 DiagnosisResult.added_to_plan_id 写成该计划。一次事务。
  Future<DiagnosisWeekAddition> addToThisWeek({
    required String diagnosisResultId,
    required ContentLibrary content,
  }) async {
    return db.transaction(() async {
      final r = await (db.select(db.diagnosisResults)
            ..where((t) => t.id.equals(diagnosisResultId)))
          .getSingle();
      final plan = await PlanRepository(db).activePlan(r.dogId);
      if (plan == null) throw StateError('没有活动计划');
      final goals = await PlanRepository(db).goals(plan.id);
      final statuses = await skillStatusMap(r.dogId);
      final dog = await (db.select(db.dogs)..where((t) => t.id.equals(r.dogId))).getSingle();
      final result = addDiagnosisToWeek(
        solutionSkills: decodeIdList(r.solutionSkillIds),
        currentGoalIds: [for (final g in goals) g.skillId],
        mastered: {
          for (final e in statuses.entries)
            if (e.value == 'mastered') e.key,
        },
        ageWeeks: ageWeeksOn(parseDateOnly(dog.birthDate), _clock().toLocal()),
        skills: content.skills,
      );
      var position = goals.isEmpty ? 0 : goals.map((g) => g.position).reduce((a, b) => a > b ? a : b) + 1;
      for (final g in result.added) {
        await db.into(db.planGoals).insert(PlanGoalsCompanion.insert(
              planId: plan.id,
              skillId: g.skillId,
              position: position++,
              targetSessions: g.targetSessions,
              source: sourceToDb(g.source),
            ));
      }
      await (db.update(db.diagnosisResults)..where((t) => t.id.equals(r.id)))
          .write(DiagnosisResultsCompanion(addedToPlanId: Value(plan.id)));
      return result;
    });
  }

  /// 在线模式（AI 助理训犬师）的"加入本周计划"确认卡片：主人点确认时执行。
  /// 按 [addDiagnosisToWeek] 同一套规则重新校验一次（卡片生成后情况可能变了），再写入当前活动计划。
  Future<DiagnosisWeekAddition> addSkillsToThisWeek({
    required String dogId,
    required List<String> skillIds,
    required ContentLibrary content,
  }) async {
    return db.transaction(() async {
      final plan = await PlanRepository(db).activePlan(dogId);
      if (plan == null) throw StateError('没有活动计划');
      final goals = await PlanRepository(db).goals(plan.id);
      final statuses = await skillStatusMap(dogId);
      final dog = await (db.select(db.dogs)..where((t) => t.id.equals(dogId))).getSingle();
      final result = addDiagnosisToWeek(
        solutionSkills: skillIds,
        currentGoalIds: [for (final g in goals) g.skillId],
        mastered: {
          for (final e in statuses.entries)
            if (e.value == 'mastered') e.key,
        },
        ageWeeks: ageWeeksOn(parseDateOnly(dog.birthDate), _clock().toLocal()),
        skills: content.skills,
      );
      var position = goals.isEmpty ? 0 : goals.map((g) => g.position).reduce((a, b) => a > b ? a : b) + 1;
      for (final g in result.added) {
        await db.into(db.planGoals).insert(PlanGoalsCompanion.insert(
              planId: plan.id,
              skillId: g.skillId,
              position: position++,
              targetSessions: g.targetSessions,
              source: sourceToDb(g.source),
            ));
      }
      return result;
    });
  }

  /// "加入下周"弹窗用的预览：与本周同一规则（第 9 节），周龄按下周一计算，
  /// 当前目标视为空。实际下周生成时在 nextWeekPlan() 里按当时的掌握情况再算一次。
  Future<DiagnosisWeekAddition> previewNextWeek({
    required String diagnosisResultId,
    required ContentLibrary content,
  }) async {
    final r = await (db.select(db.diagnosisResults)
          ..where((t) => t.id.equals(diagnosisResultId)))
        .getSingle();
    final dog = await (db.select(db.dogs)..where((t) => t.id.equals(r.dogId))).getSingle();
    final statuses = await skillStatusMap(r.dogId);
    final nextMonday = weekStartOf(_clock().toLocal()).add(const Duration(days: 7));
    return addDiagnosisToWeek(
      solutionSkills: decodeIdList(r.solutionSkillIds),
      currentGoalIds: const [],
      mastered: {
        for (final e in statuses.entries)
          if (e.value == 'mastered') e.key,
      },
      ageWeeks: ageWeeksOn(parseDateOnly(dog.birthDate), nextMonday),
      skills: content.skills,
    );
  }

  /// 加入下周计划：DiagnosisResult.added_to_plan_id 保持 null，把技能并入
  /// 当前活动计划的 pending_diagnosis_skills（去重、保持顺序）。返回合并后的列表。
  Future<List<String>> addToNextWeek({required String diagnosisResultId}) async {
    return db.transaction(() async {
      final r = await (db.select(db.diagnosisResults)
            ..where((t) => t.id.equals(diagnosisResultId)))
          .getSingle();
      final plan = await PlanRepository(db).activePlan(r.dogId);
      if (plan == null) throw StateError('没有活动计划');
      final merged = <String>[...decodeIdList(plan.pendingDiagnosisSkills)];
      for (final s in decodeIdList(r.solutionSkillIds)) {
        if (!merged.contains(s)) merged.add(s);
      }
      await (db.update(db.weeklyPlans)..where((t) => t.id.equals(plan.id)))
          .write(WeeklyPlansCompanion(pendingDiagnosisSkills: Value(jsonEncode(merged))));
      await (db.update(db.diagnosisResults)..where((t) => t.id.equals(r.id)))
          .write(const DiagnosisResultsCompanion(addedToPlanId: Value(null)));
      return merged;
    });
  }
}
