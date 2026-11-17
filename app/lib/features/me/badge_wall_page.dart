/// 徽章墙（ST-2）：已获得的彩色显示获得日期与获得者，未获得的灰色显示 description 作为获得条件。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/household_repository.dart';
import '../shell/badge_icons.dart';

final earnedBadgesProvider = StreamProvider<List<DogBadge>>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield const [];
    return;
  }
  yield* ref.watch(badgeRepositoryProvider).watchEarned(dog.id);
});

class BadgeWallPage extends ConsumerWidget {
  const BadgeWallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final earned = {for (final b in ref.watch(earnedBadgesProvider).valueOrNull ?? const <DogBadge>[]) b.badgeId: b};
    final names = ref.watch(nicknamesProvider).valueOrNull ?? const {};
    final me = ref.watch(currentUserIdProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('徽章墙（${earned.length}/${lib?.badges.length ?? 0}）')),
      body: lib == null
          ? const Center(child: CircularProgressIndicator())
          : GridView.count(
              key: const Key('badge_wall'),
              crossAxisCount: 2,
              padding: const EdgeInsets.all(12),
              childAspectRatio: 0.95,
              children: [
                for (final b in lib.badges)
                  Card(
                    key: Key('badge_${b.id}_${earned.containsKey(b.id) ? 'earned' : 'locked'}'),
                    color: earned.containsKey(b.id) ? cs.primaryContainer : cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(badgeIcon(b.conditionType),
                              size: 40, color: earned.containsKey(b.id) ? cs.primary : cs.outline),
                          const SizedBox(height: 8),
                          Text(b.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: earned.containsKey(b.id) ? null : cs.outline)),
                          const SizedBox(height: 4),
                          if (earned[b.id] case final e?)
                            Text(
                              '${_date(e.earnedAt)}\n${displayNickname(names, e.earnedByUserId, meId: me)} 获得',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            Text(b.description,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _date(String iso) {
  final d = DateTime.parse(iso).toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
