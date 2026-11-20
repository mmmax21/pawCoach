/// 我的 Tab（M4 简报第 3 节）：狗档案（含口令表）/ 家庭成员 / 徽章墙 / 提醒设置 / 订阅入口（首版隐藏）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_nav.dart';
import '../../core/dog_avatar.dart';
import '../../core/providers.dart';
import 'direct_ai_settings.dart';
import 'server_settings.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dog = ref.watch(currentDogProvider).valueOrNull;
    final hh = ref.watch(householdStreamProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      bottomNavigationBar: const AppBottomNav(current: AppTab.me),
      body: ListView(
        children: [
          if (dog != null)
            ListTile(
              leading: DogAvatar(dogId: dog.id, size: 48, editable: true),
              title: Text(dog.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(hh?.name ?? ''),
            ),
          const Divider(),
          ListTile(
            key: const Key('me_dog_profile'),
            leading: const Icon(Icons.badge_outlined),
            title: const Text('狗档案'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/dog-profile'),
          ),
          ListTile(
            key: const Key('me_cues'),
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('口令表'),
            subtitle: const Text('全家统一的口令词与手势'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/me/cues'),
          ),
          ListTile(
            key: const Key('me_family'),
            leading: const Icon(Icons.family_restroom),
            title: const Text('家庭成员'),
            subtitle: const Text('邀请码、成员、家庭名称'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/me/family'),
          ),
          ListTile(
            key: const Key('me_badges'),
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('徽章墙'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/me/badges'),
          ),
          ListTile(
            key: const Key('me_reminder'),
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('提醒设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reminder'),
          ),
          const ServerUrlTile(),
          const DirectAiTile(),
          if (subscriptionEntryEnabled)
            const ListTile(
              key: Key('me_subscription'),
              leading: Icon(Icons.workspace_premium_outlined),
              title: Text('订阅'),
            ),
        ],
      ),
    );
  }
}

final householdStreamProvider = StreamProvider((ref) => ref.watch(familyRepositoryProvider).watchHousehold());
