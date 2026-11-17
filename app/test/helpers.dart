/// 测试公用：从仓库根 content/ 直接读内容库（不经 Flutter assets）。
library;

import 'dart:io';

import 'package:puppy_trainer/data/content/content_sources.dart';
import 'package:puppy_trainer/data/content/content_repository.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:drift/native.dart';
import 'package:puppy_trainer/data/db/database.dart';

/// 仓库根 content/ 目录（app/ 的上一级）。
Directory repoContentDir() {
  var dir = Directory.current;
  for (var i = 0; i < 4; i++) {
    final c = Directory('${dir.path}/content');
    if (File('${c.path}/VERSION.md').existsSync()) return c;
    dir = dir.parent;
  }
  throw StateError('找不到仓库根 content/ 目录，当前 ${Directory.current.path}');
}

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

Future<ContentLibrary> loadRepoContent({AppDatabase? db}) async {
  final repo = ContentRepository(
    db: db ?? memoryDb(),
    source: FileContentSource(repoContentDir()),
  );
  return repo.ensureLoaded();
}
