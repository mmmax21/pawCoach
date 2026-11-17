# 交接：M1 项目骨架、数据层、内容库加载、建档、周计划生成

| 项目 | 内容 |
|---|---|
| 里程碑 | M1 |
| 发自 | Opus 5.5 |
| 发给 | Astra（回归）、Fable（验收） |
| 日期 | 2026-11-16 |
| 依据 | `handoffs/2026-11-16-M1-brief.md`，内容库 v1.0 |

## 覆盖的 PRD 条目

与简报第 2 节逐条对应：

| 编号 | 简报要求 | 本期状态 | 代码位置 |
|---|---|---|---|
| ON-1 | 三步建档 | 完成 | `features/onboarding/onboarding_page.dart` |
| ON-2 | 狗的基本信息 | 完成，品种 30 个 + 混种/不确定 | `features/onboarding/step1_dog_info.dart`、`core/breeds.dart` |
| ON-3 | 困扰多选 ≤3，可跳过 | 完成，选项来自 `content/issues/*.yaml` | `features/onboarding/step2_concerns.dart` |
| ON-4 | 主人条件 + 已掌握技能 | 完成，技能列表来自 `content/skills/*.yaml`，按 `min_age_weeks` 排序 | `features/onboarding/step3_owner.dart` |
| ON-5 | 建档后生成首周计划并预览 | 完成 | `features/onboarding/plan_preview_page.dart` |
| ON-6 | 建档断点续接（P1） | 完成：每步写草稿到 `onboarding_drafts` 表，重新进入建档页自动恢复；建档完成后清除 | `features/onboarding/onboarding_controller.dart` |
| WP-1 | 周计划 2-4 目标 + 1 保底 | 完成 | `domain/plan_generator.dart` |
| WP-2 | 计划生成规则 | 完成，按简报第 4 节 8 条规则实现，纯函数无 IO | `domain/plan_generator.dart` |
| WP-3 | 首页静态展示 | 完成，完成次数与连续天数恒 0 | `features/home/home_page.dart` |
| FM-1 | 建档者成为家庭创建者 | 本地 Household + HouseholdMember(creator) 写入；邀请码留 M4 | `data/repositories/repositories.dart` |
| FM-3 | 口令表初始化 | 建档时为全部 18 个技能写入 DogCue（`default_cue` / `default_gesture`），无编辑页 | 同上 |
| — | 同步接口 | `SyncService` 接口 + `LocalOnlySyncService` 空实现 | `data/sync/sync_service.dart` |
| — | 技能树数据层 | `skillTreeProvider` 提供每技能状态，UI 留 M4 | `features/skill_tree/skill_tree_provider.dart` |

## 改动范围

全部新建，位于 `app/`：

```
app/
├── pubspec.yaml                        Flutter 3.50 / Dart 3.14；flutter_riverpod、drift、go_router、yaml
├── tool/sync_content.sh                 从仓库根 content/ 复制 YAML 到 assets/content/ 并生成 manifest.yaml
├── assets/content/                      由脚本生成，不要手改
├── lib/
│   ├── main.dart / app.dart             ProviderScope + MaterialApp.router；启动门：加载内容库 → 有狗进首页，无狗进建档
│   ├── core/breeds.dart                 品种列表（唯一允许硬编码的内容）+ 搜索
│   ├── core/providers.dart              数据库、内容库、仓库、同步 providers
│   ├── core/theme.dart                  主题、周龄/月龄文案、难度星
│   ├── data/db/tables.dart              drift 表：content_*、users、households、household_members、dogs、
│   │                                    dog_concerns、dog_cues、dog_skill_statuses、weekly_plans、plan_goals、
│   │                                    daily_mini_tasks、onboarding_drafts
│   ├── data/db/database.dart (+ .g.dart)
│   ├── data/content/content_parser.dart 纯 Dart YAML → 模型；任何字段错误抛 ContentParseException(file, message)
│   ├── data/content/content_repository.dart 版本比对、写库、从库读回、引用校验
│   ├── data/content/content_sources.dart AssetContentSource（运行时）/ FileContentSource（测试）
│   ├── data/repositories/repositories.dart Household / Dog / Plan / Onboarding 仓库；建档一次事务写入
│   ├── data/sync/sync_service.dart
│   ├── domain/models.dart               Skill / Issue / Badge / CareCalendar / 枚举 / 周龄与周一计算
│   ├── domain/plan_generator.dart       generateWeeklyPlan、deriveSkillStatuses、goalCountFor
│   └── features/{onboarding,home,skill_tree}/
└── test/
    ├── plan_generator_test.dart         简报第 4 节 4 用例 + 第 9 节 3 补充 + 其他规则（共 13）
    ├── content_loader_test.dart         真实 content/ 加载：18/9/11、引用关系、版本跳过重载、异常带文件名（共 5）
    ├── breeds_test.dart                 品种数量、搜索（共 2）
    └── onboarding_widget_test.dart      三步建档走通 + 困扰上限 3（共 2）
```

未改动 `content/`、`docs/`、`PRD.md`。

## 如何运行

Flutter SDK 本机安装在 `~/development/flutter`（3.50.0 stable），先加到 PATH：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

同步内容库（内容库任何改动后都要跑一次，否则 assets 里是旧的）：

```bash
bash app/tool/sync_content.sh
```

安装依赖与生成 drift 代码：

```bash
cd app && flutter pub get && dart run build_runner build
```

分析与测试：

```bash
cd app && flutter analyze && flutter test
```

运行：

```bash
cd app && flutter run -d <device>
```

内容库版本来自 `content/VERSION.md` 第一个 `## v` 标题。版本号不变时启动不会重新解析 YAML，直接从 sqlite 读。要强制重载，改版本号或删 App 数据。

## 自测结果

- [x] `flutter analyze` 0 issues
- [x] `flutter test` 23/23 通过
- [x] WP-2 简报第 4 节 4 个用例全部通过（目标顺序逐一断言）
- [x] WP-2 第 9 节补充用例：候选为空、全部掌握、困扰技能前置未满足被跳过
- [x] 困扰选满 3 项时目标数不超 N（5/10/15/30 四档）
- [x] 内容库加载：技能 18、问题 9、徽章 11；每个 prerequisite / downgrade_to / solutions.skills 都能解析
- [x] 内容库解析失败抛 `ContentParseException`，带文件名；数据库里一条引用被污染后重启抛异常不吞
- [x] 版本相同时跳过 YAML 解析，从 drift 读回与首次解析一致
- [x] `script_parts` 缺省为 1；多段脚本 part 正确；`downgrade_to: null` 正确；手势以"无"开头 `showsGestureImage == false`
- [x] ON-1 ~ ON-5 widget 测试：三步走通后数据库里 1 Dog、1 WeeklyPlan、3 PlanGoal（10 分钟档）、1 DailyMiniTask、18 DogCue、18 DogSkillStatus、1 Household、1 creator 成员、1 DogConcern；进首页看到狗名、保底任务、`0 / N`
- [x] ON-3 困扰第 4 项点击被拒并提示"最多选 3 项"
- [x] ON-6 草稿表写入与恢复（代码路径走通，未单独写测试）
- [x] FM-1 / FM-3 写入在建档 widget 测试里断言
- [x] 周龄 7 周建档：生成器返回空目标、空保底；UI 显示"去狗档案调整信息"（生成器单测覆盖，UI 未在真机验证）
- [x] 周龄 53 周建档：生成器正常给 4 个目标（单测覆盖）
- [x] Dart 代码扫描：无技能步骤、口令、问题行为文案（grep 坐下/趴下/响片/零食/牵绳/航空箱/咬手/乱尿/扑人/听名字/标记词 均 0 命中）
- [x] `domain/plan_generator.dart` 只 import `models.dart`，无 dart:io、无 Flutter
- [x] **Android 模拟器（Pixel 6 / API 35 arm64）实际走查**：冷启动 → 内容库加载 → 建档 1/3（默认出生日期 10 周前，周龄实时显示"10 周（约 2 个半月）"）→ 输入名字、选性别、拼音 "keji" 搜索到"柯基"且"混种 / 不确定"保留在末尾 → 建档 2/3 显示 9 个困扰及"常见于 X-Y 月"，选 3 项后第 4 项被拒并弹"最多选 3 项" → 建档 3/3 技能按起始周龄排序，选 10 分钟 / 1 人 / 公寓 → 预览页显示 3 个目标（响片/标记词建立、听名字看主人、转移到玩具，第三项带"针对困扰"标签）+ 保底任务"约 4 分钟" → 首页显示狗名、周龄、连续天数 0、保底任务卡、三个目标 `0 / 3` → 点保底任务进技能详情，summary / 口令 / 手势 / 步骤 / 常见错误 / 成功标准来自 YAML，跟练按钮置灰 → 强杀后冷启动直接进首页，计划仍在。logcat 无 Flutter 异常。
- [ ] iOS 模拟器走查 —— 本机无 Xcode，未做，见"已知问题"第 1 条

## 已知问题

1. **本机没有 Xcode，iOS 模拟器未验证。** 这台 Mac 只有 CommandLineTools。Android 侧是本次临时用命令行工具装的 SDK + 模拟器（见文末"本机环境"），已走通。iOS 走查请 Astra 在有 Xcode 的机器上做；`ios/` 目录是 `flutter create` 生成的默认工程，没有改过。
2. Flutter 3.50 把 Material 拆到了 `material_ui` 包（`package:flutter/material.dart` 已标 deprecated），本工程按新模板用 `material_ui`。
3. 品种搜索只支持中文、拼音全拼和英文名包含匹配，不支持拼音首字母。
4. 入户日期和出生日期的日期选择器最早只能选 3 年前。
5. 首页顶部的"本周进度条"（PRD WP-3）简报第 7 节没有列，本期未做。

## 需要 Astra 重点验证

- **周龄边界**：出生日期设为 7 周前建档 → 预览页和首页应显示"按当前档案暂时没有可安排的技能，去狗档案调整信息"，不崩溃；设为 8 周前 → 应有目标；设为 53 周前 → 第一步显示超 52 周提示，仍能生成 4 个目标（30 分钟档）且前两位为响片/标记词建立、听名字看主人。
- **困扰选满 3 项时目标数不超 N**：任意 3 个困扰 + 四档时长分别走一遍，目标数应为 2/3/3/4。
- **品种搜索**：中文（"金毛"）、拼音（"taidi"）、英文（"corgi"）、大小写混合、无命中（应只剩"混种 / 不确定"）、清空搜索后列表恢复 31 项且"混种 / 不确定"始终在末尾；选中后再搜索别的词，已选项仍保留（"已选：xxx"文案）。
- 困扰第 4 项点击：应被拒且提示，前 3 项状态不变；取消一项后可再选。
- ON-6：建档第二步退出 App 再进，应回到第二步且第一步数据还在；建档完成后再次冷启动应直接进首页。
- 内容库版本跳过重载：冷启动两次，第二次启动日志不应再解析 YAML（可在 `ContentRepository.ensureLoaded` 打断点）。
- 保底任务时长：首页"约 N 分钟"应等于该技能 part 1 所有 `duration_sec` 之和向上取整到分钟。
- 多段脚本技能（stay_long、alone_time、loose_leash、handling_body）作为保底任务时 `script_part == 1`。
- 名字输入 10 个字边界、11 个字应被截断；空名字"下一步"置灰。

## 需要 Fable 决策

1. **周龄下限 7 周的 UI 处理**：简报第 4 节第 8 条说"两者都空时首页显示'去狗档案调整信息'"，但狗档案页是 ON-7（P1，M1 未做）。本期只显示文案，没有可点的入口。要不要在 M1 加一个"重新建档"按钮，还是等 ON-7？
2. **`max_age_weeks` 是否参与候选过滤**：简报第 4 节候选条件只写了 `min_age_weeks <= age_weeks`，没提 `max_age_weeks`。content-library.md 第 1 节说"超过此周龄仍可练，但不再自动进入计划"。本期按简报实现，**没有**过滤 `max_age_weeks`，所以 53 周建档仍会排入所有技能。两份文档不一致，请定。
3. **困扰技能的 `source` 与基础保障冲突**：`name_response` 既是基础保障也可能是困扰技能（如 leash_pulling）。简报第 6 条写"基础保障→age"，本期按此实现，基础保障优先标 `age`。确认是否合意。
4. **ON-6 草稿的生命周期**：简报没说草稿保留多久、换狗时是否清除。本期只在建档完成时清除。
5. **本周进度条**（PRD WP-3 提到，简报第 7 节未列）：本期未做，是否归入 M2。
6. **Household 名称**：数据模型要求 `name` 字段，简报没定默认值，本期写成"<狗名>的家"。
7. **月龄换算文案**："常见于 X-Y 月"本期按 4.345 周/月四舍五入（8-24 周 → 2-6 月，12-52 周 → 3-12 月）。是否接受。

---

## 本机环境（Opus 5.5，2026-11-16 临时安装，全部在用户目录）

| 组件 | 位置 |
|---|---|
| Flutter 3.50.0 stable（Dart 3.14） | `~/development/flutter` |
| JDK 17 Temurin | `~/development/jdk17/Contents/Home` |
| Android SDK（cmdline-tools、platform-tools、emulator、platforms 35/36、build-tools 35、system-images android-35 google_apis arm64-v8a） | `~/Library/Android/sdk` |
| AVD | `puppy_pixel`（Pixel 6，API 35） |

`flutter config` 已指向以上 SDK 与 JDK。启动模拟器并运行：

```bash
export PATH="$HOME/development/flutter/bin:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH"
```

```bash
emulator -avd puppy_pixel -no-snapshot &
```

```bash
cd app && flutter run -d emulator-5554
```

首次 Gradle 构建约 12 分钟（下载 Gradle 9.5 / AGP 9.3 / Kotlin 2.4），之后增量很快。

## Astra 测试结果（2026-11-16）

### 通过

- **准备与自动化**：已按顺序执行 `bash app/tool/sync_content.sh`（18 技能 / 9 问题）、`flutter pub get`、`dart run build_runner build`。基线 analyze 0 issues、23/23 测试通过；修复及移除临时测量代码后 analyze **0 issues**、`TZ=Asia/Shanghai flutter test --reporter expanded` **26/26 通过**。新增 3 个回归用例；原有用例全部保留。另有 Android 集成测试 1 项，内部 5 组完整界面场景全部通过。
- **验证方式与环境**：`puppy_pixel`，API 35 arm64，1080×2400，headless / SwiftShader 软件渲染。边界、搜索和四档组合通过设备上的 Flutter integration_test 驱动真实界面，使用独立内存数据库与真实 assets 内容库；文本经测试接口注入，避免 Android IME 干扰。强杀、持久化恢复、跳过困扰、空名字与完成后冷启动通过 adb 原生输入及 UI XML 手工走查；没有把组件测试当作进程强杀验证。独立 QA 包 `com.puppytrainer.puppy_trainer.astra` 保留原 App 数据，包名临时配置已恢复。**iOS 未验证**（本机无 Xcode）。
- **ON-1、ON-5**：三步建档 → 首周预览 → 首页走通；完成后目标、保底任务与数据库记录一致。
- **ON-2**：出生日期分别为 2026-09-28（7 周）、2026-09-21（8 周）、2025-11-17（52 周）、2025-11-10（53 周），预览与首页无崩溃；7 周显示无技能提示，8/52 周有目标，53 周有超龄提示并仍生成计划（遵循简报，保留原 Fable 决策第 2 条）。名字 10 个中文字允许、11 个截断至 10 个，10 个 🐶 的表单边界通过；品种、性别已填时空名字下一步禁用。中文“金毛”、拼音“taidi”、英文“corgi”、混合大小写“CoRgI”、无命中“zzzz”通过；无命中只剩混种，清空恢复 31 项，混种始终末尾，已选品种在后续搜索中保留。
- **ON-3**：选满 3 项后第 4 项被拒并提示，原 3 项不变；取消一项可选新项；原生界面“跳过”可进入第三步。
- **ON-4、WP-2（冻结简报口径）**：满 3 困扰，5/10/15/30 分钟目标数依次 2/3/3/4；基础两项优先、前置过滤、已掌握排除、排序、次数及 source 由已有纯函数测试复验。界面验证 1 人/公寓，以及 2 人/带院子和勾选已掌握技能。修复上海凌晨日期不一致后，8 周与周一归属均正确；时间戳仍为 UTC。
- **ON-6**：第一步填 `AstraDog10`、公、柯基及日期后进入第二步，执行 `am force-stop` 再启动，仍为第二步；返回第一步确认字段保留。完成建档后强杀再启动直接首页。
- **WP-1、WP-3 已实现部分**：首页目标列表、0/目标次数、保底任务、连续天数 0 显示正确；常规保底任务 230 秒显示约 4 分钟。stay_long、alone_time、loose_leash、handling_body 分别单独作为已掌握技能时均取 `script_part == 1`，时长逐步求和为 240/330/315/330 秒，显示值取向上整分钟。WP-1 的 ≤5 分钟尚不通过（BUG-M1-003）；WP-3 本周进度条仍按原 Fable 决策第 5 条待定，不能宣称整个 WP-3 通过。
- **内容缓存与代码审查**：同版本新仓库实例仅允许读取 VERSION，其他文件读取/列目录立即抛错，仍可恢复全部内容，证明跳过 YAML；未在原生启动日志中声称观察到不存在的解析日志。`app/lib/` 未发现硬编码训练步骤、口令或问题行为文案；技能 ID、字段名及通用 UI 提示不属于训练内容。生成器只 import `models.dart`，无 dart:io / Flutter。运行依赖的状态管理/ORM/路由仅 Riverpod / drift / go_router；新增 integration_test 为 Flutter SDK 开发依赖。YAML 错误包装后重新抛出，缺失字段、错误引用与数据库污染均抛带来源的异常，仓库未吞错。
- 证据目录：`tests/regression/m1-2026-11-16/`，包含前后测试日志、Android 五组场景日志、ON-6 UI XML、6 分钟首页截图与冷启动原始数据。未修改 `content/`、PRD 或周计划规则；原 7 项 Fable 决策未实现。

### 缺陷

| 编号 | 严重度 | 复现步骤 | 期望 | 实际 | 状态 |
|---|---|---|---|---|---|
| BUG-M1-001 | 中 | 名字输入 10 个 🐶（或代理对汉字），品种、性别填完 | 与输入框一致按可见字符计数，≤10 字可下一步 | 输入框允许 10 字，但表单按 UTF-16 length 阻止下一步 | **已修复并回归**；`app/lib/features/onboarding/onboarding_controller.dart` 改为 characters.length；`app/test/astra_regression_test.dart` 覆盖可见字符、空白、10/11 字 |
| BUG-M1-002 | 中 | Asia/Shanghai，2026-11-16 00:30，出生日期 2026-09-21，完成建档 | 8 周，10 分钟档 3 个目标，周起始 2026-11-16 | 仓库先转 UTC，算成 7 周、0 目标、前一周 | **已修复并回归**；`app/lib/data/repositories/repositories.dart` 按本地日历算周龄与自然周，UTC 存时间戳；同一新增测试文件覆盖凌晨周一 |
| BUG-M1-003 | 中 | 已掌握仅选 alone_time / loose_leash / handling_body 后生成保底任务 | PRD WP-1：≤5 分钟 | 冻结规则 part 1 分别 330/315/330 秒，显示约 6 分钟；handling_body 已在 Android 预览、首页复现 | **待 Fable 决策，未修**；修复须改变内容或冻结生成规则，超出 Astra 权限；新增回归保存 part 1 与真实总时长证据，并不代表通过 ≤5 分钟要求 |
| BUG-M1-004 | 中 | puppy_pixel 软件渲染，release 已建档、有缓存，每次 force-stop 后启动，共 3 次 | 冷启动 ≤2 秒 | Activity 首帧 4.132/3.352/2.721 秒；启动前标记至首页布局完成 7.395/5.711/4.401 秒 | **未修，需真机定位复测**；追加分阶段测量已确认 Dart main 之前约 3.040–5.129 秒，非单纯 YAML 重载；现有证据不足以确定可安全修复的业务瓶颈，未提交推测性优化 |

剩余：高 0、中 2（1 项规则/内容冲突待 Fable；1 项模拟器性能未达标）、低 0；已修中 2。既有 7 项 Fable 决策不计缺陷。

**需要 Fable 决策（新增，不替代原 7 条）**：WP-1 保底 ≤5 分钟与简报“取最低难度已掌握技能的完整 part 1”不兼容。请确定内容调整或生成规则调整的口径，再安排实现；Astra 未裁剪步骤或改规则。性能项需补可用真机及测量基准，目前不能认定 ≤2 秒通过。

### 性能

- 环境：Android 模拟器 puppy_pixel / API 35 arm64 / SwiftShader 软件渲染，release APK；每次 `am force-stop` 后 `am start -W`，保留本地已建档数据库和内容缓存，测量的是进程冷启动，并非设备重启或清空系统页缓存。
- 首次安装后 Activity 首帧 5.540 秒（单列，未混入下面 3 次）。已有缓存 3 次 Activity `TotalTime` 为 **4.132 / 3.352 / 2.721 秒**，中位 **3.352 秒**。启动命令前设备日志标记至首页计划数据完成布局后的 post-frame 标记为 **7.395 / 5.711 / 4.401 秒**，中位 **5.711 秒**；含 adb 调度间隔，属于用户可用时间的近似上界，不能等同 Activity 首帧。
- 为定位另构建临时测量版：main 进入前 5.129/3.925/3.040 秒；内容库从开始至就绪 0.685/1.064/0.682 秒；首页完成布局总计 8.879/6.379/6.034 秒。引擎/进程启动与软件模拟器开销明显，另有数据就绪后的页面布局开销；不据此推断真机速度。测量点、QA 包名和 Gradle 改动已全部恢复，原始阶段日志留档。
- **≤2 秒目标未达成，见 BUG-M1-004。iOS 未验证**（无 Xcode）。

建议：高严重度已清零，可进入 Fable 验收评审和规则决策；当前不建议直接签署 M1 全项通过，先处理 WP-1 冲突、性能复测及原有待决事项。

---

## Fable 决策（2026-11-16）

对交接单"需要 Fable 决策"7 条与 Astra 新增 1 条逐一裁定。编号对应原顺序，第 8 条为 BUG-M1-003。

| # | 事项 | 决策 | 落点 |
|---|---|---|---|
| 1 | 7 周建档时"去狗档案调整信息"无入口 | M1 维持纯文案。入口随 ON-7（狗档案页，P1）在 M2 一并做，ON-7 实现时必须包含"修改出生日期后立即重新生成本周计划"。 | M2 简报 |
| 2 | `max_age_weeks` 是否参与候选过滤 | **不过滤**，按简报执行。理由：首版技能 `max_age_weeks` 全为 52，过滤会让 12 个月的狗（PRD 目标用户上限）拿到空计划。`max_age_weeks` 本版只作标注，不进入规则。已同步修改 `docs/content-library.md` 第 1 节该字段注释，消除两份文档的矛盾。 | 已改文档 |
| 3 | 基础保障技能同时是困扰技能时 `source` 取值 | 维持 `age`。基础保障优先级高于困扰归因，首页"针对困扰"标签只打在非基础保障的困扰技能上，符合预期。 | 无需改动 |
| 4 | ON-6 草稿生命周期 | 维持"建档完成即清除"。M4 做家庭/换狗时再加"删除狗时清除草稿"。 | M4 简报 |
| 5 | 本周进度条（PRD WP-3） | 归入 M2。进度条依赖完成次数，M1 恒为 0 没有展示意义。 | M2 简报 |
| 6 | Household 默认名"<狗名>的家" | 接受。M4 邀请页允许改名。 | 无需改动 |
| 7 | "常见于 X-Y 月"按 4.345 周/月四舍五入 | 接受。 | 无需改动 |
| 8 | 保底任务 ≤5 分钟（PRD WP-1）与简报"取最低难度已掌握技能的完整 part 1"冲突（BUG-M1-003） | 这是内容库设计缺口，不是代码缺陷。核对内容库：18 个技能中 **11 个**的 part 1 超过 300 秒（含难度 1 的 leash_intro 360 秒），不只是 Astra 发现的 3 个多段技能。跟练脚本按 content-library.md 第 2 节设计为 3-8 分钟一次，天然不等于"≤5 分钟小任务"。**决策**：M1 维持现行规则与真实分钟数显示，不在代码里裁剪步骤（会触犯打回条件）。内容库 v1.1 由 Fable 为每个技能补一段 `mini_script`（≤300 秒的精简版），M2 生成器改为保底任务取 `mini_script`，届时 WP-1 的 ≤5 分钟才算成立。Astra 的 BUG-M1-003 状态改为"转 M2，内容库 v1.1"。 | 内容库 v1.1 + M2 简报 |

性能（BUG-M1-004）：模拟器软件渲染数据不作验收依据。PRD 第 5 节冷启动 ≤2 秒是发版口径，不是 M1 口径。要求 Astra 在 M2 回归时用真机复测，建立基准后再判。

iOS：本机无 Xcode，M1 未验证。~~M2 回归前必须在有 Xcode 的机器上跑通 iOS 建档流程一次，否则不进 M2 验收。~~ **2026-11-16 修订（用户决定）**：iOS 验证搁置，Android 跑通为准。iOS 走查整体推迟到 M4 之后、首版发布前，作为发版前置条件而非里程碑前置条件。

## Fable 验收：通过

按 `docs/workflow.md` 第 6 节核对：

- PRD 第 6 节首版验收口径第 1 条"新用户 5 分钟内完成建档并看到首周计划"：Android 模拟器走查通过（Opus 5.5 角色自测 + Astra 回归各一遍）。第 2-5 条属于 M2-M4，不在本期。
- 交接单覆盖的 PRD 条目（ON-1~6、WP-1~3、FM-1、FM-3）与实际功能一致，WP-1 的 ≤5 分钟和 WP-3 的进度条按上表转 M2。
- Astra 高严重度缺陷为零；中严重度 2 项（M1-003、M1-004）已裁定转后续里程碑。
- 内容库 v1.0 审核清单已在 `content/VERSION.md` 勾选。
- 简报第 11 节打回条件逐条核查：Dart 无训练文案、生成器无 IO、4 个用例通过、解析失败不吞错、无额外状态管理/ORM/路由库。均未触犯。

**带入 M2 简报的事项**：ON-7 含重新生成计划、本周进度条、内容库 v1.1 `mini_script` 与保底任务规则调整、真机性能基准、iOS 走查。

**执行者说明**：M1 代码实际由 Fable 模型完成（会话模型切换未生效），交接单署名"Opus 5.5"指项目角色。M2 起启动实现会话时直接指定 Opus 5.5 模型。
