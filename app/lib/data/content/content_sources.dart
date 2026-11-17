/// 内容源实现：Flutter assets 与本地文件系统（测试用）。
library;

import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'content_parser.dart';
import 'content_repository.dart';

/// 从 `assets/content/` 读取，清单来自 tool/sync_content.sh 生成的 manifest.yaml。
class AssetContentSource implements ContentSource {
  AssetContentSource({AssetBundle? bundle, this.root = 'assets/content'})
      : _bundle = bundle;

  final AssetBundle? _bundle;
  final String root;

  AssetBundle get bundle => _bundle ?? rootBundle;

  @override
  Future<String> read(String relativePath) =>
      bundle.loadString('$root/$relativePath');

  @override
  Future<({List<String> skills, List<String> issues})> listFiles() async {
    final text = await read('manifest.yaml');
    return parseManifest('manifest.yaml', text);
  }
}

/// 直接读磁盘目录，例如仓库根 `content/`。
class FileContentSource implements ContentSource {
  FileContentSource(this.rootDir);
  final Directory rootDir;

  @override
  Future<String> read(String relativePath) =>
      File('${rootDir.path}/$relativePath').readAsString();

  @override
  Future<({List<String> skills, List<String> issues})> listFiles() async {
    List<String> names(String sub) {
      final d = Directory('${rootDir.path}/$sub');
      return d
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.yaml'))
          .toList()
        ..sort();
    }

    return (skills: names('skills'), issues: names('issues'));
  }
}
