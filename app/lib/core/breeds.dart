/// 品种列表。这是整个工程里唯一允许硬编码的内容列表（M1 简报第 6 节）。
/// 末尾固定"混种 / 不确定"。
library;

class Breed {
  const Breed(this.id, this.name, {this.aliases = const []});
  final String id;
  final String name;

  /// 用于搜索的别名 / 拼音。
  final List<String> aliases;
}

const String mixedBreedId = 'mixed_or_unknown';

const List<Breed> breeds = [
  Breed('poodle', '贵宾犬', aliases: ['泰迪', 'guibin', 'taidi', 'poodle']),
  Breed('golden_retriever', '金毛寻回犬', aliases: ['金毛', 'jinmao', 'golden']),
  Breed('labrador', '拉布拉多', aliases: ['labuladuo', 'lab', 'labrador']),
  Breed('corgi', '柯基', aliases: ['keji', 'corgi']),
  Breed('shiba', '柴犬', aliases: ['chaiquan', 'shiba']),
  Breed('border_collie', '边境牧羊犬', aliases: ['边牧', 'bianmu', 'border collie']),
  Breed('samoyed', '萨摩耶', aliases: ['samoye', 'samoyed']),
  Breed('husky', '哈士奇', aliases: ['二哈', 'hashiqi', 'husky']),
  Breed('bichon', '比熊', aliases: ['bixiong', 'bichon']),
  Breed('pomeranian', '博美', aliases: ['bomei', 'pomeranian']),
  Breed('french_bulldog', '法国斗牛犬', aliases: ['法斗', 'fadou', 'frenchie']),
  Breed('english_bulldog', '英国斗牛犬', aliases: ['英斗', 'yingdou', 'bulldog']),
  Breed('schnauzer', '雪纳瑞', aliases: ['xuenarui', 'schnauzer']),
  Breed('chihuahua', '吉娃娃', aliases: ['jiwawa', 'chihuahua']),
  Breed('dachshund', '腊肠犬', aliases: ['lachang', 'dachshund']),
  Breed('beagle', '比格', aliases: ['bige', 'beagle']),
  Breed('german_shepherd', '德国牧羊犬', aliases: ['德牧', 'demu', 'german shepherd']),
  Breed('alaskan_malamute', '阿拉斯加雪橇犬', aliases: ['阿拉斯加', 'alasijia', 'malamute']),
  Breed('shih_tzu', '西施犬', aliases: ['xishi', 'shih tzu']),
  Breed('maltese', '马尔济斯', aliases: ['maerjisi', 'maltese']),
  Breed('yorkshire', '约克夏', aliases: ['yuekexia', 'yorkie', 'yorkshire']),
  Breed('pug', '巴哥犬', aliases: ['八哥', 'bage', 'pug']),
  Breed('cocker_spaniel', '可卡犬', aliases: ['keka', 'cocker']),
  Breed('pekingese', '京巴', aliases: ['jingba', 'pekingese']),
  Breed('chinese_rural', '中华田园犬', aliases: ['土狗', 'tianyuan', 'tugou']),
  Breed('doberman', '杜宾', aliases: ['dubin', 'doberman']),
  Breed('rottweiler', '罗威纳', aliases: ['luoweina', 'rottweiler']),
  Breed('australian_shepherd', '澳大利亚牧羊犬', aliases: ['澳牧', 'aomu', 'aussie']),
  Breed('whippet', '惠比特', aliases: ['huibite', 'whippet']),
  Breed('cavalier', '查理王小猎犬', aliases: ['查理王', 'chaliwang', 'cavalier']),
  Breed(mixedBreedId, '混种 / 不确定', aliases: ['混种', 'hunzhong', 'mixed', '不确定', '串串']),
];

/// 搜索：名称、别名包含查询串（不区分大小写）。空查询返回全部。
/// "混种 / 不确定"始终保留在末尾。
List<Breed> searchBreeds(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return breeds;
  final matched = breeds.where((b) {
    if (b.id == mixedBreedId) return false;
    if (b.name.toLowerCase().contains(q)) return true;
    return b.aliases.any((a) => a.toLowerCase().contains(q));
  }).toList();
  matched.add(breeds.last);
  return matched;
}

Breed? breedById(String id) {
  for (final b in breeds) {
    if (b.id == id) return b;
  }
  return null;
}
