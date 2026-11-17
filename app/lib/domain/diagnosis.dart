/// 问题行为诊断树遍历（AI-3，M3 简报第 7 节）。
///
/// 纯函数，无 IO，不依赖 Flutter，不调模型。输入 issue 与已选路径（每一问选的选项下标），
/// 输出下一题或结果。追问与结果文案全部来自内容库原文。
library;

import 'models.dart';

/// 诊断树最多 4 问（PRD AI-3、docs/content-library.md 第 3 节）。
const maxDiagnosisDepth = 4;

class DiagnosisException implements Exception {
  DiagnosisException(this.message);
  final String message;
  @override
  String toString() => 'DiagnosisException: $message';
}

sealed class DiagnosisStep {
  const DiagnosisStep();
}

/// 还需要回答的一题。
class DiagnosisQuestion extends DiagnosisStep {
  const DiagnosisQuestion({
    required this.nodeIndex,
    required this.node,
    required this.depth,
  });

  /// diagnosis_tree 中的下标。
  final int nodeIndex;
  final DiagnosisNode node;

  /// 第几问（从 1 开始）。
  final int depth;
}

/// 到达结果。
class DiagnosisOutcome extends DiagnosisStep {
  const DiagnosisOutcome({required this.resultKey, required this.solution});
  final String resultKey;
  final Solution solution;
}

/// 已答过的一问（用于展示与入库）。
class DiagnosisAnswer {
  const DiagnosisAnswer({required this.question, required this.option});
  final String question;
  final String option;
}

/// 从根节点（下标 0）按 [path] 走诊断树。
///
/// 抛 [DiagnosisException]：选项下标越界；next 指向不存在的节点；
/// 已到结果仍有多余路径；超过 [maxDiagnosisDepth] 问；result 在 solutions 里找不到。
DiagnosisStep diagnosisNext(Issue issue, List<int> path) {
  if (issue.diagnosisTree.isEmpty) {
    throw DiagnosisException('${issue.id} 没有诊断树');
  }
  var nodeIndex = 0;
  for (var i = 0; i < path.length; i++) {
    final node = issue.diagnosisTree[nodeIndex];
    final choice = path[i];
    if (choice < 0 || choice >= node.options.length) {
      throw DiagnosisException(
          '${issue.id} 第 ${i + 1} 问选项 $choice 越界（共 ${node.options.length} 个）');
    }
    final opt = node.options[choice];
    final result = opt.result;
    if (result != null) {
      if (i != path.length - 1) {
        throw DiagnosisException('${issue.id} 第 ${i + 1} 问已到结果，路径多出 ${path.length - i - 1} 项');
      }
      return DiagnosisOutcome(resultKey: result, solution: solutionOf(issue, result));
    }
    final next = opt.next;
    if (next == null || next < 0 || next >= issue.diagnosisTree.length) {
      throw DiagnosisException('${issue.id} 第 ${i + 1} 问选项 $choice 的 next=$next 越界');
    }
    nodeIndex = next;
  }
  final depth = path.length + 1;
  if (depth > maxDiagnosisDepth) {
    throw DiagnosisException('${issue.id} 超过 $maxDiagnosisDepth 问仍未到结果');
  }
  return DiagnosisQuestion(
    nodeIndex: nodeIndex,
    node: issue.diagnosisTree[nodeIndex],
    depth: depth,
  );
}

/// 按路径还原已答的问题与选项文字（路径必须合法）。
List<DiagnosisAnswer> diagnosisAnswers(Issue issue, List<int> path) {
  final out = <DiagnosisAnswer>[];
  for (var i = 0; i < path.length; i++) {
    final step = diagnosisNext(issue, path.sublist(0, i));
    if (step is! DiagnosisQuestion) {
      throw DiagnosisException('${issue.id} 路径在第 ${i + 1} 问前已结束');
    }
    if (path[i] < 0 || path[i] >= step.node.options.length) {
      throw DiagnosisException('${issue.id} 第 ${i + 1} 问选项 ${path[i]} 越界');
    }
    out.add(DiagnosisAnswer(
      question: step.node.question,
      option: step.node.options[path[i]].text,
    ));
  }
  return out;
}

Solution solutionOf(Issue issue, String resultKey) {
  for (final s in issue.solutions) {
    if (s.key == resultKey) return s;
  }
  throw DiagnosisException('${issue.id} 的 solutions 中没有 $resultKey');
}

/// 枚举诊断树所有到达结果的完整路径（测试与内容校验用）。
List<List<int>> allDiagnosisPaths(Issue issue) {
  final out = <List<int>>[];
  void walk(List<int> path) {
    final step = diagnosisNext(issue, path);
    switch (step) {
      case DiagnosisOutcome():
        out.add(path);
      case DiagnosisQuestion(:final node):
        for (var i = 0; i < node.options.length; i++) {
          walk([...path, i]);
        }
    }
  }

  walk(const []);
  return out;
}
