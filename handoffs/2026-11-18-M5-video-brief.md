# M5 开发简报：视频纠错（本机分析，接入 App）

| 项目 | 内容 |
|---|---|
| 里程碑 | M5 |
| 发给 | Opus 5.5 |
| 发自 | Fable |
| 日期 | 2026-11-18 |
| 前置 | M4（A + B）已验收；内容库 v1.3（`content/VERSION.md`）；PRD 2026-11-18 变更记录 |
| 验收人 | Fable；回归由 Astra 执行 |
| 时间 | 11 月 21 日黑客松演示。**11 月 19 日晚交接**，20 日 12:00 冻结 |

先读：`PRD.md` 顶部变更记录与 AI-4；`content/video_checks.yaml`；`content/skills/sit.yaml`、`stay_short.yaml`、`stay_long.yaml` 的 `tutorial.common_mistakes` 与 `video_checks`；`docs/content-library.md` 第 6.5 节；`video_service/README.md`、`video_service/ORIGIN.md`、`video_service/app/main.py`、`video_service/pawcoach/analyze.py`、`video_service/pawcoach/schema.py`；`handoffs/2026-11-16-M3-brief.md` 第 16.4 节（模板文案规则，本期沿用）。

---

## 1. 目标

主人在"坐下 / 短暂等待 / 延长等待"技能页上传一段训练视频，约一两分钟后看到：
1. 本次测量数据（反应快慢、保持时长、成功率）。
2. 检测到的错误：每条是该技能**常见错误的内容库原文** + 时间证据。
3. "按正确方法跟练"按钮，进入该技能跟练。

全程在演示笔记本本机完成：视频分析服务跑在笔记本上，App 通过局域网调用。**不调任何大模型。**

## 2. 背景：video_service 是什么

队友的 PawCoach 项目，已原样整合到 `video_service/`（来源见 `ORIGIN.md`）。它把视频拆成三条流水线：姿态识别（SuperAnimal + YOLO 找狗，判坐 / 站 / 卧）、语音识别（Whisper 听口令、标记词、释放词）、奖励（打点或标记词兜底），再对齐成一轮一轮的 `trials`。接口：`POST /analyze` 上传视频与 meta，返回 `job_id`；`GET /results/{job_id}` 轮询。

本机环境已就绪：conda 环境 `pawcoach`（Python 3.12），依赖、conda-forge 的 ffmpeg、检测权重 `video_service/data/models/yolov8n.pt` 均已装好，`video_service` 86/86 测试通过。**运行前必须 `conda activate pawcoach`**，否则找不到 ffmpeg。

Fable 已确认的现状：
- 狗检测已经是自动的（姿态提取时先跑检测并缓存，后续读缓存）。
- **语音识别不是自动的**：`AsrAudioExtractor` 只读 `data/asr/<视频名>.json`，这份缓存原本靠 `scripts/b5_asr_probe.py` 手动生成。新上传的视频没有缓存，识别不到任何口令。这是本期必须修的第一件事。
- 教练文字默认走 `LLMCoach`（赞助商大模型），无密钥时兜底 `TemplateCoach`。两者都是队友自写的训练建议，**不是内容库原文**，App 一律不展示。
- 上传的视频永久留在 `data/uploads/`，不符合 PRD"分析后不留存"。
- Whisper 模型下载站本机可直连；SuperAnimal 权重从 HuggingFace 下载，本机可直连。

## 3. 第一部分：video_service 改动

只改 `video_service/`。保持其现有 86 项测试全部通过，新增测试放 `video_service/tests/`。

### 3.1 上传即自动分析（必须）

- 语音转写缓存缺失时自动转写：把 `scripts/b5_asr_probe.py` 的 `transcribe()` 抽到 `pawcoach/audio/transcribe.py`，`AsrAudioExtractor` 找不到缓存时调用它，结果写入 `data/asr/`，与原缓存格式一致。脚本改为复用这个函数。
- 模型只加载一次（进程内缓存），不要每个请求重新加载。
- 语言：默认自动检测；meta 新增可选 `language`，App 传 `zh`。
- 环境不支持时（缺 whisper）回退空事件并在结果里标明，不崩。

### 3.2 关闭大模型（必须）

- 新增环境变量 `COACH_MODE`，取值 `off`（默认）/ `template` / `llm`。`off` 时 `coach` 字段为空串，**不发任何外部网络请求**。只有显式设为 `llm` 才调大模型。
- 安全层 `red_flags` 逻辑保留，但 App 本期不传 red_flags（见 4.4）。

### 3.3 补测量字段（必须）

`Trial` 增加以下字段（只增不改，保持向后兼容）：

| 字段 | 含义 |
|---|---|
| `cue_times: list[float]` | 本轮内、狗坐下之前识别到的所有口令时刻 |
| `markers_during_hold: int` | 坐下到起身之间识别到的标记词次数 |
| `corrections: list[{word, t}]` | 本轮内识别到的纠正词及时刻 |

meta 新增可选 `correction_words: list[str]`，匹配方式与口令词相同（复用同音表思路）。`summary` 已有 `trials`、`reliable_trials`，`quality` 已有 `unclear_ratio`，App 直接用。

每轮还要能区分**是否可靠**：在结果里给每个 trial 加 `reliable: bool`（按现有 `gate_trials` 判定），App 只用可靠轮次判定。

### 3.4 分析后不留存（必须）

分析完成或失败后删除：上传的原视频、标准化视频、该视频的姿态与转写缓存。`data/pawcoach.db` 里的结果保留（只有数字，不含画面）。

### 3.5 运行脚本与预热（必须）

- `video_service/run.sh`：激活 conda 环境 `pawcoach`，在 `video_service/` 下以 `0.0.0.0:8001` 启动服务。
- `video_service/scripts/warmup.py`：预先下载并加载 Whisper base、SuperAnimal 权重，检查 yolov8n 权重存在，打印每项状态与耗时。演示前跑一次，现场不再下载。
- `GET /` 健康检查额外返回 `asr`、`pose`、`coach_mode` 三项状态，供 App 和演示前自查。

## 4. 第二部分：App 改动

### 4.1 内容库

- `tool/sync_content.sh` 多拷 `video_checks.yaml`；最低内容库版本升到 v1.3（`video_checks.yaml` 必填）。
- 解析技能的可选字段 `video_checks` 与 `video_checks.yaml`，缓存方式同现有内容表。

### 4.2 纯函数判定器

新增 `app/lib/domain/video_checks.dart`，纯函数，无 IO、无 Flutter。输入：视频服务返回的 result JSON、该技能的 `video_checks` 映射、`video_checks.yaml` 的规则与阈值、本次目标保持时长。输出：

- `status`：`retake`（可靠轮次 < `min_reliable_trials` 或 `unclear_ratio` > `retake_unclear_ratio`）/ `ok`。
- `metrics`：反应快慢中位数、保持时长中位数、成功率、可靠轮次数。
- `findings`：命中的检测器列表，每项含 `mistake` 下标与证据数据（时间点、秒数、次数）。

8 个检测器严格按 `video_checks.yaml` 的 `rule` 与阈值实现，阈值从内容库读，不在 Dart 里写死。

### 4.3 页面

- **入口**：技能详情页，仅当该技能有 `video_checks` 时显示"上传训练视频纠错"。可从相册选或现场录（复用现有视频选取），时长上限 120 秒。
- **上传**：meta 传 `cues` = 该狗口令表里此技能的口令词，`marker_words` / `release_words` / `correction_words` 取 `video_checks.yaml`，`target_hold` = 该技能成功标准对应秒数（短暂等待 3、延长等待 30、坐下 2，写在一张 Dart 常量表里并注明出处是成功标准原文），`language` = `zh`。
- **等待**：显示"正在分析，约一两分钟"，每 3 秒轮询一次；超时 5 分钟、服务失败、连不上服务各有提示，可重试。
- **结果页**，顺序固定：
  1. `retake` 时只显示重拍提示（模板句："画面里大部分时间看不清狗的姿势，请从侧面拍到狗全身后重拍"）和重新上传按钮，不显示任何纠错。
  2. 本次数据卡片。
  3. "检测到的问题"：每条显示常见错误**原文**（逐字取自 `tutorial.common_mistakes[mistake]`），下方一行证据（模板句 + 数字，例如"第 12.5 秒坐下，第 14.3 秒才奖励，晚了 1.8 秒"）。
  4. 没有命中时：模板句"这段视频里没有发现常见错误"，并显示该技能 `tutorial.success_criteria` 原文。
  5. "按正确方法跟练"按钮，进入该技能跟练；"看教程"按钮进入教程。
- **不展示** video_service 返回的 `coach` 字段（本期它为空；即便将来非空也不展示）。

### 4.4 安全

上传前页面上提供勾选项："狗在视频里有咆哮、龇牙、扑咬或明显害怕"。勾选后**不上传**，直接显示固定模板句："视频里出现攻击或恐惧信号时，请先暂停自行训练，咨询兽医或专业训犬师。"不经视频服务。

### 4.5 存储与开关

- 新表 `VideoAnalyses`（本机，不同步）：id、dog_id、skill_id、created_at、status、metrics_json、findings_json、内容库版本。schema 升到 5，迁移保留全部数据。
- 历史：技能详情页可看本技能最近 5 次纠错结果。
- 构建参数 `VIDEO_ANALYSIS`（默认关闭）、`VIDEO_BASE_URL`（默认 `http://10.0.2.2:8001`）。真机演示时填笔记本局域网 IP，debug 包已允许明文 http。
- 客户端不新增依赖（`dio` 上传 multipart，`image_picker` 选视频）。

### 4.6 模板文案

可写在 Dart 的只有：字段标签、等待与错误提示、重拍提示、无问题提示、安全提示、证据句式。证据句式只能代入数字与时间，不能出现任何训练方法描述。沿用 M3 简报 16.4 的规则与原文性测试思路。

## 5. 测试要求

1. **video_service**：
   - 新视频无缓存时自动转写并产出口令事件（用一段带口令录音的合成视频或测试替身）。
   - `COACH_MODE=off` 时零外部请求、`coach` 为空。
   - 新增三个 trial 字段与 `reliable` 的计算单测。
   - 分析后上传文件、标准化文件、缓存被删除。
   - 原 86 项不回退。
2. **App**：
   - 判定器：8 个检测器各有命中 / 未命中用例；阈值改动后结果随之变化（证明读自内容库）；`retake` 两种触发；只用可靠轮次。
   - 原文性：结果页每个文本块要么逐字等于内容库字段，要么属于 4.6 模板集合。
   - 安全勾选后不发任何请求。
   - widget：上传、等待、结果、重拍、失败五种状态。
   - 既有测试全部不回退。
3. **端到端**：起真实 `video_service`，用一段真实狗训练视频跑通"App 上传 → 结果页"。
   - **真实视频需要用户提供**（队友的样例视频不在本机）。拿不到时用合成视频跑通链路，并在交接单写明"未用真实视频验证"，交由 Astra 回归补测。
   - 记录一次完整分析耗时（预热后）。

## 6. 交接要求

- 文件：`handoffs/2026-11-19-M5-video.md`，格式按 `docs/workflow.md` 第 3 节。
- "如何运行"写清：预热、启动 video_service、模拟器与真机分别怎么连、演示包的构建参数。
- 列出 video_service 每处改动，便于队友日后比对他自己的仓库。
- 不提交 git；不改 `PRD.md`、`docs/`、`content/`、`tests/ai_boundary/`。

## 7. 打回条件

- M1–M4 打回条件任一。
- App 展示了既非内容库原文、也不在 4.6 模板集合内的训练建议文字。
- 默认配置下 video_service 发起了任何大模型请求。
- 勾选安全项后仍上传了视频。
- 分析完成后视频文件仍留在磁盘上。
- 检测阈值写死在 Dart 里，而不是读自 `video_checks.yaml`。
- `retake` 情况下仍显示了纠错结论。
- video_service 原有测试或 App 既有测试出现回退。
