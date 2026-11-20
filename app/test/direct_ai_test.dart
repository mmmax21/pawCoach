/// "我的 → AI 模型直连"：配置持久化、AgentClient 切换与直连请求格式测试。
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/agent_client.dart';

class _StubAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  Map<String, dynamic> responseBody = {
    'stop_reason': 'end_turn',
    'content': [
      {'type': 'text', 'text': 'OK'},
    ],
  };

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(responseBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('Base URL 规范化：默认官方地址、自动补 https://、去末尾斜杠', () {
    expect(DirectAgentClient.normalizeBaseUrl(''), DirectAgentClient.defaultDirectBaseUrl);
    expect(DirectAgentClient.normalizeBaseUrl('relay.example.com/'), 'https://relay.example.com');
    expect(DirectAgentClient.normalizeBaseUrl('http://192.168.1.5:3000/v1/'), 'http://192.168.1.5:3000/v1');
  });

  test('DirectAgentClient 正确发送 Anthropic Messages 请求并解析响应', () async {
    final adapter = _StubAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://relay.example.com/v1'))..httpClientAdapter = adapter;
    final client = DirectAgentClient(
      apiKey: 'sk-test-123',
      baseUrl: 'https://relay.example.com/v1',
      model: 'claude-sonnet-4-5',
      dio: dio,
    );
    final turn = await client.turn(
      system: 'sys',
      messages: const [
        {'role': 'user', 'content': 'hi'},
      ],
      tools: const [],
    );
    expect(turn.stopReason, 'end_turn');
    expect(turn.text, 'OK');
    expect(turn.upstream, 'direct');
    expect(adapter.lastOptions?.path, '/messages');
    expect(adapter.lastOptions?.headers['x-api-key'], 'sk-test-123');
    expect(adapter.lastOptions?.headers['anthropic-version'], '2023-06-01');
  });

  test('DirectAiConfigController 保存、重启读回与清空', () async {
    final dir = Directory.systemTemp.createTempSync('direct_ai_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/direct_ai_config.json');

    final c = DirectAiConfigController(file: () async => file);
    await c.save(apiKey: 'sk-ant-abc', baseUrl: 'relay.test/', model: 'claude-sonnet-4-5');
    expect(c.state.enabled, isTrue);
    expect(c.state.baseUrl, 'https://relay.test');

    final reloaded = DirectAiConfigController(file: () async => file);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reloaded.state.apiKey, 'sk-ant-abc');
    expect(reloaded.state.model, 'claude-sonnet-4-5');

    await reloaded.clear();
    expect(reloaded.state.enabled, isFalse);
  });

  test('agentClientProvider 根据是否填写 API Key 自动切换直连或服务端', () async {
    final dir = Directory.systemTemp.createTempSync('direct_ai_prov_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final container = ProviderContainer(overrides: [
      directAiConfigProvider.overrideWith(
        (ref) => DirectAiConfigController(file: () async => File('${dir.path}/cfg.json')),
      ),
    ]);
    addTearDown(container.dispose);

    expect(container.read(agentClientProvider), isA<HttpAgentClient>());
    await container.read(directAiConfigProvider.notifier).save(
          apiKey: 'sk-ant-xyz',
          baseUrl: 'https://api.anthropic.com',
          model: 'claude-opus-5-5',
        );
    expect(container.read(agentClientProvider), isA<DirectAgentClient>());
    await container.read(directAiConfigProvider.notifier).clear();
    expect(container.read(agentClientProvider), isA<HttpAgentClient>());
  });
}
