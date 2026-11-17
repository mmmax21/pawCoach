/// 跟练页的界面文案（非训练内容）。
///
/// 集中放在一个文件里，方便审计"Dart 代码里没有技能步骤 / 口令 / 问题行为文案"：
/// 这里只有按钮标签和简报第 5 节明确给出的固定提示语。
library;

class TrainingStrings {
  const TrainingStrings._();

  static const clickerButton = '响片';
  static const clickerPrompt = '狗做对的瞬间按下';
  static const speakNext = '下一步';
  static const pause = '暂停';
  static const resume = '继续';
  static const restart = '重来一次';
  static const skip = '跳过';
  static const next = '下一步';
  static const finish = '完成';
  static const yourCue = '你的口令：';
  static const imagePlaceholder = '图片占位';
  static const quitTitle = '退出这次跟练？';
  static const quitBody = '现在退出会丢弃本次，不计入打卡。';
  static const quitConfirm = '退出并丢弃';
  static const quitCancel = '继续练';
}
