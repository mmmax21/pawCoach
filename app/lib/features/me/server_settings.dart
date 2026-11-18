/// "我的 → 服务器地址"：在线模式与家庭同步共用的 server/ 地址（2026-11-19 真机彩排）。
/// 换 Wi-Fi 后电脑 IP 会变，在这里改一下即可，不用重新打包。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';

class ServerStrings {
  const ServerStrings._();
  static const title = '服务器地址';
  static const subtitle = '在线 AI 教练与家庭同步使用';
  static const hint = '例如 192.168.1.19:8000';
  static const test = '测试连接';
  static const save = '保存';
  static const cancel = '取消';
  static const testing = '正在连接…';
  static const fail = '连不上：请确认电脑上的服务已启动、手机和电脑在同一个 Wi-Fi';
  static String ok(String upstream) => '连接正常（模型上游：$upstream）';
}

class ServerUrlTile extends ConsumerWidget {
  const ServerUrlTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(serverUrlProvider);
    return ListTile(
      key: const Key('me_server'),
      leading: const Icon(Icons.dns_outlined),
      title: const Text(ServerStrings.title),
      subtitle: Text('${ServerStrings.subtitle} · $url'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(context: context, builder: (_) => const ServerUrlDialog()),
    );
  }
}

class ServerUrlDialog extends ConsumerStatefulWidget {
  const ServerUrlDialog({super.key, this.dio});
  final Dio? dio;

  @override
  ConsumerState<ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends ConsumerState<ServerUrlDialog> {
  late final _ctrl = TextEditingController(text: ref.read(serverUrlProvider));
  String? _status;
  bool _testing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = ServerUrlController.normalize(_ctrl.text);
    setState(() {
      _testing = true;
      _status = ServerStrings.testing;
    });
    try {
      final dio = widget.dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 4), receiveTimeout: const Duration(seconds: 4)));
      final r = await dio.get<Map<String, dynamic>>('$url/healthz');
      final up = (r.data?['upstream'] ?? '?').toString();
      if (mounted) setState(() => _status = ServerStrings.ok(up));
    } catch (_) {
      if (mounted) setState(() => _status = ServerStrings.fail);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(ServerStrings.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('server_url_input'),
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: ServerStrings.hint),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(_status!, key: const Key('server_url_status'), style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('server_url_test'),
          onPressed: _testing ? null : _test,
          child: const Text(ServerStrings.test),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(ServerStrings.cancel)),
        FilledButton(
          key: const Key('server_url_save'),
          onPressed: () async {
            await ref.read(serverUrlProvider.notifier).set(_ctrl.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text(ServerStrings.save),
        ),
      ],
    );
  }
}
