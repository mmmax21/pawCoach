import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/ai_coach/chat_page.dart';
import 'features/ai_coach/coach_home_page.dart';
import 'features/ai_coach/diagnosis_page.dart';
import 'features/dog_profile/dog_profile_page.dart';
import 'features/settings/reminder_page.dart';
import 'features/home/home_page.dart';
import 'features/home/skill_detail_page.dart';
import 'features/video/video_check_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/onboarding/plan_preview_page.dart';
import 'features/record/record_page.dart';
import 'features/report/report_page.dart';
import 'features/training/training_page.dart';
import 'data/repositories/session_repository.dart';
import 'features/join/join_page.dart';
import 'features/me/badge_wall_page.dart';
import 'features/me/cue_editor_page.dart';
import 'features/me/family_page.dart';
import 'features/me/me_page.dart';
import 'features/records/records_page.dart';
import 'features/shell/app_effects.dart';
import 'features/shell/badge_celebration.dart';
import 'features/shell/removed_notice.dart';
import 'features/skill_tree/skill_tree_page.dart';

/// 根导航 key：徽章祝贺弹窗、通知点击等不在页面树里的入口用它拿 context。
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // M4：5 Tab 与"我的"、加入家庭
      GoRoute(path: '/skills', builder: (_, __) => const SkillTreePage()),
      GoRoute(
        path: '/records',
        builder: (_, s) => RecordsPage(
            initialTab: switch (s.uri.queryParameters['tab']) {
          'reports' => 1,
          'care' => 2,
          _ => 0
        }),
      ),
      GoRoute(path: '/me', builder: (_, __) => const MePage()),
      GoRoute(path: '/me/cues', builder: (_, __) => const CueEditorPage()),
      GoRoute(path: '/me/family', builder: (_, __) => const FamilyPage()),
      GoRoute(path: '/me/badges', builder: (_, __) => const BadgeWallPage()),
      GoRoute(path: '/join', builder: (_, __) => const JoinPage()),
      GoRoute(path: '/', builder: (_, __) => const _Gate()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(
        path: '/plan-preview/:planId',
        builder: (_, s) => PlanPreviewPage(planId: s.pathParameters['planId']!),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(path: '/dog-profile', builder: (_, __) => const DogProfilePage()),
      GoRoute(
        path: '/report/:id',
        builder: (_, s) => ReportPage(reportId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/training/:skillId/:part',
        builder: (_, s) => TrainingPage(
          skillId: s.pathParameters['skillId']!,
          part: int.parse(s.pathParameters['part']!),
        ),
      ),
      GoRoute(
        path: '/record',
        builder: (_, s) => RecordPage(draft: s.extra as SessionDraft?),
      ),
      GoRoute(path: '/coach', builder: (_, __) => const CoachHomePage()),
      GoRoute(
        path: '/coach/chat',
        builder: (_, s) => ChatPage(
          skillId: s.uri.queryParameters['skill'],
          issueId: s.uri.queryParameters['issue'],
          conversationId: s.uri.queryParameters['conv'],
          step: int.tryParse(s.uri.queryParameters['step'] ?? ''),
          part: int.tryParse(s.uri.queryParameters['part'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/coach/diagnosis',
        builder: (_, s) =>
            DiagnosisPage(initialIssueId: s.uri.queryParameters['issue']),
      ),
      GoRoute(
          path: '/settings/reminder', builder: (_, __) => const ReminderPage()),
      GoRoute(
        path: '/skill/:skillId',
        builder: (_, s) => SkillDetailPage(
          skillId: s.pathParameters['skillId']!,
          part: int.tryParse(s.uri.queryParameters['part'] ?? ''),
        ),
      ),
      // M5（AI-4）：视频纠错与历史结果
      GoRoute(
        path: '/skill/:skillId/video',
        builder: (_, s) => VideoCheckPage(skillId: s.pathParameters['skillId']!),
      ),
      GoRoute(
        path: '/skill/:skillId/video/:analysisId',
        builder: (_, s) => VideoHistoryResultPage(
          skillId: s.pathParameters['skillId']!,
          analysisId: s.pathParameters['analysisId']!,
        ),
      ),
    ],
  );
});

class PuppyTrainerApp extends ConsumerStatefulWidget {
  const PuppyTrainerApp({super.key});

  @override
  ConsumerState<PuppyTrainerApp> createState() => _PuppyTrainerAppState();
}

class _PuppyTrainerAppState extends ConsumerState<PuppyTrainerApp> {
  @override
  void initState() {
    super.initState();
    _bootReminder();
    _bootSync();
  }

  /// M4：同步调度（写后推、前台每 5 秒拉、回前台立即拉）与本地副作用（徽章、养护）。
  /// 只在手机上开启（appEffectsEnabledProvider），失败不影响启动、离线照常建档打卡。
  Future<void> _bootSync() async {
    if (!ref.read(appEffectsEnabledProvider)) return;
    try {
      await ref.read(contentLibraryProvider.future);
      ref.read(appEffectsProvider).start();
      ref.read(syncSchedulerProvider).start();
    } catch (e) {
      debugPrint('同步初始化失败：$e');
    }
  }

  /// ST-7：初始化本地通知（点通知打开首页），按当前设置与今天的打卡情况重新调度。
  /// 失败不影响启动。
  Future<void> _bootReminder() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await ref
          .read(reminderNotifierProvider)
          .init(onTap: () => onReminderNotificationTap(ref));
      await ref.read(contentLibraryProvider.future);
      final dog = await ref.read(dogRepositoryProvider).currentDog();
      if (dog != null) await ref.read(reminderServiceProvider).refresh(dog.id);
    } catch (e) {
      debugPrint('提醒初始化失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '幼犬训练',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => RemovedNoticeHost(
        navigatorKey: rootNavigatorKey,
        router: ref.read(routerProvider),
        child: BadgeCelebrationHost(
          navigatorKey: rootNavigatorKey,
          currentPath: () => ref
              .read(routerProvider)
              .routerDelegate
              .currentConfiguration
              .uri
              .path,
          routeChanges: ref.read(routerProvider).routerDelegate,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// 点每日提醒通知 → 打开首页。可测性入口（M4 简报第 11 节）：集成测试直接调用，
/// 与通知点击走同一代码路径。
void onReminderNotificationTap(WidgetRef ref) =>
    ref.read(routerProvider).go('/home');

/// 启动门：加载内容库 → 有狗进首页，没狗进建档。
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentLibraryProvider);
    final dog = ref.watch(currentDogProvider);

    return content.when(
      loading: () => const _Loading('正在加载内容库…'),
      error: (e, st) => _Error('内容库加载失败', '$e'),
      data: (_) => dog.when(
        loading: () => const _Loading('正在读取档案…'),
        error: (e, st) => _Error('数据库读取失败', '$e'),
        data: (d) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.go(d == null ? '/onboarding' : '/home');
          });
          return const _Loading('');
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(text),
              ],
            ],
          ),
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error(this.title, this.detail);
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(detail),
            ],
          ),
        ),
      );
}
