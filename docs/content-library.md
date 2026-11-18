# 内容库附录

本文档定义内容库的结构、首版技能清单和问题行为清单。内容本身由 Fable 整理并审核，开发（Opus 5.5）只实现加载与展示，不在代码里写死任何训练内容。

---

## 0. 版本规则

- 内容库版本记录在 `content/VERSION.md`，每个版本一个 `## vX.Y（日期）` 段落。
- 客户端以文件中**最高的版本号**为当前版本，不依赖段落顺序（M3 验收决策 2026-11-17）。
- 新版本段落一律放在文件最上方。
- 客户端读到低于最低要求的版本时报错，不静默兼容。

## 1. 技能（Skill）数据格式

```yaml
id: sit                          # 唯一 ID，英文小写下划线
name: 坐下
category: basic_obedience        # basic_obedience / house / social / impulse / leash / handling
min_age_weeks: 8                 # 最早可开始的周龄
max_age_weeks: 52                # 建议完成周龄，首版仅作标注，不参与计划生成过滤（M1 验收决策 2026-11-16）
prerequisites: [name_response]   # 前置技能 ID 列表，空数组表示无前置
difficulty: 1                    # 1-5
default_cue: 坐                  # 默认口令，建档时可改
default_gesture: 手掌向上，从狗鼻前向上抬
sessions_to_master: 2            # 几次"完全做到"视为掌握
tutorial:
  summary: 一句话说明这个技能解决什么
  steps:
    - text: 步骤文字
      image: sit_step1.png
  common_mistakes:
    - 口令重复喊多次
    - 奖励给得太晚
  success_criteria: 口令说一次，3 秒内坐下，保持 2 秒
script:                          # 跟练脚本，见第 2 节
  - step: 1
    instruction: 拿一块零食放在狗鼻子前
    duration_sec: 10
    voice: true
    clicker_hint: false
  - step: 2
    instruction: 零食缓慢向上向后移动，狗抬头时屁股会自然坐下
    duration_sec: 15
    voice: true
    clicker_hint: true           # 此步出现响片按钮提示
scoring_hint: 完全做到 = 5 次中 4 次以上成功；部分 = 2-3 次；没做到 = 1 次以下
mini_script:                     # v1.1 起必填：每日保底版，≤300 秒，3-6 步，不分 part，格式同 script
  - step: 1
    instruction: 拿一块零食放在狗鼻子前，向上抬，屁股碰地就按响片
    duration_sec: 60
    voice: true
    clicker_hint: true
downgrade_to: lure_follow        # "没做到"两次后下周降为此技能（可为空）
sources:
  - 来源标注，供 Fable 审核追溯
```

## 2. 跟练脚本（Script）规则

- 每步 `duration_sec` 为建议时长，计时器倒数，到点语音提示"下一步"或由主人手动进入。
- `voice: true` 的步骤，进入时朗读 `instruction`。
- `clicker_hint: true` 的步骤，界面高亮响片按钮并提示"狗做对的瞬间按下"。
- 单次跟练总时长控制在 3-8 分钟，超过 8 分钟的技能拆成多个脚本（`script_part: 1/2`）。
- `mini_script` 是每日保底任务用的精简版（v1.1 起），总时长 ≤5 分钟，只做维持不做推进；客户端 `DailyMiniTask.script_part = 0` 时读它。
- 脚本不含品种或个体差异判断，这类调整交给 AI 教练基于档案做表达层面的提示。

## 3. 问题行为（Issue）数据格式

```yaml
id: biting_hands
name: 咬手 / 啃人
category: puppy_behavior         # puppy_behavior / house / anxiety / reactivity
typical_age_weeks: [8, 24]
diagnosis_tree:                  # 追问树，最多 4 层
  - q: 咬人时狗的状态是？
    options:
      - text: 玩耍兴奋时
        next: 1
      - text: 被摸到某个部位时
        next: 2
      - text: 任何时候都咬
        next: 1
  - q: 咬的力度？
    options:
      - text: 轻咬，没破皮
        result: play_biting
      - text: 用力，有破皮
        result: hard_biting
  - q: 被摸哪里？
    options:
      - text: 爪子 / 耳朵 / 嘴
        result: handling_sensitivity
      - text: 其他
        result: play_biting
solutions:
  play_biting:
    summary: 幼犬换牙期正常行为，重点是教会咬合抑制
    skills: [bite_inhibition, redirect_to_toy, calm_settle]
    management:
      - 准备 3 种不同材质的磨牙玩具
      - 咬到手立刻停止互动 10 秒
    escalate_if: 4 周后无改善或出现低吼
  hard_biting:
    summary: ...
    skills: [...]
    management: [...]
    escalate_if: 立即咨询训犬师
  handling_sensitivity:
    summary: ...
    skills: [handling_paws, handling_mouth]
    management: [...]
    escalate_if: ...
sources: []
```

`escalate_if` 是 AI 必须原样转述的升级条件。诊断结果中出现 `escalate_if` 触发词时，AI 不再给方案，只给升级建议。

## 4. 首版技能清单（18 个）

| ID | 名称 | 类别 | 起始周龄 | 前置 | 难度 |
|---|---|---|---|---|---|
| name_response | 听名字看主人 | basic_obedience | 8 | 无 | 1 |
| lure_follow | 跟随零食 | basic_obedience | 8 | 无 | 1 |
| marker_intro | 响片 / 标记词建立 | basic_obedience | 8 | 无 | 1 |
| sit | 坐下 | basic_obedience | 8 | name_response, lure_follow | 1 |
| down | 趴下 | basic_obedience | 10 | sit | 2 |
| stay_short | 短暂等待（3 秒） | impulse | 12 | sit | 2 |
| stay_long | 延长等待（30 秒 + 距离） | impulse | 16 | stay_short | 3 |
| recall_indoor | 室内召回 | basic_obedience | 10 | name_response | 2 |
| recall_outdoor | 户外召回（长绳） | basic_obedience | 20 | recall_indoor, stay_short | 4 |
| potty_training | 定点大小便 | house | 8 | 无 | 2 |
| crate_intro | 航空箱 / 围栏适应 | house | 8 | 无 | 2 |
| alone_time | 独处练习（分离焦虑预防） | house | 10 | crate_intro | 3 |
| bite_inhibition | 咬合抑制 | social | 8 | marker_intro | 2 |
| redirect_to_toy | 转移到玩具 | social | 8 | 无 | 1 |
| calm_settle | 安静趴垫 | impulse | 12 | down | 3 |
| leash_intro | 牵绳适应 | leash | 10 | 无 | 1 |
| loose_leash | 松绳行走 | leash | 16 | leash_intro, name_response | 4 |
| handling_body | 全身触摸脱敏（爪、耳、嘴） | handling | 8 | 无 | 2 |

**技能树示意**

```
name_response ─┬─ sit ─┬─ down ─── calm_settle
               │       └─ stay_short ─┬─ stay_long
               │                      └─ recall_outdoor
               ├─ recall_indoor ──────────┘
               └─ loose_leash ◄── leash_intro
lure_follow ───┘ (sit)
marker_intro ─── bite_inhibition
crate_intro ──── alone_time
potty_training / redirect_to_toy / handling_body（无前置）
```

## 5. 首版问题行为清单（9 个）

| ID | 名称 | 典型周龄 | 方案涉及技能 |
|---|---|---|---|
| biting_hands | 咬手 / 啃人 | 8-24 | bite_inhibition, redirect_to_toy, handling_body |
| potty_accidents | 室内乱尿 | 8-20 | potty_training, crate_intro |
| separation_crying | 独处时哭叫 | 8-24 | crate_intro, alone_time, calm_settle |
| jumping_on_people | 扑人 | 12-40 | sit, stay_short, calm_settle |
| chewing_furniture | 啃家具 / 鞋子 | 10-32 | redirect_to_toy, crate_intro |
| leash_pulling | 牵绳暴冲 | 16-52 | leash_intro, loose_leash, name_response |
| not_coming | 叫不回来 | 12-52 | name_response, recall_indoor, recall_outdoor |
| excessive_barking | 乱叫 | 12-52 | calm_settle, redirect_to_toy |
| resource_guarding | 护食 / 护玩具 | 12-52 | handling_body, marker_intro（escalate 阈值低，方案以管理为主） |

## 6. 疫苗 / 驱虫默认日历

| 周龄 | 项目 | 类型 |
|---|---|---|
| 6-8 | 首针核心疫苗 | 疫苗 |
| 10-12 | 第二针 | 疫苗 |
| 14-16 | 第三针 + 狂犬 | 疫苗 |
| 每 2 周至 12 周，之后每月 | 体内驱虫 | 驱虫 |
| 每月 | 体外驱虫 | 驱虫 |

实际日程以兽医为准，App 内标注"默认日程，请按兽医建议调整"。

## 6.5 视频纠错规则（v1.3 起）

- `content/video_checks.yaml` 定义检测器：每个检测器用视频服务的测量结果（口令、坐下、起身、奖励时刻，结束方式，口令次数，等待中的标记词，纠正性话语）判定主人是否犯了某个错误，阈值写在这里，由 Fable 维护。
- 技能 YAML 的可选字段 `video_checks` 把检测器映射到本技能 `tutorial.common_mistakes` 的下标：

```yaml
video_checks:
  - { detector: late_reward, mistake: 2 }
```

- App 命中检测器后展示该条常见错误的**原文**，附测量证据（时间点、秒数），再引导进入本技能跟练。任何一方都不生成训练建议文字，保持 AI-1 边界。
- 只用可靠轮次判定；可靠轮次少于 `min_reliable_trials` 或画面无法判断占比超过 `retake_unclear_ratio` 时，只提示重拍。
- 首版只覆盖 sit、stay_short、stay_long。新增检测器需要客户端同步实现，`validate.py` 会拒绝客户端没有实现的检测器 ID。

## 7. 内容审核清单（Fable 使用）

每个技能 / 问题行为入库前核对：
- [ ] 方法符合正向训练原则，无惩罚性手段
- [ ] 来源已标注
- [ ] 前置依赖在技能树中无环
- [ ] 跟练脚本单次 ≤8 分钟
- [ ] 评分标准可操作（主人能自己判断）
- [ ] 常见错误 ≥3 条
- [ ] 问题行为的 `escalate_if` 已填写
- [ ] 不含任何医疗建议
