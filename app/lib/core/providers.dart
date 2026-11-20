/// 全局 Riverpod providers：数据库、内容库、仓库、同步。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/ai/agent_client.dart';
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
import '../data/video/capture_camera.dart';
import '../data/video/frame_check.dart';
import '../data/video/video_api.dart';
import '../data/video/video_picker.dart';
import '../data/video/live_client.dart';
import '../data/video/live_controller.dart';
import '../data/video/live_mic.dart';
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
// ---------------------------------------------------------------------------
// 服务器地址（2026-11-19 真机彩排）：在线模式与家庭同步共用 server/。
// 默认取构建参数 SYNC_BASE_URL；用户可在"我的 → 服务器地址"里修改（换 Wi-Fi 后 IP 会变，不用重新打包）。
// 存在本机文件 server_url.txt，不进数据库、不同步。
// ---------------------------------------------------------------------------

/// 默认服务器地址：显式传入 SYNC_BASE_URL 时优先使用；未传入时 iOS 默认连本机 127.0.0.1:8000，其余平台默认 10.0.2.2:8000。
String get defaultServerUrl {
  const fromEnv = String.fromEnvironment('SYNC_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (Platform.isIOS) return 'http://127.0.0.1:8000';
  return syncBaseUrl;
}

class ServerUrlController extends StateNotifier<String> {
  ServerUrlController({String? initial, Future<File> Function()? file})
      : _file = file,
        super(initial ?? defaultServerUrl) {
    _load();
  }
  final Future<File> Function()? _file;

  Future<File> _target() async {
    if (_file != null) return _file();
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'server_url.txt'));
  }

  Future<void> _load() async {
    try {
      final f = await _target();
      if (f.existsSync()) {
        final v = f.readAsStringSync().trim();
        if (v.isNotEmpty && mounted) state = v;
      }
    } catch (_) {}
  }

  /// 规范化：补 http://、去掉末尾斜杠。返回保存后的地址。
  static String normalize(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return v;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'http://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  Future<String> set(String raw) async {
    final v = normalize(raw);
    if (v.isEmpty) return state;
    state = v;
    try {
      (await _target()).writeAsStringSync(v);
    } catch (_) {}
    return v;
  }
}

final serverUrlProvider = StateNotifierProvider<ServerUrlController, String>((ref) => ServerUrlController());

final syncApiProvider = Provider<SyncApi>((ref) => DioSyncApi(baseUrl: ref.watch(serverUrlProvider)));

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

// ---------------------------------------------------------------------------
// 在线模式：AI 助理训犬师（2026-11-18）
// ---------------------------------------------------------------------------

/// 构建参数 AI_ONLINE=true 时默认在线；否则默认离线（内容库直出、零网络）。
const aiOnlineByDefault = bool.fromEnvironment('AI_ONLINE', defaultValue: false);

/// 离线 / 在线开关，用户在 AI 教练页切换，存在本机文件（不进数据库、不同步）。
class AiOnlineController extends StateNotifier<bool> {
  AiOnlineController({bool initial = aiOnlineByDefault, Future<File> Function()? file})
      : _file = file,
        super(initial) {
    _load();
  }
  final Future<File> Function()? _file;

  Future<File> _target() async {
    if (_file != null) return _file();
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'ai_mode.txt'));
  }

  Future<void> _load() async {
    try {
      final f = await _target();
      if (f.existsSync()) {
        final v = f.readAsStringSync().trim();
        if (mounted) state = v == 'online';
      }
    } catch (_) {
      // 测试环境没有文档目录：保持默认
    }
  }

  Future<void> set(bool online) async {
    state = online;
    try {
      (await _target()).writeAsStringSync(online ? 'online' : 'offline');
    } catch (_) {}
  }
}

final aiOnlineProvider = StateNotifierProvider<AiOnlineController, bool>((ref) => AiOnlineController());

/// 手机端直连大模型配置（存在本机文件 direct_ai_config.json，不进数据库、不同步）。
class DirectAiConfig {
  const DirectAiConfig({
    this.apiKey = '',
    this.baseUrl = DirectAgentClient.defaultDirectBaseUrl,
    this.model = DirectAgentClient.defaultDirectModel,
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get enabled => apiKey.trim().isNotEmpty;

  Map<String, String> toJson() => {
        'api_key': apiKey,
        'base_url': baseUrl,
        'model': model,
      };

  factory DirectAiConfig.fromJson(Map<String, dynamic> json) => DirectAiConfig(
        apiKey: (json['api_key'] ?? '').toString(),
        baseUrl: (json['base_url'] ?? DirectAgentClient.defaultDirectBaseUrl).toString(),
        model: (json['model'] ?? DirectAgentClient.defaultDirectModel).toString(),
      );
}

class DirectAiConfigController extends StateNotifier<DirectAiConfig> {
  DirectAiConfigController({DirectAiConfig initial = const DirectAiConfig(), Future<File> Function()? file})
      : _file = file,
        super(initial) {
    _load();
  }

  final Future<File> Function()? _file;

  Future<File> _target() async {
    if (_file != null) return _file();
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'direct_ai_config.json'));
  }

  Future<void> _load() async {
    try {
      final f = await _target();
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map<String, dynamic> && mounted) {
          state = DirectAiConfig.fromJson(data);
        }
      }
    } catch (_) {}
  }

  Future<void> save({required String apiKey, required String baseUrl, required String model}) async {
    final next = DirectAiConfig(
      apiKey: apiKey.trim(),
      baseUrl: DirectAgentClient.normalizeBaseUrl(baseUrl),
      model: model.trim().isEmpty ? DirectAgentClient.defaultDirectModel : model.trim(),
    );
    state = next;
    try {
      (await _target()).writeAsStringSync(jsonEncode(next.toJson()));
    } catch (_) {}
  }

  Future<void> clear() => save(apiKey: '', baseUrl: DirectAgentClient.defaultDirectBaseUrl, model: DirectAgentClient.defaultDirectModel);
}

final directAiConfigProvider = StateNotifierProvider<DirectAiConfigController, DirectAiConfig>((ref) => DirectAiConfigController());

/// 在线模式客户端：手机端配置了 API Key 时直连模型，否则走电脑服务端 /v1/agent。
final agentClientProvider = Provider<AgentClient>((ref) {
  final direct = ref.watch(directAiConfigProvider);
  if (direct.enabled) {
    return DirectAgentClient(
      apiKey: direct.apiKey,
      baseUrl: direct.baseUrl,
      model: direct.model,
    );
  }
  return HttpAgentClient(baseUrl: ref.watch(serverUrlProvider));
});

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

/// 引导拍摄用的相机。测试 override 成假相机。
final captureCameraFactoryProvider = Provider<CaptureCameraFactory>((ref) => PluginCaptureCamera.new);

/// 取景自检客户端：与视频分析同一个服务（VIDEO_BASE_URL）。测试 override。
final frameCheckerProvider = Provider<FrameChecker>((ref) => DioFrameChecker(baseUrl: defaultVideoBaseUrl));

/// 实时计时：造一个控制器（真实相机帧之外的全部依赖：服务连接、麦克风）。测试 override 成替身。
/// 阈值 [lateSec] 由页面从内容库读出后传入。
final liveControllerFactoryProvider = Provider<LiveController Function(WidgetRef ref, double lateSec)>(
  (ref) => (ref, lateSec) => LiveController(
        client: WsLiveClient(baseUrl: defaultVideoBaseUrl),
        mic: RecordLiveMic(),
        lateSec: lateSec,
      ),
);

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
