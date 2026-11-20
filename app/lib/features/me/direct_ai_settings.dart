/// "我的 → AI 模型直连"：手机端直接输入 Anthropic API Key / 中转地址 / 模型名，不经电脑服务端。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/ai/agent_client.dart';

class DirectAiStrings {
  const DirectAiStrings._();
  static const title = 'AI 模型直连';
  static const offSubtitle = '未配置（当前走电脑服务器）';
  static String onSubtitle(String model) => '已开启直连 · $model';
  static const apiKeyLabel = 'API Key';
  static const apiKeyHint = 'sk-ant-...（留空则走电脑服务器）';
  static const baseUrlLabel = '接口地址（Base URL）';
  static const modelLabel = '模型名称';
  static const test = '测试连接';
  static const testing = '正在连接…';
  static const clear = '清空直连';
  static const cancel = '取消';
  static const save = '保存';
  static const needKey = '请先输入 API Key';
  static const ok = '直连正常，可以脱离电脑使用在线 AI 教练';
  static String fail(String detail) => '连接失败：$detail';
}

class DirectAiTile extends ConsumerWidget {
  const DirectAiTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(directAiConfigProvider);
    return ListTile(
      key: const Key('me_direct_ai'),
      leading: const Icon(Icons.key_outlined),
      title: const Text(DirectAiStrings.title),
      subtitle: Text(cfg.enabled ? DirectAiStrings.onSubtitle(cfg.model) : DirectAiStrings.offSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(context: context, builder: (_) => const DirectAiDialog()),
    );
  }
}

class DirectAiDialog extends ConsumerStatefulWidget {
  const DirectAiDialog({super.key, this.clientFactory});
  final AgentClient Function(DirectAiConfig cfg)? clientFactory;

  @override
  ConsumerState<DirectAiDialog> createState() => _DirectAiDialogState();
}

class _DirectAiDialogState extends ConsumerState<DirectAiDialog> {
  late final _cfg = ref.read(directAiConfigProvider);
  late final _keyCtrl = TextEditingController(text: _cfg.apiKey);
  late final _urlCtrl = TextEditingController(text: _cfg.baseUrl);
  late final _modelCtrl = TextEditingController(text: _cfg.model);
  bool _obscure = true;
  bool _testing = false;
  String? _status;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _status = DirectAiStrings.needKey);
      return;
    }
    setState(() {
      _testing = true;
      _status = DirectAiStrings.testing;
    });
    try {
      final cfg = DirectAiConfig(
        apiKey: key,
        baseUrl: DirectAgentClient.normalizeBaseUrl(_urlCtrl.text),
        model: _modelCtrl.text.trim().isEmpty ? DirectAgentClient.defaultDirectModel : _modelCtrl.text.trim(),
      );
      final client = widget.clientFactory?.call(cfg) ??
          DirectAgentClient(apiKey: cfg.apiKey, baseUrl: cfg.baseUrl, model: cfg.model);
      await client.turn(
        system: '只回复 OK',
        messages: const [
          {'role': 'user', 'content': 'ping'},
        ],
        tools: const [],
      );
      if (mounted) setState(() => _status = DirectAiStrings.ok);
    } catch (e) {
      if (mounted) setState(() => _status = DirectAiStrings.fail('$e'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(DirectAiStrings.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('direct_ai_key_input'),
              controller: _keyCtrl,
              obscureText: _obscure,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: DirectAiStrings.apiKeyLabel,
                hintText: DirectAiStrings.apiKeyHint,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('direct_ai_url_input'),
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: DirectAiStrings.baseUrlLabel,
                hintText: DirectAgentClient.defaultDirectBaseUrl,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('direct_ai_model_input'),
              controller: _modelCtrl,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: DirectAiStrings.modelLabel,
                hintText: DirectAgentClient.defaultDirectModel,
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 10),
              Text(_status!, key: const Key('direct_ai_status'), style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('direct_ai_test'),
          onPressed: _testing ? null : _test,
          child: const Text(DirectAiStrings.test),
        ),
        if (_cfg.enabled)
          TextButton(
            key: const Key('direct_ai_clear'),
            onPressed: () async {
              await ref.read(directAiConfigProvider.notifier).clear();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(DirectAiStrings.clear),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(DirectAiStrings.cancel)),
        FilledButton(
          key: const Key('direct_ai_save'),
          onPressed: () async {
            await ref.read(directAiConfigProvider.notifier).save(
                  apiKey: _keyCtrl.text,
                  baseUrl: _urlCtrl.text,
                  model: _modelCtrl.text,
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text(DirectAiStrings.save),
        ),
      ],
    );
  }
}
