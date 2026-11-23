/// 视频纠错结果存取（M5 简报 4.5）。本机表 video_analyses，不同步、不存视频。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/video_checks.dart';
import '../../domain/video_progress.dart';
import '../db/database.dart';

class StoredVideoAnalysis {
  const StoredVideoAnalysis({
    required this.id,
    required this.dogId,
    required this.skillId,
    required this.createdAt,
    required this.status,
    required this.metrics,
    required this.findings,
    required this.contentVersion,
    this.retakeReasons = const [],
  });
  final String id;
  final String dogId;
  final String skillId;
  final DateTime createdAt;
  final VideoStatus status;
  final VideoMetrics metrics;
  final List<VideoFinding> findings;
  final String contentVersion;
  final List<RetakeReason> retakeReasons;

  VideoJudgement get judgement => VideoJudgement(
      status: status,
      metrics: metrics,
      findings: findings,
      retakeReasons: retakeReasons);

  factory StoredVideoAnalysis.fromRow(VideoAnalyse r) => StoredVideoAnalysis(
        id: r.id,
        dogId: r.dogId,
        skillId: r.skillId,
        createdAt: DateTime.parse(r.createdAt),
        status: r.status == 'retake' ? VideoStatus.retake : VideoStatus.ok,
        metrics: VideoMetrics.fromJson(jsonDecode(r.metricsJson) as Map),
        findings: [
          for (final f in jsonDecode(r.findingsJson) as List)
            VideoFinding.fromJson(f as Map),
        ],
        contentVersion: r.contentVersion,
        retakeReasons: _reasons(jsonDecode(r.metricsJson) as Map),
      );

  /// 重拍原因存在 metrics_json 的 retake_reasons 里（不改表结构）；旧记录没有这个字段 → 空。
  static List<RetakeReason> _reasons(Map m) => [
        for (final n in (m['retake_reasons'] as List? ?? const []))
          ...RetakeReason.values.where((r) => r.name == n),
      ];
}

String _metricsJson(VideoJudgement j) => jsonEncode({
      ...j.metrics.toJson(),
      if (j.retakeReasons.isNotEmpty)
        'retake_reasons': [for (final r in j.retakeReasons) r.name],
    });

class VideoRepository {
  VideoRepository(this.db);
  final AppDatabase db;

  /// 历史只展示最近几次（M5 简报 4.5：最近 5 次）。
  static const historyLimit = 5;

  Future<String> save({
    required String dogId,
    required String skillId,
    required VideoJudgement judgement,
    required String contentVersion,
    required DateTime now,
  }) async {
    final id = 'va_${now.microsecondsSinceEpoch}';
    await db.into(db.videoAnalyses).insert(VideoAnalysesCompanion.insert(
          id: id,
          dogId: dogId,
          skillId: skillId,
          createdAt: now.toUtc().toIso8601String(),
          status: judgement.status.name,
          metricsJson: _metricsJson(judgement),
          findingsJson:
              jsonEncode([for (final f in judgement.findings) f.toJson()]),
          contentVersion: contentVersion,
        ));
    return id;
  }

  /// 用户补标口令、重新判定后，覆盖同一条记录（一次上传在历史里只占一行）。
  Future<void> replace(String id, VideoJudgement judgement) async {
    await (db.update(db.videoAnalyses)..where((t) => t.id.equals(id)))
        .write(VideoAnalysesCompanion(
      status: Value(judgement.status.name),
      metricsJson: Value(_metricsJson(judgement)),
      findingsJson:
          Value(jsonEncode([for (final f in judgement.findings) f.toJson()])),
    ));
  }

  Stream<List<StoredVideoAnalysis>> watchRecent(String dogId, String skillId) {
    final q = db.select(db.videoAnalyses)
      ..where((t) => t.dogId.equals(dogId) & t.skillId.equals(skillId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(historyLimit);
    return q
        .watch()
        .map((rows) => [for (final r in rows) StoredVideoAnalysis.fromRow(r)]);
  }

  /// 该技能的全部已判定检查（不含重拍），按时间升序：用于"和上次比"与纠错进度。
  Stream<List<VideoAttempt>> watchAttempts(String dogId, String skillId) {
    final q = db.select(db.videoAnalyses)
      ..where((t) =>
          t.dogId.equals(dogId) &
          t.skillId.equals(skillId) &
          t.status.equals(VideoStatus.ok.name))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            () {
              final a = StoredVideoAnalysis.fromRow(r);
              return VideoAttempt(id: a.id, at: a.createdAt, judgement: a.judgement);
            }(),
        ]);
  }

  Future<List<VideoAttempt>> attempts(String dogId, String skillId) =>
      watchAttempts(dogId, skillId).first;

  Future<StoredVideoAnalysis?> byId(String id) async {
    final r = await (db.select(db.videoAnalyses)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : StoredVideoAnalysis.fromRow(r);
  }
}
