/// 狗狗照片头像（2026-11-18 情感化）。
///
/// 照片只存在本机：<应用文档目录>/avatars/<dogId>.jpg，不进数据库、不同步、不上传。
/// 没有照片时显示橙色渐变 + 爪印。点头像可从相册换照片。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'theme.dart';

class DogAvatarStore {
  DogAvatarStore([this._dir]);
  final Future<Directory> Function()? _dir;

  Future<Directory> _root() async {
    final base = await (_dir ?? getApplicationDocumentsDirectory)();
    final d = Directory(p.join(base.path, 'avatars'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<File?> load(String dogId) async {
    final f = File(p.join((await _root()).path, '$dogId.jpg'));
    return f.existsSync() ? f : null;
  }

  /// 把选好的图片复制进来（覆盖旧的），返回新文件。
  Future<File> save(String dogId, String sourcePath) async {
    final f = File(p.join((await _root()).path, '$dogId.jpg'));
    return File(sourcePath).copy(f.path);
  }
}

final dogAvatarStoreProvider =
    Provider<DogAvatarStore>((ref) => DogAvatarStore());

/// 选照片：测试里可替换。
typedef AvatarPicker = Future<String?> Function();

final avatarPickerProvider = Provider<AvatarPicker>((ref) => () async {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );
      return x?.path;
    });

/// 当前头像文件；换照片后 invalidate。
final dogAvatarProvider =
    FutureProvider.family<File?, String>((ref, dogId) async {
  try {
    return await ref.watch(dogAvatarStoreProvider).load(dogId);
  } catch (_) {
    return null; // 测试环境没有文档目录等情况：退回默认头像
  }
});

class DogAvatar extends ConsumerWidget {
  const DogAvatar(
      {super.key, required this.dogId, this.size = 56, this.editable = false});
  final String dogId;
  final double size;
  final bool editable;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(avatarPickerProvider)();
    if (path == null) return;
    await ref.read(dogAvatarStoreProvider).save(dogId, path);
    // 同路径覆盖：清掉图片缓存，否则还显示旧照片
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ref.invalidate(dogAvatarProvider(dogId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(dogAvatarProvider(dogId)).valueOrNull;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: file == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF6B27A), AppColors.primary],
              )
            : null,
        image: file == null
            ? null
            : DecorationImage(image: FileImage(file), fit: BoxFit.cover),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: file == null
          ? Icon(Icons.pets, color: Colors.white, size: size * 0.48)
          : null,
    );
    if (!editable) return avatar;
    return Semantics(
      button: true,
      label: '更换狗狗照片',
      child: GestureDetector(
        key: const Key('dog_avatar_edit'),
        onTap: () => _pick(context, ref),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline),
                ),
                child: Icon(Icons.photo_camera_outlined,
                    size: size * 0.2, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
