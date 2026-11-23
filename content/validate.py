#!/usr/bin/env python3
"""内容库校验脚本。

用法：python3 content/validate.py
检查项：
  - YAML 可解析
  - 技能必填字段、类别、周龄、脚本时长、clicker_hint 至少一个 true
  - mini_script（v1.1 起必填）：非空、步骤连续、总时长 ≤300s、至少一个 clicker_hint
  - 技能前置 / downgrade_to 引用存在，技能树无环
  - 问题行为 diagnosis_tree 每条路径都落到 result，next 不越界
  - solutions.skills 引用存在，escalate_if 非空
  - 禁用词（惩罚性手段）扫描
  - video_checks.yaml（v1.3 起必填）：检测器 ID 唯一、阈值字段齐全；技能 video_checks 引用的
    检测器存在、mistake 下标不越界、同一技能内检测器不重复
  - faq.yaml（v1.4 起）：id 唯一且以 faq_ 开头、不与技能 / 问题行为重名；question、answer、sources 非空；
    keywords ≥2 字、不重复、不含健康拦截词；related 引用存在
"""
import glob
import os
import sys

import yaml

ROOT = os.path.dirname(os.path.abspath(__file__))
SKILL_CATEGORIES = {"basic_obedience", "house", "social", "impulse", "leash", "handling"}
ISSUE_CATEGORIES = {"puppy_behavior", "house", "anxiety", "reactivity"}
SKILL_REQUIRED = [
    "id", "name", "category", "min_age_weeks", "max_age_weeks", "prerequisites",
    "difficulty", "default_cue", "default_gesture", "sessions_to_master",
    "tutorial", "script", "mini_script", "scoring_hint", "downgrade_to", "sources",
]
MINI_SCRIPT_MAX_SEC = 300  # v1.1：每日保底版总时长上限（PRD WP-1 ≤5 分钟）
TUTORIAL_REQUIRED = ["summary", "steps", "common_mistakes", "success_criteria"]
SCRIPT_STEP_REQUIRED = ["step", "instruction", "duration_sec", "voice", "clicker_hint"]
ISSUE_REQUIRED = ["id", "name", "category", "typical_age_weeks", "diagnosis_tree", "solutions", "sources"]
SOLUTION_REQUIRED = ["summary", "skills", "management", "escalate_if"]
BANNED = ["打它", "打狗", "揍", "按头", "按鼻子", "P链", "p链", "电击", "止吠器", "喷水", "小黑屋", "猛拉", "吊", "踢"]

errors: list[str] = []
warnings: list[str] = []


def err(f: str, msg: str) -> None:
    errors.append(f"{os.path.relpath(f, ROOT)}: {msg}")


def warn(f: str, msg: str) -> None:
    warnings.append(f"{os.path.relpath(f, ROOT)}: {msg}")


def load(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except Exception as e:  # noqa: BLE001
        err(path, f"YAML 解析失败: {e}")
        return None


def scan_banned(path: str) -> None:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    for w in BANNED:
        if w in text:
            warn(path, f"出现疑似禁用词「{w}」，人工确认是否为反面提醒")


def check_skill(path: str, data: dict) -> None:
    for k in SKILL_REQUIRED:
        if k not in data:
            err(path, f"缺字段 {k}")
    if errors and any(path in e for e in errors[-len(SKILL_REQUIRED):]):
        return
    fname = os.path.splitext(os.path.basename(path))[0]
    if data["id"] != fname:
        err(path, f"id={data['id']} 与文件名不一致")
    if data["category"] not in SKILL_CATEGORIES:
        err(path, f"category={data['category']} 不在允许集合")
    if not (6 <= data["min_age_weeks"] <= 52):
        err(path, f"min_age_weeks={data['min_age_weeks']} 超出范围")
    if data["max_age_weeks"] != 52:
        warn(path, f"max_age_weeks={data['max_age_weeks']}，规范为 52")
    if not (1 <= data["difficulty"] <= 5):
        err(path, "difficulty 应在 1-5")
    if data["sessions_to_master"] not in (2, 3):
        warn(path, f"sessions_to_master={data['sessions_to_master']}，规范为 2 或 3")

    t = data["tutorial"]
    for k in TUTORIAL_REQUIRED:
        if k not in t:
            err(path, f"tutorial 缺 {k}")
    if "steps" in t and not (5 <= len(t["steps"]) <= 7):
        warn(path, f"tutorial.steps 有 {len(t['steps'])} 步，规范 5-7")
    if "common_mistakes" in t and len(t["common_mistakes"]) < 3:
        err(path, f"common_mistakes 只有 {len(t['common_mistakes'])} 条，至少 3")

    script = data["script"]
    parts = data.get("script_parts", 1)
    by_part: dict[int, list] = {}
    for s in script:
        for k in SCRIPT_STEP_REQUIRED:
            if k not in s:
                err(path, f"script step {s.get('step')} 缺 {k}")
        by_part.setdefault(s.get("part", 1), []).append(s)
    if len(by_part) != parts:
        err(path, f"script_parts={parts} 但实际 part 数={len(by_part)}")
    for p, steps in by_part.items():
        total = sum(s.get("duration_sec", 0) for s in steps)
        if total > 480:
            err(path, f"part {p} 脚本总时长 {total}s 超过 480s")
        elif total < 120:
            warn(path, f"part {p} 脚本总时长 {total}s 偏短")
        if not any(s.get("clicker_hint") for s in steps):
            warn(path, f"part {p} 没有任何 clicker_hint=true 的步骤")
        if parts == 1 and not (4 <= len(steps) <= 8):
            warn(path, f"有 {len(steps)} 步，规范 5-7")

    mini = data["mini_script"]
    if not isinstance(mini, list) or not mini:
        err(path, "mini_script 应为非空列表")
    else:
        for s in mini:
            for k in SCRIPT_STEP_REQUIRED:
                if k not in s:
                    err(path, f"mini_script step {s.get('step')} 缺 {k}")
            if "part" in s:
                err(path, "mini_script 不分 part，不应有 part 字段")
        for i, s in enumerate(mini, 1):
            if s.get("step") != i:
                err(path, f"mini_script step 编号应连续，第 {i} 条是 {s.get('step')}")
        mtotal = sum(s.get("duration_sec", 0) for s in mini)
        if mtotal > MINI_SCRIPT_MAX_SEC:
            err(path, f"mini_script 总时长 {mtotal}s 超过 {MINI_SCRIPT_MAX_SEC}s")
        elif mtotal < 90:
            warn(path, f"mini_script 总时长 {mtotal}s 偏短")
        if not any(s.get("clicker_hint") for s in mini):
            err(path, "mini_script 没有任何 clicker_hint=true 的步骤")
        if not (3 <= len(mini) <= 6):
            warn(path, f"mini_script 有 {len(mini)} 步，规范 3-6")

    if not data["sources"]:
        err(path, "sources 为空")


def check_issue(path: str, data: dict, skill_ids: set[str]) -> None:
    for k in ISSUE_REQUIRED:
        if k not in data:
            err(path, f"缺字段 {k}")
            return
    fname = os.path.splitext(os.path.basename(path))[0]
    if data["id"] != fname:
        err(path, f"id={data['id']} 与文件名不一致")
    if data["category"] not in ISSUE_CATEGORIES:
        err(path, f"category={data['category']} 不在允许集合")
    sols = data["solutions"]
    if not (2 <= len(sols) <= 4):
        warn(path, f"solutions 有 {len(sols)} 个，规范 2-4")
    for key, s in sols.items():
        for k in SOLUTION_REQUIRED:
            if k not in s or not s[k]:
                err(path, f"solution {key} 缺或为空: {k}")
        for sid in s.get("skills", []):
            if sid not in skill_ids:
                err(path, f"solution {key} 引用不存在的技能 {sid}")
        m = s.get("management", [])
        if not (3 <= len(m) <= 5):
            warn(path, f"solution {key} management 有 {len(m)} 条，规范 3-5")

    tree = data["diagnosis_tree"]
    if len(tree) < 2:
        warn(path, f"diagnosis_tree 只有 {len(tree)} 个节点，规范至少 2")
    reachable_results: set[str] = set()

    def walk(idx: int, depth: int, seen: tuple) -> None:
        if idx in seen:
            err(path, f"diagnosis_tree 出现环: {seen + (idx,)}")
            return
        if idx >= len(tree):
            err(path, f"next={idx} 越界")
            return
        if depth > 4:
            err(path, "diagnosis_tree 路径深度超过 4")
            return
        node = tree[idx]
        if "q" not in node or "options" not in node:
            err(path, f"diagnosis_tree[{idx}] 缺 q 或 options")
            return
        for o in node["options"]:
            if "result" in o:
                if o["result"] not in sols:
                    err(path, f"result={o['result']} 不在 solutions 中")
                reachable_results.add(o["result"])
            elif "next" in o:
                walk(o["next"], depth + 1, seen + (idx,))
            else:
                err(path, f"diagnosis_tree[{idx}] 选项「{o.get('text')}」既无 next 也无 result")

    walk(0, 1, ())
    for key in sols:
        if key not in reachable_results:
            warn(path, f"solution {key} 没有任何诊断路径能到达")


def check_tree_acyclic(skills: dict[str, dict]) -> None:
    state: dict[str, int] = {}

    def dfs(n: str, stack: list) -> None:
        state[n] = 1
        for p in skills[n].get("prerequisites", []):
            if p not in skills:
                err(os.path.join(ROOT, "skills", f"{n}.yaml"), f"前置技能 {p} 不存在")
                continue
            if state.get(p) == 1:
                err(os.path.join(ROOT, "skills"), f"技能树有环: {' -> '.join(stack + [n, p])}")
            elif state.get(p) is None:
                dfs(p, stack + [n])
        state[n] = 2

    for sid in skills:
        if state.get(sid) is None:
            dfs(sid, [])
    for sid, d in skills.items():
        dg = d.get("downgrade_to")
        if dg is not None and dg not in skills:
            err(os.path.join(ROOT, "skills", f"{sid}.yaml"), f"downgrade_to={dg} 不存在")
        for p in d.get("prerequisites", []):
            if p in skills and skills[p]["min_age_weeks"] > d["min_age_weeks"]:
                warn(os.path.join(ROOT, "skills", f"{sid}.yaml"), f"前置 {p} 起始周龄晚于本技能")


def main() -> int:
    skills: dict[str, dict] = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "skills", "*.yaml"))):
        d = load(f)
        if d:
            scan_banned(f)
            check_skill(f, d)
            skills[d.get("id", "")] = d
    check_tree_acyclic(skills)

    issues = 0
    for f in sorted(glob.glob(os.path.join(ROOT, "issues", "*.yaml"))):
        d = load(f)
        if d:
            scan_banned(f)
            check_issue(f, d, set(skills))
            issues += 1

    for extra in ("badges.yaml", "care_calendar.yaml"):
        p = os.path.join(ROOT, extra)
        if os.path.exists(p):
            load(p)
        else:
            err(p, "文件不存在")

    # v1.2: AI 词表
    all_ids = set(skills) | {
        os.path.splitext(os.path.basename(f))[0]
        for f in glob.glob(os.path.join(ROOT, "issues", "*.yaml"))
    }
    gp = os.path.join(ROOT, "ai_guard.yaml")
    g = load(gp) if os.path.exists(gp) else err(gp, "文件不存在")
    if g:
        for k in ("hard", "soft", "training_terms"):
            if not g.get(k):
                err(gp, f"{k} 为空或缺失")
            elif any(len(w) == 1 for w in g[k]):
                err(gp, f"{k} 含单字词，会过度匹配")
        if g.get("hard") and g.get("soft") and set(g["hard"]) & set(g["soft"]):
            err(gp, f"hard 与 soft 重复: {set(g['hard']) & set(g['soft'])}")
    tp = os.path.join(ROOT, "ai_terms.yaml")
    t = load(tp) if os.path.exists(tp) else err(tp, "文件不存在")
    if t:
        seen: set[str] = set()
        for item in t.get("terms", []):
            w = item.get("word", "")
            if len(w) < 2:
                err(tp, f"词「{w}」少于 2 字，会过度匹配")
            if w in seen:
                err(tp, f"词「{w}」重复")
            seen.add(w)
            for i in item.get("ids", []):
                if i not in all_ids:
                    err(tp, f"词「{w}」映射到不存在的 ID {i}")
            if not item.get("ids"):
                err(tp, f"词「{w}」没有映射 ID")

    vp = os.path.join(ROOT, "video_checks.yaml")
    v = load(vp) if os.path.exists(vp) else err(vp, "文件不存在（v1.3 起必填）")
    detector_ids: set[str] = set()
    if v:
        for k in ("min_reliable_trials", "retake_unclear_ratio", "marker_words", "release_words",
                  "correction_words", "detectors"):
            if k not in v:
                err(vp, f"缺 {k}")
        for w in v.get("marker_words", []) + v.get("release_words", []) + v.get("correction_words", []):
            if not isinstance(w, str) or not w.strip():
                err(vp, f"词表含空词: {w!r}")
        need = {
            "late_reward": ["threshold_sec", "min_ratio"],
            "repeated_cue": ["threshold_count", "min_ratio"],
            "session_too_long": ["max_trials"],
            "target_too_long": ["max_success_ratio"],
            "reward_after_standup": ["min_ratio"],
            "self_release": ["min_ratio"],
            "no_hold_marker": ["min_hold_sec", "min_ratio"],
            "verbal_correction": [],
            "slow_response": ["threshold_sec", "min_ratio"],
        }
        for d in v.get("detectors", []):
            did = d.get("id")
            if did in detector_ids:
                err(vp, f"检测器 {did} 重复")
            detector_ids.add(did)
            if did not in need:
                err(vp, f"未知检测器 {did}（客户端没有对应实现）")
                continue
            for k in ["name", "rule", "evidence"] + need[did]:
                if k not in d:
                    err(vp, f"检测器 {did} 缺 {k}")
    video_skills = 0
    for sid, s in skills.items():
        checks = s.get("video_checks")
        if checks is None:
            continue
        video_skills += 1
        path = os.path.join(ROOT, "skills", f"{sid}.yaml")
        if s.get("video_target", "sit") not in ("sit", "down", "arrive"):
            err(path, f"video_target 只能是 sit、down 或 arrive：{s.get('video_target')!r}")
        mistakes = s.get("tutorial", {}).get("common_mistakes", [])
        seen_d: set[str] = set()
        for c in checks:
            d, m = c.get("detector"), c.get("mistake")
            if d not in detector_ids:
                err(path, f"video_checks 引用不存在的检测器 {d}")
            if d in seen_d:
                err(path, f"video_checks 检测器 {d} 重复")
            seen_d.add(d)
            if not isinstance(m, int) or not 0 <= m < len(mistakes):
                err(path, f"video_checks 的 mistake 下标 {m} 越界（共 {len(mistakes)} 条常见错误）")

    # v1.6: 身体信号（可缺省）
    bp = os.path.join(ROOT, "body_signals.yaml")
    body_signal_count = 0
    if os.path.exists(bp):
        scan_banned(bp)
        b = load(bp) or {}
        known = {"tail_tucked", "body_low", "ears_drop", "yawn", "freeze", "panting", "tail_high", "tail_wag", "high_motion"}
        ids = set()
        for sg in b.get("signals", []):
            sid = sg.get("id")
            if sid in ids:
                err(bp, f"信号 {sid} 重复")
            ids.add(sid)
            if sid not in known:
                err(bp, f"未知信号 {sid}（视频服务没有测量它）")
            for k in ("name", "looks_like", "meaning", "category"):
                if not str(sg.get(k, "")).strip():
                    err(bp, f"信号 {sid} 缺 {k}")
            if sg.get("category") not in ("stress", "arousal"):
                err(bp, f"信号 {sid} 的 category 只能是 stress 或 arousal")
        body_signal_count = len(ids)
        def refs(lst, where):
            for x in lst or []:
                if x not in ids:
                    err(bp, f"{where} 引用不存在的信号 {x}")
        r = b.get("readiness", {})
        refs(r.get("stressed", {}).get("any_of"), "readiness.stressed.any_of")
        refs(r.get("stressed", {}).get("count_of"), "readiness.stressed.count_of")
        refs(r.get("excited", {}).get("count_of"), "readiness.excited.count_of")
        for k in ("calm", "excited", "stressed", "unclear"):
            if not str(r.get("advice", {}).get(k, "")).strip():
                err(bp, f"readiness.advice 缺 {k}")
        if r.get("calm_down_skill") not in skills:
            err(bp, f"readiness.calm_down_skill 引用不存在的技能 {r.get('calm_down_skill')}")
        refs(b.get("in_session", {}).get("stop_count_of"), "in_session.stop_count_of")
        for sec, keys in (("in_session", ("window_s", "stop_min_count", "stop_advice")), ("pacing", ("lookback", "min_same", "stressed", "excited")),
                          ("referral", ("signals", "advice"))):
            for k in keys:
                if k not in b.get(sec, {}):
                    err(bp, f"{sec} 缺 {k}")
        refs(b.get("referral", {}).get("signals"), "referral.signals")
        if not b.get("sources"):
            err(bp, "缺 sources")
        health = ["病", "药", "疼", "痛", "诊断", "症状"]
        for line in open(bp, encoding="utf-8").read().splitlines():
            if line.lstrip().startswith("#"):
                continue
            for w in health:
                if w in line:
                    err(bp, f"出现健康相关词「{w}」：身体信号只描述行为，不做健康判断")

    # v1.4: 常见问题
    fp = os.path.join(ROOT, "faq.yaml")
    faq_count = 0
    if os.path.exists(fp):
        scan_banned(fp)
        fq = load(fp)
        health_words = set((g or {}).get("hard", [])) | set((g or {}).get("soft", []))
        seen_ids: set[str] = set()
        seen_kw: dict[str, str] = {}
        for item in (fq or {}).get("faqs", []):
            faq_count += 1
            fid = item.get("id", "")
            if not fid.startswith("faq_"):
                err(fp, f"{fid}: id 要以 faq_ 开头")
            if fid in seen_ids:
                err(fp, f"{fid}: id 重复")
            if fid in all_ids:
                err(fp, f"{fid}: 与技能 / 问题行为重名")
            seen_ids.add(fid)
            for k in ("question", "answer"):
                if not str(item.get(k, "")).strip():
                    err(fp, f"{fid}: {k} 为空")
            if not item.get("sources"):
                err(fp, f"{fid}: 缺来源 sources")
            kws = item.get("keywords") or []
            if not kws:
                err(fp, f"{fid}: keywords 为空")
            for w in kws:
                if len(str(w)) < 2:
                    err(fp, f"{fid}: 检索词「{w}」少于 2 字")
                if w in seen_kw:
                    err(fp, f"{fid}: 检索词「{w}」与 {seen_kw[w]} 重复")
                seen_kw[w] = fid
                hit = [h for h in health_words if h in str(w)]
                if hit:
                    err(fp, f"{fid}: 检索词「{w}」含健康拦截词 {hit}")
            for r in item.get("related") or []:
                if r not in all_ids:
                    err(fp, f"{fid}: related 引用不存在的 ID {r}")

    print(f"身体信号 {body_signal_count} 种；", end="")
    print(f"技能 {len(skills)} 个，问题行为 {issues} 个，视频纠错技能 {video_skills} 个，常见问题 {faq_count} 条")
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"\n{len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
