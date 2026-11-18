# PawCoach 开发进度

> 更新时间：2026-11-17。计划全文见 [CodePlan_detail.md](CodePlan_detail.md)，每步的验收记录见 [../reports/](../reports/)。

## 当前状态

**阶段 A（骨架与全链路跑通）已完成。** 一条命令可以跑完「视频 → JSON → 教练建议 → 落库」：

```bash
python -m pawcoach.cli analyze data/raw/sample.mp4 -o results/sample.json
```

当前链路里口令、姿态、奖励打点都是真实现。手机视频（HEVC、竖屏旋转、变帧率）会在分析前自动标准化。**阶段 B 已完成：B1～B8 全部跑通**——SuperAnimal 关键点推理、判坐站卧规则、狗检测、Whisper 口令转写、口令关键词事件、口令换真、奖励合并都已跑通。姿态已接进 `analyze`（`.venv-b` 跑真姿态、`.venv` 回退 stub），口令提取器 `AsrAudioExtractor`（B7）、奖励提取器 `MergedRewardExtractor`（B8，tap > marker > visual）都已接进 `analyze`，`trials[].cue_t` 来自真实音频事件，没打点的轮次由 marker 兜底。**阶段 C 已开始：C1 置信度门控完成**——狗出画 / 低置信 / 正面视角的片段标成 `unclear`、汇总成 `unclear_seconds`，低 conf 轮次不进 `summary` 指标，`coach` 会说明「本段有 X 秒无法可靠判断」；`dog_visible_ratio` 也从占位改成了真值。**C2 进度规则层完成**——`coach/rules.py` 纯函数（升档 +25% / 回退 -20% / 晚奖励改「标记时机」），11 个用例通过。**C3 LLMCoach 升级 + RAG SOP 完成**——`meta.json` 加可选 `target_hold`，`TemplateCoach`/`LLMCoach` 输出引用视频时间点的建议并注入规则层 + SOP 检索（`prompts/sop.md`）。**C4 安全层完成**——`meta.red_flags` 红旗（咆哮/龇牙/扑咬/恐惧/打/踢/猛拉）触发转介文本，不生成训练计划。**C5 30 用例评估完成**——`eval cases` 跑 30 用例（25 规则 + 5 安全）30/30 全过，**阶段 C 全部完成**。**D1 FastAPI 后端完成**——`app/main.py`（`POST /analyze` 上传 + `GET /results/<id>` 查结果），`analyze_video` 抽到 `pawcoach/analyze.py` 供 cli 和 app 共用，curl 端到端验证通过。**D2 性能优化完成**——降帧 10fps，dog3 全流程 1m34s（≤3 分钟），**阶段 D 全部完成，A～D 四个阶段全部结束**。

## 总览

| 阶段 | 内容 | 进度 |
|---|---|---|
| A | 骨架与全链路跑通 | 10 / 10 完成（A10 视频标准化是后加的，因目标平台是安卓和 iOS） |
| B | 换真实现（姿态、口令、奖励合并） | 8 / 8 完成（B1～B8） |
| C | 判定、处方、安全 | 5 / 5 完成（C1～C5） |
| D | API 后端（前端由同事负责） | 2 / 2 完成（D1～D2） |

## 阶段 A 明细

| 步骤 | 内容 | commit | 验收结果 |
|---|---|---|---|
| A1 | 初始化环境 | `05ebbe3` | numpy、pydantic、httpx 可导入，ffmpeg 可用 |
| A2 | 项目骨架 + `schema.py` | `05ebbe3` | `AnalysisResult()` 能打印空结构 |
| A3 | `video` 模块 + `probe` 命令 | `05ebbe3` | `probe` 输出时长、fps、帧数、音轨 |
| A4 | 三个模块接口 `Protocol` | `e15410c` | 三个 Protocol 可导入 |
| A5 | 样例视频 + `meta.json` | `17bc26f` | 两个文件存在，meta 能被 pydantic 解析 |
| A6 | 三个 stub 实现 | `805c99a` | 三个 extractor 各返回 list |
| A7 | `events/align.py` 对齐 | `0d57286` | `tests/test_align.py` 2 个用例通过 |
| A8 | `coach`（Template + LLM 兜底） | `6bc88c0` | Template 返回非空，LLM 无 key 兜底不抛异常 |
| A9 | `analyze` 命令 + `store.py` 落库 | `50830a2` | 输出 JSON 含 `video_id/quality/trials/summary/unpaired/coach` |
| A10 | 视频标准化（手机 HEVC、竖屏旋转、变帧率） | 见 git log | 合成的 iPhone 风格素材转成 H.264、rotation=0、固定 30fps、方向摆正；`tests/` 共 12 个用例通过 |

A1 到 A9 的验收标准已在一次集中验证中逐项重跑，全部通过。A10 验收见 [reports/A10.md](../reports/A10.md)。

## 阶段 B 明细

| 步骤 | 内容 | commit | 验收结果 |
|---|---|---|---|
| B1 | SuperAnimal 安装 + 关键点推理 | `09102c4`、`7a18c70` | `reports/pose_keypoints_sample.png` 已生成，8 帧里关键点基本贴在狗身上；`dog2.mp4` 518 帧每帧都检测到了狗，平均置信度 0.50。详见 [reports/B1.md](../reports/B1.md) |
| B2 | 姿态规则判坐、站、卧 + 时序平滑 | 见 git log | 侧面视频 `dog3.mp4` 逐秒对人工标注 44/50（88%），30 个「坐」全对；正面视频 `dog2.mp4` 全部降级成 `unclear`（1/13）；片段时长之和等于视频时长；`tests/` 共 24 个用例通过。详见 [reports/B2.md](../reports/B2.md) |
| B3 | 狗检测与主狗跟踪 | 见 git log | 用 YOLOv8n 的 cat+dog 类找主狗，判断狗在不在画面；对 B2 的人工标注 dog3 50/50、dog2 13/13（贴边阈值是对着 dog3 调的）；dog3、dog1 里狗离开画面的区间都标出来了；`tests/` 共 35 个用例通过。详见 [reports/B3.md](../reports/B3.md) |
| B4 | 姿态换真 + 跑通 + 记基线 | 见 git log | `.venv-b` 里 `analyze` 用 SuperAnimal 真实现、`.venv` 里回退 stub；dog3 出 1 轮 `hold=5.63s`、`ended_by=stand_up`，时间轴与肉眼看一致；35 个单测全过。详见 [reports/B4.md](../reports/B4.md) |
| B5 | 口令识别（Whisper）安装 | 见 git log | whisper base 装进 `.venv-b`，dog3（英文）和 dog1（中文）都转出带时间戳的转写；funasr 按计划「只留 Whisper 兜底」分支不装；sample 无语音是负样本。详见 [reports/B5.md](../reports/B5.md) |
| B6 | 口令关键词事件 | 见 git log | `AsrAudioExtractor` 读 whisper 转写缓存，用 `meta` 口令词 + 同音表匹配，输出 `AudioEvent[]`；dog3（sit/yes/good）三类都对上、dog1（坐/好）命中（解说词假阳性）；`tests/` 共 40 个用例通过。详见 [reports/B6.md](../reports/B6.md) |
| B7 | 口令换真 + 跑通 + 记基线 | 见 git log | `analyze` 的音频提取器换成 `AsrAudioExtractor`，dog3 出 4 轮、`cue_t=0.0/11.0/26.0/37.0` 来自真实音频事件（不再来自 stub）；`tests/` 共 40 个用例通过。详见 [reports/B7.md](../reports/B7.md) |
| B8 | 奖励合并（tap > marker > visual） | 见 git log | `MergedRewardExtractor` 接进 `analyze`：tap 直接读 `reward_taps`，没打点的轮次用 marker 兜底（`source="marker"`）；dog3（`reward_taps=[]`、3 个 `Yes.`）走 marker 兜底出 3 个奖励，`success_rate=1.0`（之前空打点时是 0.0）；`tests/` 共 45 个用例通过。详见 [reports/B8.md](../reports/B8.md) |

## 阶段 C 明细

| 步骤 | 内容 | commit | 验收结果 |
|---|---|---|---|
| C1 | 置信度门控 | 见 git log | `unclear` 片段（狗出画/低置信/正面）汇总成 `unclear_seconds`，低 conf 轮次经 `gate_trials` 不进 `summary`；`dog_visible_ratio` 接真（dog3 0.827，原硬编码 1.0）；coach 输出「本段有 19.3 秒无法可靠判断」；出画区间与 unclear 段实测对应；`tests/` 共 48 个用例通过。详见 [reports/C1.md](../reports/C1.md) |
| C2 | 进度规则层 | 见 git log | `coach/rules.py` 纯函数 `plan_progress`（升档 +25% / 回退 -20% / 晚奖励改「标记时机」只拦升不拦回），`ProgressPlan` 输出目标时长+动作+重点；11 个用例覆盖每条规则分支；`tests/` 共 59 个用例通过。详见 [reports/C2.md](../reports/C2.md) |
| C3 | LLMCoach 升级 + RAG SOP | 见 git log | `meta.json` 加可选 `target_hold`（目标时长来源，回退 median_hold）；`coach/sop.py` 关键词检索 `prompts/sop.md`（分级 SOP）；`LLMCoach` 注入规则层 + SOP + 历史，`TemplateCoach` 输出引用时间点建议（dog3 引用 11.0s/13.0s）；`tests/` 共 66 个用例通过。详见 [reports/C3.md](../reports/C3.md) |
| C4 | 安全层 | 见 git log | `coach/safety.py` 硬规则：`red_flags` 红旗（咆哮/龇牙/扑咬/恐惧/打/踢/猛拉）→ 转介文本，不生成训练计划；coach 之前拦截；端到端验证（sample + `hitting` → 转介）；`tests/` 共 77 个用例通过。详见 [reports/C4.md](../reports/C4.md) |
| C5 | 30 用例评估 | 见 git log | `eval/coach_cases.yaml` 30 用例（25 规则 + 5 安全）+ `eval cases` 子命令；合理率 25/25、安全转介率 5/5、总计 30/30；只评规则层 + 安全层确定性输出，不评 LLM 自由文本；`tests/` 共 81 个用例通过。详见 [reports/C5.md](../reports/C5.md) |

## 阶段 D 明细

| 步骤 | 内容 | commit | 验收结果 |
|---|---|---|---|
| D1 | FastAPI 后端 + 接口契约 | 见 git log | `app/main.py`：`POST /analyze` 上传（file + meta）+ `GET /results/<id>` 查结果，后台线程跑 `analyze_video`（抽到 `pawcoach/analyze.py` 供 cli/app 共用）；curl 端到端验证（上传 sample + meta → job_id → done 含完整 result）；`tests/` 共 83 个用例通过。详见 [reports/D1.md](../reports/D1.md) |
| D2 | 性能优化 | 见 git log | 降帧 30→10fps（Sit-Stay 秒级变化够用），帧数降到 1/3，推理快 3 倍；缓存缺失自动推理（`run_if_missing=True`）；dog3（55.5s）删缓存后全流程计时 1m34s ≤ 3 分钟；`tests/` 共 83 个用例通过。详见 [reports/D2.md](../reports/D2.md) |

## 各模块真假状态

| 模块 | 当前实现 | 是否真实 |
|---|---|---|
| 视频读取（probe、抽帧、抽音频） | ffmpeg | 真实 |
| 视频标准化 | ffmpeg 转 H.264、固定 30fps、方向摆正；已符合标准则不转码 | 真实，只用合成素材验证过，没有真实 iPhone 或安卓视频 |
| 奖励打点 | `MergedRewardExtractor`（B8）：优先读 `meta.reward_taps`，没打点的轮次用 marker 兜底（`source="marker"`），visual 可选未做 | 真实 |
| 事件对齐 | 纯规则 `align()`，C1 加了置信度门控（`unclear_seconds` / `gate_trials`） | 真实，有单测 |
| 落库 | SQLite `data/pawcoach.db` | 真实 |
| 教练建议 | `TemplateCoach`（C3：引用时间点 + 规则层输出），`LLMCoach`（C3：注入规则层 + SOP + 历史）无 key 时兜底到模板；后端 OpenAI 兼容 `api.openai-next.com`（`LLM_API_KEY`/`LLM_MODEL`/`LLM_BASE_URL` 环境变量） | 模板文本（LLM 真实调用待 key） |
| 进度规则层 | `coach/rules.py`（C2）：`plan_progress` 纯函数输出 `ProgressPlan`（目标时长/动作/重点） | 真实，已接进 coach（C3） |
| SOP 检索 | `coach/sop.py`（C3）：`prompts/sop.md` 关键词检索 | 真实（简单关键词，不上向量库） |
| 安全层 | `coach/safety.py`（C4）：`red_flags` 红旗 → 转介文本，不生成训练计划 | 真实（用户勾选，无自动检测） |
| 姿态 | `SuperAnimalPoseExtractor` 已接进 `analyze`：读 SuperAnimal 关键点判坐、站、卧，用 YOLO 检测框判断狗在不在画面。侧面视频可用，正面视频降级成 `unclear`。`.venv-b`（有 pandas）跑真实现，`.venv`（缺 pandas）回退 `StubPoseExtractor` 并打印提示 | **真实**（按环境回退） |
| 口令 | `AsrAudioExtractor` 已接进 `analyze`（B7）：读 whisper 转写缓存，用 `meta` 口令词 + 同音表匹配输出 `AudioEvent[]`，`trials[].cue_t` 来自真实音频事件 | **真实**（B7 换真） |

## 真实视频验证

用 B 站一段真实狗视频跑了一遍 `analyze`（柯基坐下教学视频，60.5 秒，852x480）。

- 流水线能处理真实视频：读取规格、检测音轨、对齐、出 JSON、落库都没出错。
- 结果里的 `hold=60.49`、`latency=0.0`、`cue_t=0.0` 是 stub 写死的值，不是测量结果。
- 该视频是带字幕的教学视频，不是干净的「口令、坐下、保持、释放」，不适合做基线。

## 数据位置

以下路径都在 `.gitignore` 中，只存在本机。

| 数据 | 位置 |
|---|---|
| 合成样例视频（30 秒，无狗） | `data/raw/sample.mp4`、`data/raw/sample.meta.json` |
| 真实狗视频（B 站，仅本机验证用） | `data/raw/dog1.mp4` |
| 真实狗视频（YouTube，CC BY，供 B1 验证姿态） | `data/raw/dog2.mp4`（正面为主，17.5 秒），来源与许可记在 `data/sources.csv` |
| 真实狗视频（YouTube，CC BY，侧面坐、起身，供 B2 验证判坐规则） | `data/raw/dog3.mp4`（404x720，55.5 秒，已裁掉黑边），来源与许可记在 `data/sources.csv` |
| 狗检测结果、权重 | `data/pose/*_dogbox.npy`（每帧主狗框）、`data/models/yolov8n.pt`（6.5MB，下载命令见 `requirements-b.txt`），框叠加图在 `reports/dog_boxes_dog1/2/3.png` |
| 口令转写结果 | `data/asr/dog1.json`、`dog3.json`（whisper base 转写缓存，B6 复用），whisper 模型在 `~/.cache/whisper` |
| SuperAnimal 关键点结果 | `data/pose/*.h5`，验收图在 `reports/pose_keypoints_sample.png`（dog2）、`reports/pose_keypoints_dog3.png`（dog3） |
| 姿态人工标注（B2 评估用，会提交） | `tests/fixtures/dog2_pose_labels.json`、`dog3_pose_labels.json`；标注用的对照图在 `data/labels/`（本机） |
| 分析结果 JSON | `results/sample.json`、`results/dog1.json` |
| 落库 | `data/pawcoach.db` 的 `analyses` 表，`payload` 列存完整结果 |

## 已知问题

1. `pytest` 没写进 `requirements.txt`，新环境按 requirements 安装后跑不了 A7 的测试。
2. `LLMCoach` 的真实 API 调用路径没验证过。本机没有 `LLM_API_KEY`，只验证了兜底分支。
3. `yt-dlp` 只装在 `.venv` 里，没有写进 requirements。
4. 网络：这台机器直连不了 GitHub、HuggingFace、Wikimedia Commons、Google，国内站点（B 站、清华 PyPI 镜像）可直连。国外站点要走本机代理 `127.0.0.1:7892`（macOS 系统代理已开启，HTTP、HTTPS、SOCKS 同一端口），但终端环境变量没有设代理，命令默认不会走它，需要显式指定，例如 `curl -x http://127.0.0.1:7892`、`yt-dlp --proxy http://127.0.0.1:7892`。已验证经代理可访问 GitHub、HuggingFace、Wikimedia Commons、Google、YouTube。代理软件没启动时国外站点会超时，所以 B1 下载 SuperAnimal 权重前要先确认代理在运行。
5. 真实视频还没有一段是干净的「口令、坐下、保持、释放」完整过程。`dog1.mp4` 带字幕和讲解；`dog2.mp4`（比利时牧羊犬幼犬，正面为主，17.5 秒）是手势引导坐下，没有保持和释放；`dog3.mp4`（柯利犬，侧面，55.5 秒）反复坐下起身，每次只坐几秒，还带字幕和训练师。它们只适合验证姿态识别，保持时长没有真值可对。Wikimedia Commons 里没找到坐下训练类视频。
6. 复核字段 `reviewer_correction`、`risk_flag` 等只在表里预留，还没有写入逻辑。
7. 视频标准化只用合成素材验证过，没有真实 iPhone 或安卓视频。HDR（10-bit）、杜比视界、实况照片等情况没处理。标准化会把音轨压成 16kHz 单声道，原始音质不保留。
8. `data/normalized/` 里的标准化产物不会自动清理，会随分析量增长。
9. 阶段 B 用单独的 Python 3.12 环境 `.venv-b`：deeplabcut 3.0.2 只支持到 3.12，而 `.venv` 是 3.13。B4 用「能不能 import pandas」在 `analyze` 里自动切换：`.venv-b` 跑真姿态，`.venv` 回退 stub（打印 `[姿态：stub…]`）。没做「子进程自动调 `.venv-b`」，所以在 `.venv` 里跑 `analyze` 仍是 stub 结果，要真姿态得用 `.venv-b/bin/python`。
10. SuperAnimal 推理速度：17.3 秒视频（518 帧）在 Apple 芯片 MPS 上用时 77.9 秒，约 4.5 倍实时。按这个速度 60 秒视频只姿态一项就要约 4.5 分钟，超过 D3 的「全流程 3 分钟」目标，需要降采样帧率、换小检测器或上 GPU。
11. 关键点在狗位于画面边缘、被手挡住、转身或快速起身时会错位，B2 的规则必须用置信度过滤这类帧。另外，狗不在画面里的帧（`dog3.mp4` 的片尾黑屏）仍有不少关键点置信度大于 0.3，只靠置信度判断「狗在不在」不可靠。
12. 判坐用的信号（体轴倾角 `(tail_base_y - neck_base_y) / 体长`）在 `dog3.mp4`（侧面）上坐和站分得开（坐 0.83 到 0.97，站 -0.78 到 0.54），但只有这一只狗。正面视角下信号不可用，B2 把正面或背面降级成 `unclear`，所以正面拍摄的视频算不出保持时长。详见 [reports/B2.md](../reports/B2.md)。
13. B2 的趴下（`down`）规则没有任何真实视频验证，只有合成关键点的单测。
14. 缓存（H5、dogbox）按视频文件名匹配，而 `analyze` 会先标准化：HEVC 视频（如 `dog1.mp4`）会被转码成 `data/normalized/dog1.norm.mp4`，按 `dog1` 存的缓存就对不上，真姿态报「找不到 H5」。dog2/dog3/sample 都是 h264+30fps+rotation0，标准化原样复用所以没踩到。关键点和检测框该对原视频还是标准化后视频跑（坐标、帧数会变）还没定，留到 B5～B8 或换新视频时决定。
15. B3 的「狗在不在画面」只验证了 dog3、dog1、dog2 三段视频；贴边小框阈值（8%）是对着 dog3 调的；多只狗时只取一只，没有多狗视频验证。

## 下一步

阶段 D 全部完成，A～D 四个阶段全部结束。下一步是比赛准备（前端同事对接 API + 彩排 + 演示许可署名），不在本开发计划内。B8 遗留的跨轮奖励归因粗糙（dog3 第 1、2 轮都指向 `reward_t=13.0`）仍属切分/归因迭代项。
