# 狗的状态（身体信号）辅助训练

| 项目 | 内容 |
|---|---|
| 目标（用户 2026-11-23） | 根据视频或图片分析狗狗情绪，融入训练；用户要求六个方向全部做 |
| 实现 | Opus 5.5 |
| 开关 | 和视频纠错同一个 `VIDEO_ANALYSIS`（默认显示"敬请期待"）；需要电脑上的 video_service |

## 六个方向的落地

| 方向 | 落地 |
|---|---|
| 1 练前状态检查 | 技能页"练前看看狗的状态" → 拍视频 / 选视频 / 选照片 → `POST /body-check` → 平静 / 兴奋 / 有压力信号 / 看不清 + 内容库建议；兴奋时按钮"先做「安静趴垫」"，有压力信号时按钮跳到降级技能 |
| 2 练习中该停 | 实时计时快照带最近 30 秒信号次数，达到内容库门槛显示"该停一停了"原文 |
| 3 视频纠错里的狗状态 | 上传分析结果附 `body`，结果页显示"狗的状态"与信号含义；任意 30 秒窗口压力信号够多时显示"该停一停"并注明从第几秒开始 |
| 4 节奏与奖励 | 最近 3 次检查里 2 次同一状态 → 技能页显示节奏建议原文；AI 助理训犬师新工具 `get_dog_state`，系统提示要求按 pacing_advice 调整、不下情绪结论 |
| 5 长期记录 | 周报新增"狗的状态（练前检查）"：各状态次数、出现最多的信号、节奏建议 |
| 6 安全转介 | 出现"僵住不动"→ 转介卡片（内容库原文：建议咨询专业训犬师）；练前检查、视频结果、实时计时都会显示 |

## 关键文件

- 内容库 v1.6：`content/body_signals.yaml`（9 种信号的样子与含义、各规则阈值与建议原文、来源），`validate.py` 校验并拒绝健康相关词。
- video_service：`pawcoach/body/signals.py`（测量）、`pawcoach/body/check.py`（取样）、`app/main.py` `/body-check`、`analyze.py`（result.body）、`live/session.py`（快照 body）、`live/pose_live.py`（FrameRead 带关键点；`shared_engine()` 共用一份模型）。
- App：`lib/domain/body_signals.dart`、`lib/data/body/body_api.dart`、`lib/data/repositories/body_repository.dart`（存在 video_analyses 表，skill_id `__body__`，不同步，没有改表结构）、`lib/features/body/`、技能页 / 实时计时 / 视频结果 / 周报 / AI 助理工具的接入。
- 验证：`video_service/reports/V3-body-signals.md`。

## 测试

- App 769 项全过（新增 `test/body_signals_test.dart` 11 项）；video_service 226 项全过（新增 `tests/test_body_signals.py`）；server 41 项全过；内容库 0 errors。

## 已知限制 / 后续

- 喘气、动得多在实拍上可用；尾巴、身体高低只在侧面可信；打哈欠、僵住、耳朵往后压缺实拍样本，未验证。
- 关键点里没有牙齿、舌头：龇牙、舔嘴、露眼白都测不了（视觉大模型兜底可补，需要凭据）。
- 视频纠错历史页回看时不显示当时的"狗的状态"（状态单独存了一条记录）。
- 和其他视频功能一样默认关闭。
