#!/usr/bin/env python3
"""Launch the current frozen trajectory evaluation using local .env credentials.

Does not print credentials, overwrite existing annotations, or retry failed calls
silently. No Judge input is taken from private scores or source snapshots.
"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shlex
import sys

import run as pipeline


def env_values(path):
    values = {}
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:]
            if "=" not in line:
                raise ValueError("Invalid .env line; expected NAME=value")
            name, value = line.split("=", 1)
            values[name.strip()] = " ".join(shlex.split(value, comments=True))
    return values


def resolve_judge(values, provider, model=None, endpoint=None, extra_body=None):
    """Keep provider credentials isolated; DeepSeek never falls back to a GPT key."""
    if provider == "deepseek":
        model = model or values.get("DEEPSEEK_MODEL") or "deepseek-flash"
        key = values.get("DEEPSEEK_API_KEY")
        base = values.get("DEEPSEEK_BASE_URL") or "https://api.deepseek.com"
        defaults = {"thinking": {"type": "enabled"}, "reasoning_effort": "high", "max_tokens": 65536}
        judge_id = "deepseek_flash_high_v1"
    else:
        model = model or values.get("JUDGE_MODEL") or values.get("GPT_MODEL")
        key = values.get("JUDGE_API_KEY") or values.get("GPT_API_KEY")
        base = values.get("GPT_BASE_URL", "")
        endpoint = endpoint or values.get("JUDGE_ENDPOINT")
        defaults = {"reasoning_effort": "high", "max_completion_tokens": 16000}
        judge_id = "gpt61_high_v1"
    if not model or not key:
        raise ValueError(f"Missing model or API key for provider {provider}; no cross-provider credential fallback")
    if not endpoint:
        base = base.rstrip("/")
        if base.endswith("/responses"):
            base = base.removesuffix("/responses")
        if not base:
            raise ValueError(f"Missing base URL for provider {provider}")
        endpoint = base if base.endswith("/chat/completions") else base + "/chat/completions"
    return model, endpoint, key, extra_body if extra_body is not None else json.dumps(defaults), judge_id


def execution_status(run, judge_id, model, error, provider=None):
    manifest = pipeline.read(run / "private/manifest.json")
    folder = run / "judges" / judge_id
    done = {p.stem for p in (folder / "annotations").glob("*.json")}
    failures = []
    states = Counter()
    for case in manifest["cases"]:
        cid = case["case_id"]
        attempts = sorted((folder / "attempts" / cid).glob("*/metadata.json"))
        if cid in done:
            states["validated_unreviewed"] += 1
        elif attempts:
            last = pipeline.read(attempts[-1])
            states[last["status"]] += 1
            if last["status"] == "error":
                failures.append({"case_id": cid, "error": last.get("error"), "metadata": str(attempts[-1].relative_to(run))})
        else:
            states["not_attempted"] += 1
    value = {"updated_at": pipeline.now(), "run": str(run), "judge_id": judge_id,
             "model": model, "provider": provider, "total_cases": len(manifest["cases"]), "states": dict(states),
             "complete": len(done) == len(manifest["cases"]), "failures": failures,
             "batch_error": error,
             "review_status": "pending; validated labels are not human-reviewed results"}
    pipeline.write(folder / "execution_status.json", value)
    lines = ["# 轨迹 Judge 执行状态", "", f"Judge：{model}；批次：{judge_id}。", "",
             f"已取得并校验的标注：{len(done)}/{len(manifest['cases'])}。", "",
             "| 状态 | case 数 |", "|---|---:|"]
    lines += [f"| {state} | {count} |" for state, count in sorted(states.items())]
    if failures:
        lines += ["", "失败记录："] + [f"- {r['case_id']}：{r['error']}" for r in failures]
    lines += ["", "未完成或失败的请求不计为验证标签，不生成伪造分数。已有合法标注在续跑时跳过。"]
    (folder / "execution_status.md").write_text("\n".join(lines) + "\n")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--env-file", type=Path, default=pipeline.ROOT / ".env")
    parser.add_argument("--provider", choices=["gpt", "deepseek"], default="gpt")
    parser.add_argument("--judge-id", help="default: a separate batch ID for the selected provider")
    parser.add_argument("--model")
    parser.add_argument("--endpoint")
    parser.add_argument("--extra-body", help="JSON override; defaults use the selected provider's output budget parameter")
    parser.add_argument("--response-format", choices=["json_object", "none"], default="json_object")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--limit", type=int, default=0, help="0: all remaining cases; use 2 for a pilot")
    parser.add_argument("--case", action="append")
    args = parser.parse_args()
    if args.limit < 0 or args.timeout <= 0:
        parser.error("limit must be nonnegative and timeout must be positive")
    if args.judge_id is not None and (args.judge_id in ("", ".", "..") or Path(args.judge_id).name != args.judge_id):
        parser.error("judge-id must be a simple directory name")
    try:
        values = env_values(args.env_file)
        values.update({k: v for k, v in os.environ.items() if k.startswith(("JUDGE_", "GPT_", "DEEPSEEK_")) and v})
        model, endpoint, key, body, default_id = resolve_judge(values, args.provider, args.model, args.endpoint, args.extra_body)
        args.judge_id = args.judge_id or default_id
        os.environ["JUDGE_API_KEY"] = key
        run = args.run_dir or pipeline.HERE / (pipeline.HERE / "CURRENT_RUN.txt").read_text().strip()
        run = run.resolve()
        judge_args = argparse.Namespace(run_dir=run, judge_id=args.judge_id, model=model,
            command=None, endpoint=endpoint, api_key_env="JUDGE_API_KEY", extra_body=body,
            response_format=args.response_format, timeout=args.timeout, limit=args.limit, case=args.case)
        print(f"Run: {run.name}; provider: {args.provider}; Judge: {model}; credentials loaded (not displayed)", flush=True)
        error = None
        try:
            pipeline.judge(judge_args)
        except Exception as exc:
            error = f"{type(exc).__name__}: {exc}"
        status = execution_status(run, args.judge_id, model, error, provider=args.provider)
        print("Status:", json.dumps(status["states"], ensure_ascii=False), flush=True)
        print("Execution record:", run / "judges" / args.judge_id / "execution_status.md", flush=True)
        if error:
            parser.exit(1, error + "\n")
        if status["states"].get("validated_unreviewed"):
            pipeline.validate(judge_args)
            pipeline.summarize(judge_args)
    except (ValueError, OSError) as exc:
        parser.exit(1, f"Error: {exc}\n")


if __name__ == "__main__":
    main()
