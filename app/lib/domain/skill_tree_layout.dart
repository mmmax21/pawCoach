/// 技能树可视化布局（ST-3，M4 批次 B）。纯函数，无 IO，不依赖 Flutter。
///
/// 结构完全来自内容库 prerequisites，不写死技能或坐标：
/// - 列 = 该技能到根的最长前置链长度（无前置的在第 0 列）；
/// - 列内顺序用重心法（按前置 / 后继在相邻列中的平均位置）往返排序几轮，减少连线交叉；
///   没有前置也没有后继的孤立技能排在各自列的最后；
/// - 坐标为 0–1 的相对值，由界面按可用宽高缩放。
library;

import 'models.dart';

class TreeNodePos {
  const TreeNodePos({required this.skillId, required this.column, required this.row, required this.x, required this.y});
  final String skillId;
  final int column;

  /// 列内序号（从 0 开始）。
  final int row;

  /// 节点中心的相对坐标（0–1）。
  final double x;
  final double y;
}

class TreeEdge {
  const TreeEdge({required this.from, required this.to});

  /// 前置技能。
  final String from;
  final String to;
}

class SkillTreeLayout {
  const SkillTreeLayout({required this.nodes, required this.edges, required this.columns, required this.maxRows});
  final Map<String, TreeNodePos> nodes;
  final List<TreeEdge> edges;
  final int columns;

  /// 最多的一列有几个节点（界面据此决定节点高度）。
  final int maxRows;
}

SkillTreeLayout layoutSkillTree(List<Skill> skills, {int sweeps = 4}) {
  final byId = {for (final s in skills) s.id: s};
  final depth = <String, int>{};
  int depthOf(String id, Set<String> stack) {
    final cached = depth[id];
    if (cached != null) return cached;
    if (!stack.add(id)) return 0; // 内容库若出现环，按 0 处理，不死循环
    final s = byId[id];
    var d = 0;
    for (final p in s?.prerequisites ?? const <String>[]) {
      if (!byId.containsKey(p)) continue;
      final pd = depthOf(p, stack) + 1;
      if (pd > d) d = pd;
    }
    stack.remove(id);
    return depth[id] = d;
  }

  for (final s in skills) {
    depthOf(s.id, {});
  }
  final edges = [
    for (final s in skills)
      for (final p in s.prerequisites)
        if (byId.containsKey(p)) TreeEdge(from: p, to: s.id),
  ];
  final children = <String, List<String>>{};
  final parents = <String, List<String>>{};
  for (final e in edges) {
    children.putIfAbsent(e.from, () => []).add(e.to);
    parents.putIfAbsent(e.to, () => []).add(e.from);
  }
  final columns = skills.isEmpty ? 0 : depth.values.reduce((a, b) => a > b ? a : b) + 1;
  final cols = List.generate(columns, (_) => <String>[]);
  // 初始顺序：难度、最低周龄、id（稳定）
  final initial = [...skills]..sort((a, b) {
      if (a.difficulty != b.difficulty) return a.difficulty - b.difficulty;
      if (a.minAgeWeeks != b.minAgeWeeks) return a.minAgeWeeks - b.minAgeWeeks;
      return a.id.compareTo(b.id);
    });
  for (final s in initial) {
    cols[depth[s.id]!].add(s.id);
  }

  bool isolated(String id) => (children[id] ?? const []).isEmpty && (parents[id] ?? const []).isEmpty;

  void sortBy(List<String> col, Map<String, double> pos, List<String> Function(String) neighbors) {
    final key = <String, double>{};
    for (var i = 0; i < col.length; i++) {
      final ns = neighbors(col[i]).where(pos.containsKey).toList();
      key[col[i]] = isolated(col[i])
          ? 1e9 + i
          : ns.isEmpty
              ? i.toDouble()
              : ns.map((n) => pos[n]!).reduce((a, b) => a + b) / ns.length;
    }
    final idx = {for (var i = 0; i < col.length; i++) col[i]: i};
    col.sort((a, b) {
      final c = key[a]!.compareTo(key[b]!);
      return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
    });
  }

  Map<String, double> positions() {
    final m = <String, double>{};
    for (final col in cols) {
      for (var i = 0; i < col.length; i++) {
        m[col[i]] = (i + 0.5) / col.length;
      }
    }
    return m;
  }

  for (var s = 0; s < sweeps; s++) {
    for (var c = 1; c < columns; c++) {
      sortBy(cols[c], positions(), (id) => parents[id] ?? const []);
    }
    for (var c = columns - 2; c >= 0; c--) {
      sortBy(cols[c], positions(), (id) => children[id] ?? const []);
    }
  }

  final maxRows = cols.fold(0, (m, c) => c.length > m ? c.length : m);
  final nodes = <String, TreeNodePos>{};
  for (var c = 0; c < columns; c++) {
    final col = cols[c];
    // 每列在总高度内垂直居中，行距统一按最多那一列算。
    final offset = (maxRows - col.length) / 2;
    for (var r = 0; r < col.length; r++) {
      nodes[col[r]] = TreeNodePos(
        skillId: col[r],
        column: c,
        row: r,
        x: (c + 0.5) / columns,
        y: (offset + r + 0.5) / maxRows,
      );
    }
  }
  return SkillTreeLayout(nodes: nodes, edges: edges, columns: columns, maxRows: maxRows);
}

/// 节点上显示的短名：去掉内容库技能名里的括号补充说明（"户外召回（长绳）"→"户外召回"）。
String skillShortName(String name) {
  final i = name.indexOf('（');
  return (i > 0 ? name.substring(0, i) : name).trim();
}

/// 两条线段（节点中心连线）是否交叉，测试用于统计交叉数。
int countCrossings(SkillTreeLayout l) {
  var n = 0;
  final segs = [for (final e in l.edges) (l.nodes[e.from]!, l.nodes[e.to]!)];
  for (var i = 0; i < segs.length; i++) {
    for (var j = i + 1; j < segs.length; j++) {
      final (a1, a2) = segs[i];
      final (b1, b2) = segs[j];
      if (a1.column != b1.column || a2.column != b2.column) continue;
      if (a1.skillId == b1.skillId || a2.skillId == b2.skillId) continue;
      if ((a1.row - b1.row) * (a2.row - b2.row) < 0) n++;
    }
  }
  return n;
}
