/// 选训练视频：复用 image_picker（M2 打卡页已用），时长上限 120 秒（M5 简报 4.3）。
library;

import 'package:image_picker/image_picker.dart';

import 'video_api.dart' show videoMaxDurationSec;

abstract class VideoPicker {
  /// 返回本地视频路径；用户取消返回 null。
  Future<String?> pick({required bool camera});
}

class ImagePickerVideoPicker implements VideoPicker {
  @override
  Future<String?> pick({required bool camera}) async {
    // maxDuration 只对现场录制生效；相册视频的时长由服务端按 meta.max_duration 校验。
    final f = await ImagePicker().pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(seconds: videoMaxDurationSec),
    );
    return f?.path;
  }
}
