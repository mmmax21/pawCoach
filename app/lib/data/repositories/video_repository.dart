/// 视频纠错结果存取（M5 简报 4.5）。本机表 video_analyses，不同步、不存视频。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/video_checks.dart';
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
  });
  final String id;
  final String dogId;
  final String skillId;
  final DateTime createdAt;
  final VideoStatus status;
  final VideoMetrics metrics;
  final List<VideoFinding> findings;
  final String contentVersion;

  VideoJudgement get judgement =>
      VideoJudgement(status: status, metrics: metrics, findings: findings);

  factory StoredVideoAnalysis.fromRow(VideoAnalyse r) => StoredVideoAnalysis(
        id: r.id,
        dogId: r.dogId,
        skillId: r.skillId,
        createdAt: DateTime.parse(r.createdAt),
        status: r.status == 'retake' ? VideoStatus.retake : VideoStatus.ok,
        metrics: VideoMetrics.fromJson(jsonDecode(r.metricsJson) as Map),
        findings: [
          for (final f in jsonDecode(r.findingsJson) as List) VideoFinding.fromJson(f as Map),
        ],
        contentVersion: r.contentVersion,
      );
}

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
          metricsJson: jsonEncode(judgement.metrics.toJson()),
          findingsJson: jsonEncode([for (final f in judgement.findings) f.toJson()]),
          contentVersion: contentVersion,
        ));
    return id;
  }

  Stream<List<StoredVideoAnalysis>> watchRecent(String dogId, String skillId) {
    final q = db.select(db.videoAnalyses)
      ..where((t) => t.dogId.equals(dogId) & t.skillId.equals(skillId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(historyLimit);
    return q.watch().map((rows) => [for (final r in rows) StoredVideoAnalysis.fromRow(r)]);
  }

  Future<StoredVideoAnalysis?> byId(String id) async {
    final r = await (db.select(db.videoAnalyses)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : StoredVideoAnalysis.fromRow(r);
  }
}
