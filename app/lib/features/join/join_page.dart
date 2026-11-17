/// 加入已有家庭（FM-2，简报 5.2）：输入邀请码与昵称 → 加入 → 全量拉取 → 直接进首页，不走狗的建档。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/sync/sync_service.dart';

class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key});

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  final _code = TextEditingController();
  final _nick = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _nick.dispose();
    super.dispose();
  }

  bool get _valid => _code.text.trim().length == 6 && _nick.text.trim().isNotEmpty;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(httpSyncServiceProvider).joinHousehold(inviteCode: _code.text, nickname: _nick.text.trim());
      if (ref.read(appEffectsEnabledProvider)) ref.read(syncSchedulerProvider).start();
      if (mounted) context.go('/home');
    } on SyncException catch (e) {
      setState(() => _error = switch (e.code) {
            'invalid_invite' => '邀请码不正确或已失效',
            'already_has_dog' => '这台手机已经建过档，不能加入别的家庭',
            'already_in_household' => '这个账号已经在别的家庭里',
            _ => e.isNetwork ? '没有连上同步服务，请检查网络' : '加入失败（${e.code}）',
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加入已有家庭')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('请家人在"我的 → 家庭成员"里查看 6 位邀请码。加入后直接看到同一只狗的全部数据。'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('join_code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(labelText: '邀请码', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('join_nickname'),
            controller: _nick,
            maxLength: 20,
            decoration: const InputDecoration(labelText: '你的昵称（例如：爸爸）', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('join_error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('join_submit'),
            onPressed: !_valid || _busy ? null : _join,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('加入'),
          ),
        ],
      ),
    );
  }
}
