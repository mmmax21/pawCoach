/// AI 回答三层流程（AI-1）：健康拦截 → 检索 → 第三层。
///
/// 前一层命中就不进下一层。第一、二层是本地纯函数（domain/ai_guard.dart、
/// domain/retrieval.dart），不调模型。第三层按 [AiMode]：
/// - `library`（首版默认，M3 简报第 16 节）：内容库直出（domain/answer_composer.dart），零网络；
/// - `model`（构建开关 `--dart-define=AI_MODE=model`）：调用 [AiClient] 由模型生成（第 5 节原实现）。
/// 不做 IO 以外的副作用：入库由调用方在拿到 [CoachDone] 后进行。
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../domain/ai_guard.dart';
import '../../domain/answer_composer.dart';
import '../../domain/models.dart';
import '../../domain/retrieval.dart';
import 'ai_client.dart';
import 'prompt_builder.dart';

/// 第三层的实现方式。
enum AiMode { library, model }

/// 构建参数 `AI_MODE`，默认 `library`；其他值一律按 library 处理（不意外联网）。
const aiModeName = String.fromEnvironment('AI_MODE', defaultValue: 'library');
const AiMode buildAiMode = aiModeName == 'model' ? AiMode.model : AiMode.library;

enum AiMessageKind { normal, guardHealth, guardNoHit, diagnosisQ, diagnosisResult }

String kindToDb(AiMessageKind k) => switch (k) {
      AiMessageKind.normal => 'normal',
      AiMessageKind.guardHealth => 'guard_health',
      AiMessageKind.guardNoHit => 'guard_no_hit',
      AiMessageKind.diagnosisQ => 'diagnosis_q',
      AiMessageKind.diagnosisResult => 'diagnosis_result',
    };

AiMessageKind kindFromDb(String s) => switch (s) {
      'guard_health' => AiMessageKind.guardHealth,
      'guard_no_hit' => AiMessageKind.guardNoHit,
      'diagnosis_q' => AiMessageKind.diagnosisQ,
      'diagnosis_result' => AiMessageKind.diagnosisResult,
      _ => AiMessageKind.normal,
    };

/// 发给模型的历史条数上限（简报第 6 节）。
const aiHistoryLimit = 10;

class CoachAnswer {
  const CoachAnswer({
    required this.text,
    required this.cited,
    required this.kind,
    required this.modelCalled,
    this.retrieval,
    this.blocks,
  });

  /// 展示与入库的正文（已去掉 `[ref: ...]`）。
  final String text;
  final List<String> cited;
  final AiMessageKind kind;

  /// 是否调用了模型（第一、二层命中时为 false）。
  final bool modelCalled;
  final RetrievalResult? retrieval;

  /// library 模式的回答块（[text] 为其纯文本快照）；model 模式与固定话术为 null。
  final List<AnswerBlock>? blocks;
}

sealed class CoachEvent {
  const CoachEvent();
}

/// 流式过程中的展示文本（已隐藏尾部的 `[ref` 片段）。
class CoachDelta extends CoachEvent {
  const CoachDelta(this.text);
  final String text;
}

class CoachDone extends CoachEvent {
  const CoachDone(this.answer);
  final CoachAnswer answer;
}

typedef AiLogger = void Function(String message);

class AiCoachEngine {
  AiCoachEngine({
    required this.library,
    this.client,
    this.mode = buildAiMode,
    AiLogger? log,
  }) : _log = log ?? ((m) => debugPrint('[ai] $m')) {
    if (mode == AiMode.model && client == null) {
      throw ArgumentError('model 模式需要 AiClient');
    }
  }

  final ContentLibrary library;

  /// 只在 model 模式使用；library 模式为 null，保证不会发起网络请求。
  final AiClient? client;
  final AiMode mode;
  final AiLogger _log;

  /// 第一、二层判定（不调模型）。返回 null 表示需要进入第三层。
  /// 第一层先判：健康类不论是否命中内容库都拦。
  CoachAnswer? localVerdict(String question, RetrievalResult retrieval) {
    final guard = checkHealthGuard(question, library.aiGuard);
    if (guard.blocked) {
      _log('guard_health $guard');
      return const CoachAnswer(
        text: healthGuardReply,
        cited: [],
        kind: AiMessageKind.guardHealth,
        modelCalled: false,
      );
    }
    if (retrieval.noHit) {
      return CoachAnswer(
        text: noHitGuardReply,
        cited: const [],
        kind: AiMessageKind.guardNoHit,
        modelCalled: false,
        retrieval: retrieval,
      );
    }
    return null;
  }

  /// 三层流程。网络失败时抛 [AiClientException]（调用方不入库）。
  Stream<CoachEvent> ask({
    required String question,
    required DogBrief dog,
    String? skillId,
    String? issueId,
    List<ChatTurn> history = const [],
    int? scriptPart,
    Map<String, CueView> cues = const {},
  }) async* {
    final retrieval = retrieve(
      message: question,
      library: library,
      skillId: skillId,
      issueId: issueId,
    );
    final local = localVerdict(question, retrieval);
    if (local != null) {
      _log('${kindToDb(local.kind)} $retrieval');
      yield CoachDone(local);
      return;
    }

    if (mode == AiMode.library) {
      // 16.5：历史消息不影响回答，同一问题在同一上下文下输出恒定。
      final composed = composeAnswer(
        library: library,
        retrieval: retrieval,
        contextSkillId: skillId,
        currentStep: dog.currentStep,
        scriptPart: scriptPart,
        recentScores: dog.recentScores,
        cues: cues,
      );
      yield CoachDone(CoachAnswer(
        text: composed.snapshot,
        cited: composed.cited,
        kind: AiMessageKind.normal,
        modelCalled: false,
        retrieval: retrieval,
        blocks: composed.blocks,
      ));
      return;
    }

    final system = buildSystemPrompt(dog: dog, materials: retrieval.ids, library: library);
    final recent = history.length > aiHistoryLimit
        ? history.sublist(history.length - aiHistoryLimit)
        : history;
    final raw = StringBuffer();
    await for (final chunk in client!.chat(
      system: system,
      messages: [...recent, ChatTurn(role: 'user', content: question)],
    )) {
      raw.write(chunk);
      yield CoachDelta(visibleWhileStreaming(raw.toString()));
    }
    yield CoachDone(finalizeAnswer(raw.toString(), retrieval));
  }

  /// 解析 `[ref]`、校验 ID、按固定话术改判 kind。
  CoachAnswer finalizeAnswer(String raw, RetrievalResult retrieval) {
    final parsed = parseAnswer(raw);
    if (containsNoHitReply(parsed.body)) {
      return CoachAnswer(
        text: parsed.body,
        cited: const [],
        kind: AiMessageKind.guardNoHit,
        modelCalled: true,
        retrieval: retrieval,
      );
    }
    var cited = parsed.refs;
    final allowed = retrieval.ids.toSet();
    if (!parsed.hadRef || cited.isEmpty) {
      _log('ref_missing: 回答缺少 [ref]，cited_content_ids 置空');
      cited = const [];
    } else if (!cited.every(allowed.contains)) {
      _log('ref_invalid: $cited 不全在检索集合 $allowed 内，cited_content_ids 置空');
      cited = const [];
    }
    return CoachAnswer(
      text: parsed.body,
      cited: cited.toSet().toList(),
      kind: AiMessageKind.normal,
      modelCalled: true,
      retrieval: retrieval,
    );
  }
}

/// 流式展示时隐藏回答尾部的 `[ref: ...]`（含尚未写完的 `[re` 片段）。
String visibleWhileStreaming(String raw) {
  final lower = raw.toLowerCase();
  final at = lower.lastIndexOf('[ref');
  if (at >= 0) return raw.substring(0, at).trimRight();
  const marker = '[ref';
  for (var n = marker.length - 1; n > 0; n--) {
    if (lower.endsWith(marker.substring(0, n))) {
      return raw.substring(0, raw.length - n);
    }
  }
  return raw;
}
