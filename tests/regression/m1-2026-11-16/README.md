# M1 Astra 回归证据（2026-11-16）

最终结论和缺陷状态见 `handoffs/2026-11-16-M1-foundation.md` 末尾。

- `analyze-final.log`：恢复临时配置后 0 issues。
- `test-final.log`：原有 23 + 新增 3，共 26 通过；drift 在部分既有测试的内存数据库并存时输出 debug warning，测试没有失败。
- `defects-before-fix.log`：001/002 两个断言修复前失败。
- `android-ui.log`：puppy_pixel 上 5 组场景通过。此前输入法/滚动定位导致的脚本失败已修正，不作为产品缺陷。
- `on6-*.xml`、`empty-name-disabled.xml`：release 实际主入口的原生 UI 走查证据。
- `mini-six-minute-preview.xml`、`home-six-minute.png`：003 的设备复现。
- `cold-start.json`：3 次 release 进程冷启动；`cold-start-phases.json/log`：独立追加的分阶段定位。
- `multipart-duration.log`：4 个多段脚本均选 part 1；完整总时长事实断言，不表示满足 ≤5 分钟。

复跑自动化：先从项目根执行 `bash app/tool/sync_content.sh`，再进入 app 执行 `flutter pub get`、`dart run build_runner build`、`flutter analyze`、`TZ=Asia/Shanghai flutter test --reporter expanded`。设备界面测试命令为 `flutter test integration_test/m1_regression_test.dart -d emulator-5554 --reporter expanded`。

本轮设备构建临时对 debug/release 设置 applicationIdSuffix `.astra`，避免覆盖原 App；配置已恢复。复跑设备测试时同样应使用隔离测试包，或使用专用空白模拟器。集成测试覆盖内存库，持久化及性能另外使用真实文件库验证。

性能测量：每次 force-stop QA 包，在设备日志写本次唯一 ASTRA 标记，然后 am start -W；在首页 _PlanSection 首次 build 安排 post-frame 日志 ASTRA_HOME_READY，用设备 logcat epoch 时间差测量。分阶段版另在 main 第一行、binding 就绪、首帧、内容库 future 开始/完成记录标记。临时标记均已移除，未加入产品代码。日志只保留 ASTRA/flutter 相关信息。设备软件渲染开销明显，本轮不代表真机验收。

运行环境无 Xcode，iOS 未验证。训练内容 content/ 未修改。
