/// 记录 Tab（M4 简报第 3 节）：训练记录（按日期倒序，显示操作者）/ 周报列表 / 养护。
library;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_nav.dart';
import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/repositories/session_repository.dart' show scoreFromDb;
import '../../domain/models.dart';
import 'care_page.dart';

/// 其他成员看到带视频备注的记录时的说明（简报 5.5，本期不上传视频文件）。
const videoOnRecorderPhone = '视频保存在录制者的手机上';

final sessionsStreamProvider = StreamProvider<List<TrainingSession>>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield const [];
    return;
  }
  final db = ref.watch(databaseProvider);
  yield* (db.select(db.trainingSessions)
        ..where((t) => t.dogId.equals(dog.id))
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .watch();
});

final reportsStreamProvider = StreamProvider<List<WeeklyReport>>((ref) async* {
  final dog = await ref.watch(currentDogProvider.future);
  if (dog == null) {
    yield const [];
    return;
  }
  final db = ref.watch(databaseProvider);
  yield* (db.select(db.weeklyReports)
        ..where((t) => t.dogId.equals(dog.id))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();
});

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('记录'),
          bottom: const TabBar(tabs: [
            Tab(key: Key('records_tab_sessions'), text: '训练记录'),
            Tab(key: Key('records_tab_reports'), text: '周报'),
            Tab(key: Key('records_tab_care'), text: '养护'),
          ]),
        ),
        bottomNavigationBar: const AppBottomNav(current: AppTab.records),
        body: const TabBarView(children: [SessionsList(), ReportsList(), CarePage()]),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _fmt(DateTime t) {
  final l = t.toLocal();
  return '${l.month}月${l.day}日 ${_two(l.hour)}:${_two(l.minute)}';
}

/// RC-5：训练记录按日期 / 按技能两种视图。
enum SessionsView { byDate, bySkill }

/// 按日期分组（本地日历，倒序）。纯函数。
List<(DateTime, List<TrainingSession>)> groupSessionsByDate(List<TrainingSession> list) {
  final m = <DateTime, List<TrainingSession>>{};
  for (final s in list) {
    final l = DateTime.parse(s.startedAt).toLocal();
    m.putIfAbsent(DateTime(l.year, l.month, l.day), () => []).add(s);
  }
  final keys = m.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final k in keys) (k, m[k]!..sort((a, b) => b.startedAt.compareTo(a.startedAt))),
  ];
}

/// 按技能分组：技能顺序按最近一次练习倒序，组内按时间倒序。纯函数。
List<(String, List<TrainingSession>)> groupSessionsBySkill(List<TrainingSession> list) {
  final m = <String, List<TrainingSession>>{};
  for (final s in list) {
    m.putIfAbsent(s.skillId, () => []).add(s);
  }
  for (final v in m.values) {
    v.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
  final keys = m.keys.toList()..sort((a, b) => m[b]!.first.startedAt.compareTo(m[a]!.first.startedAt));
  return [for (final k in keys) (k, m[k]!)];
}

final sessionsViewProvider = StateProvider<SessionsView>((ref) => SessionsView.byDate);

String _scoreLabel(String s) => switch (scoreFromDb(s)) {
      Score.full => '完全做到',
      Score.partial => '部分做到',
      Score.none => '没做到',
      null => '',
    };

class SessionsList extends ConsumerWidget {
  const SessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsStreamProvider);
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final names = ref.watch(nicknamesProvider).valueOrNull ?? const {};
    final me = ref.watch(currentUserIdProvider).valueOrNull;
    final view = ref.watch(sessionsViewProvider);
    String skillName(String id) => lib?.skillById[id]?.name ?? id;
    return sessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('读取失败：$e')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('还没有训练记录'));
        Widget tile(TrainingSession s, {required bool showSkill}) {
          final who = displayNickname(names, s.userId, meId: me);
          final part = s.scriptPart == miniScriptPart ? '保底任务' : '第 ${s.scriptPart} 部分';
          return ListTile(
            key: Key('session_${s.id}'),
            title: Text(showSkill ? '${skillName(s.skillId)} · ${_scoreLabel(s.score)}' : '${_fmt(DateTime.parse(s.startedAt))} · ${_scoreLabel(s.score)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(showSkill ? '${_fmt(DateTime.parse(s.startedAt))} · $part' : part, maxLines: 1),
                Text('练习者：$who', key: Key('session_who_${s.id}')),
                if (s.noteText != null && s.noteText!.isNotEmpty) Text(s.noteText!),
                if (s.noteVideoUrl != null)
                  Text(s.userId == me ? '有视频备注' : videoOnRecorderPhone, key: Key('session_video_${s.id}')),
              ],
            ),
            isThreeLine: true,
          );
        }

        final children = <Widget>[];
        if (view == SessionsView.byDate) {
          for (final (day, items) in groupSessionsByDate(list)) {
            children.add(_GroupHeader(
                key: Key('sessions_date_${day.year}-${day.month}-${day.day}'),
                text: '${day.month}月${day.day}日 · ${items.length} 次'));
            children.addAll(items.map((s) => tile(s, showSkill: true)));
          }
        } else {
          for (final (skill, items) in groupSessionsBySkill(list)) {
            final full = items.where((s) => s.score == 'full').length;
            children.add(_GroupHeader(
                key: Key('sessions_skill_$skill'),
                text: '${skillName(skill)} · ${items.length} 次（完全做到 $full 次）'));
            children.addAll(items.map((s) => tile(s, showSkill: false)));
          }
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<SessionsView>(
                key: const Key('sessions_view'),
                segments: const [
                  ButtonSegment(value: SessionsView.byDate, label: Text('按日期'), icon: Icon(Icons.calendar_today, size: 16)),
                  ButtonSegment(value: SessionsView.bySkill, label: Text('按技能'), icon: Icon(Icons.school_outlined, size: 16)),
                ],
                selected: {view},
                onSelectionChanged: (v) => ref.read(sessionsViewProvider.notifier).state = v.first,
              ),
            ),
            Expanded(child: ListView(key: const Key('sessions_list'), children: children)),
          ],
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class ReportsList extends ConsumerWidget {
  const ReportsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsStreamProvider);
    return reports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('读取失败：$e')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('还没有周报，每周日晚上自动生成'));
        return ListView(
          key: const Key('reports_list'),
          children: [
            for (final r in list)
              ListTile(
                key: Key('report_item_${r.id}'),
                leading: Icon(r.readAt == null ? Icons.mark_email_unread : Icons.description_outlined),
                title: Text('周报 · ${_fmt(DateTime.parse(r.createdAt))}'),
                subtitle: Text(r.aiComment, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => context.push('/report/${r.id}'),
              ),
          ],
        );
      },
    );
  }
}
