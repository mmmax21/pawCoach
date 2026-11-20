/// "我的 → 服务器地址"：在线模式与家庭同步共用的 server/ 地址（2026-11-19 真机彩排）。
/// 换 Wi-Fi 后电脑 IP 会变，在这里改一下即可，不用重新打包。
/// 视频分析服务（video_service，默认 8001 端口）的地址用同一个对话框，见 [VideoUrlTile]。
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

  static const videoTitle = '视频分析服务地址';
  static const videoSubtitle = '视频纠错、引导拍摄与实时计时使用';
  static const videoHint = '例如 192.168.1.19:8001';
  static String videoOk(String pose) => '连接正常（姿态模型：$pose）';
}

/// 一类地址的配置：存哪个 provider、怎么测连接。
class _UrlKind {
  const _UrlKind({
    required this.provider,
    required this.title,
    required this.hint,
    required this.healthPath,
    required this.healthField,
    required this.ok,
    required this.keyPrefix,
  });
  final StateNotifierProvider<ServerUrlController, String> provider;
  final String title;
  final String hint;
  final String healthPath;
  final String healthField;
  final String Function(String) ok;
  final String keyPrefix;
}

final _serverKind = _UrlKind(
  provider: serverUrlProvider,
  title: ServerStrings.title,
  hint: ServerStrings.hint,
  healthPath: '/healthz',
  healthField: 'upstream',
  ok: ServerStrings.ok,
  keyPrefix: 'server_url',
);

final _videoKind = _UrlKind(
  provider: videoUrlProvider,
  title: ServerStrings.videoTitle,
  hint: ServerStrings.videoHint,
  healthPath: '/',
  healthField: 'pose',
  ok: ServerStrings.videoOk,
  keyPrefix: 'video_url',
);

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

/// "我的 → 视频分析服务地址"：只在打开视频功能（VIDEO_ANALYSIS）时显示。
class VideoUrlTile extends ConsumerWidget {
  const VideoUrlTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(videoAnalysisEnabledProvider)) return const SizedBox.shrink();
    final url = ref.watch(videoUrlProvider);
    return ListTile(
      key: const Key('me_video_server'),
      leading: const Icon(Icons.videocam_outlined),
      title: const Text(ServerStrings.videoTitle),
      subtitle: Text('${ServerStrings.videoSubtitle} · $url'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(context: context, builder: (_) => const ServerUrlDialog.video()),
    );
  }
}

class ServerUrlDialog extends ConsumerStatefulWidget {
  const ServerUrlDialog({super.key, this.dio}) : _video = false;
  const ServerUrlDialog.video({super.key, this.dio}) : _video = true;
  final Dio? dio;
  final bool _video;

  _UrlKind get _kind => _video ? _videoKind : _serverKind;

  @override
  ConsumerState<ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends ConsumerState<ServerUrlDialog> {
  late final _kind = widget._kind;
  late final _ctrl = TextEditingController(text: ref.read(_kind.provider));
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
      final r = await dio.get<Map<String, dynamic>>('$url${_kind.healthPath}');
      final v = (r.data?[_kind.healthField] ?? '?').toString();
      if (mounted) setState(() => _status = _kind.ok(v));
    } catch (_) {
      if (mounted) setState(() => _status = ServerStrings.fail);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_kind.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: Key('${_kind.keyPrefix}_input'),
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(hintText: _kind.hint),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(_status!, key: Key('${_kind.keyPrefix}_status'), style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: Key('${_kind.keyPrefix}_test'),
          onPressed: _testing ? null : _test,
          child: const Text(ServerStrings.test),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(ServerStrings.cancel)),
        FilledButton(
          key: Key('${_kind.keyPrefix}_save'),
          onPressed: () async {
            await ref.read(_kind.provider.notifier).set(_ctrl.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text(ServerStrings.save),
        ),
      ],
    );
  }
}
