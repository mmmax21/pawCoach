/// "加入本周 / 下周"弹窗里的打基础说明与解锁条件（M4 简报第 9 节，2026-11-17 修订）。
/// 句式模板在这里，技能名一律取内容库（[name]）。纯函数，便于单测。
library;

import '../../domain/plan_generator.dart';

/// 每个"前置未满足"的方案技能输出两行：
/// - 打基础：新加入的写"先练 P，为 S 打基础"；原本就在计划里的写
///   "本周计划里的 P1、P2 正是在为 S 打基础，先把它们练好"；
/// - 解锁条件："S：掌握 P1、P2 后解锁"（周龄未到时加"，且满 N 周龄"）。
List<({String key, String text})> foundationLines(
  DiagnosisWeekAddition r,
  String Function(String id) name, {
  bool nextWeek = false,
}) {
  final week = nextWeek ? '下周计划' : '本周计划';
  final out = <({String key, String text})>[];
  for (final f in r.foundations) {
    final s = name(f.target);
    if (f.newlyAdded.isNotEmpty) {
      out.add((key: 'diagnosis_foundation_${f.target}', text: '先练${f.newlyAdded.map(name).join('、')}，为$s打基础'));
    }
    if (f.alreadyInPlan.isNotEmpty) {
      out.add((
        key: 'diagnosis_foundation_existing_${f.target}',
        text: '$week里的${f.alreadyInPlan.map(name).join('、')}正是在为$s打基础，先把它们练好',
      ));
    }
    final conds = <String>[
      if (f.unlockPrerequisites.isNotEmpty) '掌握${f.unlockPrerequisites.map(name).join('、')}',
      if (f.unlockAgeWeeks != null) '满 ${f.unlockAgeWeeks} 周龄',
    ];
    if (conds.isNotEmpty) {
      out.add((key: 'diagnosis_unlock_${f.target}', text: '$s：${conds.join('，且')}后解锁'));
    }
  }
  return out;
}
