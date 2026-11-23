# 内容库版本

## v1.5（2026-11-23）

- 视频纠错覆盖从 3 个技能扩到 5 个：新增 `down`（趴下）、`calm_settle`（安静趴垫）。
- 技能新增可选字段 `video_target: sit | down`（缺省 sit）：视频服务按"口令 → 进入目标姿势 → 保持"切分轮次。
- `video_checks.yaml` 新增检测器 `slow_response`（口令到做到超过 3 秒的轮次占比 ≥ 0.5）。3 秒取自 `down` 成功标准原文"狗在 3 秒内趴下"。
- 映射：down → slow_response（常见错误 4：太早加口令）、reward_after_standup（2：手一抬狗就起来）；calm_settle → verbal_correction（1：站起来就说"不行"）、target_too_long（2：一上来就要求趴 1 分钟）、self_release（3：忘记说"好了"，狗自己溜走）。共新增 5 条可检测的常见错误（合计 14 条）。
- 只映射能从"姿势时间线 + 声音时刻"测出来的错误；主人的手势、零食位置、垫子摆放仍做不到，不映射。
- `validate.py`：认识 slow_response 及其阈值；校验 video_target 取值。
- 校验：`python3 content/validate.py` 0 errors, 0 warnings
- 整理人：Opus 5.5

## v1.4（2026-11-18）

- 新增 `faq.yaml`：常见问题 24 条，覆盖不属于某一个技能或问题行为的训练通识（几个月开始练、每次练多久、零食怎么选、响片与标记词、奖励时机、为什么不打骂、全家口令一致、换地方就不会、怎么算学会、怎么减少零食、走神、退步、社会化等）。
- 每条含标准问法、检索词、回答、要点、相关技能 / 问题行为与来源；AI 教练检索命中后原文直出，不调用模型。
- 不收健康、疾病、用药、喂养量、品种选择，以及内容库未覆盖的新技能教法（与 `tests/ai_boundary/out_of_library.yaml` 保持一致）。
- `validate.py` 新增 faq 校验：id 唯一且不与技能 / 问题行为重名、检索词 ≥2 字不重复且不含健康拦截词、related 引用存在、来源非空。
- 校验：`python3 content/validate.py` 0 errors, 0 warnings
- 整理人：Opus 5.5（2026-11-18 起 Fable 停用，用户授权由 Opus 维护内容库）
- 其余内容与 v1.3 相同。

## v1.3（2026-11-18）

- 新增 `video_checks.yaml`：视频纠错检测规则，8 个检测器（奖励太晚、口令重复、一次练太久、目标时长太长、起身后才给奖励、狗自己结束等待、长等待中没有保持费、失败时出声纠正），含阈值、最少可靠轮次、重拍门槛，以及上传时用的标记词 / 释放词 / 纠正词词表。
- `sit`、`stay_short`、`stay_long` 新增可选字段 `video_checks`：把检测器映射到本技能 `tutorial.common_mistakes` 的条目下标。App 纠错时只展示该条目原文，不生成任何建议文字。
- 映射覆盖：sit 3 条、stay_short 4 条、stay_long 2 条，共 9 条常见错误。主人手势、零食高度、走动方式等需要识别人的动作，视频服务做不到，不映射。
- 阈值来源：奖励晚 1 秒与 sit 常见错误原文一致；其余比例阈值取保守值，宁可漏报不误报。
- `validate.py` 新增 video_checks 校验：检测器 ID 唯一且有客户端实现、阈值字段齐全、技能引用的检测器存在、下标不越界。已用故意写错的映射验证会报错。
- 校验：`python3 content/validate.py` 0 errors, 0 warnings
- 审核人：Fable
- 其余内容与 v1.2 相同。新版本段落按约定放在最上方。

## v1.1（2026-11-16）

- 每个技能新增 `mini_script`：每日保底版跟练脚本，总时长 ≤300 秒，3-6 步，不分 part。对应 PRD WP-1 "保底任务 ≤5 分钟"，M1 验收决策第 8 条。
- `mini_script` 只压缩正式 `script` 的步骤和时长，不引入正式脚本里没有的动作或道具；每条至少一个 `clicker_hint: true` 的步骤。
- `validate.py` 新增：`mini_script` 必填、步骤编号连续、总时长 ≤300s、至少一个 clicker_hint、不允许 `part` 字段。
- 校验：`python3 content/validate.py` 0 errors, 0 warnings
- 审核人：Fable
- 其余内容（技能 18、问题行为 9、徽章 11、日历 1）与 v1.0 相同，未改动。
- 客户端：读到 v1.0 应报错而不是静默兼容（M2 简报第 12 节）。`DailyMiniTask.script_part = 0` 表示跟练 `mini_script`。

### mini_script 时长一览

| 技能 | 步数 | 秒 |
|---|---|---|
| lure_follow | 5 | 145 |
| marker_intro | 5 | 150 |
| name_response | 5 | 160 |
| sit | 4 | 160 |
| stay_short | 5 | 170 |
| handling_body | 5 | 175 |
| recall_indoor | 5 | 180 |
| redirect_to_toy | 5 | 190 |
| down | 5 | 205 |
| alone_time | 5 | 210 |
| stay_long | 5 | 220 |
| leash_intro | 5 | 225 |
| bite_inhibition | 5 | 230 |
| loose_leash | 5 | 240 |
| potty_training | 5 | 240 |
| recall_outdoor | 5 | 240 |
| crate_intro | 6 | 245 |
| calm_settle | 5 | 270 |

### 审核说明
- alone_time 的 mini 版只做到离开 1 分钟（正式版 part 1 到 2 分钟、part 2 到 5 分钟），保底任务定位是每天维持，不是推进。
- handling_body 的 mini 版把正式版两个 part 的爪、耳、嘴各取一个最轻的动作，不涉及指甲和牙齿擦拭。
- stay_long 的 mini 版距离只到 3 步、时长只到 20 秒，低于正式版的 5 步 30 秒。
- potty_training 的 mini 版和正式版本质相同（都是一次带出），只缩短等待时长；这个技能本身不适合"压缩"。

## v1.0（2026-11-16）

- 技能 18 个，问题行为 9 个，徽章 11 个，疫苗/驱虫默认日历 1 份
- 校验：`python3 content/validate.py` 0 errors, 0 warnings
- 审核人：Fable

### 审核说明
- 所有技能和方案只用正向训练方法；文中出现的"惩罚/骂"等词均在"不要这样做"的反例语境。
- resource_guarding 三个方案的 escalate_if 阈值统一为"僵硬、低吼、龇牙任一项即停止自行训练"。
- 多段脚本（script_parts: 2）：stay_long、alone_time、loose_leash、handling_body。客户端按 part 分两次跟练。
- alone_time 的 default_gesture 为"无"，客户端对"无"开头的手势文案不展示手势图。
- 问题行为 solutions.skills 允许引用清单外的基础技能（如 sit、name_response），不限于 content-library.md 第 5 节列出的主技能。

### 已知可改进点（不阻塞开发）
- potty_accidents.excitement_urination 同时覆盖兴奋漏尿与服从性漏尿，后续可拆分。
- separation_crying 节点 2 "人在家另一房间也哭" 归入 alone_time_buildup，保守处理，靠 escalate_if 兜底。
- not_coming 节点 4 "放开跑/伸缩绳" 落到 recall_avoidance，也可考虑 recall_distraction。
- excessive_barking.demand_barking 合并了要求关注和无聊两种成因。

## v1.2（2026-11-16）

- 新增 `ai_guard.yaml`：AI 健康拦截词表，hard / soft / training_terms 三组，全部 ≥2 字。
- 新增 `ai_terms.yaml`：AI 检索分词词表，词 → 内容 ID 映射，全部 ≥2 字，ID 均存在。
- `validate.py` 新增对两个词表的校验：非空、无单字词、无重复、ID 存在。
- 新增 `tests/ai_boundary/`：`in_library` / `out_of_library` / `health` 各 30 题，Fable 用词表规则模拟跑过 90/90；另有 `model_should_refuse.yaml` 10 题供 Astra 用真实服务端人工判定。
- 校验：`python3 content/validate.py` 0 errors, 0 warnings
- 审核人：Fable
- 技能、问题行为、徽章、日历与 v1.1 相同。
- 客户端：读到 v1.1 应报错（`ai_guard.yaml` / `ai_terms.yaml` 必填）。

### 词表设计说明
- 单字词一律不收（"坐"会命中"坐飞机"，"叫"会命中"叫什么名字"），用两字以上短语代替。
- 健康词优先于训练词：hard 组命中即拦，不看语境。soft 组只在同句无训练词时拦，"它没精神，坐下练不进去"不拦。
- 分词是子串匹配不是真分词，所以词表里的词要避免互为子串造成双计（"咬手"和"咬人"都保留但删了"咬"）。
