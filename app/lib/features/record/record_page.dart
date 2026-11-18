/// 记录页（RC-1 / RC-4，M2 简报第 2 节）：打卡、三档评分、文字备注、视频备注。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models.dart';
import 'checkin_celebration.dart';

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
    final f = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
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
    // 情感化：打卡成功庆祝（约 2.6 秒自动关闭）。读不到连续天数时不显示，直接回首页。
    if (!mounted) return;
    final days = await _streakDays(d.dogId);
    if (!mounted) return;
    if (days != null) {
      final lib = ref.read(contentLibraryProvider).valueOrNull;
      await showCheckinCelebration(
        context,
        score: score,
        streakDays: days,
        skillName: lib?.skillById[d.skillId]?.name ?? d.skillId,
      );
    }
    if (mounted) context.go('/home');
  }

  Future<int?> _streakDays(String dogId) async {
    try {
      final db = ref.read(databaseProvider);
      final row = await (db.select(db.streaks)
            ..where((t) => t.dogId.equals(dogId)))
          .getSingleOrNull();
      return row?.currentDays;
    } catch (_) {
      return null;
    }
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
            Row(
              key: const Key('record_score'),
              children: [
                for (final (i, opt) in _scoreOptions.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: _ScoreButton(
                      option: opt,
                      selected: _score == opt.score,
                      onTap: () => setState(() =>
                          _score = _score == opt.score ? null : opt.score),
                    ),
                  ),
                ],
              ],
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

/// 三档评分（跟练现场：大按钮、表情一眼可辨，单手可点）。
typedef _ScoreOption = ({
  Score score,
  String emoji,
  String label,
  Color color,
  Color soft
});

const List<_ScoreOption> _scoreOptions = [
  (
    score: Score.full,
    emoji: '😄',
    label: RecordStrings.full,
    color: AppColors.success,
    soft: AppColors.successSoft
  ),
  (
    score: Score.partial,
    emoji: '🙂',
    label: RecordStrings.partial,
    color: AppColors.streak,
    soft: AppColors.streakSoft
  ),
  (
    score: Score.none,
    emoji: '😕',
    label: RecordStrings.none,
    color: Color(0xFF8C7B6E),
    soft: Color(0xFFF2EBE5)
  ),
];

class _ScoreButton extends StatelessWidget {
  const _ScoreButton(
      {required this.option, required this.selected, required this.onTap});
  final _ScoreOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        key: Key('record_score_${option.score.name}'),
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? option.soft : Colors.white,
          borderRadius: BorderRadius.circular(AppSpace.radius),
          border: Border.all(
              color: selected ? option.color : AppColors.outline,
              width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpace.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child:
                      Text(option.emoji, style: const TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 6),
                Text(option.label,
                    style: t.labelLarge?.copyWith(
                        color:
                            selected ? option.color : AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
