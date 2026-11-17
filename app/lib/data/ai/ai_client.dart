/// 调服务端代理 `POST /v1/chat`，读 SSE 流（M3 简报第 3、9 节）。
///
/// 客户端不直连模型、不持有任何 API key；base URL 从
/// `--dart-define=AI_BASE_URL=` 读，默认 `http://10.0.2.2:8000`（Android 模拟器访问宿主机）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// 发给模型的一条历史消息。
class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  /// user | assistant
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// 网络或服务端错误。对话页据此显示"教练暂时联系不上，稍后再试"，消息不入库。
class AiClientException implements Exception {
  AiClientException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'AiClientException: $message${cause == null ? '' : ' ($cause)'}';
}

abstract class AiClient {
  /// 流式返回增量文本。失败抛 [AiClientException]。
  Stream<String> chat({
    required String system,
    required List<ChatTurn> messages,
    int maxTokens,
  });
}

const aiBaseUrl = String.fromEnvironment(
  'AI_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// 默认回答长度上限。
const defaultAiMaxTokens = 2048;

class HttpAiClient implements AiClient {
  HttpAiClient({String baseUrl = aiBaseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              // 流式响应：两次数据之间最多等 60 秒。
              receiveTimeout: const Duration(seconds: 60),
            ));

  final Dio _dio;

  @override
  Stream<String> chat({
    required String system,
    required List<ChatTurn> messages,
    int maxTokens = defaultAiMaxTokens,
  }) async* {
    final Response<ResponseBody> resp;
    try {
      resp = await _dio.post<ResponseBody>(
        '/v1/chat',
        data: {
          'system': system,
          'messages': [for (final m in messages) m.toJson()],
          'max_tokens': maxTokens,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      throw AiClientException('请求失败', e);
    }
    final body = resp.data;
    if (body == null) throw AiClientException('空响应');
    try {
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final event in parseSse(lines)) {
        if (event.event == 'error') throw AiClientException('服务端错误：${event.data}');
        if (event.data == '[DONE]') return;
        yield event.data;
      }
    } on AiClientException {
      rethrow;
    } catch (e) {
      throw AiClientException('读取流失败', e);
    }
    // 没收到 [DONE] 就断了，视为网络失败，整条回答不入库。
    throw AiClientException('流意外结束');
  }
}

class SseEvent {
  const SseEvent({required this.event, required this.data});
  final String event;
  final String data;
}

/// 标准 SSE 解析：空行分隔事件；同一事件多行 `data:` 用 `\n` 连接；`:` 开头为注释。
Stream<SseEvent> parseSse(Stream<String> lines) async* {
  var event = 'message';
  final data = <String>[];
  var hasData = false;
  await for (final raw in lines) {
    final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    if (line.isEmpty) {
      if (hasData) yield SseEvent(event: event, data: data.join('\n'));
      event = 'message';
      data.clear();
      hasData = false;
      continue;
    }
    if (line.startsWith(':')) continue;
    final idx = line.indexOf(':');
    final field = idx < 0 ? line : line.substring(0, idx);
    var value = idx < 0 ? '' : line.substring(idx + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        event = value;
      case 'data':
        data.add(value);
        hasData = true;
    }
  }
  if (hasData) yield SseEvent(event: event, data: data.join('\n'));
}
