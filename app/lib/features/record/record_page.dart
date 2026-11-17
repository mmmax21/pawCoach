/// 记录页（RC-1 / RC-4，M2 简报第 2 节）：打卡、三档评分、文字备注、视频备注。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models.dart';

class RecordStrings {
  const RecordStrings._();
  static const title = '记录这次训练';
  static const scoreTitle = '这次做得怎么样？';
  static const full = '完全做到';
  static const partial = '部分做到';
  static const none = '没做到';
  static const noteHint = '备注（可选）';
  static const videoPick = '添加视频备注（≤60 秒）';
  static const videoPicked = '已选择视频：';
  static const save = '保存并打卡';
  static const trainer = '训练人：';
  static const skippedPrefix = '本次跳过的步骤：';
  static const needScore = '请先选择一个评分';
}

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key, required this.draft});
  final SessionDraft? draft;

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  Score? _score;
  final _note = TextEditingController();
  String? _videoPath;
  bool _saving = false;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final db = ref.read(databaseProvider);
    final u = await (db.select(db.users)
          ..where((t) => t.id.equals(widget.draft?.userId ?? '')))
        .getSingleOrNull();
    if (mounted) setState(() => _nickname = u?.nickname);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    // 只做本地选取并存路径，不压缩不上传（M2 简报第 2 节 RC-1）。
    final f = await ImagePicker()
        .pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (f != null && mounted) setState(() => _videoPath = f.path);
  }

  Future<void> _save() async {
    final d = widget.draft;
    final score = _score;
    if (d == null || score == null) return;
    setState(() => _saving = true);
    await ref.read(sessionRepositoryProvider).save(
          draft: d,
          score: score,
          noteText: _note.text,
          videoPath: _videoPath,
          now: ref.read(clockProvider)(),
        );
    // ST-7：打卡成功后取消今天的待发提醒，从明天起重新调度。失败不影响打卡。
    try {
      await ref.read(reminderServiceProvider).onCheckin(d.dogId);
    } catch (e) {
      debugPrint('提醒重新调度失败：$e');
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(RecordStrings.title)),
        body: const Center(child: Text('没有待记录的训练')),
      );
    }
    final lib = ref.watch(contentLibraryProvider).valueOrNull;
    final skill = lib?.skillById[d.skillId];
    final t = Theme.of(context).textTheme;
    final mm = d.durationSec ~/ 60;
    final ss = d.durationSec % 60;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(RecordStrings.title),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(skill?.name ?? d.skillId, style: t.headlineSmall),
            const SizedBox(height: 4),
            Text('用时 $mm 分 $ss 秒 · 响片 ${d.clickerCount} 次',
                key: const Key('record_summary')),
            if (_nickname != null)
              Text('${RecordStrings.trainer}$_nickname',
                  key: const Key('record_trainer')),
            if (d.skippedSteps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${RecordStrings.skippedPrefix}${d.skippedSteps.join('、')}',
                    key: const Key('record_skipped')),
              ),
            const SizedBox(height: 16),
            Text(RecordStrings.scoreTitle, style: t.titleMedium),
            if (skill != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(skill.scoringHint, style: t.bodySmall),
              ),
            const SizedBox(height: 8),
            SegmentedButton<Score>(
              key: const Key('record_score'),
              segments: const [
                ButtonSegment(
                    value: Score.full, label: Text(RecordStrings.full)),
                ButtonSegment(
                    value: Score.partial, label: Text(RecordStrings.partial)),
                ButtonSegment(
                    value: Score.none, label: Text(RecordStrings.none)),
              ],
              selected: _score == null ? {} : {_score!},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  setState(() => _score = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('record_note'),
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: RecordStrings.noteHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('record_video'),
              onPressed: _pickVideo,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(_videoPath == null
                  ? RecordStrings.videoPick
                  : '${RecordStrings.videoPicked}${_videoPath!.split(Platform.pathSeparator).last}'),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('record_save'),
              onPressed: _score == null || _saving ? null : _save,
              child: const Text(RecordStrings.save),
            ),
          ),
        ),
      ),
    );
  }
}
