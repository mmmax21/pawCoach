import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/core/breeds.dart';

void main() {
  test('30 个品种，末尾固定混种/不确定', () {
    expect(breeds.length, 31);
    expect(breeds.last.id, mixedBreedId);
    expect(breeds.map((b) => b.id).toSet().length, breeds.length);
  });

  test('搜索：中文、拼音、别名，混种始终在末尾', () {
    expect(searchBreeds('').length, breeds.length);
    final jinmao = searchBreeds('金毛');
    expect(jinmao.first.id, 'golden_retriever');
    expect(jinmao.last.id, mixedBreedId);
    expect(searchBreeds('taidi').first.id, 'poodle');
    expect(searchBreeds('CORGI').first.id, 'corgi');
    final none = searchBreeds('zzzz');
    expect(none.length, 1);
    expect(none.single.id, mixedBreedId);
  });
}
