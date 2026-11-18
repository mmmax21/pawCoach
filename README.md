# 幼犬训练 App（2026 上海黑客松）

一款面向 2–12 个月幼犬主人的训练 App：每周给出训练目标，手机跟着练，练完打卡评分；AI 教练在内容库范围内随时答疑，另外附带疫苗、驱虫等养护提醒。

- 平台：Flutter（Android / iOS 同一套代码），演示以 Android 为主
- 内容：整理公开的正向训练与响片训练方法，做成结构化内容库（`content/`）。App 里的训练步骤、常见错误、AI 回答都取自内容库，不在代码里写死，也不让模型自由发挥
- 演示日期：2026 年 11 月 21 日

---

## 功能一览

| 模块 | 能做什么 | 状态 |
|---|---|---|
| 建档 | 三步问卷：狗的信息 → 当前困扰 → 主人条件，完成后生成首周计划 | ✅ |
| 周计划 | 按月龄、已掌握技能、困扰、每日时长生成 2–4 个目标技能 + 每日保底任务（≤5 分钟）；周报与下周自动调整 | ✅ |
| 跟练 | 全屏分步引导、语音播报、响片按钮、计时，切后台 / 锁屏继续 | ✅ |
| 记录打卡 | 三档评分、备注、连续打卡天数、历史记录 | ✅ |
| AI 教练 | 课程内提问、问题行为诊断（追问 → 方案 → 一键加入计划）、常见问题。**两种模式**：离线 = 内容库原文直出，不联网；在线 = **AI 助理训犬师**，会查看狗狗档案、训练记录和本周计划，按业务规则判断，给出可确认的操作（加入计划、开始跟练、转介兽医 / 训犬师） | ✅（在线需启动 `server/`） |
| 家庭共享 | 邀请码加入家庭，多台手机同步训练记录，任一成员打卡都算 | ✅（需启动 `server/`） |
| 徽章、养护日历 | 训练里程碑徽章，疫苗 / 驱虫提醒 | ✅ |
| 视频纠错 | 上传训练视频，自动指出"奖励太晚""口令重复"等常见错误 | 🚧 **敬请期待**（入口已放在技能页，暂不可点） |

18 个技能（坐下、趴下、等待、召回、松绳行走、定点如厕、独处练习等）、9 类问题行为，详见 `content/`。

---

## 目录结构

```
.
├── PRD.md              产品需求文档（功能编号如 ON-1、WP-2 都出自这里）
├── docs/               内容库格式、数据模型、协作流程
├── content/            内容库（YAML）：技能、问题行为、徽章、养护日历、AI 词表；validate.py 校验
├── app/                Flutter App
│   ├── lib/features/   各页面（home、training、ai_coach、records、me……）
│   ├── lib/domain/     纯逻辑：计划生成、评分、AI 回答组装、视频判定
│   ├── lib/data/       本地数据库（drift）、内容加载、同步、各类仓库
│   └── test/           单元测试与页面测试
├── server/             后端（FastAPI）：家庭账号与同步；可选的 AI 模型代理
├── video_service/      视频分析服务（FastAPI + 姿态识别 + Whisper），视频纠错用，目前暂不开放
├── tests/              AI 回答边界测试题集、迁移回归数据
└── handoffs/           每个里程碑的任务简报与交接单（实现细节、验收证据、遗留问题）
```

---

## 快速开始

### 1. 准备环境

| 需要 | 版本 / 说明 |
|---|---|
| Flutter | 3.50（`flutter --version`），Dart ≥ 3.6 |
| Android Studio | 带一台 Android 模拟器（AVD），或一部开了 USB 调试的安卓手机 |
| Python | 3.12+，只有要启动 `server/` 时才需要 |

> 如果终端里找不到 `flutter`，要把 Flutter 的 `bin` 目录加进 PATH，例如 `export PATH="$HOME/development/flutter/bin:$PATH"`。

### 2. 只运行 App（最简单，单机就能体验大部分功能）

```bash
cd app
flutter pub get
flutter run            # 有多台设备时加 -d emulator-5554
```

不启动任何后端也能完整走：建档 → 周计划 → 跟练 → 打卡 → 周报 → AI 教练（内容库直出）→ 徽章 / 养护提醒。家庭同步连不上服务时会在后台静默重试，不影响使用。

打开模拟器（把 `<AVD 名称>` 换成自己的，`emulator -list-avds` 可以查）：

```bash
~/Library/Android/sdk/emulator/emulator -avd <AVD 名称> &
```

### 3. 启动后端（体验家庭共享时需要）

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
FAKE_UPSTREAM=1 .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

- 默认端口 8000。Android 模拟器里的 `10.0.2.2` 就是电脑本机，App 默认连 `http://10.0.2.2:8000`，不用改配置。
- 数据库默认在 `server/data/app.db`（已在 `.gitignore` 里，不会提交）。
- 验证：`curl localhost:8000/healthz`
- 体验家庭共享：开两台模拟器各装一份 App。A 建档后进 **我的 → 家庭成员** 看 6 位邀请码；B 在建档第一屏点 **加入已有家庭**，输入邀请码。

### 3.5 打开在线模式（AI 助理训犬师）

1. 启动后端（任选一种上游，见 `server/README.md`）：有 API key 就 `export ANTHROPIC_API_KEY=...`；没有就用本机已登录的 `claude` 命令行：

```bash
cd server && CLI_UPSTREAM=1 .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

2. App 里进 **AI 教练**，右上角切到 **在线**。连不上服务时会自动改用离线模式回答并提示。

### 4. 用真手机演示

手机和电脑连同一个 Wi-Fi，把地址换成电脑的局域网 IP，**用 debug 包**（release 包不允许连局域网的 http 地址）：

```bash
cd app
flutter run -d <设备> --dart-define=SYNC_BASE_URL=http://<电脑局域网IP>:8000
```

电脑防火墙需要放行 8000 端口。

### 构建参数一览

| 参数 | 默认 | 作用 |
|---|---|---|
| `SYNC_BASE_URL` | `http://10.0.2.2:8000` | 家庭同步服务地址 |
| `AI_ONLINE` | `false` | AI 教练默认是否在线模式（用户也可以在 AI 教练页随时切换） |
| `AI_MODE` | `library` | 旧版模型生成开关（M3），保留不用；在线模式请用 AI 教练页的开关 |
| `AI_BASE_URL` | `http://10.0.2.2:8000` | 在线模式的服务地址（`server/`） |
| `VIDEO_ANALYSIS` | `false` | 视频纠错开关。默认关闭，入口显示"敬请期待"；开发时设 `true` 可打开完整功能 |
| `VIDEO_BASE_URL` | `http://10.0.2.2:8001` | 视频分析服务地址 |

用法：`flutter run --dart-define=参数=值`，多个参数重复写多次 `--dart-define`。

---

## 测试

```bash
cd app && flutter test                         # App：单元测试 + 页面测试
cd server && .venv/bin/python -m pytest -q     # 后端：AI 代理 + 家庭同步
python3 content/validate.py                    # 内容库格式校验
```

> `app/test/m4_astra_legacy_migration_test.dart` 运行时会改写 `tests/regression/m4a-2026-11-17/` 下的两个文件，跑完用 `git checkout -- tests/regression/` 还原即可。

---

## 视频纠错（敬请期待）

代码已经在仓库里，但还不够稳定，所以首版先不开放：

- 能做的：服务端识别狗"坐下 / 起身"的时刻和主人说的口令、奖励词，App 按内容库规则判断常见错误（坐下、短时等待、长时间等待三个技能），并附上时间证据
- 还不够好的：只认侧面拍摄；真实环境下中文口令的识别不稳定；需要在电脑上跑一个较重的分析服务（姿态模型 + Whisper）
- 想试用：见 `handoffs/2026-11-19-M5-video.md` 的"如何运行"（启动 `video_service/run.sh`，App 加 `--dart-define=VIDEO_ANALYSIS=true`）

---

## 想深入了解

| 想知道 | 看哪里 |
|---|---|
| 产品范围、功能编号、验收标准 | `PRD.md` |
| 内容库怎么写、字段含义 | `docs/content-library.md`、`content/VERSION.md` |
| 数据表和同步策略 | `docs/data-model.md` |
| 分工与交接流程 | `docs/workflow.md` |
| 每个里程碑做了什么、有哪些已知问题 | `handoffs/`（M1 骨架与建档 → M2 跟练与打卡 → M3 AI 教练 → M4 家庭 / 徽章 / 养护 → M5 视频纠错） |
| 后端接口 | `server/README.md` |
| 视频分析服务原理 | `video_service/README.md`（由队友的 PawCoach 项目整合而来） |
