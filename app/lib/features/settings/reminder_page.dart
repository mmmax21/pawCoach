/// 提醒设置（ST-7，M3 简报第 8 节）：开关 + 时间，默认关闭、19:00。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../data/repositories/reminder_repository.dart';

class ReminderPage extends ConsumerStatefulWidget {
  const ReminderPage({super.key});

  @override
  ConsumerState<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends ConsumerState<ReminderPage> {
  String? _dogId;
  ReminderConfig? _config;
  DateTime? _next;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dog = await ref.read(dogRepositoryProvider).currentDog();
    if (dog == null) return;
    final c = await ref.read(reminderRepositoryProvider).get(dog.id);
    if (!mounted) return;
    setState(() {
      _dogId = dog.id;
      _config = c;
    });
  }

  Future<void> _save(ReminderConfig c) async {
    final dogId = _dogId;
    if (dogId == null) return;
    setState(() {
      _saving = true;
      _config = c;
    });
    try {
      final r = await ref.read(reminderServiceProvider).update(dogId, c);
      if (!mounted) return;
      setState(() => _next = r.next);
      if (!r.granted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          key: Key('reminder_denied'),
          content: Text('没有通知权限，提醒不会弹出。可在系统设置里打开。'),
        ));
      }
    } catch (e, st) {
      debugPrint('提醒保存失败：$e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    final c = _config;
    if (c == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: c.hour, minute: c.minute),
    );
    if (picked == null) return;
    await _save(ReminderConfig(enabled: c.enabled, hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    String two(int n) => n.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('提醒设置')),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  key: const Key('reminder_switch'),
                  title: const Text('每日训练提醒'),
                  subtitle: const Text('当天还没打卡时提醒；打过卡当天不再提醒'),
                  value: c.enabled,
                  onChanged: _saving
                      ? null
                      : (v) => _save(ReminderConfig(enabled: v, hour: c.hour, minute: c.minute)),
                ),
                ListTile(
                  key: const Key('reminder_time'),
                  enabled: !_saving,
                  title: const Text('提醒时间'),
                  trailing: Text('${two(c.hour)}:${two(c.minute)}',
                      key: const Key('reminder_time_text'),
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: _pickTime,
                ),
                if (c.enabled && _next != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '下一次提醒：${_next!.month}月${_next!.day}日 ${two(_next!.hour)}:${two(_next!.minute)}',
                      key: const Key('reminder_next'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
    );
  }
}
