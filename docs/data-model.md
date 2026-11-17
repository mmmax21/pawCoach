# 数据模型

供 Opus 5.5 实现数据层时使用。字段命名用 snake_case，时间统一 ISO 8601 UTC。

## 账号与家庭

```
User
  id, phone_or_email, nickname, avatar_url, created_at

Household
  id, name, creator_user_id, invite_code, created_at

HouseholdMember
  household_id, user_id, role (creator | member), joined_at
```

## 狗与档案

```
Dog
  id, household_id, name, birth_date, breed_id, breed_text, sex,
  home_date, living_env (apartment | house_with_yard),
  daily_minutes (5 | 10 | 15 | 30), trainer_count,
  initial_mastered (string[] JSON, M4 起；建档时勾选的"已经会"的技能，随狗同步，
                    供各端重算 DogSkillStatus：建档已会 + 周报判定掌握 + 训练记录),
  created_at, updated_at

DogConcern                    # 建档时勾选的困扰
  dog_id, issue_id, created_at

DogCue                        # 口令表
  dog_id, skill_id, cue_word, gesture_text, updated_at

DogSkillStatus
  dog_id, skill_id,
  status (locked | available | in_progress | mastered),
  mastered_at, full_success_count, fail_count
```

## 计划与记录

```
WeeklyPlan
  id, dog_id, week_start (date), generated_by (system | user),
  status (active | completed), regenerate_next (bool, M2 起),
  pending_diagnosis_skills (string[] JSON, 默认 [], M3 起；"加入下周"的诊断技能，下周生成时排最前), created_at
  唯一约束 (dog_id, week_start)

PlanGoal
  plan_id, skill_id, target_sessions, completed_sessions,
  source (age | concern | carryover | downgrade | ai_diagnosis | manual)

DailyMiniTask
  plan_id, skill_id, script_part

TrainingSession
  id, dog_id, user_id, skill_id, script_part,   # script_part = 0 表示 mini_script（M2 起），≥1 为正式脚本
  started_at, ended_at, duration_sec,           # 打卡日期按 started_at 的本地日期归日
  score (full | partial | none),
  note_text, note_video_url,
  skipped_steps (int[]),                        # JSON 数组；备注开头同时写"跳过步骤：N"
  clicker_count,
  synced_at

Streak
  dog_id, current_days, longest_days, last_checkin_date

WeeklyReport
  id, dog_id, plan_id, summary_json, ai_comment, next_plan_id, read_at (nullable), created_at
  唯一约束 plan_id
  # summary_json 结构见 handoffs/2026-11-16-M2-brief.md 第 4 节
```

## AI

```
AiConversation
  id, dog_id, type (course_qa | diagnosis), skill_id (nullable),
  issue_id (nullable, M3 起), created_at, updated_at
  # 课程内提问按 (dog_id, skill_id) 复用；自由提问为 skill_id 为空的 course_qa

AiMessage
  id, conversation_id, role (user | assistant | system),
  content,                      # 内容库直出时存展示用纯文本快照，内容库升级后历史不变
  cited_content_ids (string[]),
  kind (normal | guard_health | guard_no_hit | diagnosis_q | diagnosis_result, M3 起),
  created_at

DiagnosisResult
  id, conversation_id, dog_id, user_id (nullable, M4 起；诊断人，M3 旧记录为空), issue_id, result_key,
  solution_skill_ids (string[]), added_to_plan_id (nullable), created_at
```

## 提醒

```
ReminderSetting                # M3 起，ST-7
  dog_id, enabled (bool, 默认 false), hour, minute (默认 19:00), updated_at
  # 客户端预排未来 14 天单次本地通知（ID 1001–1014），已打卡当天不排；
  # 启动、打卡、设置变更时整体重排（BUG-M3-002 修复后口径）
```

## 养护

```
CareReminder
  id, dog_id, type (vaccine | deworm_internal | deworm_external),
  title, due_date, done_at, source (default | user)

WeightLog        # P2
  dog_id, measured_at, weight_kg

FeedingLog       # P2
  dog_id, fed_at, amount_g

PottyLog         # P2
  dog_id, logged_at, location (correct | wrong), type (pee | poop)
```

## 徽章

```
BadgeDefinition  # 内容库下发
  id, name, icon, condition_type, condition_value

DogBadge
  dog_id, badge_id, earned_at, earned_by_user_id
```

## 内容库（只读，服务端下发）

```
ContentVersion
  version, published_at, changelog

Skill / Issue / Script / BadgeDefinition / CareCalendarTemplate
  结构见 content-library.md，客户端按 version 增量拉取并本地缓存

ContentAiLexicon               # M3 起，本地缓存 ai_guard.yaml / ai_terms.yaml，同版本启动不重读文件
```

## 同步策略

M4 起以 `handoffs/2026-11-17-M4-brief.md` 第 5 节为准，要点：

- 客户端本地库（drift）为主写入点，所有同步记录带 `client_updated_at` 与 `deleted`（软删除）。
- 上行：本地写入后立即推送；失败排队重试。
- 下行：按服务端自增序号 `server_seq` 增量拉取，前台每 5 秒一次，回到前台立即一次。
- 冲突：同一记录以 `client_updated_at` 较新者胜，不做字段级合并。`dog_badges` 例外，已存在即不覆盖。
- 周计划、计划目标、保底任务、周报、徽章、默认养护条目使用确定性主键，两台设备生成的同一事实合并为一条。
- Streak 和 DogSkillStatus 不同步，由每台客户端从同步来的 TrainingSession 本地重算。
- 不同步：内容库缓存、建档草稿、每日提醒设置、Streak、DogSkillStatus、本地账号与同步状态。
