/// 我的 → 狗档案 → 口令表（FM-3）：全家统一，改动随同步生效。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../dog_profile/dog_profile_page.dart' show CueTable;

class CueEditorPage extends ConsumerWidget {
  const CueEditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dog = ref.watch(currentDogProvider).valueOrNull;
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('口令表')),
      body: dog == null || lib == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const Key('cue_editor'),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('口令表全家统一：每位成员跟练时显示同样的口令词和手势。'),
                const SizedBox(height: 8),
                CueTable(key: ValueKey(dog.id), dogId: dog.id, skills: lib.skills),
              ],
            ),
    );
  }
}
