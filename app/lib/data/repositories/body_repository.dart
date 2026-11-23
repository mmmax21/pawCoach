/// 狗的状态（身体信号）检查记录。
///
/// 不新建表：存在本机表 video_analyses 里（不同步、不存视频），skill_id 固定为 [bodySkillKey]，
/// 视频纠错的查询都按真实技能 id 过滤，不会读到这些行。
/// status 存 [BodyState] 名；metrics_json 存 {context, skill, summary}。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/body_signals.dart';
import '../db/database.dart';

const bodySkillKey = '__body__';

/// 检查是在哪里做的。
enum BodyContext { preTraining, video, live }

class BodyCheckRecord {
  const BodyCheckRecord({
    required this.id,
    required this.at,
    required this.state,
    required this.context,
    required this.summary,
    this.skillId,
    this.referral = false,
  });
  final String id;
  final DateTime at;
  final BodyState state;
  final BodyContext context;
  final String? skillId;
  final BodySummary summary;
  final bool referral;
}

class BodyRepository {
  BodyRepository(this.db);
  final AppDatabase db;

  Future<String> save({
    required String dogId,
    required BodyAssessment assessment,
    required BodySummary summary,
    required BodyContext context,
    required String contentVersion,
    required DateTime now,
    String? skillId,
  }) async {
    final id = 'bc_${now.microsecondsSinceEpoch}';
    await db.into(db.videoAnalyses).insert(VideoAnalysesCompanion.insert(
          id: id,
          dogId: dogId,
          skillId: bodySkillKey,
          createdAt: now.toUtc().toIso8601String(),
          status: assessment.state.name,
          metricsJson: jsonEncode({
            'context': context.name,
            'skill': skillId,
            'referral': assessment.referral,
            'summary': summary.toJson(),
          }),
          findingsJson: '[]',
          contentVersion: contentVersion,
        ));
    return id;
  }

  static BodyCheckRecord _row(VideoAnalyse r) {
    final m = jsonDecode(r.metricsJson) as Map;
    return BodyCheckRecord(
      id: r.id,
      at: DateTime.parse(r.createdAt),
      state: BodyState.values.firstWhere((s) => s.name == r.status, orElse: () => BodyState.unclear),
      context: BodyContext.values.firstWhere((c) => c.name == m['context'], orElse: () => BodyContext.preTraining),
      skillId: m['skill'] as String?,
      referral: m['referral'] == true,
      summary: BodySummary.fromJson((m['summary'] as Map?) ?? const {}),
    );
  }

  /// 最近的检查，新的在前。
  Future<List<BodyCheckRecord>> recent(String dogId, {int limit = 10}) async {
    final rows = await (db.select(db.videoAnalyses)
          ..where((t) => t.dogId.equals(dogId) & t.skillId.equals(bodySkillKey))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
    return [for (final r in rows) _row(r)];
  }

  Stream<List<BodyCheckRecord>> watchRecent(String dogId, {int limit = 10}) {
    final q = db.select(db.videoAnalyses)
      ..where((t) => t.dogId.equals(dogId) & t.skillId.equals(bodySkillKey))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return q.watch().map((rows) => [for (final r in rows) _row(r)]);
  }

  /// [from, to) 之间的检查（周报用）。
  Future<List<BodyCheckRecord>> between(String dogId, DateTime from, DateTime to) async {
    final rows = await (db.select(db.videoAnalyses)
          ..where((t) =>
              t.dogId.equals(dogId) &
              t.skillId.equals(bodySkillKey) &
              t.createdAt.isBiggerOrEqualValue(from.toUtc().toIso8601String()) &
              t.createdAt.isSmallerThanValue(to.toUtc().toIso8601String())))
        .get();
    return [for (final r in rows) _row(r)];
  }
}
