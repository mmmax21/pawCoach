/// "我的 → 服务器地址"：规范化、持久化，在线模式与同步都用它。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/ai/agent_client.dart';
import 'package:puppy_trainer/data/sync/sync_service.dart';
import 'package:puppy_trainer/data/video/video_api.dart';

void main() {
  test('地址规范化：补 http://、去掉末尾斜杠', () {
    expect(ServerUrlController.normalize('192.168.1.19:8000'), 'http://192.168.1.19:8000');
    expect(ServerUrlController.normalize(' http://a.test:8000/ '), 'http://a.test:8000');
    expect(ServerUrlController.normalize('https://x.test//'), 'https://x.test');
    expect(ServerUrlController.normalize('  '), '');
  });

  test('保存后写入本机文件，下次启动读回；空地址不覆盖', () async {
    final dir = Directory.systemTemp.createTempSync('server_url_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/server_url.txt');
    final c = ServerUrlController(initial: 'http://10.0.2.2:8000', file: () async => file);
    expect(await c.set('192.168.1.19:8000'), 'http://192.168.1.19:8000');
    expect(file.readAsStringSync(), 'http://192.168.1.19:8000');
    expect(await c.set(''), 'http://192.168.1.19:8000');
    final again = ServerUrlController(initial: 'http://10.0.2.2:8000', file: () async => file);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(again.state, 'http://192.168.1.19:8000');
  });

  test('在线模式与家庭同步都使用当前服务器地址', () {
    final dir = Directory.systemTemp.createTempSync('server_url2_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final container = ProviderContainer(overrides: [
      serverUrlProvider.overrideWith((ref) =>
          ServerUrlController(initial: 'http://192.168.1.19:8000', file: () async => File('${dir.path}/s.txt'))),
    ]);
    addTearDown(container.dispose);
    expect(container.read(agentClientProvider), isA<HttpAgentClient>());
    expect(container.read(syncApiProvider), isA<DioSyncApi>());
    final a1 = container.read(agentClientProvider);
    container.read(serverUrlProvider.notifier).set('192.168.1.50:8000');
    // 地址变了会重新创建客户端
    expect(identical(container.read(agentClientProvider), a1), isFalse);
  });

  test('视频分析服务地址：单独存 video_url.txt，视频客户端跟着地址重建', () async {
    final dir = Directory.systemTemp.createTempSync('video_url_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/video_url.txt');
    final container = ProviderContainer(overrides: [
      videoUrlProvider.overrideWith((ref) =>
          ServerUrlController(fileName: 'video_url.txt', fallback: 'http://10.0.2.2:8001', file: () async => file)),
    ]);
    addTearDown(container.dispose);
    expect(container.read(videoUrlProvider), 'http://10.0.2.2:8001');
    final api1 = container.read(videoAnalysisApiProvider);
    expect(api1, isA<DioVideoAnalysisApi>());
    await container.read(videoUrlProvider.notifier).set('192.168.1.19:8001');
    expect(file.readAsStringSync(), 'http://192.168.1.19:8001');
    expect(identical(container.read(videoAnalysisApiProvider), api1), isFalse);
  });
}
