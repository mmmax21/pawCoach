/// 视频纠错页的模板文案（M5 简报 4.6）。
///
/// 允许写在 Dart 里的只有：字段标签、等待与错误提示、重拍提示、无问题提示、安全提示、证据句式。
/// 证据句式只代入数字与时间（verbal_correction 额外代入内容库 correction_words 里的词），
/// 不出现任何训练方法描述。原文性测试用 [VideoStrings.isTemplate] 判断一段文字是否属于模板集合。
library;

import '../../domain/video_checks.dart';

class VideoStrings {
  const VideoStrings._();

  // ---- 字段标签 / 按钮
  static const entry = '上传训练视频纠错';
  static const pageTitle = '视频纠错';
  static const shootingHint = '拍摄要求：从侧面拍到狗全身，视频不超过 120 秒';
  static const pickGallery = '从相册选择';
  static const pickCamera = '现场录制';
  static const safetyCheck = '狗在视频里有咆哮、龇牙、扑咬或明显害怕';
  static const metricsTitle = '本次数据';
  static const latency = '反应快慢（中位数）';
  static const hold = '保持时长（中位数）';
  static const reliable = '可清楚判断的轮次';
  static const findingsTitle = '检测到的问题';
  static const successCriteria = '成功标准';
  static const practice = '按正确方法跟练';
  static const tutorial = '看教程';
  static const reupload = '重新上传';
  static const retry = '重试';
  static const repick = '重新选择视频';
  static const history = '视频纠错记录';
  static const noData = '—';

  // ---- 等待与错误提示
  static const uploading = '正在上传视频…';
  static const analyzing = '正在分析，约一两分钟';
  static const prechecking = '正在检查画面，约十几秒';
  static const realigning = '正在重新判定…';
  static const errUnreachable = '连不上视频分析服务。请确认电脑上的服务已启动，手机和电脑在同一网络。';
  static const errFailed = '分析失败，请重试。';
  static const errTimeout = '分析超过 5 分钟还没有结果，请重试。';
  static const errTooLong = '视频超过 120 秒，请剪短后重新上传。';
  static const errRealign = '重新判定失败，请重试。';

  // ---- 固定模板句（简报 4.3 / 4.4 原句）
  static const retake = '画面里大部分时间看不清狗的姿势，请从侧面拍到狗全身后重拍';

  // ---- 按原因的重拍提示（减少重拍，2026-11-18 起草，待 Fable 确认；只讲拍摄与录音，不含训练方法）
  static const retakeNoDog = '画面里大部分时间没有拍到完整的狗，请把狗全身放进画面后重拍';
  static const retakeAngle = '从这个角度看不出狗是坐着还是站着，请从侧面拍到狗全身后重拍';
  static const retakeNoVoice = '这段视频没有录到说话声，听不到口令和奖励词，请打开声音、离手机近一些后重拍';
  static const retakeCueNotHeard =
      '看到狗坐下了，但没听清口令。可以在下面标出哪几次是听口令坐下的，或者离手机近一些、清楚地说口令后重拍';
  static String retakeTooFew(int n) => '能确认的完整轮次不到 $n 轮，请多练几轮后重拍';

  static String retakeFor(RetakeReason? r, {int minTrials = 2}) => switch (r) {
        RetakeReason.noDog => retakeNoDog,
        RetakeReason.wrongAngle => retakeAngle,
        RetakeReason.noVoice => retakeNoVoice,
        RetakeReason.cueNotHeard => retakeCueNotHeard,
        RetakeReason.tooFewReliable => retakeTooFew(minTrials),
        RetakeReason.tooUnclear || null => retake,
      };

  // ---- 补标口令
  static const confirmTitle = '标出听口令坐下的几次';
  static const confirmNote = '你标出的几轮不计算反应快慢和口令次数';
  static const confirmButton = '确认并重新判定';
  static String sitCandidate(num a, num b) => '第 ${sec(a)}–${sec(b)} 秒 狗坐下';
  static const noFindings = '这段视频里没有发现常见错误';
  static const safetyStop = '视频里出现攻击或恐惧信号时，请先暂停自行训练，咨询兽医或专业训犬师。';

  // ---- 历史列表
  static const historyRetake = '需要重拍';
  static String historyFindings(int n) => '发现 $n 个问题';

  // ---- 带数字的标签
  static String successRate(num target) => '成功率（保持满 ${sec(target)} 秒）';
  static String seconds(num v) => '${sec(v)} 秒';
  static String percent(double v) => '${(v * 100).round()}%';
  static String ratio(int a, int b) => '$a / $b';
  static String practicePart(int part) => '$practice 第 $part 部分';
  static String historyDate(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.month} 月 ${l.day} 日 ${two(l.hour)}:${two(l.minute)}';
  }

  /// 秒数显示：一位小数，整数不带小数点（12.5、3）。
  static String sec(num v) {
    final s = v.toDouble().toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  // ---- 证据句式：只代入数字与时间
  static String evidence(VideoFinding f) {
    final e = f.evidence;
    num n(String k) => e[k] as num;
    switch (f.detector) {
      case 'late_reward':
        return '第 ${sec(n('sit_start'))} 秒坐下，第 ${sec(n('reward_t'))} 秒才奖励，晚了 ${sec(n('delay'))} 秒'
            '（有奖励的 ${n('rewarded')} 轮里 ${n('late')} 轮晚于 ${sec(n('threshold_sec'))} 秒）';
      case 'repeated_cue':
        final times = [
          for (final t in e['cue_times'] as List) '第 ${sec(t as num)} 秒'
        ].join('、');
        return '$times各识别到一次口令，共 ${n('count')} 次后狗才坐下'
            '（${n('trials')} 轮里 ${n('repeated')} 轮口令重复）';
      case 'session_too_long':
        return '这段视频一共练了 ${n('trials')} 轮';
      case 'target_too_long':
        return '目标保持 ${sec(n('target'))} 秒，${n('trials')} 轮里 ${n('reached')} 轮达到';
      case 'reward_after_standup':
        return '第 ${sec(n('sit_end'))} 秒起身，第 ${sec(n('reward_t'))} 秒才奖励'
            '（有奖励的 ${n('rewarded')} 轮里 ${n('after')} 轮在起身后奖励）';
      case 'self_release':
        return '${n('trials')} 轮里 ${n('self')} 轮是狗自己起身结束的';
      case 'no_hold_marker':
        return '保持了 ${sec(n('hold'))} 秒，期间识别到标记词 ${n('markers')} 次'
            '（保持较久的 ${n('long')} 轮里 ${n('silent')} 轮没有标记词）';
      case 'verbal_correction':
        return [
          for (final h in e['hits'] as List)
            '第 ${sec((h as Map)['t'] as num)} 秒识别到「${h['word']}」',
        ].join('，');
    }
    return '';
  }

  /// 所有固定字符串。
  static const fixed = <String>{
    entry,
    pageTitle,
    shootingHint,
    pickGallery,
    pickCamera,
    safetyCheck,
    metricsTitle,
    latency,
    hold,
    reliable,
    findingsTitle,
    successCriteria,
    practice,
    tutorial,
    reupload,
    retry,
    repick,
    history,
    noData,
    uploading,
    analyzing,
    errUnreachable,
    errFailed,
    errTimeout,
    errTooLong,
    retake,
    noFindings,
    safetyStop,
    historyRetake,
    prechecking,
    realigning,
    errRealign,
    retakeNoDog,
    retakeAngle,
    retakeNoVoice,
    retakeCueNotHeard,
    confirmTitle,
    confirmNote,
    confirmButton,
  };

  static const _num = r'\d+(?:\.\d+)?';
  static const _t = '第 $_num 秒';

  /// 带数字的模板：数字位置只能是数字。verbal_correction 的词另由 [isTemplate] 校验来自内容库。
  static final patterns = <RegExp>[
    RegExp('^成功率（保持满 $_num 秒）\$'),
    RegExp('^$_num 秒\$'),
    RegExp(r'^\d+%$'),
    RegExp(r'^\d+ / \d+$'),
    RegExp('^$practice 第 \\d+ 部分\$'),
    RegExp(r'^\d+ 月 \d+ 日 \d\d:\d\d$'),
    RegExp(r'^发现 \d+ 个问题$'),
    RegExp(r'^能确认的完整轮次不到 \d+ 轮，请多练几轮后重拍$'),
    RegExp('^第 $_num–$_num 秒 狗坐下\$'),
    RegExp('^$_t坐下，$_t才奖励，晚了 $_num 秒（有奖励的 \\d+ 轮里 \\d+ 轮晚于 $_num 秒）\$'),
    RegExp('^$_t(?:、$_t)*各识别到一次口令，共 \\d+ 次后狗才坐下（\\d+ 轮里 \\d+ 轮口令重复）\$'),
    RegExp(r'^这段视频一共练了 \d+ 轮$'),
    RegExp('^目标保持 $_num 秒，\\d+ 轮里 \\d+ 轮达到\$'),
    RegExp('^$_t起身，$_t才奖励（有奖励的 \\d+ 轮里 \\d+ 轮在起身后奖励）\$'),
    RegExp(r'^\d+ 轮里 \d+ 轮是狗自己起身结束的$'),
    RegExp('^保持了 $_num 秒，期间识别到标记词 \\d+ 次（保持较久的 \\d+ 轮里 \\d+ 轮没有标记词）\$'),
  ];

  /// verbal_correction 证据：「第 x 秒识别到「词」」，词必须来自内容库 correction_words。
  static bool _isCorrectionEvidence(String text, List<String> correctionWords) {
    final parts = text.split('，');
    final re = RegExp('^$_t识别到「(.+)」\$');
    return parts.every((p) {
      final m = re.firstMatch(p);
      return m != null && correctionWords.contains(m.group(1));
    });
  }

  /// 一段文字是否属于模板集合。
  static bool isTemplate(String text,
          {List<String> correctionWords = const []}) =>
      fixed.contains(text) ||
      patterns.any((r) => r.hasMatch(text)) ||
      _isCorrectionEvidence(text, correctionWords);
}
