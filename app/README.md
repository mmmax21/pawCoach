# puppy_trainer

## 构建环境要求（2026-11-17，Fable 裁定 BUG-M3-001）

- **release 构建需要 JDK 21。** JDK 17 下 `image_picker_android` 的 `lintVitalAnalyzeRelease` 会崩溃（lint 内部调用 `List.removeLast`）。不要用关闭 lint 的方式绕过。
- debug 构建、`flutter test`、模拟器联调不受影响，JDK 17 可用。
- Astra 验证过的做法见 `tests/regression/m3-2026-11-17-r2/build-release.sh`：在 `app/` 下设置 `M3_JDK21` 为 JDK 21 的 Home 目录后执行该脚本。


A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## M4：家庭共享同步

同步地址用构建参数 `SYNC_BASE_URL`，默认 `http://10.0.2.2:8000`（Android 模拟器访问宿主机，与 AI 代理同一服务）。

```bash
# 服务端（另开终端）
cd ../server && DB_PATH=data/app.db .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
# 模拟器
flutter run -d emulator-5554
# 真机（与笔记本同一局域网；debug 包放开了明文 http，release 包只放开 10.0.2.2 / localhost）
flutter run -d <设备> --dart-define=SYNC_BASE_URL=http://<笔记本局域网 IP>:8000
```

没有网络时建档、打卡照常，联网后自动注册、上传、补推。
