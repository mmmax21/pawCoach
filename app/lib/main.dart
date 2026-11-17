import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/training_audio_service.dart';
import 'services/weekly_job.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 后台音频服务必须在 runApp 之前注册（audio_service 要求）。
  try {
    await initTrainingAudio();
  } catch (e) {
    debugPrint('后台音频初始化失败：$e');
  }
  // 周日 21:00 的周报任务；失败不阻塞启动，冷启动补跑兜底。
  registerWeeklyJob().catchError((Object e) {
    debugPrint('周报任务注册失败：$e');
  });
  runApp(const ProviderScope(child: PuppyTrainerApp()));
}
