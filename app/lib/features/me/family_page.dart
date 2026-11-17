/// 家庭成员（FM-1 / FM-2 / FM-5）：邀请码（可复制、可重新生成）、成员列表、家庭改名、我的昵称。
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/sync/sync_service.dart';
import 'me_page.dart' show householdStreamProvider;

final membersProvider = StreamProvider<List<MemberView>>((ref) => ref.watch(familyRepositoryProvider).watchMembers());

class FamilyPage extends ConsumerStatefulWidget {
  const FamilyPage({super.key});

  @override
  ConsumerState<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends ConsumerState<FamilyPage> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 进入页面时：未上传则上传（拿邀请码），已上传则刷新邀请码。失败只提示，不影响本地使用。
  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = ref.read(httpSyncServiceProvider);
      await s.ensureHouseholdUploaded();
      await s.householdInfo();
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.isNetwork ? '没有连上同步服务，联网后自动生成邀请码' : '同步失败（${e.code}）');
    } catch (e) {
      if (mounted) setState(() => _error = '同步失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('重新生成邀请码？'),
        content: const Text('旧邀请码会立即失效，已加入的成员不受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(key: const Key('invite_regen_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('重新生成')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(httpSyncServiceProvider).regenerateInvite();
    } on SyncException catch (e) {
      _snack(e.status == 403 ? '只有创建者可以重新生成邀请码' : '没有连上同步服务');
    }
  }

  /// FM-4：创建者移除成员（不能移除自己）。
  Future<void> _remove(MemberView m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('移除${m.nickname}？'),
        content: const Text('移除后对方的手机会退出这个家庭，看不到狗的数据。对方已经同步上来的训练记录会保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(key: const Key('member_remove_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('移除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(httpSyncServiceProvider).removeMember(m.userId);
      if (mounted) _snack('已移除${m.nickname}');
    } on SyncException catch (e) {
      _snack(switch (e.code) {
        'not_creator' => '只有创建者可以移除成员',
        'cannot_remove_self' => '不能移除自己',
        _ => e.isNetwork ? '没有连上同步服务' : '移除失败（${e.code}）',
      });
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<String?> _ask(String title, String initial, Key key) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(key: key, controller: c, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('取消')),
          FilledButton(
            key: const Key('family_dialog_save'),
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hh = ref.watch(householdStreamProvider).valueOrNull;
    final members = ref.watch(membersProvider).valueOrNull ?? const [];
    final me = ref.watch(currentUserIdProvider).valueOrNull;
    final isCreator = hh != null && hh.creatorUserId == me;
    final code = hh?.inviteCode;
    return Scaffold(
      appBar: AppBar(title: const Text('家庭成员')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              key: const Key('family_name'),
              contentPadding: EdgeInsets.zero,
              title: Text(hh?.name ?? ''),
              subtitle: const Text('家庭名称'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final v = await _ask('家庭改名', hh?.name ?? '', const Key('family_rename_field'));
                if (v != null && v.isNotEmpty) await ref.read(familyRepositoryProvider).rename(v);
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('邀请码'),
                    const SizedBox(height: 8),
                    if (code != null)
                      SelectableText(code,
                          key: const Key('invite_code'),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 6))
                    else if (_busy)
                      const LinearProgressIndicator()
                    else
                      Text(_error ?? '尚未生成', key: const Key('invite_code_missing')),
                    const SizedBox(height: 8),
                    const Text('家人在新手机上打开 App，选"加入已有家庭"，输入邀请码即可看到同一只狗。'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        key: const Key('invite_copy'),
                        onPressed: code == null
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: code));
                                if (mounted) _snack('已复制邀请码');
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                      ),
                      if (isCreator)
                        OutlinedButton.icon(
                          key: const Key('invite_regen'),
                          onPressed: code == null ? null : _regenerate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新生成'),
                        ),
                      if (code == null && !_busy)
                        TextButton(key: const Key('invite_retry'), onPressed: _refresh, child: const Text('重试')),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('成员（${members.length}）', style: Theme.of(context).textTheme.titleSmall),
            for (final m in members)
              ListTile(
                key: Key('member_${m.userId}'),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(m.nickname.isEmpty ? '?' : m.nickname.characters.first)),
                title: Text(m.isMe ? '${m.nickname}（我）' : m.nickname),
                subtitle: Text(m.role == 'creator' ? '创建者' : '成员'),
                trailing: m.isMe
                    ? const Icon(Icons.edit_outlined)
                    : isCreator
                        ? IconButton(
                            key: Key('member_remove_${m.userId}'),
                            tooltip: '移除成员',
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () => _remove(m),
                          )
                        : null,
                onTap: !m.isMe
                    ? null
                    : () async {
                        final v = await _ask('修改我的昵称', m.nickname, const Key('nickname_field'));
                        if (v == null || v.isEmpty) return;
                        await ref.read(familyRepositoryProvider).setMyNickname(v);
                        try {
                          await ref.read(httpSyncServiceProvider).setNickname(v);
                        } catch (_) {}
                      },
              ),
          ],
        ),
      ),
    );
  }
}
