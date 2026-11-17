import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breeds.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'onboarding_controller.dart';

/// 第一步：狗的基本信息（ON-2）。
class Step1DogInfo extends ConsumerStatefulWidget {
  const Step1DogInfo({super.key});

  @override
  ConsumerState<Step1DogInfo> createState() => _Step1DogInfoState();
}

class _Step1DogInfoState extends ConsumerState<Step1DogInfo> {
  late final TextEditingController _name;
  final _breedQuery = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: ref.read(onboardingControllerProvider).dogName);
  }

  @override
  void dispose() {
    _name.dispose();
    _breedQuery.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final ageWeeks = ageWeeksOn(form.birthDate, DateTime.now());
    final results = searchBreeds(_breedQuery.text);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('dog_name'),
          controller: _name,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: '名字（必填，≤10 字）',
            border: OutlineInputBorder(),
          ),
          onChanged: ctrl.setDogName,
        ),
        const SizedBox(height: 12),
        ListTile(
          key: const Key('birth_date'),
          contentPadding: EdgeInsets.zero,
          title: const Text('出生日期'),
          subtitle: Text('${_fmt(form.birthDate)} · 周龄 ${ageWeeksLabel(ageWeeks)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () =>
              _pickDate(initial: form.birthDate, onPicked: ctrl.setBirthDate),
        ),
        if (ageWeeks < 8)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('周龄不足 8 周，大部分技能还不能开始，计划可能为空。',
                style: TextStyle(color: Colors.orange)),
          ),
        if (ageWeeks > 52)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('已超过 52 周，仍可训练，内容按幼犬阶段编排。',
                style: TextStyle(color: Colors.orange)),
          ),
        ListTile(
          key: const Key('home_date'),
          contentPadding: EdgeInsets.zero,
          title: const Text('入户日期'),
          subtitle: Text(_fmt(form.homeDate)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () =>
              _pickDate(initial: form.homeDate, onPicked: ctrl.setHomeDate),
        ),
        const SizedBox(height: 12),
        Text('性别', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        SegmentedButton<Sex>(
          key: const Key('sex'),
          segments: const [
            ButtonSegment(value: Sex.male, label: Text('公')),
            ButtonSegment(value: Sex.female, label: Text('母')),
          ],
          selected: form.sex == null ? {} : {form.sex!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) ctrl.setSex(s.first);
          },
        ),
        const SizedBox(height: 16),
        Text('品种', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        TextField(
          key: const Key('breed_search'),
          controller: _breedQuery,
          decoration: InputDecoration(
            hintText: '搜索品种（中文 / 拼音）',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _breedQuery.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_breedQuery.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        if (form.breedId != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('已选：${breedById(form.breedId!)?.name ?? ''}',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        RadioGroup<String>(
          groupValue: form.breedId,
          onChanged: (v) {
            if (v != null) ctrl.setBreed(v);
          },
          child: Column(
            children: [
              for (final b in results)
                RadioListTile<String>(
                  key: Key('breed_${b.id}'),
                  dense: true,
                  title: Text(b.name),
                  value: b.id,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
