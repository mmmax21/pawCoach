/// 模型回复里的少量 Markdown（加粗、标题）转成富文本，避免 `**` `#` 原样显示。
///
/// 只处理这两种：`**加粗**` 和行首的 `#` 标题。其余文字原样保留。
/// 没配对的 `**` 按普通文字显示，不会吞掉后面的内容。
library;

import 'package:material_ui/material_ui.dart';

final _bold = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
final _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*)$');

/// 把 [text] 解析成 [TextSpan] 列表。
List<TextSpan> inlineMarkdownSpans(String text) {
  const boldStyle = TextStyle(fontWeight: FontWeight.bold);
  final spans = <TextSpan>[];
  final lines = text.split('\n');
  for (var li = 0; li < lines.length; li++) {
    var line = lines[li];
    var lineBold = false;
    final h = _heading.firstMatch(line);
    if (h != null) {
      line = h.group(1)!;
      lineBold = true;
    }
    var pos = 0;
    for (final m in _bold.allMatches(line)) {
      if (m.start > pos) {
        spans.add(TextSpan(text: line.substring(pos, m.start), style: lineBold ? boldStyle : null));
      }
      spans.add(TextSpan(text: m.group(1), style: boldStyle));
      pos = m.end;
    }
    if (pos < line.length) {
      spans.add(TextSpan(text: line.substring(pos), style: lineBold ? boldStyle : null));
    }
    if (li < lines.length - 1) spans.add(const TextSpan(text: '\n'));
  }
  return spans;
}

/// 可选中的富文本，等价于 `SelectableText(text)`，但会渲染加粗和标题。
class InlineMarkdownText extends StatelessWidget {
  const InlineMarkdownText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      SelectableText.rich(TextSpan(children: inlineMarkdownSpans(text)));
}
