"""PawCoach 命令行入口。

子命令（见 docs/CodePlan_detail.md）：
- probe     : 打印视频时长 / fps / 帧数 / 是否含音轨 / 编码 / 旋转 / 是否变帧率（步骤 A3、A10）
- normalize : 把手机视频标准化为 H.264 + 固定帧率 + 方向摆正（步骤 A10）
- analyze   : 视频 → JSON → 教练建议 全链路（步骤 A9）；分析前先自动标准化（步骤 A10）

analyze 的编排（标准化 → 读 meta → video/pose/audio/reward → align → coach → 落库 + 写 JSON）：
阶段 A 的 pose/audio 用 stub，B 阶段逐步换成真实现，编排代码不变。
"""

from __future__ import annotations

import argparse
from pathlib import Path

from pawcoach.analyze import NORMALIZED_DIR, analyze_video


def _cmd_probe(args: argparse.Namespace) -> None:
    from pawcoach.video.probe import load_video

    info = load_video(args.path)
    print(
        f"duration={info.duration:.1f}s, fps={info.fps}, frames={info.n_frames}, "
        f"size={info.width}x{info.height}, has_audio={info.has_audio}, "
        f"codec={info.codec}, rotation={info.rotation}, vfr={info.is_vfr}"
    )


def _cmd_normalize(args: argparse.Namespace) -> None:
    from pawcoach.video.normalize import normalize_video

    res = normalize_video(args.path, args.out_dir, force=args.force)
    if res.transcoded:
        print(f"已标准化：{res.path}")
        for r in res.reasons:
            print(f"  - {r}")
    else:
        print(f"已符合标准，无需转码：{res.path}")
    i = res.info
    print(
        f"duration={i.duration:.1f}s, fps={i.fps:.2f}, size={i.width}x{i.height}, "
        f"codec={i.codec}, rotation={i.rotation}, vfr={i.is_vfr}"
    )


def _cmd_analyze(args: argparse.Namespace) -> None:
    from pawcoach.schema import to_json

    result = analyze_video(args.path)
    out = Path(args.output or f"results/{result.video_id}.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(to_json(result), encoding="utf-8")

    print(result.coach)
    print(f"\n[结果已写入 {out}]")
    print("[已落库 data/pawcoach.db]")


def _cmd_eval_cases(args: argparse.Namespace) -> None:
    from pawcoach.eval_cases import evaluate, load_cases

    cases = load_cases(args.path)
    results, n_pass, n_referral, n_referral_pass = evaluate(cases)

    for cid, desc, passed, detail in results:
        mark = "PASS" if passed else "FAIL"
        print(f"[{mark}] 用例 {cid}: {desc}")
        if not passed and "failed" in detail:
            for c in detail["failed"]:
                print(f"      期望 {c['field']}={c['want']!r}，实际 {c['got']!r}")

    n_total = len(cases)
    n_rule = n_total - n_referral
    n_rule_pass = n_pass - n_referral_pass
    print()
    print(f"合理率（规则用例）：{n_rule_pass}/{n_rule}")
    print(f"安全转介率：{n_referral_pass}/{n_referral}")
    print(f"总计：{n_pass}/{n_total}")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="pawcoach")
    sub = parser.add_subparsers(dest="command", required=True)

    p_probe = sub.add_parser("probe", help="打印视频信息")
    p_probe.add_argument("path", help="视频文件路径")
    p_probe.set_defaults(func=_cmd_probe)

    p_norm = sub.add_parser("normalize", help="把手机视频标准化为 H.264 + 固定帧率 + 方向摆正")
    p_norm.add_argument("path", help="视频文件路径")
    p_norm.add_argument("--out-dir", default=NORMALIZED_DIR, help=f"输出目录（默认 {NORMALIZED_DIR}）")
    p_norm.add_argument("--force", action="store_true", help="即使已符合标准也强制转码")
    p_norm.set_defaults(func=_cmd_normalize)

    p_analyze = sub.add_parser("analyze", help="分析训练视频并生成教练建议")
    p_analyze.add_argument("path", help="视频文件路径")
    p_analyze.add_argument(
        "-o", "--output",
        help="结果 JSON 输出路径（默认 results/<video_id>.json）",
    )
    p_analyze.set_defaults(func=_cmd_analyze)

    p_eval = sub.add_parser("eval", help="评估命令")
    sub_eval = p_eval.add_subparsers(dest="eval_command", required=True)
    p_cases = sub_eval.add_parser("cases", help="跑 coach 用例评估（合理率 + 安全转介率）")
    p_cases.add_argument("path", help="用例文件路径（如 eval/coach_cases.yaml）")
    p_cases.set_defaults(func=_cmd_eval_cases)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
