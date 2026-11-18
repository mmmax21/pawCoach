/// 全局 Riverpod providers：数据库、内容库、仓库、同步。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/ai/ai_client.dart';
import '../data/ai/ai_coach_engine.dart' show AiMode, buildAiMode;
import '../data/content/content_repository.dart';
import '../data/content/content_sources.dart';
import '../data/db/database.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/repositories.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/badge_repository.dart';
import '../data/repositories/care_repository.dart';
import '../data/repositories/household_repository.dart';
import '../data/sync/derived_state.dart';
import '../data/sync/sync_scheduler.dart';
import '../data/sync/sync_service.dart';
import '../data/repositories/video_repository.dart';
import '../data/video/video_api.dart';
import '../data/video/video_picker.dart';
import '../services/care_reminder_service.dart';
import '../services/nudge_service.dart';
import '../domain/models.dart';
import '../domain/care_calendar.dart' show careNotificationIdBase;
import '../domain/nudges.dart' show nudgeIdMax, nudgeRestartId;
import '../services/reminder_service.dart';

/// 可在测试里 override 成内存库。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'puppy_trainer.sqlite'));
    return NativeDatabase.createInBackground(file);
  }));
  ref.onDispose(db.close);
  return db;
});

final contentSourceProvider =
    Provider<ContentSource>((ref) => AssetContentSource());

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(
    db: ref.watch(databaseProvider),
    source: ref.watch(contentSourceProvider),
  );
});

/// 启动时加载内容库；失败会把异常抛到 UI 层展示。
final contentLibraryProvider = FutureProvider<ContentLibrary>((ref) {
  return ref.watch(contentRepositoryProvider).ensureLoaded();
});

final householdRepositoryProvider =
    Provider((ref) => HouseholdRepository(ref.watch(databaseProvider)));
final dogRepositoryProvider =
    Provider((ref) => DogRepository(ref.watch(databaseProvider)));
final planRepositoryProvider =
    Provider((ref) => PlanRepository(ref.watch(databaseProvider)));
final onboardingRepositoryProvider =
    Provider((ref) => OnboardingRepository(ref.watch(databaseProvider)));

final sessionRepositoryProvider =
    Provider((ref) => SessionRepository(ref.watch(databaseProvider)));
final reportRepositoryProvider =
    Provider((ref) => ReportRepository(ref.watch(databaseProvider)));
final profileRepositoryProvider =
    Provider((ref) => ProfileRepository(ref.watch(databaseProvider)));

/// 当前时间。单测可 override 成固定时钟。
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// M4：家庭共享同步、徽章、养护
// ---------------------------------------------------------------------------

/// 服务端接口（--dart-define=SYNC_BASE_URL=...）。测试 override 成内存替身。
final syncApiProvider = Provider<SyncApi>((ref) => DioSyncApi());

final derivedStateProvider =
    Provider((ref) => DerivedState(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

final httpSyncServiceProvider = Provider<HttpSyncService>((ref) {
  final s = HttpSyncService(db: ref.watch(databaseProvider), api: ref.watch(syncApiProvider));
  s.onRemoteChange = (tables) async {
    final content = await ref.read(contentLibraryProvider.future);
    await ref.read(derivedStateProvider).recompute(content: content);
    final dog = await ref.read(dogRepositoryProvider).currentDog();
    if (dog == null) return;
    if (tables.contains('care_reminders') || tables.contains('dogs')) {
      try {
        await ref.read(careReminderServiceProvider).refresh(dog.id);
      } catch (_) {}
    }
    if (tables.contains('training_sessions')) {
      try {
        await ref.read(reminderServiceProvider).refresh(dog.id);
      } catch (_) {}
    }
  };
  // FM-4：被移出家庭后取消本机已排的每日提醒与养护通知。
  s.onRemoved = () async {
    try {
      final n = ref.read(reminderNotifierProvider);
      for (var i = 0; i < reminderScheduleDays; i++) {
        await n.cancel(reminderNotificationId + i);
      }
      final cn = ref.read(careNotifierProvider);
      for (var i = careNotificationIdBase; i < careNotificationIdBase + 100; i++) {
        await cn.cancel(i);
      }
      final nn = ref.read(nudgeNotifierProvider);
      for (var id = nudgeRestartId; id <= nudgeIdMax; id++) {
        await nn.cancel(id);
      }
    } catch (_) {}
  };
  return s;
});

final syncServiceProvider = Provider<SyncService>((ref) => ref.watch(httpSyncServiceProvider));

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final s = SyncScheduler(db: ref.watch(databaseProvider), service: ref.watch(httpSyncServiceProvider));
  ref.onDispose(s.stop);
  return s;
});

final badgeRepositoryProvider =
    Provider((ref) => BadgeRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));
final careRepositoryProvider =
    Provider((ref) => CareRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));
final familyRepositoryProvider = Provider((ref) => FamilyRepository(ref.watch(databaseProvider)));

final careNotifierProvider = Provider<CareNotifier>((ref) => LocalCareNotifier());
final careReminderServiceProvider = Provider((ref) => CareReminderService(
      db: ref.watch(databaseProvider),
      notifier: ref.watch(careNotifierProvider),
      clock: ref.watch(clockProvider),
    ));

/// AI-5 主动干预推送（通知 ID 3000–3099，独立渠道）。
final nudgeNotifierProvider =
    Provider<CareNotifier>((ref) => LocalCareNotifier(null, 'training_nudge', '训练建议'));
final nudgeStoreProvider = Provider<NudgeStore>((ref) => FileNudgeStore());
final nudgeServiceProvider = Provider((ref) => NudgeService(
      db: ref.watch(databaseProvider),
      notifier: ref.watch(nudgeNotifierProvider),
      store: ref.watch(nudgeStoreProvider),
      clock: ref.watch(clockProvider),
    ));

/// 本机当前用户 id（注册前为 local_user）。
final currentUserIdProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.localAccounts)..limit(1))
      .watchSingleOrNull()
      .map((a) => a?.userId ?? HouseholdRepository.localUserId);
});

/// user_id → 昵称。
final nicknamesProvider = StreamProvider<Map<String, String>>(
    (ref) => ref.watch(familyRepositoryProvider).watchNicknames());

/// 是否启动同步调度与本地副作用（徽章判定与弹窗、养护排期）。
/// 只在手机上默认开启；主机上跑的 widget 测试默认关闭，避免计时器与弹窗干扰既有用例。
final appEffectsEnabledProvider = Provider<bool>((ref) => Platform.isAndroid || Platform.isIOS);

/// 订阅入口（首版隐藏，PRD 1.4 / M4 简报第 3 节）。
const subscriptionEntryEnabled = false;

/// 当前狗（一个家庭一只狗）。null 表示尚未建档。
final currentDogProvider = StreamProvider<Dog?>((ref) {
  return ref.watch(dogRepositoryProvider).watchCurrentDog();
});

// ---------------------------------------------------------------------------
// M3：AI 教练与提醒
// ---------------------------------------------------------------------------

/// 第三层模式（M3 简报第 16 节）：构建参数 AI_MODE，默认 library（内容库直出、零网络）。
/// 测试可 override。
final aiModeProvider = Provider<AiMode>((ref) => buildAiMode);

/// 模型调用只走服务端代理；只在 model 模式下被读取。测试 override 成 FakeAiClient。
final aiClientProvider = Provider<AiClient>((ref) => HttpAiClient());

final aiRepositoryProvider = Provider(
    (ref) => AiRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

final reminderRepositoryProvider =
    Provider((ref) => ReminderRepository(ref.watch(databaseProvider)));

/// 本地通知后端；测试 override 成假实现。
final reminderNotifierProvider =
    Provider<ReminderNotifier>((ref) => LocalReminderNotifier());

final reminderServiceProvider = Provider((ref) => ReminderService(
      db: ref.watch(databaseProvider),
      notifier: ref.watch(reminderNotifierProvider),
      clock: ref.watch(clockProvider),
    ));

// ---------------------------------------------------------------------------
// M5：视频纠错（PRD AI-4）
// ---------------------------------------------------------------------------

/// 构建参数 VIDEO_ANALYSIS（默认关闭）。测试可 override。
final videoAnalysisEnabledProvider = Provider<bool>((ref) => videoAnalysisEnabled);

/// 视频分析服务客户端（VIDEO_BASE_URL）。测试 override 成替身。
final videoAnalysisApiProvider = Provider<VideoAnalysisApi>((ref) => DioVideoAnalysisApi());

/// 选视频（相册 / 现场录）。测试 override。
final videoPickerProvider = Provider<VideoPicker>((ref) => ImagePickerVideoPicker());

/// 轮询间隔与超时（简报 4.3：每 3 秒一次，5 分钟超时）。测试可缩短。
final videoPollingProvider =
    Provider<({Duration interval, Duration timeout})>((ref) => (
          interval: const Duration(seconds: 3),
          timeout: const Duration(minutes: 5),
        ));

final videoRepositoryProvider =
    Provider((ref) => VideoRepository(ref.watch(databaseProvider)));
