/// 实时计时页的模板文案。
///
/// 和 VideoStrings 同一条规矩：页面上除了内容库原文（技能名、common_mistakes）以外，
/// 只能出现这里的固定句式，且只讲"现在发生了什么"，不讲训练方法。
/// "怎么改"由内容库 common_mistakes 的原文承担，页面只负责把它放到对的时刻。
///
/// 单独成文件是为了不改 video_strings.dart（它属于取景自检那一部分）。
/// [LiveStrings.isTemplate] 与 VideoStrings.isTemplate 的作用相同，供原文性测试使用。
library;

import '../../data/video/live_client.dart';

class LiveStrings {
  const LiveStrings._();

  static const entry = '实时计时';
  static const title = '实时计时';
  static const intro = '边练边看：屏幕会实时显示口令、坐下、奖励各发生在第几秒，以及奖励比坐下晚了多久。';
  static const start = '开始';
  static const finish = '结束并查看';
  static const reward = '奖励';
  static const connecting = '正在连接分析服务，首次约几秒…';
  static const retry = '重试';
  static const back = '返回';
  static const finishing = '正在整理结果…';

  // ---- 故障（讲清楚是哪一环，不让人对着空画面干等）
  static const errUnreachable = '连不上视频分析服务。请确认电脑上的服务已启动、手机和电脑在同一网络，并在“我的 → 视频分析服务地址”里填对电脑 IP。';
  static const errPose = '电脑上的视频分析服务没有装好姿态模型，无法实时判断坐下。';
  static const errDisconnected = '和视频分析服务断开了，这一次的计时没有保存。';
  static const errServer = '视频分析服务出错，请重试。';
  static const errCamera = '相机打不开，请检查相机权限后重试。';
  static const errNoPermission = '需要相机权限才能实时计时。可以在系统设置里打开。';

  // ---- 麦克风
  static const micOff = '没有声音输入：口令和奖励请用屏幕上的“奖励”按钮点按记录';
  static const micDenied = '没有麦克风权限：奖励请用屏幕上的“奖励”按钮点按记录';
  static const micQuiet = '麦克风没有收到声音';

  // ---- 状态
  static const dogSit = '狗：坐着';
  static const dogStand = '狗：站着';
  static const dogUnknown = '狗：还没看清';
  static const waitingCue = '等口令';
  static const waitingDog = '口令已发出，等狗坐下';
  static const waitingReward = '狗已坐下，等奖励';

  // ---- 当场提示：服务端只给代码，文字在这里
  static const hintRewardDue = '该奖励了';
  static const hintRewardLate = '奖励晚了';
  static String hintCueRepeated(int n) => '口令说了 $n 次';

  static String? hintFor(String? code, {int cueCount = 0}) => switch (code) {
        'reward_due' => hintRewardDue,
        'reward_late' => hintRewardLate,
        'cue_repeated' => hintCueRepeated(cueCount),
        _ => null,
      };

  // ---- 轮次卡片：只代入数字
  static String sec(num v) {
    final s = v.toDouble().toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String trialTitle(int n) => '第 $n 轮';
  static String cueAt(List<double> times) => '口令 ${times.map((t) => '${sec(t)} 秒').join('、')}';
  static String sitAt(double t) => '坐下 ${sec(t)} 秒';
  static String rewardAt(double t) => '奖励 ${sec(t)} 秒';
  static String delay(double d) => '奖励比坐下晚 ${sec(d)} 秒';
  static String delayRunning(double d) => '已等 ${sec(d)} 秒，还没奖励';
  static String onTime(double d) => '奖励及时，晚 ${sec(d)} 秒';
  static const noRewardYet = '还没有奖励';

  static String elapsed(double t) => '${t.floor()} 秒';

  /// 大读数："1.6 s"；还没有可显示的值时是破折号。
  static String bigDelay(double? d) => d == null ? '—' : '${sec(d)} s';

  /// 轮次行：各段用 " · " 连接。页面和测试都走这个函数，原文性检查按同一个格式认。
  static const rowSeparator = ' · ';
  static String trialRow(int n, {required List<double> cues, required double sit, double? reward}) => [
        trialTitle(n),
        if (cues.isNotEmpty) cueAt(cues),
        sitAt(sit),
        if (reward != null) rewardAt(reward) else noRewardYet,
      ].join(rowSeparator);

  /// 一段文字是否属于模板（原文性测试用）。
  static final _patterns = <RegExp>[
    RegExp(r'^口令说了 \d+ 次$'),
    RegExp(r'^第 \d+ 轮$'),
    RegExp(r'^口令 [\d.]+ 秒(、[\d.]+ 秒)*$'),
    RegExp(r'^坐下 [\d.]+ 秒$'),
    RegExp(r'^奖励 [\d.]+ 秒$'),
    RegExp(r'^奖励比坐下晚 [\d.]+ 秒$'),
    RegExp(r'^已等 [\d.]+ 秒，还没奖励$'),
    RegExp(r'^奖励及时，晚 [\d.]+ 秒$'),
    RegExp(r'^\d+ 秒$'),
    RegExp(r'^[\d.]+ s$'), // 大读数
  ];

  static const _fixed = <String>{
    entry, intro, start, finish, reward, connecting, retry, back, finishing,
    errUnreachable, errPose, errDisconnected, errServer, errCamera, errNoPermission,
    micOff, micDenied, micQuiet, dogSit, dogStand, dogUnknown,
    waitingCue, waitingDog, waitingReward, hintRewardDue, hintRewardLate, noRewardYet,
  };

  /// 一段文字是否属于模板。轮次行由 " · " 连接若干段，每一段都必须是模板。
  static bool isTemplate(String text) {
    if (text == '—') return true; // 读数没有值
    if (_fixed.contains(text) || _patterns.any((r) => r.hasMatch(text))) return true;
    if (text.contains(rowSeparator)) {
      return text.split(rowSeparator).every((p) => _fixed.contains(p) || _patterns.any((r) => r.hasMatch(p)));
    }
    return false;
  }
}

/// 服务端快照 → 屏幕上"现在该显示什么状态"。纯函数，不依赖界面。
enum LiveStage { waitingCue, waitingDog, waitingReward, rewarded }

LiveStage stageOf(LiveSnapshot? s) {
  if (s == null) return LiveStage.waitingCue;
  final live = s.liveTrial;
  if (live != null) {
    if (live.rewardT == null && live.sitEnd == null) return LiveStage.waitingReward;
    if (live.rewardT != null) return LiveStage.rewarded;
  }
  if (s.pendingCueT != null) return LiveStage.waitingDog;
  return LiveStage.waitingCue;
}
