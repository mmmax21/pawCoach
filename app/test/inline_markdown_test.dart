import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/features/ai_coach/inline_markdown.dart';

String plain(List<TextSpan> s) => s.map((e) => e.text).join();
List<String> bold(List<TextSpan> s) =>
    [for (final e in s) if (e.style?.fontWeight == FontWeight.bold) e.text!];

void main() {
  test('**加粗** 去掉星号并加粗', () {
    final s = inlineMarkdownSpans('先练**响片 / 标记词**，再加**摸摸**。');
    expect(plain(s), '先练响片 / 标记词，再加摸摸。');
    expect(bold(s), ['响片 / 标记词', '摸摸']);
  });

  test('多行与编号列表保留换行', () {
    final s = inlineMarkdownSpans('你可以：\n\n1. **响片 2 分钟**：先约 10 次');
    expect(plain(s), '你可以：\n\n1. 响片 2 分钟：先约 10 次');
  });

  test('行首 # 标题去掉井号并加粗', () {
    final s = inlineMarkdownSpans('## 今天的计划\n正文');
    expect(plain(s), '今天的计划\n正文');
    expect(bold(s), ['今天的计划']);
  });

  test('没配对的 ** 原样保留', () {
    expect(plain(inlineMarkdownSpans('a ** b')), 'a ** b');
  });

  test('普通文字不变', () {
    final s = inlineMarkdownSpans('涉及狗狗健康的问题，请尽快咨询兽医。');
    expect(plain(s), '涉及狗狗健康的问题，请尽快咨询兽医。');
    expect(bold(s), isEmpty);
  });
}
