/// 狗的状态（身体信号）页面的模板文案。
///
/// 只有字段标签、按钮、等待与错误提示、计数句式；信号名称、含义与所有训练建议都取自内容库 body_signals.yaml 原文。
library;

import '../../domain/body_signals.dart';

class BodyStrings {
  const BodyStrings._();

  static const entry = '练前看看狗的状态';
  static const comingSoon = '敬请期待';
  static const comingSoonEntry = '$entry（$comingSoon）';
  static const pageTitle = '狗的状态';
  static const intro = '拍 5–15 秒狗平时的样子，或选一张照片，看看狗现在适不适合练。尽量拍到狗的全身，侧面最清楚。';
  static const recordVideo = '拍一段视频（推荐）';
  static const galleryVideo = '从相册选视频';
  static const photo = '选一张照片';
  static const analyzing = '正在看狗的状态…';
  static const errUnreachable = '连不上视频分析服务。请确认电脑上的服务已启动、手机和电脑在同一网络，并在“我的 → 视频分析服务地址”里填对电脑 IP。';
  static const errBusy = '服务正忙，请过几秒再试。';
  static const errFailed = '分析失败，请重试。';
  static const retry = '再看一次';
  static const startTraining = '开始今天的练习';
  static const observed = '观察到的信号';
  static const noSignals = '没有观察到明显的信号';
  static const disclaimer = '只根据看得到的身体姿势和动作判断，仅供参考，不代表狗的真实感受。';
  static const photoNote = '照片只能看静态姿势；摇尾巴、喘气、动个不停需要拍视频。';
  static const sources = '依据';
  static const pacingTitle = '训练节奏建议';
  static const stopTitle = '该停一停了';
  static const referralTitle = '建议咨询专业训犬师';
  static const videoTitle = '狗的状态';
  static const weeklyTitle = '狗的状态（练前检查）';
  static const history = '最近的状态检查';

  static String doFirst(String skillName) => '先做「$skillName」';
  static String stateName(BodyState s) => switch (s) {
        BodyState.calm => '平静',
        BodyState.excited => '兴奋',
        BodyState.stressed => '有压力信号',
        BodyState.unclear => '看不清',
      };
  static String signalCount(String name, int n) => '$name · $n 次';
  static String weeklyLine(BodyState s, int n) => '${stateName(s)} $n 次';
  static String stopWindow(num start, num window, int n) =>
      '从第 ${_sec(start)} 秒开始的 ${_sec(window)} 秒里出现了 $n 次压力信号';
  static String historyDate(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.month} 月 ${l.day} 日 ${two(l.hour)}:${two(l.minute)}';
  }

  static String _sec(num v) {
    final s = v.toDouble().toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}
