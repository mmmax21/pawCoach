/// AI-5 主动干预（M4 批次 B）。纯函数，无 IO，不依赖 Flutter。
///
/// 两种触发：
/// 1. 同一技能最近 2 次正式脚本记录都是"没做到"（家庭内任一成员）→ 标题为固定模板
///    [tplDowngradeGuide]，正文为降级技能名 + 其 tutorial.summary（内容库原文）；
///    没有降级技能时正文为固定模板 [nudgeNoDowngradeBody]。
/// 2. 家庭连续 3 天无打卡 → 标题 / 正文为固定模板，正文末尾接今日保底任务的技能名。
/// 除技能名与 summary 原文外，只出现本文件里的固定模板句。
library;

import 'answer_composer.dart' show tplDowngradeGuide;
import 'models.dart';

const nudgeNoDowngradeBody = '去 AI 教练看看这个技能的常见错误。';
const nudgeRestartTitle = '已经 3 天没练了';
const nudgeRestartBody = '今天做一次保底任务就算打卡：';

/// 全部固定模板（测试用来核对正文只由模板 + 内容库原文组成）。
const nudgeTemplates = {tplDowngradeGuide, nudgeNoDowngradeBody, nudgeRestartTitle, nudgeRestartBody};

/// 通知 ID：3000 为"连续 3 天无打卡"，3001–3099 为降级建议（按技能在内容库中的顺序）。
/// 与每日提醒 1001–1014、养护 2000–2999 不冲突。
const nudgeRestartId = 3000;
const nudgeDowngradeIdBase = 3001;
const nudgeIdMax = 3099;

/// 连续 N 天无打卡后提醒；第 N+1 天的这个时刻推送。
const nudgeIdleDays = 3;
const nudgeRestartHour = 10;

class NudgeSession {
  const NudgeSession({required this.skillId, required this.scriptPart, required this.score, required this.startedAt});
  final String skillId;
  final int scriptPart;
  final Score? score;
  final DateTime startedAt;
}

class Nudge {
  const Nudge({required this.key, required this.id, required this.title, required this.body, this.at});

  /// 去重键：同一触发事实只推一次。
  final String key;
  final int id;
  final String title;
  final String body;

  /// 预排时刻（本地）；null 表示立即。
  final DateTime? at;

  @override
  String toString() => 'Nudge($key, $id, $at)';
}

/// 规则 1：降级建议。每个技能只看最近 2 次正式脚本记录（保底任务不计）。
List<Nudge> downgradeNudges({required List<NudgeSession> sessions, required List<Skill> skills}) {
  final bySkill = <String, List<NudgeSession>>{};
  for (final s in sessions) {
    if (s.scriptPart == miniScriptPart) continue;
    bySkill.putIfAbsent(s.skillId, () => []).add(s);
  }
  final byId = {for (final s in skills) s.id: s};
  final out = <Nudge>[];
  for (var i = 0; i < skills.length; i++) {
    final skill = skills[i];
    final list = bySkill[skill.id];
    if (list == null || list.length < 2) continue;
    list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final last2 = list.sublist(list.length - 2);
    if (!last2.every((s) => s.score == Score.none)) continue;
    final down = skill.downgradeTo == null ? null : byId[skill.downgradeTo];
    out.add(Nudge(
      key: 'downgrade:${skill.id}:${last2.last.startedAt.toUtc().toIso8601String()}',
      id: (nudgeDowngradeIdBase + i).clamp(nudgeDowngradeIdBase, nudgeIdMax),
      title: tplDowngradeGuide,
      body: down == null ? nudgeNoDowngradeBody : '${down.name}：${down.tutorial.summary}',
    ));
  }
  return out;
}

/// 规则 2：家庭连续 3 天无打卡。[lastActiveDay] 为最近一次打卡的本地日期（从未打卡用建档日）。
/// 返回推送时刻：最近打卡日 + 4 天的 10:00（即整整 3 天没练之后）。已过则为 [now] 之后一分钟。
Nudge restartNudge({
  required DateTime lastActiveDay,
  required DateTime now,
  required String? miniSkillName,
}) {
  final d = DateTime(lastActiveDay.year, lastActiveDay.month, lastActiveDay.day);
  var at = DateTime(d.year, d.month, d.day + nudgeIdleDays + 1, nudgeRestartHour);
  if (!at.isAfter(now)) at = now.add(const Duration(minutes: 1));
  return Nudge(
    key: 'restart:${d.year}-${d.month}-${d.day}',
    id: nudgeRestartId,
    title: nudgeRestartTitle,
    body: miniSkillName == null ? nudgeRestartBody.replaceAll('：', '。') : '$nudgeRestartBody$miniSkillName',
    at: at,
  );
}
