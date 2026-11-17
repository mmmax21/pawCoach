/// 养护页（CR-1，M4 简报第 8 节）：顶部固定展示 disclaimer 原文；
/// 按"待确认 / 即将到期 / 以后 / 已完成"分组；可改日期、标记完成、跳过、手动新增。
/// milestones 只作为时间线信息条展示，不生成提醒。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart' show parseDateOnly;
import '../../domain/care_calendar.dart';

final careStreamProvider = StreamProvider<List<CareReminder>>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield const [];
    return;
  }
  yield* ref.watch(careRepositoryProvider).watch(dog.id);
});

const careGroupTitles = {
  CareGroup.overdue: '待确认',
  CareGroup.upcoming: '即将到期',
  CareGroup.later: '以后',
  CareGroup.done: '已完成',
};

const careTypeLabels = {
  'vaccine': '疫苗',
  'deworm_internal': '体内驱虫',
  'deworm_external': '体外驱虫',
};

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CarePage extends ConsumerWidget {
  const CarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final dog = ref.watch(currentDogProvider).valueOrNull;
    final items = ref.watch(careStreamProvider);
    if (lib == null || dog == null) return const Center(child: CircularProgressIndicator());
    final today = ref.read(clockProvider)();
    final birth = parseDateOnly(dog.birthDate);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('读取失败：$e')),
      data: (list) {
        final groups = {for (final g in CareGroup.values) g: <CareReminder>[]};
        for (final r in list) {
          groups[careGroupOf(
            dueDate: parseDateOnly(r.dueDate),
            done: r.doneAt != null,
            skipped: r.skipped,
            today: today,
          )]!
              .add(r);
        }
        return Stack(
          children: [
            ListView(
              key: const Key('care_list'),
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                Card(
                  key: const Key('care_disclaimer'),
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(lib.careCalendar.disclaimer),
                  ),
                ),
                for (final m in lib.careCalendar.milestones)
                  ListTile(
                    key: Key('care_milestone_${m.id}'),
                    dense: true,
                    leading: const Icon(Icons.info_outline),
                    title: Text('${m.title}（${_d(careDateForWeek(birth, m.week))}）'),
                    subtitle: Text(m.note),
                  ),
                for (final g in CareGroup.values)
                  if (groups[g]!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('${careGroupTitles[g]}（${groups[g]!.length}）',
                          key: Key('care_group_${g.name}'), style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final r in groups[g]!) _CareTile(r: r, group: g),
                  ],
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                key: const Key('care_add'),
                onPressed: () => _add(context, ref, dog.id),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String dogId) async {
    final title = TextEditingController();
    final note = TextEditingController();
    var type = 'vaccine';
    var date = ref.read(clockProvider)();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('新增养护提醒'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                key: const Key('care_add_type'),
                value: type,
                isExpanded: true,
                items: [
                  for (final e in careTypeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => set(() => type = v ?? type),
              ),
              TextField(key: const Key('care_add_title'), controller: title, decoration: const InputDecoration(labelText: '标题')),
              TextField(key: const Key('care_add_note'), controller: note, decoration: const InputDecoration(labelText: '备注（可选）')),
              TextButton(
                key: const Key('care_add_date'),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: c, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (d != null) set(() => date = d);
                },
                child: Text('日期：${_d(date)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            FilledButton(
              key: const Key('care_add_save'),
              onPressed: () => Navigator.pop(c, title.text.trim().isNotEmpty),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref
          .read(careRepositoryProvider)
          .addManual(dogId: dogId, type: type, title: title.text.trim(), note: note.text.trim(), dueDate: date);
    }
  }
}

class _CareTile extends ConsumerWidget {
  const _CareTile({required this.r, required this.group});
  final CareReminder r;
  final CareGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(careRepositoryProvider);
    final status = r.doneAt != null ? '已完成' : (r.skipped ? '已跳过' : '');
    return ListTile(
      key: Key('care_${r.id}'),
      leading: Icon(r.type == 'vaccine' ? Icons.vaccines : Icons.bug_report_outlined),
      title: Text(r.title),
      subtitle: Text([
        '${careTypeLabels[r.type] ?? r.type} · ${r.dueDate}${status.isEmpty ? '' : ' · $status'}',
        if (r.note.isNotEmpty) r.note,
      ].join('\n')),
      isThreeLine: r.note.isNotEmpty,
      trailing: PopupMenuButton<String>(
        key: Key('care_menu_${r.id}'),
        onSelected: (v) async {
          switch (v) {
            case 'done':
              await repo.markDone(r.id);
            case 'skip':
              await repo.skip(r.id);
            case 'reopen':
              await repo.reopen(r.id);
            case 'date':
              final d = await showDatePicker(
                context: context,
                initialDate: parseDateOnly(r.dueDate),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) await repo.changeDate(r.id, d);
            case 'delete':
              await repo.deleteManual(r.id);
          }
        },
        itemBuilder: (_) => [
          if (group != CareGroup.done) ...[
            PopupMenuItem(key: Key('care_done_${r.id}'), value: 'done', child: const Text('标记已完成')),
            PopupMenuItem(key: Key('care_skip_${r.id}'), value: 'skip', child: const Text('跳过')),
            PopupMenuItem(key: Key('care_date_${r.id}'), value: 'date', child: const Text('改日期')),
          ] else
            PopupMenuItem(key: Key('care_reopen_${r.id}'), value: 'reopen', child: const Text('撤销')),
          if (r.templateId == null)
            PopupMenuItem(key: Key('care_delete_${r.id}'), value: 'delete', child: const Text('删除')),
        ],
      ),
    );
  }
}

