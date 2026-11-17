/// 测试与无服务端联调用的假客户端（M3 简报第 3、10 节）。
///
/// 不联网。返回固定文本，并在末尾引用系统提示资料块里的全部 ID，
/// 用来验证第一、二层与 `[ref]` 解析链路；不代表真实模型的回答质量。
library;

import 'ai_client.dart';
import 'prompt_builder.dart';

class FakeAiClient implements AiClient {
  FakeAiClient({this.reply, this.fail = false, this.chunkSize = 6});

  /// 自定义回答（含或不含 `[ref: ...]`）；为 null 时用默认固定文本 + 资料 ID。
  final String? reply;

  /// 为 true 时模拟网络失败。
  final bool fail;
  final int chunkSize;

  /// 被调用次数（断言"固定话术不调模型"）。
  int calls = 0;
  String? lastSystem;
  List<ChatTurn>? lastMessages;

  static const defaultText = '（测试回答）以下内容依据资料整理。';

  @override
  Stream<String> chat({
    required String system,
    required List<ChatTurn> messages,
    int maxTokens = defaultAiMaxTokens,
  }) async* {
    calls++;
    lastSystem = system;
    lastMessages = messages;
    if (fail) throw AiClientException('FakeAiClient: 模拟网络失败');
    final ids = materialIdsInPrompt(system);
    final text = reply ?? '$defaultText\n[ref: ${ids.join(', ')}]';
    for (var i = 0; i < text.length; i += chunkSize) {
      await Future<void>.microtask(() {}); // 让出一次，模拟分段到达（不用 Timer，便于 widget 测试的 fake async）
      yield text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize);
    }
  }
}
