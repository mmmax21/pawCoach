/// 狗档案页（ON-7）：可改建档的全部信息；口令表按技能列出，口令词和手势可改。
///
/// 改出生日期 / 困扰 / 每日时长后的计划处理见 ProfileRepository.save（M2 简报第 8 节）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/breeds.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models.dart';

class ProfileStrings {
  const ProfileStrings._();
  static const title = '狗档案';
  static const save = '保存';
  static const cues = '口令表';
  static const cueEditTitle = '修改口令';
  static const cueWord = '口令词';
  static const cueGesture = '手势描述';
  static const cancel = '取消';
  static const ok = '确定';
  static const savedNone = '已保存';
  static const savedRegenerated = '已保存，本周计划已按新信息重新生成';
  static const savedMarked = '已保存。本周已有训练记录，本周计划不变，下周会按新信息重新生成';
  static const maxConcerns = '最多选 3 项';
}

class DogProfilePage extends ConsumerStatefulWidget {
  const DogProfilePage({super.key});

  @override
  ConsumerState<DogProfilePage> createState() => _DogProfilePageState();
}

class _DogProfilePageState extends ConsumerState<DogProfilePage> {
  bool _loaded = false;
  String _dogId = '';
  late TextEditingController _name;
  late DateTime _birth;
  late DateTime _home;
  String? _breedId;
  Sex _sex = Sex.male;
  LivingEnv _env = LivingEnv.apartment;
  int _minutes = 10;
  int _trainers = 1;
  List<String> _concerns = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dogRepo = ref.read(dogRepositoryProvider);
    final dog = await dogRepo.currentDog();
    if (dog == null) return;
    final concerns = await dogRepo.concerns(dog.id);
    if (!mounted) return;
    setState(() {
      _dogId = dog.id;
      _name.text = dog.name;
      _birth = parseDateOnly(dog.birthDate);
      _home = parseDateOnly(dog.homeDate);
      _breedId = dog.breedId;
      _sex = sexFromDb(dog.sex);
      _env = envFromDb(dog.livingEnv);
      _minutes = dog.dailyMinutes;
      _trainers = dog.trainerCount;
      _concerns = [for (final c in concerns) c.issueId];
      _loaded = true;
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> done) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => done(DateTime.utc(picked.year, picked.month, picked.day)));
  }

  Future<void> _pickBreed() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BreedSheet(),
    );
    if (picked != null) setState(() => _breedId = picked);
  }

  bool get _valid {
    final n = _name.text.trim();
    return n.isNotEmpty && n.characters.length <= 10 && _breedId != null;
  }

  Future<void> _save() async {
    final breed = breedById(_breedId!)!;
    final content = await ref.read(contentLibraryProvider.future);
    setState(() => _saving = true);
    final effect = await ref.read(profileRepositoryProvider).save(
          dogId: _dogId,
          edit: DogProfileEdit(
            name: _name.text.trim(),
            birthDate: _birth,
            breedId: breed.id,
            breedText: breed.name,
            sex: _sex,
            homeDate: _home,
            livingEnv: _env,
            dailyMinutes: _minutes,
            trainerCount: _trainers,
            concerns: _concerns,
          ),
          content: content,
          now: ref.read(clockProvider)(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (effect) {
        PlanEffect.none => ProfileStrings.savedNone,
        PlanEffect.regeneratedNow => ProfileStrings.savedRegenerated,
        PlanEffect.markedForNextWeek => ProfileStrings.savedMarked,
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = ref.watch(contentLibraryProvider).valueOrNull;
    if (!_loaded || content == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(ProfileStrings.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final ageWeeks = ageWeeksOn(_birth, DateTime.now());
    final breed = _breedId == null ? null : breedById(_breedId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text(ProfileStrings.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('profile_name'),
            controller: _name,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: '名字（≤10 字）',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          ListTile(
            key: const Key('profile_birth'),
            contentPadding: EdgeInsets.zero,
            title: const Text('出生日期'),
            subtitle: Text('${_fmt(_birth)} · ${ageWeeksLabel(ageWeeks)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(_birth, (d) => _birth = d),
          ),
          ListTile(
            key: const Key('profile_home_date'),
            contentPadding: EdgeInsets.zero,
            title: const Text('入户日期'),
            subtitle: Text(_fmt(_home)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(_home, (d) => _home = d),
          ),
          ListTile(
            key: const Key('profile_breed'),
            contentPadding: EdgeInsets.zero,
            title: const Text('品种'),
            subtitle: Text(breed?.name ?? '未选择'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickBreed,
          ),
          const SizedBox(height: 8),
          Text('性别', style: t.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<Sex>(
            key: const Key('profile_sex'),
            segments: const [
              ButtonSegment(value: Sex.male, label: Text('公')),
              ButtonSegment(value: Sex.female, label: Text('母')),
            ],
            selected: {_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.first),
          ),
          const SizedBox(height: 16),
          Text('每天可投入', style: t.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            key: const Key('profile_minutes'),
            segments: const [
              ButtonSegment(value: 5, label: Text('5 分钟')),
              ButtonSegment(value: 10, label: Text('10 分钟')),
              ButtonSegment(value: 15, label: Text('15 分钟')),
              ButtonSegment(value: 30, label: Text('30 分钟')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() => _minutes = s.first),
          ),
          const SizedBox(height: 16),
          Text('家里几个人会训', style: t.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            key: const Key('profile_trainers'),
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3+')),
            ],
            selected: {_trainers},
            onSelectionChanged: (s) => setState(() => _trainers = s.first),
          ),
          const SizedBox(height: 16),
          Text('居住环境', style: t.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<LivingEnv>(
            key: const Key('profile_env'),
            segments: const [
              ButtonSegment(value: LivingEnv.apartment, label: Text('公寓')),
              ButtonSegment(
                  value: LivingEnv.houseWithYard, label: Text('带院子')),
            ],
            selected: {_env},
            onSelectionChanged: (s) => setState(() => _env = s.first),
          ),
          const SizedBox(height: 16),
          Text('当前困扰（最多 3 项）', style: t.titleSmall),
          for (final i in content.issues)
            CheckboxListTile(
              key: Key('profile_concern_${i.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(i.name),
              value: _concerns.contains(i.id),
              onChanged: (_) {
                setState(() {
                  if (_concerns.contains(i.id)) {
                    _concerns = [..._concerns]..remove(i.id);
                  } else if (_concerns.length >= 3) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(ProfileStrings.maxConcerns)));
                  } else {
                    _concerns = [..._concerns, i.id];
                  }
                });
              },
            ),
          const SizedBox(height: 16),
          Text(ProfileStrings.cues, style: t.titleMedium),
          const SizedBox(height: 4),
          CueTable(dogId: _dogId, skills: content.skills),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('profile_save'),
            onPressed: _valid && !_saving ? _save : null,
            child: const Text(ProfileStrings.save),
          ),
        ),
      ),
    );
  }
}

/// 口令表：按技能列出，点一行改口令词和手势描述（FM-3）。
class CueTable extends ConsumerStatefulWidget {
  const CueTable({super.key, required this.dogId, required this.skills});
  final String dogId;
  final List<Skill> skills;

  @override
  ConsumerState<CueTable> createState() => CueTableState();
}

class CueTableState extends ConsumerState<CueTable> {
  Map<String, DogCue> _cues = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await ref.read(profileRepositoryProvider).cues(widget.dogId);
    if (mounted) setState(() => _cues = {for (final r in rows) r.skillId: r});
  }

  Future<void> _edit(Skill skill, DogCue cue) async {
    final word = TextEditingController(text: cue.cueWord);
    final gesture = TextEditingController(text: cue.gestureText);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${ProfileStrings.cueEditTitle} · ${skill.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('cue_word_field'),
              controller: word,
              decoration: const InputDecoration(labelText: ProfileStrings.cueWord),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('cue_gesture_field'),
              controller: gesture,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: ProfileStrings.cueGesture),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text(ProfileStrings.cancel)),
          TextButton(
              key: const Key('cue_save'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text(ProfileStrings.ok)),
        ],
      ),
    );
    final w = word.text.trim();
    final g = gesture.text.trim();
    word.dispose();
    gesture.dispose();
    if (ok != true || w.isEmpty) return;
    await ref.read(profileRepositoryProvider).updateCue(
          dogId: widget.dogId,
          skillId: skill.id,
          cueWord: w,
          gestureText: g,
          now: ref.read(clockProvider)(),
        );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.skills]..sort((a, b) {
        final c = a.minAgeWeeks.compareTo(b.minAgeWeeks);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return Column(
      children: [
        for (final s in sorted)
          if (_cues[s.id] case final cue?)
            ListTile(
              key: Key('cue_${s.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${s.name}：${cue.cueWord}'),
              subtitle: Text(cue.gestureText),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _edit(s, cue),
            ),
      ],
    );
  }
}

class _BreedSheet extends StatefulWidget {
  const _BreedSheet();
  @override
  State<_BreedSheet> createState() => _BreedSheetState();
}

class _BreedSheetState extends State<_BreedSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchBreeds(_q.text);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                key: const Key('profile_breed_search'),
                controller: _q,
                decoration: const InputDecoration(
                  hintText: '搜索品种（中文 / 拼音）',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final b in results)
                    ListTile(
                      key: Key('profile_breed_${b.id}'),
                      title: Text(b.name),
                      onTap: () => Navigator.pop(context, b.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
