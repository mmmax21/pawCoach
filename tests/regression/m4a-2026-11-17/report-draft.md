
## Astra 测试结果（2026-11-17）

### 通过

本轮由 Astra 复跑；设备为 Android `emulator-5554`，日期 / 测试时区为 Asia/Shanghai。以下证据均位于 `tests/regression/m4a-2026-11-17/`。设备截图由集成测试检查点自动抓取，不使用手动点按或录屏；B 为真实服务端的另一成员 API 身份，采用简报第10节及 Fable 已接受的替代方案。不是两台手机同时看首页。

- 基线：`flutter analyze` 零问题（`analyze.log`）；Flutter **518/518**（`flutter-test.log`）；服务端 **30/30**（`pytest.log`）。新增2条回归后最终分析零问题、Flutter **520/520**（`analyze-final.log`、`flutter-test-final.log`），服务端 **30/30**（`pytest-final.log`）。未删、跳过或放宽原断言。
- 已覆盖的 PRD：NAV 五 Tab；FM-1/2/3/5 家庭、邀请码、双向同步、成员归属；RC-3 家庭连续打卡与 RC-4 记录操作者昵称；ST-2 徽章；CR-1 养护日历；WP-5 周报列表入口；M3-D8/D2/D5 对应的本批次实现。证据：`device-tour.log` 与 `tour_01_home.png` 至 `tour_12_skill_tree.png`、最终全量日志。RC 历史两视图和视频文件上传不在本批次范围，不能据此声称已验收。
- PRD 第6节“双端10秒可见”：真实服务端的三轮自动 E2E 全通过，详见性能表；B→A 断言在 A 已打开的首页自动更新，未靠重新进入页面。

#### 交接单“需要 Astra 重点验证”逐项

| # | 结论 | 观察、证据及验证边界 |
|---|---|---|
| 1 双向打卡 / 离线补推 | **通过** | `visibility-1/2/3.json` 与对应 `.log`：双向均≤10秒。`http-regression.log`、`flutter-test-final.log` 中 `m4_astra_http_test.dart`：A离线建档和保存记录、B离线保存记录，连接失败后发件箱保留，重连后两端各恰好2条原ID记录。设备首页 / B成员记录见 `tour_07_home_updated_by_b.png`、`tour_08_records_show_b.png`。 |
| 2 M3老用户升级 | **通过（真实数据库升级及首次联网）；旧APK覆盖链路受阻** | 取真实 M3 归档 `m3-2026-11-17-r2/weekly-after.sqlite` 的副本升级3→4：`m3-before.json`、`m3-upgrade.sqlite`、`migration-result.json`。24张旧表的每个旧字段、全部行集合保持一致，16张同步表现有行均有 `client_updated_at`；保留1训练记录、3计划、11目标、2周报、1诊断、2对话、7消息等；默认养护生成34条。`http-regression.log` 另核对迁移后首次注册上传、拿邀请码、新成员加入后历史记录 / 计划 / 周报 / 诊断 / 消息逐字段一致。旧APK安装这一具体步骤缺少有构建出处的M3基线包，见 `apk-inventory.json`；无运行报错，不能把数据库测试写成完成旧APK覆盖安装。 |
| 3 两端周日离线生成再合并 | **通过（真实服务端 + 两本地库）** | `http-regression.log`、`flutter-test-final.log`：将生成时钟设为周日21:30，A/B各自生成后才push / pull，reportId与nextPlanId一致，两端最终各1周报、2个不同周的计划，2条训练记录仍在。调用真实仓库生成与HTTP同步，未触发Android真实周日任务。 |
| 4 重新生成邀请码 | **通过** | 真HTTP测试断言新旧码不同，旧码加入返回404；原widget测试断言界面“邀请码不正确或已失效”。证据 `http-regression.log`、`flutter-test-final.log`；家庭页面 `tour_03_family_invite_code.png`、`tour_04_family_two_members.png`。邀请码出现在界面截图是预期，未打印到运行日志。 |
| 5 徽章不重复 / B归属 | **通过** | `tour_06_badge_popup_team_effort_by_b.png` 可见“爸爸获得了这枚徽章”，`tour_09_badge_wall.png` 为徽章墙；真HTTP测试两端都只有1条team_effort且owner=B，再evaluate无新徽章，markSeen后不再进入未读流。既有widget测试重复重建不再次弹出、pytest拒绝覆盖owner。证据 `http-regression.log`、`flutter-test-final.log`、`pytest-final.log`。 |
| 6 养护日期 / 闹钟 | **通过** | 既有单测断言改出生日期只动未编辑默认项，用户改期 / done / skipped保持；全量日志通过。`carryover.log` 实际排期2000–2007，`care-alarms.txt` 中8个本包单次闹钟最早11月24日09:00、最晚12月29日09:00，无过期排期，独立于每日1001–1014。`carry_08_care_scheduled.png` 显示过期条目仍在待确认组而未推送。`care-scheduled-prefs.xml`及`care-alarm-summary.json`把实际持久化ID2000–2007与这8条日期对应，系统与返回排期一致。 |
| 7 “扑人”规则 | **通过** | `flutter-test-final.log` 中 `m4_diagnosis_join_test.dart`：10周5分钟补入lure_follow；10/15/30分钟档基础已在计划时不重复加入、说明基础目标与解锁条件，覆盖分支与上限。本机10分钟档弹窗截图 `tour_10_diagnosis_jumping_add_this_week.png`。5分钟为单测覆盖，不冒称两档均设备走查。 |
| 8 M1–M3集成不回退 | **通过（权限前置修正后）** | `legacy-integration.log` 中M1 1/1、M2 2/2、M3 library 1/1、M3 Astra r2 1/1通过；旧model集成首轮4/5，提醒项报“超时未出现：Found 0 widgets with key [<'reminder_next'>]: []”。按APK重装后通知授权前置缺失排查（未采集首轮原生权限弹窗截图）；`run_legacy_m3.py`在测试开始后执行pm grant（`ASTRA_PERMISSION rc=0`），同一文件原5例完整复跑 **5/5**，见 `legacy-m3-rerun.log`。合计10例均有最终通过结果；model测试使用本地FAKE_UPSTREAM，不使用真实模型或密钥。 |

#### M3 带入五项（简报第11节入口）

| 项目 | 结论 | 自动驱动、断言及截图 |
|---|---|---|
| 点提醒通知打开首页 | **通过（点击处理入口）** | 从“我的”调用实际 `onReminderNotificationTap(ref)`，断言路由`/home`及首页目标出现；`carry_01_notification_home.png`。未实点系统通知。 |
| 通知栏暂停 / 继续 / 下一步 | **通过（媒体动作共用入口）** | 调用active runner的 `remoteControls`：暂停后注入5秒剩余量完全不变，继续后2秒恰减2000ms，next使stepIndex+1且running。`carry_02_remote_paused_5s.png`、`carry_03_remote_resumed.png`、`carry_04_remote_next.png` 同时可见步骤与秒数。音频为FakeAudio，不证明物理通知栏或锁屏TTS。 |
| 锁屏后问教练返回 | **通过（生命周期注入）** | 进入对话即paused，注入inactive→hidden→paused与10秒，再恢复resumed返回，步骤及剩余量与离开时完全一致，继续1秒恰减1000ms。`carry_05_lock_return.png`，`carryover.log`的`ASTRA lock`；未按电源键。 |
| 切后台后问教练返回 | **通过（生命周期注入）** | 同上独立走第二次，剩余19000ms在暂停10秒后保留，恢复1秒为18000ms。`carry_05_background_return.png`、`ASTRA background`。这是简报允许的模拟生命周期路径。 |
| 带键盘返回不溢出 | **通过** | `tester.showKeyboard`后断言Android真实viewInsets.bottom>0，原生键盘截图 `carry_06_keyboard_open.png`；pop回跟练保持running，截图 `carry_07_keyboard_return_no_overflow.png`，每个检查点`t.takeException()`为空，无overflow异常。 |

上述均由新增 `app/integration_test/m4_astra_carryover_test.dart` 驱动，`run_carryover.py`自动截图；`carryover.log` **1/1**。最初测试驱动的生命周期顺序及键盘检查接口错误分别保留在 `carryover-first-test-harness-error.log`、`carryover-second-test-harness-error.log`；按Flutter真实生命周期补hidden阶段、改用真实键盘insets断言后通过，未改App或降低要求。

### 第13节打回条件逐条核查

| 条件 | 结论 | 独立核查证据 |
|---|---|---|
| 1 M1/M2/M3任一原打回项 | **通过（本轮覆盖边界如下）** | `source-review.md`、`static-audit.json`、520全量与旧10例集成最终通过。M1：训练步骤 / 口令仍来自库，生成器无IO/Flutter、原规则用例通过、解析失败throw、依赖未越界。M2：绝对时刻状态机，后台 / 暂停恢复断言、纯函数、nextWeek六类分支、原文speech、周报幂等均通过。M3细分见下一表。真实后台音频与新release包并非本轮重新实测。 |
| 2 双端>10秒或不可自动复现 | **通过** | 3轮真实E2E均rc=0，最大1.812秒；`visibility-1/2/3.json`。 |
| 3 同步丢记录 / 被旧行覆盖 | **通过** | 真HTTP补推、迁移首次上传、原codec / LWW / stale测试，`http-regression.log`、两端同步单测最终日志及`pytest-final.log`。 |
| 4 同周两份计划 / 周报 | **通过** | 真HTTP双端离线生成再合并，确定性ID及已有周计划保留测试；`http-regression.log`、最终全量。 |
| 5 重复徽章 / owner被覆盖 | **通过** | 真HTTP两端owner=B、seen / evaluate；pytest immutable；设备B归属截图。 |
| 6 过期养护推送 / ID冲突 | **通过** | `care-alarms.txt`、`carryover.log`及排期单测；8条未来单次排期，2000–2007。 |
| 7 养护标题 / 说明非库原文 | **通过** | `m4_badges_care_test.dart`逐条比较原字段，`m4_ui_widget_test.dart`校验disclaimer；最终520全绿。 |
| 8 “扑人”错误技能 / 缺基础说明 | **通过** | `m4_diagnosis_join_test.dart`、`tour_10_diagnosis_jumping_add_this_week.png`。 |
| 9 离线不能建档 / 打卡 | **通过（真实连接拒绝路径）** | 真HTTP测试使用不可达localhost:1，建档打卡已持久化、失败后发件箱不清空、恢复后全部到达；`http-regression.log`。未额外把设备切飞行模式。 |
| 10 日志泄露token / 邀请码 | **通过** | 独立检查Dio无日志拦截器、同步错误只打印错误码或表名，server不打印请求体；`test_no_secret_in_logs`使用本次真实凭证断言caplog无泄漏，`pytest-final.log`、`static-audit.json`、`source-review.md`。 |

M3继承门槛拆分：

| 条件 | 结论 / 证据 |
|---|---|
| 90题边界、健康与无命中本地判定 | **通过**；最终全量中库内30、库外30、健康30全过，三组模型调用=0，源码为纯函数。 |
| 诊断追问 / 结果不调模型 | **通过**；原诊断集成与单测、真实页面tour截图，`source-review.md`。 |
| 客户端 / 构建无API key | **通过（源码及所扫描debug产物）**；`static-audit.json`记录artifact SHA256及密钥特征命中0；本轮不使用密钥。M3已关闭release lint问题不重开，本轮未重新打release，不能声称已扫描当前M4新release。 |
| 提示规则模板无技能步骤 / 口令、展示不隐藏escalate_if | **通过**；模板与素材拼接分开，既有测试及原文性逐块断言通过，`source-review.md`。 |
| library问答零网络 | **通过（问答引擎）**；模型计数为0与原library五场景集成通过；M4家庭同步网络属于单独业务，不作为library违规。 |
| 原文性、未经诊断不显示solution | **通过**；118例（100题+18上下文）及组装器 / 诊断测试全过。 |
| 未改边界题目 | **通过**；本轮未写该目录，`static-audit.json`保存题集SHA256；未以改题换通过。 |

### 缺陷

| 编号 | 严重度 | 复现步骤 | 期望 | 实际 | 状态 |
|---|---|---|---|---|---|
| — | — | 本轮上述回归 | 无崩溃、丢数据、规则偏差 | 在已测范围内未发现新增产品缺陷 | 高0 / 中0 / 低0；未修改业务代码 |

测试驱动首轮错误与Android授权前置缺失已保留原失败日志并完成复跑，不作为产品缺陷编号。没有改变Fable的六条既定裁定。

### 性能

均为Android模拟器debug + 本机服务端，非真机。计时口径沿用`e2e_visibility.py`（输出同时保存时钟offset）：

| 轮次 | A打卡→B拉取 | B推送→A首页显示 | 证据 | 结论 |
|---|---:|---:|---|---|
| 1 | 0.225秒 | 1.664秒 | `visibility-1.json` | 通过 |
| 2 | 0.251秒 | 1.811秒 | `visibility-2.json` | 通过 |
| 3 | 0.196秒 | 1.805秒 | `visibility-3.json` | 通过 |

旧library设备集成本次记录直出：课程171ms、自由76ms、健康71ms、库外51ms、跟练提问114ms（`legacy-integration.log`的`M3TIMING`）。本轮未新增冷启动 / 切步骤性能计时；不引用此前真机缺项作为通过。

### AI 边界测试

`flutter-test-final.log`：边界90/90，三组模型调用均0；原文性118/118。`model_should_refuse.yaml`的10题仅按Fable改定用途验证原文性，不要求改回guard_no_hit。model集成5例使用FAKE_UPSTREAM验证旧模式协议与断网展示，不算真实模型质量评测。未调用真实模型、未使用任何密钥。

### 未验证、受阻及证据有效性

- **旧M3 APK有数据→原地覆盖M4 APK的安装链路受阻**：卡在准备有可核实版本出处的M3基线包；`apk-inventory.json`未找到归档旧APK，只有当前build输出。没有命令运行报错，缺的是基线产物。真实schema3数据库迁移、历史逐字段保留、首次联网上传与新成员拉取均已通过，不能替代安装链路。补测只需提供可核实M3包后做覆盖安装，不需要重做全部回归。
- 第二台实体设备、物理通知按钮、真实电源锁屏 / 后台TTS、iOS、真机冷启动、Android真实周日定时任务不在本轮所用替代入口的证明范围。双端API身份、生命周期注入已获本期简报 / Fable允许；不写成亲手实测系统行为。周日双端生成验证的是仓库+真实服务端合并，而非操作系统触发。
- `alarms.txt`、`notification-preferences.xml`是测试卸载APK后尝试抓取的无效证据，出现`run-as: unknown package: com.puppytrainer.puppy_trainer`；第一次`care-prefs.xml`用了错误偏好文件名，原文`cat: shared_prefs/FlutterSharedPreferences.xml: No such file or directory`；`care-scheduled-notifications.xml`也错过卸载时点。这些保留排障，不用于通过结论；有效系统证据为仍安装时的`care-alarms.txt`、`care-scheduled-prefs.xml`及解析汇总`care-alarm-summary.json`。

### 改动与验收建议

新增测试：`app/integration_test/m4_astra_carryover_test.dart`（五项入口及Android养护调度）、`app/test/m4_astra_legacy_migration_test.dart`（真实M3数据库完整性）、`app/test/m4_astra_http_test.dart`（真实HTTP离线补推 / 唯一性 / owner / 老数据首次上传）。其余新增为本证据目录脚本、日志、截图和数据库副本；交接单仅末尾追加。未改PRD、docs、content、边界题目、业务代码；未提交git或切分支。

**建议进入 Fable 验收**：已测范围高严重度缺陷清零，518原有测试全部保留，新增后520/520及服务端30/30全绿；双端可见性、数据安全、原文边界与五项入口证据完整。此为提交验收建议，不替代Fable正式验收；旧APK覆盖安装缺口及本轮没有新release产物的边界须带入验收单，不能宣布所有环境均已验证。
