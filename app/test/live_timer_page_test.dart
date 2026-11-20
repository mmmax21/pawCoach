// 实时计时页：用假相机、假服务端、假麦克风驱动，不碰平台通道。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/core/providers.dart';
import 'package:puppy_trainer/data/video/capture_camera.dart';
import 'package:puppy_trainer/data/video/frame_convert.dart';
import 'package:puppy_trainer/data/video/live_client.dart';
import 'package:puppy_trainer/data/video/live_controller.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/video/live_strings.dart';
import 'package:puppy_trainer/features/video/live_timer_page.dart';

const mistakeLate = '奖励给得太晚。响片要在屁股碰地的瞬间按，晚 1 秒狗就不知道奖的是什么。';
const mistakeCue = '口令重复喊好几遍。只说一次，狗没反应就回到用手引导，不要加口令。';

Skill sitSkill({bool withChecks = true}) => Skill(
      id: 'sit',
      name: '坐下',
      category: 'basic',
      minAgeWeeks: 8,
      maxAgeWeeks: 52,
      prerequisites: const [],
      difficulty: 1,
      defaultCue: '坐',
      defaultGesture: '手上抬',
      sessionsToMaster: 5,
      scriptParts: 1,
      tutorial: const Tutorial(
        summary: 's',
        steps: [],
        commonMistakes: ['零食抬得太高', mistakeCue, mistakeLate],
        successCriteria: 'c',
      ),
      script: const [],
      miniScript: const [],
      scoringHint: '',
      downgradeTo: null,
      sources: const [],
      videoChecks: withChecks
          ? const [
              VideoCheckMapping(detector: 'late_reward', mistake: 2),
              VideoCheckMapping(detector: 'repeated_cue', mistake: 1),
            ]
          : const [],
    );

class FakeCam implements CaptureCamera {
  FakeCam({this.openError});
  final CaptureCameraException? openError;
  void Function(RawFrame)? onFrame;
  bool disposed = false;
  final calls = <String>[];
  @override
  Future<void> open() async {
    calls.add('open');
    if (openError != null) throw openError!;
  }

  @override
  Widget buildPreview(BuildContext context) => const ColoredBox(key: Key('fake_preview'), color: Color(0xFF223344));
  @override
  double get previewAspectRatio => 9 / 16;
  @override
  int get sensorOrientation => 90;
  @override
  Future<void> startStream(void Function(RawFrame frame) cb) async {
    calls.add('startStream');
    onFrame = cb;
  }

  @override
  Future<void> stopStream() async {
    calls.add('stopStream');
    onFrame = null;
  }

  @override
  Future<void> startRecording() async {}
  @override
  Future<String> stopRecording() async => '';
  @override
  Future<void> dispose() async => disposed = true;
}

class FakeClock extends LiveClock {
  double t = 0;
  @override
  void start() => t = 0;
  @override
  double get now => t;
}

class FakeClient implements LiveClient {
  final ctrl = StreamController<LiveEvent>.broadcast();
  final taps = <double>[];
  final sent = <String>[];
  Object? connectError;
  @override
  Stream<LiveEvent> get events => ctrl.stream;
  @override
  Future<void> connect() async {
    if (connectError != null) throw connectError!;
  }

  @override
  void start({required double lateSec, required bool mic}) => sent.add('start $lateSec');
  @override
  void sendFrame(double t, RgbFrame frame) {}
  @override
  void sendAudio(double t0, Uint8List pcm16le) {}
  @override
  void tap(double t) => taps.add(t);
  @override
  void stop() => sent.add('stop');
  @override
  Future<void> close() async {}
  void emit(LiveEvent e) => ctrl.add(e);
}

class FakeMic implements LiveMic {
  FakeMic({this.error});
  final LiveMicException? error;
  @override
  Future<Stream<Uint8List>> start() async {
    if (error != null) throw error!;
    return const Stream.empty();
  }

  @override
  Future<void> stop() async {}
}

Map<String, Object?> trial({double? delay, double? running, bool late = false, int cues = 1, double sit = 2.0}) => {
      'cue_times': [for (var i = 0; i < cues; i++) 0.8 + i * 0.5],
      'cue_count': cues,
      'sit_start': sit,
      'sit_end': null,
      'reward_t': delay == null ? null : sit + delay,
      'reward_src': delay == null ? null : 'voice',
      'reward_delay': delay,
      'latency': 1.2,
      'waiting_reward': delay == null,
      'running_delay': running,
      'late': late,
      'markers_during_hold': 0,
    };

LiveSnapshot snap({Map<String, Object?>? live, List<Map<String, Object?>>? trials, String? hint, String? dog = 'sit', bool micAlive = true, double t = 3.0, double? pending}) =>
    LiveSnapshot.fromJson({
      't': t,
      'dog_state': dog,
      'dog_box': [0.1, 0.4, 0.9, 0.8],
      'mic_level_db': -30.0,
      'mic_alive': micAlive,
      'trials': trials ?? (live == null ? [] : [live]),
      'pending_cue_t': pending,
      'live_trial': live,
      'late_sec': 1.0,
      'hint': hint,
    });

class Rig {
  Rig({FakeCam? cam, FakeMic? mic, FakeClient? client})
      : cam = cam ?? FakeCam(),
        mic = mic ?? FakeMic(),
        client = client ?? FakeClient();
  final FakeCam cam;
  final FakeMic mic;
  final FakeClient client;
  final clock = FakeClock();
  LiveController? ctl;
  Map<String, dynamic>? finished;
}

Future<Rig> pump(WidgetTester tester, Rig rig, {Skill? skill}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      captureCameraFactoryProvider.overrideWithValue(() => rig.cam),
      liveControllerFactoryProvider.overrideWithValue((ref, late) {
        rig.ctl = LiveController(client: rig.client, mic: rig.mic, lateSec: late, clock: rig.clock);
        return rig.ctl!;
      }),
    ],
    child: MaterialApp(
      home: LiveTimerPage(skill: skill ?? sitSkill(), lateSec: 1.0, onFinished: (r) => rig.finished = r),
    ),
  ));
  // 页面的 _open 是异步链（开相机 → 造控制器 → 连接）：多推几轮让它走完，之后才能发服务端事件
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  return rig;
}

/// 服务端事件经 StreamController 异步投递给控制器，控制器再通知页面重建：发完事件后要推两帧才看得到界面变化。
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> toRunning(WidgetTester tester, Rig rig) async {
  rig.client.emit(const LiveReady());
  await settle(tester);
  await tester.tap(find.byKey(const Key('live_start')));
  await settle(tester);
}

void main() {
  testWidgets('连接中显示提示；服务 ready 后出现"开始"', (tester) async {
    final rig = await pump(tester, Rig());
    expect(find.byKey(const Key('live_connecting')), findsOneWidget);
    expect(find.byKey(const Key('live_start')), findsNothing);
    rig.client.emit(const LiveReady());
    await settle(tester);
    expect(find.byKey(const Key('live_start')), findsOneWidget);
    expect(find.byKey(const Key('fake_preview')), findsOneWidget);
  });

  testWidgets('点开始：相机开图像流，告诉服务端阈值', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    expect(rig.cam.calls, containsAll(['open', 'startStream']));
    expect(rig.client.sent, contains('start 1.0'));
    expect(find.byKey(const Key('live_reward')), findsOneWidget);
  });

  testWidgets('连不上服务：显示具体原因和重试，不停在空画面', (tester) async {
    final client = FakeClient()..connectError = Exception('refused');
    await pump(tester, Rig(client: client));
    expect(find.byKey(const Key('live_error')), findsOneWidget);
    expect(find.text(LiveStrings.errUnreachable), findsOneWidget);
    expect(find.byKey(const Key('live_retry')), findsOneWidget);
  });

  testWidgets('服务端缺姿态模型：明确说是模型没装好', (tester) async {
    final rig = await pump(tester, Rig());
    rig.client.emit(const LiveErrorEvent('pose_unavailable: no deeplabcut'));
    await settle(tester);
    expect(find.text(LiveStrings.errPose), findsOneWidget);
  });

  testWidgets('相机没权限：提示去系统设置，没有重试按钮（重试没用）', (tester) async {
    await pump(tester, Rig(cam: FakeCam(openError: CaptureCameraException('permission'))));
    expect(find.text(LiveStrings.errNoPermission), findsOneWidget);
    expect(find.byKey(const Key('live_retry')), findsNothing);
    expect(find.byKey(const Key('live_back')), findsOneWidget);
  });

  testWidgets('狗坐下后等奖励：读数显示已等多久，超过阈值变红并出现内容库原文', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.clock.t = 2.8; // 与快照时刻一致：本地补算为 0，读数就是服务端给的 0.8
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(running: 0.8), hint: 'reward_due', t: 2.8)));
    await settle(tester);
    expect(find.byKey(const Key('live_stage')), findsOneWidget);
    expect(find.text(LiveStrings.hintRewardDue), findsOneWidget);
    expect(find.byKey(const Key('live_mistake')), findsNothing);

    rig.clock.t = 3.6;
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(running: 1.6, late: true), hint: 'reward_late', t: 3.6)));
    await settle(tester);
    expect(find.text(LiveStrings.hintRewardLate), findsOneWidget);
    // 内容库 common_mistakes 的原文，一字不改
    expect(find.text(mistakeLate), findsOneWidget);
    final delay = tester.widget<Text>(find.byKey(const Key('live_delay')));
    expect(delay.data, '1.6 s');
    expect(delay.style!.color, Colors.redAccent);
  });

  testWidgets('狗坐着不动、没有新快照时，读数靠本地时钟继续走', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.clock.t = 2.8;
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(running: 0.8), t: 2.8)));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('live_delay'))).data, '0.8 s');
    rig.clock.t = 4.3; // 1.5 秒后，服务端没有再发新快照
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<Text>(find.byKey(const Key('live_delay'))).data, '2.3 s');
  });

  testWidgets('奖励及时：读数定格为绿色，不出现常见错误', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(delay: 0.2), t: 2.4)));
    await settle(tester);
    final delay = tester.widget<Text>(find.byKey(const Key('live_delay')));
    expect(delay.data, '0.2 s');
    expect(delay.style!.color, Colors.greenAccent);
    expect(find.byKey(const Key('live_mistake')), findsNothing);
    expect(find.text(LiveStrings.onTime(0.2)), findsOneWidget);
  });

  testWidgets('奖励晚了的一轮定格为红色并显示晚了多久', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(delay: 2.3, late: true), t: 4.5)));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('live_delay'))).data, '2.3 s');
    expect(find.text(LiveStrings.delay(2.3)), findsOneWidget);
    expect(find.text(mistakeLate), findsOneWidget);
  });

  testWidgets('口令重复：显示次数提示和内容库里重复口令那一条原文', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(delay: 0.2, cues: 2), hint: 'cue_repeated', t: 2.5)));
    await settle(tester);
    expect(find.text('口令说了 2 次'), findsOneWidget);
    expect(find.text(mistakeCue), findsOneWidget);
  });

  testWidgets('点"奖励"：用会话时钟打点', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.clock.t = 3.4;
    await tester.tap(find.byKey(const Key('live_reward')));
    expect(rig.client.taps, [3.4]);
  });

  testWidgets('没有麦克风权限：醒目提示改用"奖励"按钮，练习不中断', (tester) async {
    final rig = await pump(tester, Rig(mic: FakeMic(error: LiveMicException('permission'))));
    await toRunning(tester, rig);
    expect(find.text(LiveStrings.micDenied), findsOneWidget);
    expect(find.byKey(const Key('live_reward')), findsOneWidget);
    expect(rig.ctl!.phase, LivePhase.running);
  });

  testWidgets('服务端说麦克风没收到声音：提示出现', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.client.emit(LiveSnapshotEvent(snap(micAlive: false)));
    await settle(tester);
    expect(find.text(LiveStrings.micQuiet), findsOneWidget);
  });

  testWidgets('练习中连接断开：明确告诉"这一次没有保存"，不停在旧画面', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.client.emit(LiveSnapshotEvent(snap(live: trial(running: 0.5))));
    await settle(tester);
    rig.client.emit(const LiveClosedEvent());
    await settle(tester);
    expect(find.text(LiveStrings.errDisconnected), findsOneWidget);
    expect(find.byKey(const Key('live_delay')), findsNothing);
  });

  testWidgets('结束：停图像流、发 stop，拿到结果后交给调用方', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    await tester.tap(find.byKey(const Key('live_finish')));
    // 结束要依次等相机停流、麦克风停止，都是真实的异步，不是靠 pump 推进的计时器
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await settle(tester);
    expect(rig.cam.calls, contains('stopStream'));
    expect(rig.client.sent.last, 'stop');
    expect(find.text(LiveStrings.finishing), findsOneWidget);
    rig.client.emit(const LiveResultEvent({'trials': [], 'duration': 5.0}));
    await settle(tester);
    expect(rig.finished, {'trials': [], 'duration': 5.0});
  });

  testWidgets('最近三轮：口令、坐下、奖励时刻只显示数字模板', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    rig.client.emit(LiveSnapshotEvent(snap(trials: [
      trial(delay: 0.2, sit: 2.0),
      trial(delay: 2.1, late: true, sit: 10.5),
      trial(delay: 0.3, sit: 18.0),
      trial(running: 0.4, sit: 26.0),
    ], live: trial(running: 0.4, sit: 26.0))));
    await settle(tester);
    final rows = find.descendant(of: find.byKey(const Key('live_trials')), matching: find.byType(Text));
    expect(rows, findsNWidgets(3)); // 只留最近 3 轮
    final texts = [for (final e in tester.widgetList<Text>(rows)) e.data!];
    expect(texts.first.startsWith('第 2 轮'), true);
    expect(texts.last, contains('还没有奖励'));
  });

  testWidgets('原文性：页面上每一段文字不是模板就是内容库原文', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    final seen = <String>{};
    void collect() {
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (t.data != null) seen.add(t.data!);
      }
    }

    final states = [
      snap(),
      snap(pending: 1.0, dog: 'stand'),
      snap(live: trial(running: 0.9), hint: 'reward_due'),
      snap(live: trial(running: 1.8, late: true), hint: 'reward_late'),
      snap(live: trial(delay: 0.2)),
      snap(live: trial(delay: 2.3, late: true)),
      snap(live: trial(delay: 0.2, cues: 3), hint: 'cue_repeated'),
    ];
    for (final s in states) {
      rig.client.emit(LiveSnapshotEvent(s));
      await settle(tester);
      collect();
    }
    final allowed = {'坐下', mistakeLate, mistakeCue};
    final bad = seen.where((t) => !LiveStrings.isTemplate(t) && !allowed.contains(t)).toList();
    expect(bad, isEmpty, reason: '出现了既不是模板也不是内容库原文的文字：$bad');
  });

  testWidgets('页面关闭时释放相机和控制器', (tester) async {
    final rig = await pump(tester, Rig());
    await toRunning(tester, rig);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(rig.cam.disposed, true);
  });

  group('纯函数', () {
    test('lateRewardMistakeText 只取映射指向的那一条原文', () {
      expect(lateRewardMistakeText(sitSkill()), mistakeLate);
      expect(repeatedCueMistakeText(sitSkill()), mistakeCue);
      expect(lateRewardMistakeText(sitSkill(withChecks: false)), isNull);
    });

    test('映射下标越界时返回 null，不崩', () {
      final s = Skill(
        id: 'x', name: 'x', category: 'c', minAgeWeeks: 0, maxAgeWeeks: 1, prerequisites: const [], difficulty: 1,
        defaultCue: '', defaultGesture: '', sessionsToMaster: 1, scriptParts: 1,
        tutorial: const Tutorial(summary: '', steps: [], commonMistakes: ['只有一条'], successCriteria: ''),
        script: const [], miniScript: const [], scoringHint: '', downgradeTo: null, sources: const [],
        videoChecks: const [VideoCheckMapping(detector: 'late_reward', mistake: 5)],
      );
      expect(lateRewardMistakeText(s), isNull);
    });

    test('阈值取内容库的 late_reward.threshold_sec；没配置返回 null，不退回写死的数', () {
      final cfg = VideoChecksConfig(
        minReliableTrials: 2,
        retakeUnclearRatio: 0.5,
        markerWords: const [],
        releaseWords: const [],
        correctionWords: const [],
        detectors: {
          'late_reward': const VideoDetectorRule(id: 'late_reward', name: '奖励太晚', params: {'threshold_sec': 1.5, 'min_ratio': 0.3}),
        },
      );
      expect(lateThresholdOf(cfg), 1.5);
      expect(lateThresholdOf(null), isNull);
      expect(lateThresholdOf(VideoChecksConfig(minReliableTrials: 2, retakeUnclearRatio: 0.5, markerWords: const [], releaseWords: const [], correctionWords: const [], detectors: const {})), isNull);
    });

    test('stageOf：四个阶段', () {
      expect(stageOf(null), LiveStage.waitingCue);
      expect(stageOf(snap()), LiveStage.waitingCue);
      expect(stageOf(snap(pending: 1.0, dog: 'stand')), LiveStage.waitingDog);
      expect(stageOf(snap(live: trial(running: 0.5))), LiveStage.waitingReward);
      expect(stageOf(snap(live: trial(delay: 0.2))), LiveStage.rewarded);
    });

    test('hintFor 只翻译服务端代码，未知代码不显示', () {
      expect(LiveStrings.hintFor('reward_late'), '奖励晚了');
      expect(LiveStrings.hintFor('cue_repeated', cueCount: 3), '口令说了 3 次');
      expect(LiveStrings.hintFor('something_new'), isNull);
      expect(LiveStrings.hintFor(null), isNull);
    });
  });
}
