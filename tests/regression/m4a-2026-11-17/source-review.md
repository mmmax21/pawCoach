# Astra 独立代码核对（2026-11-17）

本次未修改业务代码。下列结论来自读实现及对应测试复跑，不是重复 Opus 自查。

- `app/lib/data/content/content_parser.dart:126–127`：YAML catch 后立即 throw ContentParseException，其余字段 / 版本 / 引用校验也 throw；不能把存在 catch 误判为吞错。
- `app/lib/domain/`：未发现 dart:io 或 Flutter import；plan_generator、weekly_report、badges、care_calendar、skill_status_rebuild 为纯 Dart。pubspec 的状态管理 / ORM / 路由仍只有 Riverpod / drift / go_router。
- 训练步骤与口令：training_runner 从选定 script 取 speech；library_answer 从内容字段组装 AnswerBlock；没有把训练方法新增为 Dart 字符串。提示模板与素材拼接分开，prompt_builder 的规则模板不含训练步骤；素材函数显式附 escalate_if，library 回答保留该块。
- `HttpSyncService`：注册凭证持久化后 push outbox / 按 server_seq pull；codec 逐表应用，时间戳比较避免旧行覆盖。无法应用某行时不推进游标，日志仅含表名。训练记录、计划、周报的 codec 和离线补传由真 HTTP 回归及既有 codec / LWW 测试共同验证。
- weeklyPlanId / weeklyReportId：同一家庭同一周确定性主键；旧 M3 随机主键保留，真实历史数据首次上传另有测试。
- `BadgeRepository` + `server/store.py`：dog_id + badge_id 唯一，服务端 immutable 拒绝再次写入；两端按事件操作者判定；seen 本地持久化。真 HTTP 回归断言 team_effort 获得者为 B，重复 evaluate 为空；markSeen 后两端未读流不再含该徽章。
- `CareRepository`：source=default 且未完成未跳过的默认项才重算日期，用户改日期的条目 source=user；标题 / note 取 careCalendar 原文。care_calendar 排期剔除已过09:00、done、skipped、超过60天的条目，2000–2999；每日训练提醒1001–1014。
- `AiCoachEngine`：library 分支在调用 HTTP 客户端前返回；健康与无命中是本地判定。M4 家庭同步本身需要联网，不能把 library 零模型网络解释为整台设备零网络。诊断只读内容库并经过按钮流程才显示 solution。
- `SyncService` / server sync/store 无请求体、Authorization、invite_code 日志；异常只含状态 / 错误码。服务端 `test_no_secret_in_logs` 用已知实际 token / 邀请码检查 caplog；30/30 全绿。`static-audit.json` 保存客户端日志调用位置及源码 / 当时 debug APK 的密钥特征扫描，命中0。此项为特征扫描，不声称能识别任意未知密钥。
- 新增测试不修改 `tests/ai_boundary/`；题集哈希在 static-audit.json。既有90题 library 模式模型调用次数为0；原文性118例逐块校验库字段 / 封闭模板。

实际系统按钮 / 息屏音频 / reboot 广播不由测试入口截图证明。本轮使用简报第11节准许的真实回调及生命周期注入，不扩大结论。
