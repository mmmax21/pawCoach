/// 在线模式：调服务端 `POST /v1/agent`，一次一轮（2026-11-18）。
///
/// Agent 循环在 App 里跑（工具读写的是本机数据库），服务端只把这一轮交给模型。
/// 客户端不持有任何 API key；地址同 [aiBaseUrl]。
library;

import 'package:dio/dio.dart';

import 'ai_client.dart' show AiClientException, aiBaseUrl;

/// 模型这一轮的回复：stop_reason + 内容块（Messages API 格式，原样保存以便下一轮带回）。
class AgentTurn {
  const AgentTurn({required this.stopReason, required this.content, this.upstream});
  final String stopReason;
  final List<Map<String, dynamic>> content;
  final String? upstream;

  /// 这一轮的文字（多个 text 块拼接）。
  String get text => [
        for (final b in content)
          if (b['type'] == 'text') (b['text'] ?? '').toString(),
      ].join('\n').trim();

  List<Map<String, dynamic>> get toolUses => [for (final b in content) if (b['type'] == 'tool_use') b];
}

abstract class AgentClient {
  /// 失败抛 [AiClientException]。
  Future<AgentTurn> turn({
    required String system,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  });
}

class HttpAgentClient implements AgentClient {
  HttpAgentClient({String baseUrl = aiBaseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              // 模型一轮（含思考）可能要几十秒；命令行上游更慢
              receiveTimeout: const Duration(seconds: 200),
            ));

  final Dio _dio;

  @override
  Future<AgentTurn> turn({
    required String system,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/v1/agent',
        data: {'system': system, 'messages': messages, 'tools': tools},
      );
      final body = resp.data ?? const {};
      return AgentTurn(
        stopReason: (body['stop_reason'] ?? 'end_turn').toString(),
        content: [
          for (final b in (body['content'] as List? ?? const []))
            Map<String, dynamic>.from(b as Map),
        ],
        upstream: body['upstream']?.toString(),
      );
    } on DioException catch (e) {
      throw AiClientException('在线服务请求失败', e.response?.statusCode ?? e.type.name);
    }
  }
}
